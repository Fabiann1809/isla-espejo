extends SceneTree
## Forjador condenado test, with real physics: it calls iron blocks down (special animation) with a
## warning circle on each spot, the first on Nico; the impact hurts him and the block over him
## shatters instead of shutting him in; the others stand as solid obstacles on the world layer that
## stop a moving body and arrows, then cool down and go away; no block lands in a door lane of its
## room and it never has more than its cap standing.
## Run: godot --headless --path . --script res://tests/test_forjador_condenado.gd

## A room-sized home (30x18 tiles) inside the test room's walls; its door lanes cross its middle.
const HOME := Rect2(-140, -104, 480, 288)
## A spot of the room out of its door lanes.
const QUADRANT := Vector2(-40, -40)

var _ok := true
var _room: Node2D
var _player: Node2D
var _scene: PackedScene
var _block_script: Script
var _zone_script: Script


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_room = load("res://scenes/levels/test_room.tscn").instantiate()
	for node_name in ["Trap1", "Trap2", "Grunt1", "Grunt2", "Dummy1", "Dummy2", "Dummy3"]:
		_room.get_node(node_name).free()
	root.add_child(_room)
	await _frames(3)
	_player = _room.get_node("Player")
	_player.health.set_max_health(50)
	_scene = load("res://scenes/enemies/forjador_condenado.tscn")
	_block_script = load("res://scripts/enemies/iron_block.gd")
	_zone_script = load("res://scripts/skills/skill_zone.gd")

	var forger = _spawn(QUADRANT + Vector2(100, 0))
	var frames: SpriteFrames = forger.data.sprite_frames
	for anim: StringName in [&"idle", &"walk", &"run", &"attack", &"special", &"hurt", &"death"]:
		_check(frames.has_animation(anim) and frames.get_frame_count(anim) > 0, "forger has %s" % anim)
	_check(forger.data is DoomedForgerData, "the forger uses a DoomedForgerData")
	_check(forger.health.max_health >= 4 and forger.health.max_health <= 8 and forger.data.attack_damage == 1,
			"hard-roguelike stats (%d hp)" % forger.health.max_health)
	forger.free()
	await _blocks_fall_and_stand()
	await _never_in_door_lanes()
	await _capped()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _blocks_fall_and_stand() -> void:
	_player.global_position = QUADRANT
	var forger = _spawn(QUADRANT + Vector2(100, 0))
	var hp: int = _player.health.current
	var saw_special := false
	var blocks: Array = []
	for i in 240:
		await physics_frame
		saw_special = saw_special or forger.get_node("Sprite").animation == &"special"
		blocks = _blocks()
		if not blocks.is_empty():
			break
	_check(saw_special, "the drop plays the special animation")
	_check(blocks.size() == forger.data.blocks_per_drop, "it drops %d blocks (%d)" % [forger.data.blocks_per_drop, blocks.size()])
	var on_nico = null
	for block in blocks:
		if block.global_position.distance_to(QUADRANT) < 1.0:
			on_nico = block
	_check(on_nico != null, "the first block falls on Nico")
	var warned := true
	for block in blocks:
		warned = warned and _warning_at(block.global_position)
	_check(warned, "a warning circle marks each landing spot")
	_check(not blocks.any(func(block) -> bool: return block.is_solid()), "they are still falling: not solid yet")
	_check(_player.health.current == hp, "the warning does not hurt")
	# Nico stays where he is: the block lands on him.
	forger.queue_free()
	await create_timer(forger.data.fall_time + 0.2).timeout
	_check(_player.health.current < hp, "the impact hurts Nico (%d -> %d)" % [hp, _player.health.current])
	_check(on_nico == null or not is_instance_valid(on_nico) or not on_nico.is_solid(),
			"the block that landed on him shatters: no obstacle over Nico")
	var standing: Array = _blocks().filter(func(block) -> bool: return block.is_solid())
	_check(standing.size() == blocks.size() - 1, "the other blocks stand as obstacles (%d)" % standing.size())
	if standing.is_empty():
		return
	var block: Node2D = standing[0]
	_check(block.get_collision_layer_value(1), "a standing block is on the world layer")
	_check(await _walker_stopped(block.global_position), "it stops a moving body like Nico's")
	await _frames(2)
	var query := PhysicsRayQueryParameters2D.create(block.global_position + Vector2(-40, 0),
			block.global_position + Vector2(40, 0), 1)
	var hit: Dictionary = _room.get_world_2d().direct_space_state.intersect_ray(query)
	_check(not hit.is_empty() and hit.collider == block, "and arrows (they stop at the world layer)")
	await create_timer(block.lifetime).timeout
	_check(_blocks().is_empty(), "the blocks cool down and go away")


