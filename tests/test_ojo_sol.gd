extends SceneTree
## Ojo del sol test, with real physics: it floats (ponds do not block it, walls do); its light ray
## lies on the ground and follows Nico no faster than its turn speed, then holds still; the laser it
## fires reaches the wall and hurts Nico once when he is in the beam, and stepping well out of the line
## while the ray holds dodges it. The laser keeps turning toward Nico, never faster than its own
## turn speed, with its Hitbox turned exactly like the drawn beam: running around the eye outruns
## it, standing just beside the line does not. The eye's art looks along the beam.
## The arena is moved off the origin so the ray is checked in room coordinates.
## Run: godot --headless --path . --script res://tests/test_ojo_sol.gd

const ARENA_OFFSET := Vector2(40, 24)
const EYE_AT := Vector2(150, 200)
## Left face of the wall the laser stops at (it spans y 40..440).
const WALL_X := 380.0
const WATER_LAYER := 7
## Nico's distance from the eye while the laser sweeps.
const ORBIT_RADIUS := 130.0

var _ok := true
var _arena: Node2D
var _player: Node2D
var _eye: Node2D


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_arena = Node2D.new()
	_arena.position = ARENA_OFFSET
	root.add_child(_arena)
	_add_block(Rect2(WALL_X, 40, 16, 400), 1)
	_add_block(Rect2(EYE_AT.x - 60, EYE_AT.y + 40, 30, 30), 1 << (WATER_LAYER - 1))
	_add_block(Rect2(EYE_AT.x - 60, EYE_AT.y - 80, 30, 30), 1)
	_player = load("res://scenes/player/player.tscn").instantiate()
	_player.position = Vector2(280, 200) - ARENA_OFFSET
	_arena.add_child(_player)
	_eye = load("res://scenes/enemies/ojo_sol.tscn").instantiate()
	_eye.data = _eye.data.duplicate()
	_eye.data.patrol_radius = 0.0
	_eye.position = EYE_AT - ARENA_OFFSET
	_arena.add_child(_eye)
	var data = _eye.data
	var frames: SpriteFrames = data.sprite_frames
	for anim: StringName in [&"idle", &"walk", &"run", &"attack", &"special", &"hurt", &"death"]:
		_check(frames.has_animation(anim), "the eye has %s" % anim)
	_check(data.max_health >= 4 and data.max_health <= 8 and data.attack_damage == 1, "hard but fair stats")
	await _frames(2)

	# --- It floats over ponds, not through walls
	var over_water: bool = not _eye.test_move(_eye.global_transform.translated(Vector2(-45, 55)), Vector2(0, 10))
	_check(not _eye.get_collision_mask_value(WATER_LAYER), "ponds do not stop it")
	_check(over_water, "it can hover over a pond")
	_check(_eye.test_move(_eye.global_transform.translated(Vector2(-45, -65)), Vector2(0, 10)), "walls do stop it")

	# --- The ray follows Nico at a limited turn rate
	await _until(func() -> bool: return _eye.state == _eye.State.ATTACK, 200)
	var ray: Node2D = _arena.get_node_or_null("SunRay")
	_check(ray != null and ray.z_index == -1 and not ray.z_as_relative, "the light ray lies on the ground layer")
	if ray != null:
		_check(ray.global_position.distance_to(_eye.global_position) < 1.0, "it starts at the eye")
	_player.global_position = Vector2(280, 250)
	var before: Vector2 = _eye.aim_direction()
	await physics_frame
	var turned: float = absf(before.angle_to(_eye.aim_direction()))
	var max_turn: float = deg_to_rad(data.aim_turn_speed) / Engine.physics_ticks_per_second
	_check(turned > 0.0 and turned <= max_turn + 0.001, "the ray turns toward him, no faster than its turn speed")
	await _until(func() -> bool: return _eye.beam_step == _eye.Beam.LOCK, 200)
	var to_player: Vector2 = (_player.global_position - _eye.global_position).normalized()
	_check(_eye.aim_direction().dot(to_player) > 0.995, "by the end of its aim the ray is on him")

	# --- The laser reaches the wall and hurts him once
	var hp: int = _player.health.current
	await _until(func() -> bool: return _eye.beam_step == _eye.Beam.FIRE, 120)
	var aim: Vector2 = _eye.aim_direction()
	var expected: float = (WALL_X - _eye.global_position.x) / aim.x
	_check(absf(_eye.beam_length() - expected) < 2.0, "the laser stops at the wall (%.0f px, expected %.0f)" % [_eye.beam_length(), expected])
	await _until(func() -> bool: return _eye.beam_step == _eye.Beam.RECOVER, 300)
	_check(_player.health.current == hp - data.attack_damage, "the laser hurts Nico in the beam once (%d -> %d)" % [hp, _player.health.current])
	await physics_frame
	_check(_arena.get_node_or_null("SunRay") == null or _arena.get_node("SunRay").is_queued_for_deletion(), "the beam goes out after firing")

	# --- Stepping well out of the line while the ray holds dodges it: the sweep turns only so far
	_player.global_position = Vector2(280, 200)
	await _until(func() -> bool: return _eye.state == _eye.State.ATTACK and _eye.beam_step == _eye.Beam.LOCK, 400)
	var held: Vector2 = _eye.aim_direction()
	_player.global_position = _eye.global_position - held * 100.0
	hp = _player.health.current
	await _until(func() -> bool: return _eye.beam_step == _eye.Beam.FIRE, 120)
	_check(_eye.aim_direction().dot(held) > 0.9999, "the held ray does not follow him any more")
	await _until(func() -> bool: return _eye.beam_step == _eye.Beam.RECOVER, 300)
	_check(_player.health.current == hp, "out of the line, the laser misses (%d -> %d)" % [hp, _player.health.current])

	# --- The laser sweeps after him, no faster than its turn speed, its Hitbox under the beam
	await _check_laser_sweep(data)

	# --- Standing just beside the line, the sweeping laser catches him; the eye looks along it
	_player.global_position = Vector2(280, 200)
	await _until(func() -> bool: return _eye.state == _eye.State.ATTACK and _eye.beam_step == _eye.Beam.LOCK, 400)
	held = _eye.aim_direction()
	_player.global_position = _eye.global_position + held.rotated(deg_to_rad(9.0)) * ORBIT_RADIUS
	hp = _player.health.current
	await _until(func() -> bool: return _eye.beam_step == _eye.Beam.FIRE, 120)
	_check_look(data)
	await _until(func() -> bool: return _eye.beam_step == _eye.Beam.RECOVER, 300)
	_check(_player.health.current == hp - data.attack_damage, "beside the line, the sweep catches him (%d -> %d)" % [hp, _player.health.current])
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


