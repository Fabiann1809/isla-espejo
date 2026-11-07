extends SceneTree
## Checks temple room plans with the game's own rules (TemplePlan) and answers which cells may hold a
## spawn or a prop, so the room generator (tools/make_temple_rooms.py) never writes an invalid room
## and never ports the rules. One source of truth: whatever `TemplePlan.validate` and `spawn_ok` say.
##
## Run: godot --headless --path . --script res://tools/validate_temple_plans.gd -- <in.json> <out.json>
##   in.json:  {"<room id>": {"rows": "<18 lines>", "surge_stages": 0..2, "height": 0..2,
##              "blocked": [[x, y, level], ...], "markers": [[x, y], ...]}, ...}
##   `blocked` (optional) are the cells every SOLID prop's footprint covers at its level, `markers` every
##   spawn, chest, NPC, boss, exit and player cell: `check_props` then judges the room with the props in place.
##   out.json: {"<room id>": {"problems": [...], "base_height": h, "spawn_ok": [[x, y], ...],
##              "reached": [[x, y, level], ...], "heights": [[h per cell], ...]}, ...}
## `reached` lists every inner cell reached from the doors at that level (where a prop may stand);
## `heights` is the plan's height per cell (-1 lava, 99 masonry).
## tools/make_temple_data.gd uses `check` on the scenes it reads, so the data step refuses them too.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: -- <in.json> <out.json>")
		quit(2)
		return
	var file := FileAccess.open(args[0], FileAccess.READ)
	if file == null:
		printerr("cannot read %s" % args[0])
		quit(2)
		return
	var plans: Variant = JSON.parse_string(file.get_as_text())
	if not plans is Dictionary:
		printerr("%s is not a JSON object" % args[0])
		quit(2)
		return
	var out := {}
	var invalid := 0
	for id in plans:
		var spec: Dictionary = plans[id]
		var result := check(spec["rows"], int(spec.get("surge_stages", 0)), int(spec.get("height", 0)))
		if spec.has("blocked") and result["problems"].is_empty():
			var blocked: Array[Vector3i] = []
			for entry in spec["blocked"]:
				blocked.append(Vector3i(int(entry[0]), int(entry[1]), int(entry[2])))
			var markers: Array[Vector2i] = []
			for entry in spec.get("markers", []):
				markers.append(Vector2i(int(entry[0]), int(entry[1])))
			result["problems"].append_array(check_props(TemplePlan.parse(spec["rows"]), blocked, markers))
		out[id] = result
		if not result["problems"].is_empty():
			invalid += 1
			printerr("%s: %s" % [id, "; ".join(result["problems"])])
	var writer := FileAccess.open(args[1], FileAccess.WRITE)
	writer.store_string(JSON.stringify(out))
	writer.close()
	print("%d plans checked, %d invalid" % [plans.size(), invalid])
	quit(0 if invalid == 0 else 1)


## The verdict on one plan: the design's problems (with the surge rules when `surge_stages` > 0 and a
## complaint when its base height is not `height`), plus the cells for spawns and props.
static func check(rows: String, surge_stages: int, height: int) -> Dictionary:
	var plan := TemplePlan.parse(rows)
	var problems: Array = plan.validate(surge_stages)
	if plan.errors.is_empty() and plan.base_height != height:
		problems.append("the plan's base height is %d, the room's is %d" % [plan.base_height, height])
	var spawn_ok: Array = []
	var reached: Array = []
	var heights: Array = []
	if plan.errors.is_empty():
		var regions: Dictionary = plan.level_regions()
		for y in TemplePlan.ROWS:
			var row: Array = []
			for x in TemplePlan.COLUMNS:
				var cell := Vector2i(x, y)
				row.append(plan.height_at(cell))
				if plan.spawn_ok(cell):
					spawn_ok.append([x, y])
			heights.append(row)
		for level in regions:
			for cell in regions[level]:
				reached.append([cell.x, cell.y, level])
	return {"problems": problems, "base_height": plan.base_height, "spawn_ok": spawn_ok, "reached": reached, "heights": heights}


