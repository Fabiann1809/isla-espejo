extends SceneTree
## The player's attack numbers come from a WeaponData (data/weapons/), not from the script, and the
## bow shoots an arrow that damages the first enemy, stops at walls and vanishes at its range.
## Run: godot --headless --path . --script res://tests/test_weapons.gd

var _ok := true


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame

	var bow: Resource = load("res://data/weapons/bow.tres")
	_check(bow != null and bow.id == &"bow" and bow.projectile_scene != null, "the bow weapon data loads with its projectile")
	_check(bow.damage >= 1 and bow.attack_time > 0.0 and bow.attack_cooldown > 0.0, "the bow has usable numbers")
	_check(bow.display_name != "", "the weapon has a Spanish name in its data")
	_check(bow.projectile_speed > 0.0 and bow.projectile_range > 0.0 and bow.release_at > 0.0 and bow.release_at < 1.0,
		"the bow's projectile numbers are usable")

	var room: Node = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(room)
	await _frames(3)
	var player = room.get_node("Player")
	_check(player.weapon == bow, "the player scene equips the bow")
	_check(player.attack_damage == bow.damage and is_equal_approx(player.attack_time, bow.attack_time)
		and is_equal_approx(player.attack_cooldown, bow.attack_cooldown)
		and is_equal_approx(player.attack_move_factor, bow.move_factor), "the player copies the weapon's numbers")

	# A different weapon changes the numbers without touching the player script.
	var heavy: Resource = load("res://scripts/player/weapon_data.gd").new()
	heavy.id = &"heavy"
	heavy.damage = 3
	heavy.attack_time = 0.4
	heavy.attack_cooldown = 0.9
	heavy.move_factor = 0.1
	player.equip(heavy)
	_check(player.attack_damage == 3 and is_equal_approx(player.attack_time, 0.4)
		and is_equal_approx(player.attack_cooldown, 0.9) and is_equal_approx(player.attack_move_factor, 0.1), "equip() switches the attack numbers")
	player.equip(bow)

	await _arrow_flight(room, player, bow)
	await _arrow_hits_dummy(room, player)

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


## Empty ground: the arrow leaves at its release moment, flies and vanishes at its range; a wall
## stops it earlier.
func _arrow_flight(room: Node, player: Node, bow: Resource) -> void:
	player.global_position = Vector2(300, 200)
	player.facing = Vector2.RIGHT
	await _frames(2)
	await _tap("attack")
	await _frames(2)
	_check(_arrows(room).is_empty(), "the arrow is still in the bow before the release moment")
	await _frames(10)
	var arrows := _arrows(room)
	_check(arrows.size() == 1, "one arrow is in flight after the release moment (%d)" % arrows.size())
	if arrows.size() == 1:
		_check(arrows[0].global_position.x > player.global_position.x, "the arrow flies the way Nico faces")
	var travel_frames := int(ceil(bow.projectile_range / bow.projectile_speed * 60.0)) + 20
	await _frames(travel_frames)
	_check(_arrows(room).is_empty(), "the arrow vanishes when its range is spent")

	await _frames(30)
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 60)
	shape.shape = rect
	wall.add_child(shape)
	wall.position = Vector2(335, 200)
	room.add_child(wall)
	await _frames(2)
	await _tap("attack")
	await _frames(20)
	_check(_arrows(room).is_empty(), "a wall in front stops the arrow long before its range")
	wall.queue_free()
	await _frames(30)


## The arrow damages an enemy once and disappears on it.
func _arrow_hits_dummy(room: Node, player: Node) -> void:
	var dummy = room.get_node("Dummy1")
	player.global_position = dummy.global_position - Vector2(40, 0)
	player.facing = Vector2.RIGHT
	await _frames(2)
	var hits_before: int = dummy.hits
	await _tap("attack")
	await _frames(25)
	_check(dummy.hits == hits_before + 1, "the arrow hits the dummy exactly once (%d -> %d)" % [hits_before, dummy.hits])
	_check(_arrows(room).is_empty(), "the arrow disappears on the enemy it hit")


func _arrows(room: Node) -> Array:
	return room.get_children().filter(func(child: Node) -> bool: return child.has_method("setup") and child.has_signal("hit_landed"))


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _tap(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		_ok = false
		print("FAIL ", message)
