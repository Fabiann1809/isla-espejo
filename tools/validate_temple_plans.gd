extends SceneTree
## Checks temple room plans with the game's own rules (TemplePlan) and answers which cells may hold a
## spawn or a prop, so the room generator (tools/make_temple_rooms.py) never writes an invalid room
## and never ports the rules. One source of truth: whatever `TemplePlan.validate` and `spawn_ok` say.
##
## Run: godot --headless --path . --script res://tools/validate_temple_plans.gd -- <in.json> <out.json>
##   in.json:  {"<room id>": {"rows": "<18 lines>", "surge_stages": 0..2, "height": 0..2}, ...}
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
