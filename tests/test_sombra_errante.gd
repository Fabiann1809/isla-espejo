extends SceneTree
## Sombra errante test: it fades out (arrows cannot hit it once half faded), a circle warns where it
## will come back, it reappears behind Nico on free ground and strikes after its own telegraph; it
## never lands inside a wall or a pond (and with no free spot it does not teleport at all); the
## director's vision and speed multipliers still apply, and it keeps to its room.
## Run: godot --headless --path . --script res://tests/test_sombra_errante.gd

const ARENA := Vector2(300, 180)
const ZONE_SCRIPT := "res://scripts/skills/skill_zone.gd"
const BLOCKING := 1 | 1 << 6

var _ok := true
var _room: Node
var _player: Node2D


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_room = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(_room)
	await _frames(3)
	_player = _room.get_node("Player")
	_player.global_position = ARENA

	await _check_data()
	await _check_teleport()
	await _check_walls()
	await _check_no_room()
	await _check_director()
	await _check_territory()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check_data() -> void:
	var shade = _spawn(ARENA + Vector2(400, 0))
	_check(shade.data.get("teleport_range") != null and shade.data.id == &"sombra_errante", "the Sombra uses a TeleporterData")
	_check(shade.data.sprite_frames.has_animation(&"teleport"), "it has its teleport animation")
	var bank = root.get_node("Sound").bank
	_check(bank.has_cue(&"attack_sombra_errante") and bank.has_cue(&"death_sombra_errante"), "the Sombra has its strike and death sounds")
	shade.queue_free()
	await _frames(2)


## Fade, warned arrival behind Nico, strike after the telegraph.
func _check_teleport() -> void:
	_player.global_position = ARENA
	_player.facing = Vector2.RIGHT
	var health_before: int = _player.health.current
	var start := ARENA + Vector2(110, 0)
	var sound = root.get_node("Sound")
	sound.played.clear()
	var shade = _spawn(start)
	var dodged_while_faded := false
	var hit_while_visible := false
	var warned_before_arrival := false
	var stayed_until_arrival := true
	var landed_frame := -1
	var strike_frame := -1
	var telegraph_seen := false
	var warning_frames := 0
	for i in 240:
		await physics_frame
		_player.global_position = ARENA
		_player.facing = Vector2.RIGHT
		if shade.blink == shade.Blink.NONE and landed_frame < 0 and shade.state == shade.State.ATTACK \
				and shade._attack_phase == shade.AttackPhase.WINDUP and shade.get_node("AttackPivot/Telegraph").visible \
				and warning_frames > 0:
			landed_frame = i
		if shade.is_faded() and not dodged_while_faded:
			var health: int = shade.health.current
			dodged_while_faded = not shade.get_node("Hurtbox").receive_hit(1, ARENA) and shade.health.current == health
		if shade.blink == shade.Blink.HIDDEN:
			warning_frames += 1
			warned_before_arrival = warned_before_arrival or not _zones().is_empty()
			stayed_until_arrival = stayed_until_arrival and shade.global_position.distance_to(start) < 2.0
		if landed_frame >= 0 and not telegraph_seen:
			telegraph_seen = shade.get_node("AttackPivot/Telegraph").visible
		if landed_frame >= 0 and strike_frame < 0 and _player.health.current < health_before:
			strike_frame = i
	var arrival: Vector2 = shade.arrival_point()
	_check(dodged_while_faded, "an arrow cannot hit it while it is faded")
	_check(warned_before_arrival and stayed_until_arrival, "a circle warns of its arrival while it is gone")
	_check(warning_frames >= int(shade.data.hidden_time * 60) - 1, "the arrival is warned for %d ticks" % warning_frames)
	_check(absf(arrival.distance_to(ARENA) - shade.data.appear_distance) < 1.0 and arrival.x < ARENA.x - 20.0,
			"it reappears behind Nico (%s)" % arrival)
	_check(_spot_free(arrival), "on free ground")
	_check(landed_frame >= 0 and telegraph_seen, "it shows its telegraph after reappearing")
	_check(strike_frame >= landed_frame + int(shade.data.attack_windup * 60) - 1,
			"its strike lands only after the telegraph (%d -> %d)" % [landed_frame, strike_frame])
	_check(_player.health.current < health_before, "the strike hurts Nico (%d -> %d)" % [health_before, _player.health.current])
	_check(sound.played.has(&"attack_sombra_errante"), "the strike is heard")
	var health: int = shade.health.current
	shade.get_node("Hurtbox").receive_hit(1, ARENA)
	hit_while_visible = shade.health.current < health
	_check(hit_while_visible, "once back it can be hit")
	shade.queue_free()
	_heal()
	await _frames(60)


