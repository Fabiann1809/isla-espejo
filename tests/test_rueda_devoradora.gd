extends SceneTree
## Rueda devoradora test, with real physics: it winds up still, aimed at Nico, then rolls fast in a
## straight line spinning its sprite, hurts Nico on the way, bounces off a wall (its course reflected
## and leaning toward him, never through the wall), brakes to a stop and rests. In a small room its
## edge works as a wall: it bounces off it and never leaves.
## Run: godot --headless --path . --script res://tests/test_rueda_devoradora.gd

const ARENA_OFFSET := Vector2(30, 20)
const ROOM := Rect2(0, 0, 400, 240)
const WALL := 16.0
const DASH_ROOM_MARGIN := 20.0

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
	_add_walls()
	_player = load("res://scenes/player/player.tscn").instantiate()
	_player.position = Vector2(250, 120)
	_arena.add_child(_player)
	_player.health.set_max_health(80)

	# --- Windup, roll through Nico, bounce off the right wall
	var wheel = _spawn(Vector2(100, 120), Rect2())
	var phases = wheel.Phase
	var sprite: AnimatedSprite2D = wheel.get_node("Sprite")
	await _until(func() -> bool: return wheel.state == wheel.State.ATTACK, 120)
	_check(wheel.phase == phases.WINDUP, "it winds up first")
	var start: Vector2 = wheel.global_position
	await _frames(8)
	_check(wheel.global_position.distance_to(start) < 0.5 and sprite.animation == &"attack",
			"winding up it stands still with its faces glowing (attack)")
	var hp: int = _player.health.current
	await _until(func() -> bool: return wheel.phase == phases.ROLL, 60)
	var first_dir: Vector2 = wheel.roll_direction()
	_check(first_dir.dot(Vector2.RIGHT) > 0.95, "it rolls straight at Nico")
	var spun := 0.0
	var farthest := 0.0
	for i in 120:
		await physics_frame
		spun = maxf(spun, absf(sprite.rotation))
		farthest = maxf(farthest, wheel.global_position.x - ARENA_OFFSET.x)
		if wheel.bounces > 0:
			break
	_check(_player.health.current < hp, "rolling through Nico hurts him (%d -> %d)" % [hp, _player.health.current])
	_check(spun > 0.5, "its sprite spins while it rolls (%.2f rad)" % spun)
	_check(wheel.bounces == 1, "it bounces off the wall")
	_check(farthest < ROOM.end.x, "it never goes through the wall (x %.0f)" % farthest)
	var after: Vector2 = wheel.roll_direction()
	var pure := first_dir.bounce(Vector2.LEFT)
	var to_nico: Vector2 = (_player.global_position - wheel.global_position).normalized()
	_check(after.x < -0.5, "its course is reflected off the wall (%.2f, %.2f)" % [after.x, after.y])
	_check(after.dot(to_nico) >= pure.dot(to_nico) - 0.01, "and leans toward Nico")
	var braked := false
	for i in 400:
		await physics_frame
		braked = braked or wheel.phase == phases.BRAKE
		if wheel.phase == phases.REST:
			break
	_check(braked and wheel.phase == phases.REST, "it brakes and stops")
	var resting_at: Vector2 = wheel.global_position
	await _frames(10)
	_check(wheel.global_position.distance_to(resting_at) < 0.5, "resting, it stays still")
	_check(not wheel.get_node("AttackPivot/Hitbox").monitoring, "resting, it does not hurt")
	wheel.queue_free()
	await _frames(2)

	# --- A small room: its edge works as a wall
	var home := Rect2(ARENA_OFFSET + Vector2(40, 40), Vector2(220, 150))
	_player.global_position = home.get_center() + Vector2(70, 30)
	var keeper = _spawn(home.get_center() - ARENA_OFFSET + Vector2(-40, -20), home)
	var inner := home.grow(-DASH_ROOM_MARGIN + 2.0)
	var inside := true
	var most_bounces := 0
	for i in 420:
		await physics_frame
		inside = inside and inner.has_point(keeper.global_position)
		most_bounces = maxi(most_bounces, keeper.bounces)
	_check(most_bounces >= 1, "it bounces off the edge of its room (%d bounces)" % most_bounces)
	_check(inside, "it never leaves its room")

	# --- The lean toward Nico after a bounce, with Nico off the reflected course
	_player.global_position = keeper.global_position + Vector2(-60, -60)
	keeper.target = _player
	keeper._roll_dir = Vector2.RIGHT
	keeper._bounce(Vector2.LEFT)
	var leaned: Vector2 = keeper.roll_direction()
	_check(leaned.x < 0.0 and leaned.y < -0.1, "a bounce leans its course toward Nico (%.2f, %.2f)" % [leaned.x, leaned.y])
	_check(leaned.dot(Vector2.LEFT) >= keeper.data.min_leave, "but still leaves the wall")
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _spawn(at: Vector2, home: Rect2) -> Node2D:
	var wheel = load("res://scenes/enemies/rueda_devoradora.tscn").instantiate()
	wheel.data = wheel.data.duplicate()
	wheel.data.patrol_radius = 0.0
	wheel.home_area = home
	wheel.position = at
	_arena.add_child(wheel)
	return wheel


func _add_walls() -> void:
	var walls: Array[Rect2] = [
		Rect2(-WALL, -WALL, ROOM.size.x + WALL * 2.0, WALL), Rect2(-WALL, ROOM.size.y, ROOM.size.x + WALL * 2.0, WALL),
		Rect2(-WALL, 0, WALL, ROOM.size.y), Rect2(ROOM.size.x, 0, WALL, ROOM.size.y)]
	for rect in walls:
		var wall := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		wall.add_child(shape)
		wall.position = rect.get_center()
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
