extends SceneTree
## The player's attack numbers come from a WeaponData (data/weapons/), not from the script.
## Run: godot --headless --path . --script res://tests/test_weapons.gd

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame

	var sword: Resource = load("res://data/weapons/sword.tres")
	_check(sword != null and sword.id == &"sword", "the sword weapon data loads")
	_check(sword.damage >= 1 and sword.attack_time > 0.0 and sword.attack_cooldown > 0.0, "the sword has usable numbers")
	_check(sword.display_name != "", "the weapon has a Spanish name in its data")

	var room: Node = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(room)
	for i in 3:
		await physics_frame
	var player = room.get_node("Player")
	_check(player.weapon == sword, "the player scene equips the sword")
	_check(player.attack_damage == sword.damage and is_equal_approx(player.attack_time, sword.attack_time)
		and is_equal_approx(player.attack_cooldown, sword.attack_cooldown)
		and is_equal_approx(player.attack_move_factor, sword.move_factor), "the player copies the weapon's numbers")

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

	var dummy = room.get_node("Dummy1")
	player.global_position = dummy.global_position - Vector2(20, 0)
	player.facing = Vector2.RIGHT
	for i in 2:
		await physics_frame
	Input.action_press("attack")
	await physics_frame
	Input.action_release("attack")
	for i in 6:
		await physics_frame
	_check(player.get_node("AttackPivot/Hitbox").damage == 3, "the attack hitbox deals the equipped weapon's damage")

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		_ok = false
		print("FAIL ", message)