func _never_in_door_lanes() -> void:
	# Nico in the middle of the room, where both door lanes cross.
	_player.health.heal(_player.health.max_health)
	_player.global_position = HOME.get_center()
	var forger = _spawn(HOME.get_center() + Vector2(90, 30))
	var data = forger.data
	var spots := {}
	for i in 360:
		await physics_frame
		_player.health.heal(_player.health.max_health)
		for block in _blocks():
			spots[block.global_position] = true
	var reach_x: float = data.door_lane_half_width + data.block_size.x / 2.0 - 0.01
	var reach_y: float = data.door_lane_half_width + data.block_size.y / 2.0 - 0.01
	var clear := not spots.is_empty()
	var inside := true
	for spot: Vector2 in spots:
		var from_middle: Vector2 = spot - HOME.get_center()
		clear = clear and absf(from_middle.x) >= reach_x and absf(from_middle.y) >= reach_y
		inside = inside and HOME.grow(-data.room_margin).encloses(Rect2(spot - data.block_size / 2.0, data.block_size))
	_check(clear, "no block lands in a door lane (%d blocks)" % spots.size())
	_check(inside, "every block lands inside its room")
	forger.queue_free()
	await _clear_blocks()


func _capped() -> void:
	_player.global_position = QUADRANT
	var forger = _spawn(QUADRANT + Vector2(90, 20))
	forger.data.drop_cooldown = 0.2
	forger.data.block_lifetime = 30.0
	var most := 0
	for i in 480:
		await physics_frame
		_player.health.heal(_player.health.max_health)
		# He keeps moving so no block shatters over him.
		_player.global_position = QUADRANT + Vector2(0, 30 * sin(i * 0.05))
		most = maxi(most, _blocks().size())
	_check(most == forger.data.max_blocks, "it stops at %d blocks (most %d)" % [forger.data.max_blocks, most])
	forger.queue_free()
	await _clear_blocks()


func _walker_stopped(at: Vector2) -> bool:
	var walker := CharacterBody2D.new()
	walker.collision_layer = 0
	walker.collision_mask = _player.collision_mask
	walker.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	walker.add_child(shape)
	_room.add_child(walker)
	walker.global_position = at + Vector2(0, -30)
	for i in 30:
		await physics_frame
		walker.velocity = Vector2(0, 120)
		walker.move_and_slide()
	var stopped := walker.global_position.y < at.y
	walker.free()
	return stopped


func _clear_blocks() -> void:
	for block in _blocks():
		block.queue_free()
	await _frames(2)


func _blocks() -> Array:
	var found := []
	for child in _room.get_children():
		if child.get_script() == _block_script and not child.is_queued_for_deletion():
			found.append(child)
	return found


func _warning_at(spot: Vector2) -> bool:
	for child in _room.get_children():
		if child.get_script() == _zone_script and child.global_position.distance_to(spot) < 1.0:
			return true
	return false


func _spawn(at: Vector2) -> Node:
	var forger = _scene.instantiate()
	forger.data = forger.data.duplicate()
	forger.position = at
	forger.home_area = HOME
	_room.add_child(forger)
	return forger


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
