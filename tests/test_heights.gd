extends SceneTree
## Three height levels (see scripts/world/heights.gd): terrace footprints block only low actors, edges
## and rails only level-1 ones, top edges (layer 10) only level-2 ones, water only low ones, stairs
## change the level halfway, and arrows only stop at what blocks their level from below (a level-1 arrow
## at a layer-11 cliff). Flat rooms (nothing on layers 8 to 11) are not affected.
## Run: godot --headless --path . --script res://tests/test_heights.gd

var _ok := true


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var room: Node = load("res://scenes/levels/test_room.tscn").instantiate()
	for name in ["Trap1", "Trap2", "Grunt1", "Grunt2", "Dummy1", "Dummy2", "Dummy3"]:
		room.get_node(name).free()
	root.add_child(room)
	_wall(room, Rect2(200, 40, 32, 160), 8)    # a terrace footprint: blocks low actors
	_wall(room, Rect2(300, 40, 8, 160), 9)     # a rail: blocks high actors
	_wall(room, Rect2(380, 40, 40, 160), 7)    # water: blocks low actors only
	var stairs := _stairs(room, Vector2(520, 120), Vector2(64, 40), Vector2.RIGHT)
	await _frames(3)
	var player: Node2D = room.get_node("Player")

	_check(Heights.level_of(player) == Heights.LOW and player.get_collision_mask_value(8)
			and not player.get_collision_mask_value(9) and player.get_collision_mask_value(7),
			"Nico starts low: he collides with the low obstacles and the water")

	# Low: the terrace footprint stops him; high: he walks through it and the rail stops him.
	await _walk(player, Vector2(170, 120), "move_right", 60)
	_check(player.global_position.x < 200.0, "a low Nico is stopped by a terrace (x = %.0f)" % player.global_position.x)
	Heights.set_level(player, Heights.HIGH)
	await _walk(player, Vector2(170, 120), "move_right", 80)
	_check(player.global_position.x > 232.0 and player.global_position.x < 300.0,
			"a high Nico crosses the terrace and is stopped by its rail (x = %.0f)" % player.global_position.x)

	# Water: low stops at it, high walks over it (the rail is behind him).
	Heights.set_level(player, Heights.LOW)
	await _walk(player, Vector2(340, 120), "move_right", 50)
	_check(player.global_position.x < 380.0, "a low Nico cannot cross the water (x = %.0f)" % player.global_position.x)
	Heights.set_level(player, Heights.HIGH)
	await _walk(player, Vector2(340, 120), "move_right", 70)
	_check(player.global_position.x > 420.0, "a high Nico crosses the water, like on a bridge (x = %.0f)" % player.global_position.x)
	Heights.set_level(player, Heights.LOW)
	_check(player.get_collision_mask_value(7) and not player.get_collision_mask_value(9), "going down gives the water bit back")

	# Stairs: the level changes halfway up and halfway down.
	await _walk(player, Vector2(500, 120), "move_right", 24)
	_check(Heights.level_of(player) == Heights.HIGH, "walking up the stairs makes Nico high (x = %.0f)" % player.global_position.x)
	await _walk(player, player.global_position, "move_left", 40)
	_check(Heights.level_of(player) == Heights.LOW, "walking down the stairs makes him low again")

	# Enemies get their level too, and a flyer without the water bit never gets one.
	var grunt: Node2D = load("res://scenes/enemies/grunt.tscn").instantiate()
	room.add_child(grunt)
	await _frames(2)
	_check(Heights.level_of(grunt) == Heights.LOW and grunt.get_collision_mask_value(8), "an enemy starts low")
	var flyer := CharacterBody2D.new()
	flyer.collision_mask = 1
	Heights.set_level(flyer, Heights.HIGH)
	Heights.set_level(flyer, Heights.LOW)
	_check(not flyer.get_collision_mask_value(7), "a mask without water never gains it")
	flyer.free()
	grunt.queue_free()

	# Arrows: a low arrow stops at the terrace; a high one flies over it.
	player.global_position = Vector2(60, 60)
	var low_arrow := _arrow(room, Vector2(150, 120), Heights.LOW)
	var high_arrow := _arrow(room, Vector2(150, 160), Heights.HIGH)
	await _frames(30)
	_check(not is_instance_valid(low_arrow) or low_arrow.is_queued_for_deletion(), "a low arrow stops at a terrace")
	_check(is_instance_valid(high_arrow) and high_arrow.global_position.x > 240.0, "a high arrow flies over a terrace")
	_check(is_instance_valid(high_arrow) and not high_arrow.is_queued_for_deletion(), "and a rail does not stop it")

	# Three levels (the temple): layer 10 blocks level-2 actors, layer 11 is a cliff of height 2 that
	# only level-1 projectiles see. From the left: a footprint (8), a rail (9), a top edge (10), a cliff (11).
	_wall(room, Rect2(-440, -200, 16, 160), 8)
	_wall(room, Rect2(-404, -200, 8, 160), 9)
	_wall(room, Rect2(-376, -200, 24, 160), 10)
	_wall(room, Rect2(-330, -200, 24, 160), 11)
	var top_stairs := _stairs(room, Vector2(-200, -120), Vector2(64, 40), Vector2.RIGHT, 1)
	await _frames(2)
	_check(Heights.MID == 1 and Heights.HIGH == Heights.MID and Heights.TOP == 2 and Heights.LEVELS == 3,
			"the levels are LOW, MID (alias HIGH) and TOP")
	_check(Heights.block_layer(0) == 8 and Heights.block_layer(1) == 9 and Heights.block_layer(2) == 10,
			"each level has its own blocking layer")

	Heights.set_level(player, Heights.TOP)
	_check(player.get_collision_mask_value(10) and not player.get_collision_mask_value(8)
			and not player.get_collision_mask_value(9) and not player.get_collision_mask_value(11)
			and not player.get_collision_mask_value(7),
			"a level-2 body only has the mask bit of layer 10")
	await _walk(player, Vector2(-460, -120), "move_right", 60)
	_check(player.global_position.x > -396.0 and player.global_position.x < -352.0,
			"a level-2 Nico is stopped by layer 10 and passes layers 8 and 9 (x = %.0f)" % player.global_position.x)

	Heights.set_level(player, Heights.MID)
	_check(player.get_collision_mask_value(9) and not player.get_collision_mask_value(11),
			"a level-1 body never has the mask bit of layer 11")
	await _walk(player, Vector2(-344, -120), "move_right", 40)
	_check(player.global_position.x > -300.0,
			"a level-1 Nico is not stopped by layer 11 (x = %.0f)" % player.global_position.x)

	# Stairs with low_level 1 switch between levels 1 and 2.
	_check(top_stairs.low_level == 1, "a StairZone exports its low level")
	await _walk(player, Vector2(-220, -120), "move_right", 24)
	_check(Heights.level_of(player) == Heights.TOP,
			"stairs with low_level 1 move Nico up to level 2 (x = %.0f)" % player.global_position.x)
	await _walk(player, player.global_position, "move_left", 40)
	_check(Heights.level_of(player) == Heights.MID, "and back down to level 1")
	Heights.set_level(player, Heights.LOW)
	player.global_position = Vector2(60, 60)

	# Arrows: a level-1 arrow flies over rails and top edges and stops at a cliff; a level-2 one over all.
	var mid_arrow := _arrow(room, Vector2(-460, -150), Heights.MID)
	var top_arrow := _arrow(room, Vector2(-460, -90), Heights.TOP)
	_check(mid_arrow.get_node("WallSensor").get_collision_mask_value(11)
			and not mid_arrow.get_node("WallSensor").get_collision_mask_value(8)
			and not mid_arrow.get_node("WallSensor").get_collision_mask_value(9)
			and not mid_arrow.get_node("WallSensor").get_collision_mask_value(10),
			"a level-1 arrow's sensor sees only layer 11 (and the world)")
	await _frames(36)
	_check(not is_instance_valid(mid_arrow) or mid_arrow.is_queued_for_deletion(),
			"a level-1 arrow flies over a layer-9 rail and stops at a layer-11 cliff")
	_check(is_instance_valid(top_arrow) and not top_arrow.is_queued_for_deletion()
			and top_arrow.global_position.x > -306.0,
			"a level-2 arrow is stopped by none of 8, 9, 10, 11 (x = %.0f)" % (top_arrow.global_position.x if is_instance_valid(top_arrow) else -999.0))

	# Flyers: a body whose mask never had the water bit.
	var walker: Node2D = load("res://scenes/enemies/grunt.tscn").instantiate()
	room.add_child(walker)
	await _frames(2)
	var bat := CharacterBody2D.new()
	bat.collision_mask = 1
	_check(Heights.is_flyer(bat) and not Heights.is_flyer(walker), "a flyer is detected and a walker is not")
	_check(Heights.level_of(bat) == Heights.LOW and not bat.get_collision_mask_value(7),
			"asking a fresh body whether it flies gives it its level without a water bit")
	bat.free()
	walker.queue_free()

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _wall(room: Node, rect: Rect2, layer: int) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1 << (layer - 1)
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = rect.size
	body.add_child(shape)
	body.position = rect.get_center()
	room.add_child(body)
	return body


func _stairs(room: Node, center: Vector2, size: Vector2, direction: Vector2, low_level: int = 0) -> Area2D:
	var zone: Area2D = load("res://scripts/world/stair_zone.gd").new()
	zone.direction = direction
	zone.low_level = low_level
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = size
	zone.add_child(shape)
	zone.position = center
	room.add_child(zone)
	return zone


func _arrow(room: Node, at: Vector2, level: int) -> Node2D:
	var arrow = load("res://scenes/player/arrow.tscn").instantiate()
	arrow.setup(Vector2.RIGHT, 300.0, 200.0, 1)
	arrow.height_level = level
	room.add_child(arrow)
	arrow.global_position = at
	return arrow


func _walk(player: Node2D, from: Vector2, action: String, frames: int) -> void:
	player.global_position = from
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)
	await _frames(1)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
