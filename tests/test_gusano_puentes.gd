extends SceneTree
## Bridge worm test, with real physics: burrowed it has no body and cannot be hurt; it surfaces next
## to Nico after a warning and surges through him; its body pieces follow the head's path, block a
## moving body and hurt; it can be hurt while out (also through a piece) and then burrows again, the
## pieces following the head into the hole.
## Run: godot --headless --path . --script res://tests/test_gusano_puentes.gd

const ARENA := Vector2(300, 180)
const ENEMY_LAYER := 3

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var room: Node2D = load("res://scenes/levels/test_room.tscn").instantiate()
	for node_name in ["Trap1", "Trap2", "Grunt1", "Grunt2", "Dummy1", "Dummy2", "Dummy3"]:
		room.get_node(node_name).free()
	root.add_child(room)
	await _frames(3)
	var player: Node2D = room.get_node("Player")
	player.health.set_max_health(50)
	player.global_position = ARENA
	var worm = load("res://scenes/enemies/gusano_puentes.tscn").instantiate()
	worm.data = worm.data.duplicate()
	worm.data.patrol_radius = 0.0
	worm.data.surface_time = 2.0
	room.add_child(worm)
	worm.global_position = ARENA + Vector2(110, 30)
	await _frames(2)

	var frames: SpriteFrames = worm.data.sprite_frames
	for anim: StringName in [&"idle", &"special", &"hurt", &"death"]:
		_check(frames.has_animation(anim), "the worm has %s" % anim)
	_check(worm.data.segment_texture != null, "its body pieces have art")

	# --- Burrowed: no body, no hurtbox, invisible
	_check(worm.phase == worm.Phase.UNDER, "it starts burrowed")
	_check(not worm.get_collision_layer_value(ENEMY_LAYER), "burrowed it has no body on the enemy layer")
	var hp: int = worm.health.current
	var accepted: bool = worm.get_node("Hurtbox").receive_hit(1, player.global_position)
	_check(not accepted and worm.health.current == hp, "burrowed it cannot be hurt")
	_check(not worm.get_node("Sprite").visible, "burrowed only its ripple shows")

	# --- It travels under, warns and bursts out next to Nico
	var player_hp: int = player.health.current
	var rise_at = null
	var warned := false
	for i in 400:
		await physics_frame
		if worm.phase == worm.Phase.RISING and rise_at == null:
			rise_at = worm.global_position
			warned = _has_warning(room)
		if worm.phase == worm.Phase.RESTING:
			break
	_check(rise_at != null, "it surfaces")
	if rise_at == null:
		_finish()
		return
	var offset: float = worm.data.emerge_offset
	_check(rise_at.distance_to(ARENA) <= offset + 8.0,
			"it surfaces next to Nico (%.0f px away)" % rise_at.distance_to(ARENA))
	_check(warned, "a warning circle marks where it comes out")
	_check(worm.phase == worm.Phase.RESTING and worm.get_collision_layer_value(ENEMY_LAYER),
			"out, its head is a body")
	_check(player.health.current < player_hp, "the surge through Nico hurts him (%d -> %d)" % [player_hp, player.health.current])

	# --- The body follows the head's path
	var pieces: Array = worm.segments_out()
	_check(pieces.size() == worm.data.segment_count, "all %d body pieces are out (%d)" % [worm.data.segment_count, pieces.size()])
	var direction: Vector2 = worm._surge_dir
	var on_path := true
	for piece in pieces:
		var from_hole: Vector2 = piece.global_position - rise_at
		if absf(from_hole.cross(direction)) > 2.0 or from_hole.dot(direction) <= 0.0:
			on_path = false
	_check(on_path, "the pieces lie on the head's path, behind it")

	# --- A piece blocks a moving body (with Nico's collision mask)
	var middle: Vector2 = pieces[1].global_position
	var across := direction.orthogonal()
	var walker := CharacterBody2D.new()
	walker.collision_layer = 0
	walker.collision_mask = player.collision_mask
	walker.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	walker.add_child(shape)
	room.add_child(walker)
	walker.global_position = middle - across * 24.0
	for i in 30:
		await physics_frame
		walker.velocity = across * 120.0
		walker.move_and_slide()
	var crossed: float = (walker.global_position - middle).dot(across)
	_check(crossed < 0.0, "the body blocks the way (stopped %.0f px before its middle)" % -crossed)
	walker.queue_free()

	# --- Out, it can be hurt, by the head or by a piece
	hp = worm.health.current
	accepted = pieces[2].hurtbox.receive_hit(1, middle - across * 20.0)
	_check(accepted and worm.health.current == hp - 1, "a hit on a body piece hurts the worm")

	# --- Then it dives and the body follows it into the hole
	var tail_followed := false
	for i in 300:
		await physics_frame
		if worm.phase == worm.Phase.SINKING and not worm.segments_out().is_empty():
			tail_followed = true
		if worm.phase == worm.Phase.UNDER:
			break
	_check(tail_followed, "the head dives first and the pieces follow it under")
	_check(worm.phase == worm.Phase.UNDER, "it burrows again")
	_check(worm.segments_out().is_empty(), "no piece is left out")
	_check(not worm.get_collision_layer_value(ENEMY_LAYER), "burrowed again it has no body")
	hp = worm.health.current
	accepted = worm.get_node("Hurtbox").receive_hit(1, player.global_position)
	_check(not accepted and worm.health.current == hp, "and cannot be hurt again until it surfaces")
	_finish()


func _has_warning(room: Node) -> bool:
	var zone_script: Script = load("res://scripts/skills/skill_zone.gd")
	for child in room.get_children():
		if child.get_script() == zone_script:
			return true
	return false


func _finish() -> void:
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