## Nico runs around the eye at his own speed, starting a little ahead of the held line, while the
## laser burns: every frame it turns toward him by at most its turn speed, its Hitbox points and
## reaches exactly like the drawn beam, and he outruns it.
func _check_laser_sweep(data) -> void:
	_player.global_position = Vector2(280, 200)
	await _until(func() -> bool: return _eye.state == _eye.State.ATTACK and _eye.beam_step == _eye.Beam.LOCK, 400)
	var orbit: float = _eye.aim_direction().angle() + deg_to_rad(12.0)
	_player.global_position = _eye.global_position + Vector2.from_angle(orbit) * ORBIT_RADIUS
	var hp: int = _player.health.current
	await _until(func() -> bool: return _eye.beam_step == _eye.Beam.FIRE, 120)
	var start: Vector2 = _eye.aim_direction()
	var ray: Node2D = _arena.get_node_or_null("SunRay")
	var laser: Area2D = _eye.get_node("Laser")
	var shape: RectangleShape2D = laser.get_child(0).shape
	var max_turn: float = deg_to_rad(data.laser_turn_speed) * _eye._speed_scale() / Engine.physics_ticks_per_second
	var orbit_step: float = _player.speed / ORBIT_RADIUS / Engine.physics_ticks_per_second
	var frames := 0
	var turns_ok := true
	var hitbox_ok := ray != null
	while _eye.beam_step == _eye.Beam.FIRE and frames < 300:
		var before: Vector2 = _eye.aim_direction()
		orbit += orbit_step
		_player.global_position = _eye.global_position + Vector2.from_angle(orbit) * ORBIT_RADIUS
		await physics_frame
		if _eye.beam_step != _eye.Beam.FIRE:
			break
		frames += 1
		var aim: Vector2 = _eye.aim_direction()
		var turned: float = before.angle_to(aim)
		if turned <= 0.0 or turned > max_turn + 0.0001:
			turns_ok = false
			print("  frame %d turned %.5f rad (max %.5f)" % [frames, turned, max_turn])
		if (ray == null or not laser.monitoring
				or absf(angle_difference(laser.global_rotation, aim.angle())) > 0.001
				or absf(angle_difference(laser.global_rotation, ray.global_rotation)) > 0.001
				or (laser.global_position - _eye.global_position).normalized().dot(aim) < 0.9999
				or absf(shape.size.x - (_eye.beam_length() - data.muzzle_distance)) > 0.5):
			hitbox_ok = false
	_check(frames >= 10, "the laser burned while he ran (%d frames)" % frames)
	_check(turns_ok, "running around it, the laser turns toward him, never faster than its turn speed")
	var swept: float = rad_to_deg(start.angle_to(_eye.aim_direction()))
	_check(swept > 0.7 * data.laser_turn_speed * data.attack_time, "the laser swept after him (%.1f deg)" % swept)
	_check(hitbox_ok, "the laser's Hitbox turns and reaches exactly like the drawn beam")
	await _until(func() -> bool: return _eye.beam_step == _eye.Beam.RECOVER, 300)
	_check(_player.health.current == hp, "running around the eye he outruns the laser (%d -> %d)" % [hp, _player.health.current])


## While the laser burns the eye is drawn from `spin_art`, in the row of the beam's direction and
## spinning the way it sweeps (clockwise, the left half of the sheet, here: Nico is on that side).
func _check_look(data) -> void:
	var look: Sprite2D = _eye.get_node_or_null("Sprite/Look")
	_check(look != null and data.spin_art != null, "the eye has its aimed art (run tools/make_ojo_sol.gd)")
	if look == null:
		return
	var rows: int = data.art_directions
	var expected: int = wrapi(roundi(_eye.aim_direction().angle() / TAU * rows), 0, rows)
	var column: int = look.frame - expected * look.hframes
	_check(look.visible and look.texture == data.spin_art and _eye.look_row() == expected
			and column >= 0 and column < look.hframes, "the eye looks along the laser (row %d)" % expected)
	_check(column < look.hframes / 2.0, "its spikes spin the way the laser sweeps")


func _add_block(rect: Rect2, layer: int) -> void:
	var block := StaticBody2D.new()
	block.collision_layer = layer
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	block.add_child(shape)
	block.position = rect.get_center() - ARENA_OFFSET
	_arena.add_child(block)


func _until(condition: Callable, max_frames: int) -> void:
	for i in max_frames:
		if condition.call():
			return
		await physics_frame


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
