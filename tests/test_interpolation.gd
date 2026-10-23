extends SceneTree
## Physics interpolation: every jump of a body (Nico placed on a new map, enemies and NPCs spawned,
## the Sombra skill) resets the interpolation in that same tick, so nothing is drawn sliding from its
## old position. Run: godot --headless --path . --script res://tests/test_interpolation.gd

const META := &"interpolation_reset_tick"
const ARENA := Vector2(300, 180)

var _ok := true


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_check(ProjectSettings.get_setting("physics/common/physics_interpolation") == true,
			"physics interpolation is on")

	# --- A level: Nico's placement, every enemy and every NPC/boss/chest spawned on the map.
	var level = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.seed_value = 4242
	level.use_director = false
	root.add_child(level)
	await _frames(3)
	var player = level.player
	_check(player.get_meta(META, -1) >= 0, "Nico is placed on the map with a reset")
	var spawned := get_nodes_in_group("enemies") + get_nodes_in_group("npcs")
	var all_reset := not spawned.is_empty()
	for node in spawned:
		all_reset = all_reset and node.has_meta(META)
	_check(all_reset, "every enemy, boss and NPC spawned on the map is reset (%d)" % spawned.size())

	# --- A new map (what the exit portal and "new map" do): the player jumps across the world.
	# He walked somewhere before taking the exit.
	player.global_position += Vector2(300, -200)
	var old_position: Vector2 = player.global_position
	level.generate(777)
	var tick := Engine.get_physics_frames()
	_check(player.get_meta(META, -1) == tick and player.global_position != old_position,
			"on a new map Nico jumps to the start with a reset in the same tick")
	_check(player.get_node("Camera2D").get_meta(META, -1) == tick, "the camera jumps with him instead of gliding")
	level.queue_free()
	await _frames(2)

	# --- The Sombra skill: a short teleport.
	var room = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(room)
	await _frames(3)
	var nico = room.get_node("Player")
	nico.global_position = ARENA
	nico.facing = Vector2.RIGHT
	nico.skills.unlock(load("res://data/skills/shadow.tres"))
	await _frames(2)
	var before: Vector2 = nico.global_position
	var shadow: Resource = load("res://data/skills/shadow.tres")
	var used: bool = nico.skills.try_use(shadow.slot)
	var cast_tick := Engine.get_physics_frames()
	_check(used and nico.global_position.distance_to(before) > 50.0 and nico.get_meta(META, -1) == cast_tick,
			"the Sombra skill teleports Nico with a reset in the same tick")

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
