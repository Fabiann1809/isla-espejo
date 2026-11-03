extends SceneTree
## Carnero de basalto test, with real physics: it marks its lane on the ground (up to the wall ahead),
## charges along it hurting Nico on the way, crashes into the wall and stays stunned (still, no
## attacks) for a while; a charge that runs out of distance or reaches the edge of its room only
## recovers. The arena is moved off the origin so the lane is checked in room coordinates.
## Run: godot --headless --path . --script res://tests/test_carnero_basalto.gd

const ARENA_OFFSET := Vector2(40, 24)
## Left face of the wall the first charge crashes into (it spans y 100..300).
const WALL_X := 412.0

var _ok := true
var _arena: Node2D
var _player: Node2D


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_arena = Node2D.new()
	_arena.position = ARENA_OFFSET
	root.add_child(_arena)
	_add_wall(Rect2(WALL_X, 100, 16, 200))
	_player = load("res://scenes/player/player.tscn").instantiate()
	_player.position = Vector2(270, 200) - ARENA_OFFSET
	_arena.add_child(_player)

	# --- Lane, charge, crash and stun
	var ram = _spawn(Vector2(150, 200), 400.0)
	var charge_steps = ram.Charge
	await _until(func() -> bool: return ram.state == ram.State.ATTACK, 200)
	var lane: Node2D = _arena.get_node_or_null("ChargeLane")
	_check(lane != null, "the charge is warned by a lane on the ground")
	if lane != null:
		_check(lane.z_index == -1 and not lane.z_as_relative, "the lane lies on the ground layer")
		_check(lane.global_position.distance_to(ram.global_position) < 1.0 and absf(lane.rotation) < 0.05,
				"it starts at the ram and points at Nico")
		_check(absf(ram._lane_length - (WALL_X - 150.0)) < 2.0, "it ends at the wall (%.0f px)" % ram._lane_length)
	var start: Vector2 = ram.global_position
	await _frames(10)
	_check(ram.global_position.distance_to(start) < 1.0, "it stands still while it marks the lane")
	var health_before: int = _player.health.current
	await _until(func() -> bool: return ram.charge_step != charge_steps.WINDUP, 120)
	_check(lane == null or not is_instance_valid(lane), "the lane goes away when it charges")
	await _until(func() -> bool: return ram.charge_step != charge_steps.RUSH, 120)
	_check(_player.health.current < health_before, "the charge hurts Nico on its way (%d -> %d)" % [health_before, _player.health.current])
	_check(ram.is_stunned(), "crashing into the wall stuns it")
	_check(ram.global_position.x > WALL_X - 20.0, "it ran all the way to the wall (x %.0f)" % ram.global_position.x)
	_check(ram.get_node("StunStars").visible, "stars circle over its head")
	var stunned_at: Vector2 = ram.global_position
	_player.global_position = ram.global_position + Vector2(-60, 0)
	var attacked := false
	for i in 60:
		await physics_frame
		if ram.state == ram.State.ATTACK and ram.charge_step == charge_steps.WINDUP:
			attacked = true
	_check(ram.is_stunned() and ram.global_position.distance_to(stunned_at) < 1.0, "stunned, it stays still")
	_check(not attacked, "stunned, it cannot attack")
	await _until(func() -> bool: return not ram.is_stunned(), 120)
	_check(not ram.get_node("StunStars").visible, "the stun wears off")
	ram.queue_free()

	# --- No wall in reach: the charge ends after its distance and it only recovers
	_player.global_position = Vector2(270, 420)
	var short = _spawn(Vector2(150, 420), 80.0)
	var stunned := false
	var recovered := false
	for i in 240:
		await physics_frame
		stunned = stunned or short.is_stunned()
		recovered = recovered or (short.state == short.State.ATTACK and short.charge_step == charge_steps.RECOVER)
		if recovered:
			break
	_check(recovered and not stunned, "a charge that runs out of distance is not a crash")
	_check(absf(short.global_position.x - 230.0) < 8.0, "it ran its charge distance (x %.0f)" % short.global_position.x)
	short.queue_free()

	# --- The edge of its room stops the charge too
	_player.global_position = Vector2(260, 560)
	var keeper = _spawn(Vector2(150, 560), 400.0, Rect2(100, 520, 200, 80))
	stunned = false
	recovered = false
	for i in 240:
		await physics_frame
		stunned = stunned or keeper.is_stunned()
		recovered = recovered or (keeper.state == keeper.State.ATTACK and keeper.charge_step == charge_steps.RECOVER)
		if recovered:
			break
	_check(recovered and not stunned, "the edge of its room ends the charge without a stun")
	_check(keeper.global_position.x <= 282.0, "it stays in its room (x %.0f)" % keeper.global_position.x)
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _spawn(at: Vector2, charge_distance: float, home := Rect2()) -> Node2D:
	var ram = load("res://scenes/enemies/carnero_basalto.tscn").instantiate()
	ram.data = ram.data.duplicate()
	ram.data.patrol_radius = 0.0
	ram.data.charge_distance = charge_distance
	ram.home_area = home
	ram.position = at - ARENA_OFFSET
	_arena.add_child(ram)
	return ram


func _add_wall(rect: Rect2) -> void:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	wall.add_child(shape)
	wall.position = rect.get_center() - ARENA_OFFSET
	_arena.add_child(wall)


func _until(condition: Callable, max_frames: int) -> void:
	for i in max_frames:
		if condition.call():
			return
		await physics_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
