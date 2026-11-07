extends SceneTree
## The lava surge of a temple room. Pure logic (LavaSurgeLogic): warn, rise, fight, recede, done, one or
## two stages, waves only while fighting, kills only while fighting. With nodes (a two-stage plan room):
## walking deep in triggers it and seals the doors, the lava burns Nico on level 0 once per interval and
## never on level 1, he can climb the stairs while flooded, waves appear only on the final safe level and
## far from him, a level-0 grunt burns and its death does not count, and after the kills the lava
## recedes, the doors open and the overlay is empty.
## Run: godot --headless --path . --script res://tests/test_lava_surge.gd

const PLAN := """
#############....#############
#~~~~....................~~~~#
#~~~~.....vv......vv.....~~~~#
#~~~~..1111111111111111..~~~~#
#......1122222222222211......#
#.....>1122222222222211<.....#
#.....>1122222222222211<.....#
.......1122222222222211.......
.......1122222222222211.......
.......1122222222222211.......
.......1111111^^1111111.......
#~~~~~.1111111111111111.~~~~~#
#~~~~~.1111111111111111.~~~~~#
#~~~~~....^^.^^^^.^^....~~~~~#
#~~~~~..................~~~~~#
#~~~~~..................~~~~~#
#~~~~~..................~~~~~#
#############....#############
"""

var _ok := true
var _damage_events := 0
var _received := []
var _warned := 0


