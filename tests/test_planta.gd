extends SceneTree
## Planta tiradora test: its art and data load, it scurries between shots but stays planted while it
## charges, it shoots an orb at the player when it has a clear shot (a wall blocks it), and the orb
## hurts, vanishes on walls and at the end of its range.
## Run: godot --headless --path . --script res://tests/test_planta.gd

const ARENA := Vector2(300, 180)

var _ok := true
var _room: Node
var _player: Node2D


func _initialize() -> void:
	create_timer(40.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	_room = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(_room)
	await _frames(3)
	_player = _room.get_node("Player")

	var scene: PackedScene = load("res://scenes/enemies/planta_tiradora.tscn")
	var plant = _spawn(scene, ARENA + Vector2(100, 0))
	var frames: SpriteFrames = plant.data.sprite_frames
	for anim: StringName in [&"idle", &"walk", &"run", &"attack", &"hurt", &"death"]:
		_check(frames.has_animation(anim) and frames.get_frame_count(anim) > 0, "plant has %s" % anim)
	_check(plant.data is ShooterData and plant.data.projectile_scene != null, "plant uses a ShooterData with a projectile")

	# It fires an orb that flies toward the player, and moves between shots.
	_player.global_position = ARENA
	var home: Vector2 = plant.global_position
	var orb: Node = null
	for i in 200:
		await physics_frame
		orb = _find_orb()
		if orb != null:
			break
	_check(orb != null, "the plant spits an orb when the player is in range")
	if orb != null:
		var from: Vector2 = orb.global_position
		await _frames(6)
		var moved: Vector2 = orb.global_position - from if is_instance_valid(orb) else Vector2.ZERO
		var to_player: Vector2 = (_player.global_position - from).normalized()
		_check(moved.length() > 2.0 and moved.normalized().dot(to_player) > 0.95, "the orb flies toward the player")
	var health_before: int = _player.health.current
	await _frames(120)
	_check(_player.health.current < health_before, "the orb hurts the player (%d -> %d)" % [health_before, _player.health.current])
	_check(plant.global_position.distance_to(home) > 4.0, "the plant scurries away from its spot between shots (%.0f px)" % plant.global_position.distance_to(home))
	plant.queue_free()
	await _frames(3)

	# An orb ends at the end of its range and on a wall.
	var shot = load("res://scenes/enemies/orb.tscn").instantiate()
	shot.setup(Vector2.UP, 100.0, 50.0, 1)
	_room.add_child(shot)
	shot.global_position = ARENA + Vector2(-120, -40)
	await _frames(60)
	_check(not is_instance_valid(shot), "an orb vanishes at the end of its range")
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 80)
	shape.shape = rect
	wall.add_child(shape)
	wall.global_position = ARENA + Vector2(-60, 60)
	_room.add_child(wall)
	var blocked = load("res://scenes/enemies/orb.tscn").instantiate()
	blocked.setup(Vector2.RIGHT, 100.0, 300.0, 1)
	_room.add_child(blocked)
	blocked.global_position = ARENA + Vector2(-100, 60)
	await _frames(40)
	_check(not is_instance_valid(blocked), "an orb vanishes against a wall")

	# A wall between the plant and the player blocks its shot (the wall is long: it cannot walk around it).
	rect.size = Vector2(8, 600)
	shape.shape = rect
	_spawn(scene, ARENA + Vector2(0, 150))
	wall.global_position = ARENA + Vector2(0, 100)
	wall.rotation = PI / 2.0
	_player.global_position = ARENA + Vector2(0, 50)
	var fired := false
	for i in 150:
		await physics_frame
		if _find_orb() != null:
			fired = true
			break
	_check(not fired, "the plant does not shoot through a wall")
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _find_orb() -> Node:
	for child in _room.get_children():
		if child is EnemyOrb:
			return child
	return null


func _spawn(scene: PackedScene, at: Vector2) -> Node:
	var plant = scene.instantiate()
	plant.data = plant.data.duplicate()
	_room.add_child(plant)
	plant.global_position = at
	return plant


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