## The problems of a room with its solid props in place. `blocked` holds the (x, y, level) states the props'
## footprints cover (`TempleProp.blocks_cells()` at the prop's level), `markers` the cells of every spawn.
## Reachability is rebuilt over (cell, level) like `TemplePlan` does it, minus the blocked states: every door
## still reaches the others, nothing that was reachable is cut off (the footprints apart), every marker is
## reachable, and every stair end, bridge end and the cell in front of each is free of solid props.
static func check_props(plan: TemplePlan, blocked: Array[Vector3i], markers: Array[Vector2i]) -> Array[String]:
	var problems: Array[String] = []
	var solid := {}
	for state in blocked:
		solid[state] = true
	var before: Dictionary = plan._reach_from_doors()
	var after := _reach_without(plan, solid)
	var doors := TemplePlan.door_cells()
	for door_name in TemplePlan.DOOR_NAMES:
		var cells: Array[Vector2i] = doors[door_name]
		if not cells.any(func(c: Vector2i) -> bool: return after.has(Vector3i(c.x, c.y, plan.base_height))):
			problems.append("with the props in place the %s door cannot be reached from the north door" % door_name)
	var cut: Array[String] = []
	for state in before:
		if not after.has(state) and not solid.has(state):
			cut.append("(%d, %d) at level %d" % [state.x, state.y, state.z])
	for i in mini(cut.size(), 3):
		problems.append("the props cut off the cell %s" % cut[i])
	if cut.size() > 3:
		problems.append("the props cut off %d more cells" % (cut.size() - 3))
	for marker in markers:
		var level := plan.height_at(marker)
		if solid.has(Vector3i(marker.x, marker.y, level)):
			problems.append("the marker at (%d, %d) stands inside a solid prop" % [marker.x, marker.y])
		elif not after.has(Vector3i(marker.x, marker.y, level)):
			problems.append("the marker at (%d, %d) is not reachable with the props in place" % [marker.x, marker.y])
	for entry in approaches(plan):
		var cell: Vector2i = entry["cell"]
		if solid.has(Vector3i(cell.x, cell.y, entry["level"])):
			problems.append("a solid prop stands on %s (%d, %d)" % [entry["what"], cell.x, cell.y])
	return problems


## BFS over (cell, level) from the north door like `TemplePlan._reach_from_doors`, skipping blocked states.
static func _reach_without(plan: TemplePlan, solid: Dictionary) -> Dictionary:
	var visited := {}
	var queue: Array[Vector3i] = []
	for cell in TemplePlan.door_cells()["north"]:
		var start := Vector3i(cell.x, cell.y, plan.base_height)
		if plan.is_walkable(cell, plan.base_height) and not solid.has(start):
			queue.append(start)
			visited[start] = true
	var head := 0
	while head < queue.size():
		var state := queue[head]
		head += 1
		var cell := Vector2i(state.x, state.y)
		var level := state.z
		var next: Array[Vector3i] = []
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = cell + dir
			if plan.is_walkable(n, level) and plan._stair_step_ok(cell, n, level):
				next.append(Vector3i(n.x, n.y, level))
		if plan.is_stair(cell):
			var other := plan.height_at(cell) + 1 if level == plan.height_at(cell) else plan.height_at(cell)
			next.append(Vector3i(cell.x, cell.y, other))
		for state2 in next:
			if not visited.has(state2) and not solid.has(state2):
				visited[state2] = true
				queue.append(state2)
	return visited


## Every cell a solid prop must leave free: the walkable cell at each stair end and bridge end, and the one in
## front of it (further along the same line). `{cell, level, what}` each.
static func approaches(plan: TemplePlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for zone in plan.stairs():
		var rect: Rect2i = zone["cells"]
		var dir: Vector2i = zone["direction"]
		var low: int = zone["low_level"]
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				_add_approach(plan, out, cell - dir, dir * -1, low, "the low end of the stair at (%d, %d), cell" % [x, y])
				_add_approach(plan, out, cell + dir, dir, low + 1, "the high end of the stair at (%d, %d), cell" % [x, y])
	for y in range(1, TemplePlan.ROWS - 1):
		for x in range(1, TemplePlan.COLUMNS - 1):
			var cell := Vector2i(x, y)
			var c := plan.cell_at(cell)
			if not TemplePlan.DECKS.has(c):
				continue
			var level := plan.height_at(cell)
			for axis in _deck_axes(plan, cell):
				for sgn in [1, -1]:
					var step: Vector2i = axis * sgn
					if TemplePlan.DECKS.has(plan.cell_at(cell + step)):
						continue
					_add_approach(plan, out, cell + step, step, level, "the end of the bridge at (%d, %d), cell" % [x, y])
	return out


## The axes a deck cell's bridge runs along: `=` west-east, `|` north-south, a raised deck along its longer run.
static func _deck_axes(plan: TemplePlan, cell: Vector2i) -> Array[Vector2i]:
	var c := plan.cell_at(cell)
	if c == "=":
		return [Vector2i.RIGHT]
	if c == "|":
		return [Vector2i.DOWN]
	var across := _run(plan, cell, Vector2i.RIGHT)
	var down := _run(plan, cell, Vector2i.DOWN)
	if across > down:
		return [Vector2i.RIGHT]
	if down > across:
		return [Vector2i.DOWN]
	return [Vector2i.RIGHT, Vector2i.DOWN]


static func _run(plan: TemplePlan, cell: Vector2i, dir: Vector2i) -> int:
	var c := plan.cell_at(cell)
	var n := 1
	for sgn in [1, -1]:
		var at: Vector2i = cell + dir * sgn
		while plan.cell_at(at) == c:
			n += 1
			at += dir * sgn
	return n


static func _add_approach(plan: TemplePlan, out: Array[Dictionary], cell: Vector2i, dir: Vector2i, level: int, what: String) -> void:
	if not TemplePlan.is_inner(cell) or plan.is_stair(cell) or not plan.is_walkable(cell, level):
		return
	out.append({"cell": cell, "level": level, "what": what})
	var front := cell + dir
	if TemplePlan.is_inner(front) and not plan.is_stair(front) and plan.is_walkable(front, level):
		out.append({"cell": front, "level": level, "what": what + " (in front)"})