func _initialize() -> void:
	create_timer(400.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_pure_logic()
	await _node_tests()
	await _fix_tests()
	Engine.time_scale = 1.0
	print("RESULT: " + ("OK" if _ok else "FAILED"))
	quit(0 if _ok else 1)


# --- pure logic ----------------------------------------------------------------------------------------
func _pure_logic() -> void:
	var logic_script: GDScript = load("res://scripts/world/lava_surge_logic.gd")
	_check(logic_script != null, "scripts/world/lava_surge_logic.gd exists")
	if logic_script == null:
		return
	var one = logic_script.new(1, 3, 3)
	_check(one.state == one.State.IDLE and one.flooded_levels() == 0, "a surge starts idle and dry")
	one.start()
	var events: Array = one.step(0.05)
	_check(&"warn" in events and one.state == one.State.WARNING, "one-stage: start warns")
	events = _run(one, Tuning.TEMPLE_SURGE_WARN_SECONDS)
	_check(&"rise" in events and one.state == one.State.RISING and one.flooded_levels() == 1, "one-stage: the lava rises to stage 1")
	events = _run(one, Tuning.TEMPLE_SURGE_RISE_SECONDS + 0.2)
	_check(&"risen" in events and one.state == one.State.FIGHT, "one-stage: it fights once risen")
	for i in 3:
		one.on_kill()
	events = _run(one, 0.2)
	_check(&"recede" in events and one.state == one.State.RECEDING, "one-stage: the kills make it recede")
	events = _run(one, Tuning.TEMPLE_SURGE_RECEDE_SECONDS + 0.2)
	_check(&"receded" in events and one.state == one.State.DONE and one.flooded_levels() == 0, "one-stage: done and dry")

	var two = logic_script.new(2, 2, 3)
	two.start()
	_run(two, Tuning.TEMPLE_SURGE_WARN_SECONDS + Tuning.TEMPLE_SURGE_RISE_SECONDS + 0.3)
	_check(two.state == two.State.FIGHT and two.flooded_levels() == 1, "two-stage: stage 1 fights")
	two.on_kill()
	two.on_kill()
	events = _run(two, 0.2)
	_check(&"warn" in events and two.state == two.State.WARNING and two.kills == 0, "two-stage: kills_stage_1 warn the next rise and reset the kills")
	events = _run(two, Tuning.TEMPLE_SURGE_WARN_SECONDS)
	_check(&"rise" in events and two.flooded_levels() == 2, "two-stage: the lava rises to stage 2")
	_run(two, Tuning.TEMPLE_SURGE_RISE_SECONDS + 0.2)
	for i in 3:
		two.on_kill()
	_run(two, 0.2)
	_run(two, Tuning.TEMPLE_SURGE_RECEDE_SECONDS + 0.1)
	_check(two.state == two.State.RECEDING and two.flooded_levels() == 1, "two-stage: it recedes one level at a time")
	events = _run(two, Tuning.TEMPLE_SURGE_RECEDE_SECONDS + 0.1)
	_check(two.state == two.State.DONE and &"receded" in events, "two-stage: done after the second level")

	var waves = logic_script.new(1, 99, 99)
	waves.start()
	var before := 0
	var t := 0.0
	while waves.state != waves.State.FIGHT and t < 20.0:
		before += _count(waves.step(0.1), &"spawn_wave")
		t += 0.1
	_check(before == 0, "waves are not requested before the fight")
	var during := 0
	for i in int(Tuning.TEMPLE_SURGE_WAVE_INTERVAL * 2.5 * 10.0):
		during += _count(waves.step(0.1), &"spawn_wave")
	_check(during == 2, "waves are requested every interval during the fight (%d in 2.5 intervals)" % during)
	waves.on_kill()
	var idle = logic_script.new(1, 1, 1)
	idle.on_kill()
	_check(idle.kills == 0, "kills outside the fight do not count")


func _run(logic, seconds: float) -> Array:
	var all := []
	var left := seconds
	while left > 0.0:
		var d := minf(0.05, left)
		all.append_array(logic.step(d))
		left -= d
	return all


func _count(events: Array, name: StringName) -> int:
	return events.count(name)


# --- with nodes ---------------------------------------------------------------------------------------
func _node_tests() -> void:
	var theme: Resource = load("res://data/themes/temple.tres")
	TileArt.use_profile(theme.tileset)
	var room: Node2D = load("res://scenes/levels/rooms/room_base.tscn").instantiate()
	room.theme = theme
	room.debug_label = false
	var data: Resource = load("res://scripts/world/room_data.gd").new()
	data.id = "surge_test"
	data.surge_stages = 2
	data.kills_stage_1 = 2
	data.kills_to_recede = 2
	data.wave_size = 2
	data.max_alive = 4
	var doors: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	room.setup(data, doors)
	var shape: Node2D = load("res://scripts/world/temple_shape.gd").new()
	shape.name = "Shape"
	shape.rows = PLAN
	room.add_child(shape)
	root.add_child(room)
	var player: Node2D = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(8, 152)
	room.add_child(player)
	await _frames(3)
	_check(shape.plan.validate(2).is_empty(), "the test plan is a valid two-stage surge room (%s)" % [shape.plan.validate(2)])
	var events = root.get_node("Events")
	player.health.set_max_health(60)
	events.player_damaged.connect(func(amount: int, _from: Vector2) -> void: _damage_events += amount)
	events.lava_surge_warned.connect(func(_r: Node, _s: int) -> void: _warned += 1)
	events.lava_surge_started.connect(func(_r: Node, s: int) -> void: _received.append(["started", s]))
	events.lava_surge_receded.connect(func(_r: Node) -> void: _received.append(["receded", 0]))

	var roster: Array[PackedScene] = [load("res://scenes/enemies/grunt.tscn")]
	var surge_script: GDScript = load("res://scripts/world/lava_surge.gd")
	_check(surge_script != null, "scripts/world/lava_surge.gd exists")
	if surge_script == null:
		return
	var surge = surge_script.attach_to(room, roster)
	_check(surge != null and surge.get_parent() == room, "attach_to adds the surge to the room")
	var plain: Resource = load("res://scripts/world/room_data.gd").new()
	var other: Node2D = load("res://scenes/levels/rooms/room_base.tscn").instantiate()
	other.debug_label = false
	other.setup(plain, doors)
	_check(surge_script.attach_to(other, roster) == null, "a room without stages gets no surge")
	other.free()
	await _frames(2)
	Engine.time_scale = 1.0
	# Every physics frame: the most enemies alive at once, and the most alive plus warning rings pending.
	var peaks := {"alive": 0, "with_rings": 0}
	physics_frame.connect(func() -> void:
		if is_instance_valid(room) and is_instance_valid(surge):
			peaks["alive"] = maxi(peaks["alive"], room.enemies_alive)
			peaks["with_rings"] = maxi(peaks["with_rings"], room.enemies_alive + surge._incoming))
	# Every enemy that enters the room after this point, with the cell Nico stood in at that moment.
	var spawned: Array = []
	room.child_entered_tree.connect(func(node: Node) -> void:
		if node.get_script() != null and node.has_method("apply_frenzy") and node.position.y > 0.0 and node.name != "Burner":
			var nico := Vector2((player.position / 16.0).floor())
			node.ready.connect(func() -> void:
				spawned.append({"cell": Vector2i((node.position / 16.0).floor()), "level": Heights.level_of(node), "nico": nico})))

	# Waiting at the door does not trigger it; stepping in deep does.
	_check(surge.logic.state == surge.logic.State.IDLE, "at the door the surge sleeps")
	_check(surge.safe_spawn_cells().size() >= 60 and surge.safe_spawn_cells().all(func(c: Vector2i) -> bool:
			return shape.plan.height_at(c) == 2 and shape.plan.spawn_ok(c)), "the safe cells are spawn_ok cells of level 2")
	player.global_position = room.global_position + Vector2(88, 136)
	Heights.set_level(player, 0)
	await _frames(4)
	_check(surge.logic.state == surge.logic.State.WARNING, "entering deep triggers the surge")
	var seals := 0
	for child in surge.get_children():
		if child is StaticBody2D and child.get_collision_layer_value(1):
			seals += 1
	_check(seals == 4, "the doors seal: a body in each of the 4 gaps (%d)" % seals)
	_check(_warned == 1, "the warning is published once")
	await _frames(int((Tuning.TEMPLE_SURGE_WARN_SECONDS + 0.5) * 60))
	_check(surge.logic.state == surge.logic.State.RISING, "the lava is rising")
	var half: int = surge.overlay_cell_count()
	_check(half == 0 or half < surge.flood_total(0), "the lava has not popped in (%d of %d)" % [half, surge.flood_total(0)])
	await _frames(int((Tuning.TEMPLE_SURGE_RISE_SECONDS / 2.0) * 60))
	var mid: int = surge.overlay_cell_count()
	_check(mid > half and mid < surge.flood_total(0), "mid-rise the lava covers part of level 0 (%d of %d)" % [mid, surge.flood_total(0)])
	await _frames(int((Tuning.TEMPLE_SURGE_RISE_SECONDS) * 60))
	_check(surge.logic.state == surge.logic.State.FIGHT and surge.overlay_cell_count() == surge.flood_total(0),
			"risen: level 0 is fully covered (%d)" % surge.overlay_cell_count())
	_check(_received.has(["started", 1]), "lava_surge_started(room, 1) was published")

	# Damage: level 0 burns once per interval, level 1 never.
	player.global_position = room.global_position + Vector2(56, 120)
	Heights.set_level(player, 0)
	_damage_events = 0
	await _frames(120)
	_check(_damage_events >= 1 and _damage_events <= 3, "Nico on level 0 takes 1 damage per interval (%d in 2 s)" % _damage_events)
	player.global_position = room.global_position + Vector2(136, 184)
	Heights.set_level(player, 1)
	await _frames(10)
	_damage_events = 0
	await _frames(150)
	_check(_damage_events == 0, "Nico on level 1 takes no damage in stage 1 (%d)" % _damage_events)

	# A level-0 grunt burns and its death does not count.
	var grunt: Node2D = roster[0].instantiate()
	grunt.position = Vector2(40, 120)
	grunt.name = "Burner"
	room.add_child(grunt)
	grunt.health.set_max_health(1)
	room.register_enemy(grunt)
	var kills_before: int = surge.logic.kills
	await _frames(140)
	_check(not is_instance_valid(grunt) or grunt.health.is_dead(), "a level-0 grunt burns to death")
	_check(surge.logic.kills == kills_before, "its death does not count as a kill (%d)" % surge.logic.kills)

	# Nico climbs the stairs while flooded.
	player.global_position = room.global_position + Vector2(72, 104)
	Heights.set_level(player, 0)
	var climbed := false
	for i in 180:
		var target := room.global_position + Vector2(110, 96)
		var to := target - player.global_position
		_press("move_up", to.y < -3.0)
		_press("move_down", to.y > 3.0)
		_press("move_right", to.x > 3.0)
		_press("move_left", to.x < -3.0)
		await physics_frame
		if Heights.level_of(player) >= 1:
			climbed = true
			break
	for action in ["move_up", "move_down", "move_left", "move_right"]:
		Input.action_release(action)
	_check(climbed, "Nico on level 0 climbs the stairs while the lava burns")

	# Waves: only on level 2 and never within 4 cells of Nico.
	player.global_position = room.global_position + Vector2(240, 150)
	Heights.set_level(player, 2)
	var alive_before: int = room.enemies_alive
	await _frames(int((Tuning.TEMPLE_SURGE_WAVE_INTERVAL + Tuning.TEMPLE_SURGE_SPAWN_WARN + 1.0) * 60))
	# The wave's timer runs on game time and the wait above on physics frames; under load they drift,
	# so wait a little longer (at most as long again) for the wave to land before judging it.
	var extra := int((Tuning.TEMPLE_SURGE_WAVE_INTERVAL + Tuning.TEMPLE_SURGE_SPAWN_WARN + 1.0) * 60)
	while extra > 0 and room.enemies_alive <= alive_before:
		await physics_frame
		extra -= 1
	_check(spawned.size() >= 1, "a wave appeared (%d)" % spawned.size())
	var good := not spawned.is_empty()
	for entry in spawned:
		var cell: Vector2i = entry["cell"]
		var cells_from_nico := Vector2(cell).distance_to(entry["nico"])
		if not (shape.plan.spawn_ok(cell) and shape.plan.height_at(cell) == 2 and entry["level"] == 2):
			good = false
		if cells_from_nico < float(Tuning.TEMPLE_SURGE_SPAWN_MIN_DISTANCE) - 0.01:
			good = false
	_check(good, "waves spawn only on the safe level, at least 4 cells from Nico")
	_check(room.enemies_alive > alive_before and room.enemies_alive <= data.max_alive, "never more than max_alive alive (%d)" % room.enemies_alive)

	# Two kills raise the lava to stage 2: level 1 burns now.
	await _kill_enemies(room, 2)
	await _frames(int((Tuning.TEMPLE_SURGE_WARN_SECONDS + Tuning.TEMPLE_SURGE_RISE_SECONDS + 1.0) * 60))
	_check(surge.logic.flooded_levels() == 2 and surge.overlay_cell_count() == surge.flood_total(0) + surge.flood_total(1),
			"two kills raise the lava to stage 2 (%d cells)" % surge.overlay_cell_count())
	player.global_position = room.global_position + Vector2(136, 184)
	Heights.set_level(player, 1)
	_damage_events = 0
	await _frames(100)
	_check(_damage_events >= 1, "in stage 2 level 1 burns (%d)" % _damage_events)
	player.global_position = room.global_position + Vector2(240, 150)
	Heights.set_level(player, 2)
	player.health.heal(60)

	# The recede: kills, then everything dead, doors open, overlay empty.
	await _kill_enemies(room, 2)
	var seals_still: int = surge.get_children().filter(func(c: Node) -> bool: return c is StaticBody2D).size()
	_check(seals_still == 4, "the doors stay sealed while the lava is up")
	await _frames(int((Tuning.TEMPLE_SURGE_RECEDE_SECONDS * 2.0 + 1.0) * 60))
	_check(surge.logic.state == surge.logic.State.DONE, "the lava has receded")
	_check(surge.overlay_cell_count() == 0, "the overlay is empty (%d)" % surge.overlay_cell_count())
	await _kill_all(room)
	await _frames(20)
	seals_still = surge.get_children().filter(func(c: Node) -> bool: return c is StaticBody2D).size()
	_check(seals_still == 0, "after the room is cleared the doors open (%d bodies)" % seals_still)
	_check(peaks["alive"] <= data.max_alive, "never more than max_alive enemies alive at once (peak %d of %d)" % [peaks["alive"], data.max_alive])
	_check(peaks["with_rings"] <= data.max_alive, "pending warning rings count toward max_alive (peak %d of %d)" % [peaks["with_rings"], data.max_alive])
	_check(_received.has(["receded", 0]), "lava_surge_receded was published")
	_check(surge._seal_pulses.is_empty(), "the seal's pulse tweens are killed when the doors open")
	room.queue_free()
	await _frames(3)


# --- fix round 1: no softlock, cleared without a trigger ----------------------------------------------------
## A room that is all level-0 floor: nothing can ever be spawned on a safe level 1.
func _flat_plan() -> String:
	var lines: Array[String] = []
	for y in 18:
		var line := ""
		for x in 30:
			var ring := x == 0 or y == 0 or x == 29 or y == 17
			var door := ((y == 0 or y == 17) and x >= 13 and x <= 16) or ((x == 0 or x == 29) and y >= 7 and y <= 10)
			line += "." if (door or not ring) else "#"
		lines.append(line)
	return "\n" + "\n".join(lines) + "\n"


## A one-stage surge room on the flat plan with one tough grunt, Nico at `nico_at`. Returns the pieces.
func _flat_room(roster: Array[PackedScene], nico_at: Vector2) -> Dictionary:
	var theme: Resource = load("res://data/themes/temple.tres")
	var room: Node2D = load("res://scenes/levels/rooms/room_base.tscn").instantiate()
	room.theme = theme
	room.debug_label = false
	var data: Resource = load("res://scripts/world/room_data.gd").new()
	data.id = "surge_flat"
	data.surge_stages = 1
	data.kills_to_recede = 2
	var doors: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	room.setup(data, doors)
	var shape: Node2D = load("res://scripts/world/temple_shape.gd").new()
	shape.name = "Shape"
	shape.rows = _flat_plan()
	room.add_child(shape)
	root.add_child(room)
	var player: Node2D = load("res://scenes/player/player.tscn").instantiate()
	player.position = nico_at
	room.add_child(player)
	await _frames(3)
	player.health.set_max_health(99)
	var grunt: Node2D = load("res://scenes/enemies/grunt.tscn").instantiate()
	grunt.position = Vector2(120, 60)
	room.add_child(grunt)
	grunt.health.set_max_health(99)
	room.register_enemy(grunt)
	var surge = load("res://scripts/world/lava_surge.gd").attach_to(room, roster)
	await _frames(3)
	return {"room": room, "player": player, "grunt": grunt, "surge": surge}


func _fix_tests() -> void:
	var grunt_scene: PackedScene = load("res://scenes/enemies/grunt.tscn")
	var none: Array[PackedScene] = []
	var some: Array[PackedScene] = [grunt_scene]
	var deep := Vector2(240, 150)

	# The fallback pool is used when the roster is empty.
	var parts := await _flat_room(none, Vector2(8, 152))
	var fallback = load("res://scripts/world/lava_surge.gd").attach_to(parts["room"], none, some)
	_check(fallback != null and fallback.roster.size() == 1, "an empty roster falls back to the given pool")
	fallback.free()
	parts["room"].queue_free()
	await _frames(3)

	# Empty roster: the surge is won as soon as the initial enemies are dead.
	parts = await _flat_room(none, deep)
	var room: Node2D = parts["room"]
	var surge = parts["surge"]
	var cleared := [0]
	room.cleared.connect(func() -> void: cleared[0] += 1)
	await _frames(int((Tuning.TEMPLE_SURGE_WARN_SECONDS + Tuning.TEMPLE_SURGE_RISE_SECONDS + 0.5) * 60))
	_check(surge.logic.state == surge.logic.State.FIGHT, "flat room: the fight starts (%d)" % surge.logic.state)
	_check(cleared[0] == 0, "the room is held while the lava is up")
	parts["grunt"].health.take_damage(999)
	await _frames(int((Tuning.TEMPLE_SURGE_RECEDE_SECONDS + 1.5) * 60))
	_check(surge.logic.state == surge.logic.State.DONE, "an empty roster recedes after the room is cleared")
	_check(cleared[0] >= 1 and surge.overlay_cell_count() == 0, "the room reports cleared and the lava is gone")
	await _frames(40)
	_check(surge.get_children().filter(func(c: Node) -> bool: return c is StaticBody2D).is_empty(), "the doors are open")
	room.queue_free()
	await _frames(3)

	# A roster but no cell to spawn on: the failsafe recedes it after a few wave intervals.
	parts = await _flat_room(some, deep)
	room = parts["room"]
	surge = parts["surge"]
	_check(surge.safe_spawn_cells().is_empty(), "flat room: there is no safe cell to spawn on")
	await _frames(int((Tuning.TEMPLE_SURGE_WARN_SECONDS + Tuning.TEMPLE_SURGE_RISE_SECONDS + 0.5) * 60))
	parts["grunt"].health.take_damage(999)
	await _frames(int((Tuning.TEMPLE_SURGE_WAVE_INTERVAL * 2.0) * 60))
	_check(surge.logic.state == surge.logic.State.FIGHT, "before the stall limit the fight goes on")
	await _frames(int((Tuning.TEMPLE_SURGE_WAVE_INTERVAL * 1.5 + Tuning.TEMPLE_SURGE_RECEDE_SECONDS + 1.5) * 60))
	_check(surge.logic.state == surge.logic.State.DONE, "no spawnable cell does not softlock")
	await _frames(40)
	_check(surge.get_children().filter(func(c: Node) -> bool: return c is StaticBody2D).is_empty(), "the doors open after the failsafe")
	room.queue_free()
	await _frames(3)

	# Enemies dead before Nico goes deep: the room reports cleared and the surge never springs.
	parts = await _flat_room(some, Vector2(8, 152))
	room = parts["room"]
	surge = parts["surge"]
	var reported := [0]
	room.cleared.connect(func() -> void: reported[0] += 1)
	parts["grunt"].health.take_damage(999)
	await _frames(10)
	_check(reported[0] == 1, "a room whose enemies die before the trigger still reports cleared")
	parts["player"].global_position = room.global_position + deep
	await _frames(60)
	_check(surge.logic.state == surge.logic.State.IDLE and surge.get_children().filter(
			func(c: Node) -> bool: return c is StaticBody2D).is_empty(), "a cleared room does not spring the surge")
	room.queue_free()
	await _frames(3)


## Kills `count` living enemies of the room by dealing lethal damage to their health (a real death).
func _kill_enemies(room: Node, count: int) -> void:
	var killed := 0
	for i in 40:
		for child in room.get_children():
			if killed >= count:
				return
			if child.is_in_group("enemies") and not child.health.is_dead():
				child.health.take_damage(999)
				killed += 1
		if killed >= count:
			return
		await _frames(30)


func _kill_all(room: Node) -> void:
	for i in 20:
		var any := false
		for child in room.get_children():
			if child.is_in_group("enemies") and not child.health.is_dead():
				child.health.take_damage(999)
				any = true
		if not any:
			return
		await _frames(10)


func _press(action: String, down: bool) -> void:
	if down:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