## A wall behind Nico and a pond beside him: it lands on the free side, never in them.
func _check_walls() -> void:
	_player.global_position = ARENA
	_player.facing = Vector2.RIGHT
	var wall := _block(ARENA + Vector2(-30, 0), Vector2(16, 40), 1)
	var pond := _block(ARENA + Vector2(0, -30), Vector2(40, 16), 1 << 6)
	var shade = _spawn(ARENA + Vector2(100, 40))
	var arrival := Vector2.ZERO
	for i in 120:
		await physics_frame
		_player.global_position = ARENA
		_player.facing = Vector2.RIGHT
		_heal()
		if shade.blink == shade.Blink.APPEAR:
			arrival = shade.global_position
			break
	_check(arrival != Vector2.ZERO, "it still teleports next to a wall and a pond")
	_check(_spot_free(arrival) and arrival.distance_to(ARENA + Vector2(-30, 0)) > 10.0 and arrival.distance_to(ARENA + Vector2(0, -30)) > 10.0,
			"it lands beside Nico on free ground, not in the wall or the pond (%s)" % (arrival - ARENA))
	shade.queue_free()
	wall.queue_free()
	pond.queue_free()
	await _frames(30)


## Walls and ponds all around Nico: no free spot, so it never vanishes into one.
func _check_no_room() -> void:
	_player.global_position = ARENA
	var blocks: Array[Node] = []
	for k in 8:
		blocks.append(_block(ARENA + Vector2.from_angle(k * PI / 4.0) * 30.0, Vector2(10, 10), 1 if k % 2 == 0 else 1 << 6))
	var shade = _spawn(ARENA + Vector2.from_angle(PI / 8.0) * 100.0)
	var hidden := false
	var tried := false
	for i in 200:
		await physics_frame
		_player.global_position = ARENA
		_heal()
		tried = tried or shade.blink == shade.Blink.FADE
		hidden = hidden or shade.blink != shade.Blink.NONE and shade.blink != shade.Blink.FADE
	_check(shade.target == _player and tried, "it sees Nico and tries to teleport")
	_check(not hidden, "with no free ground around Nico it does not teleport into a wall or a pond")
	_check(shade.modulate.a == 1.0 and not shade.is_faded(), "and shows up again where it was")
	shade.queue_free()
	for block in blocks:
		block.queue_free()
	await _frames(30)


func _check_director() -> void:
	_player.global_position = ARENA
	var blind = _spawn(ARENA + Vector2(100, 0))
	blind.vision_multiplier = 0.1
	var vanished := false
	for i in 120:
		await physics_frame
		vanished = vanished or blind.blink != blind.Blink.NONE
	_check(blind.target == null and not vanished, "with little vision (x0.1) it neither notices Nico nor teleports")
	blind.queue_free()
	await _frames(2)
	var fast = _spawn(ARENA + Vector2(120, 0))
	fast.data.teleport_range = 0.0
	fast.speed_multiplier = 2.0
	var top := 0.0
	for i in 60:
		await physics_frame
		_player.global_position = ARENA
		if fast.state == fast.State.CHASE:
			top = maxf(top, fast.velocity.length())
	_check(absf(top - fast.data.chase_speed * 2.0) < 1.0, "the director's speed x2 doubles its drift (%.0f px/s)" % top)
	fast.queue_free()
	await _frames(30)


func _check_territory() -> void:
	var tuning: Script = load("res://scripts/core/tuning.gd")
	_player.global_position = ARENA
	var homebody = _spawn(ARENA + Vector2(110, 0))
	homebody.home_area = Rect2(ARENA + Vector2(80, -60), Vector2(160, 120))
	var vanished := false
	for i in 120:
		await physics_frame
		vanished = vanished or homebody.blink != homebody.Blink.NONE or homebody.target != null
	_check(not vanished, "it ignores Nico while he is outside its room")
	homebody.queue_free()
	await _frames(2)
	# The spot behind Nico is past its room's edge: it comes back on the room's side.
	_player.facing = Vector2.LEFT
	var edge = _spawn(ARENA + Vector2(-100, 0))
	edge.home_area = Rect2(ARENA + Vector2(-160, -80), Vector2(190, 160))
	var arrival := Vector2.ZERO
	for i in 150:
		await physics_frame
		_player.global_position = ARENA
		_player.facing = Vector2.LEFT
		_heal()
		if edge.blink == edge.Blink.APPEAR:
			arrival = edge.global_position
			break
	_check(arrival != Vector2.ZERO and edge.home_area.grow(-tuning.DASH_ROOM_MARGIN + 0.5).has_point(arrival),
			"it never reappears outside its room (%s)" % (arrival - ARENA))
	edge.queue_free()
	await _frames(2)


func _spawn(at: Vector2) -> Node:
	var shade = load("res://scenes/enemies/sombra_errante.tscn").instantiate()
	shade.data = shade.data.duplicate()
	shade.data.patrol_radius = 0.0
	_room.add_child(shade)
	shade.global_position = at
	return shade


func _block(at: Vector2, size: Vector2, layer: int) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	_room.add_child(body)
	body.global_position = at
	return body


func _spot_free(spot: Vector2) -> bool:
	var params := PhysicsShapeQueryParameters2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 12)
	params.shape = rect
	params.transform = Transform2D(0.0, spot)
	params.collision_mask = BLOCKING
	return root.get_world_2d().direct_space_state.intersect_shape(params, 1).is_empty()


func _zones() -> Array:
	return _room.get_children().filter(func(n: Node) -> bool:
		return n.get_script() != null and n.get_script().resource_path == ZONE_SCRIPT and not n.is_queued_for_deletion())


func _heal() -> void:
	_player.health.heal(5)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
