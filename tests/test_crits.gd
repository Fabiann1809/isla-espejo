extends SceneTree
## Critical arrows: with the chance at 1.0 every arrow deals double damage through the normal Hitbox hit,
## at 0.0 none does, `Events.player_crit` fires, the damage number turns gold and big, and the shop's
## bow upgrade adds damage (multiplied on a crit too).
## Run: godot --headless --path . --script res://tests/test_crits.gd

var _ok := true
var _events: Node
var _damages: Array[int] = []
var _crits: Array[int] = []
var _hits: Array[int] = []


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_events = root.get_node("Events")
	var state: Node = root.get_node("GameState")
	state.reset()
	_events.enemy_damaged.connect(func(_e: Node, amount: int) -> void: _damages.append(amount))
	_events.player_crit.connect(func(_e: Node, damage: int) -> void: _crits.append(damage))
	_events.player_hit_enemy.connect(func(_e: Node, damage: int) -> void: _hits.append(damage))

	var room: Node = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(room)
	var feel: Node = load("res://scripts/effects/game_feel.gd").new()
	room.add_child(feel)
	await _frames(3)
	var player = room.get_node("Player")
	var dummy = room.get_node("Dummy1")
	dummy.health.set_max_health(500)
	dummy.add_to_group("enemies")

	_check(is_equal_approx(Tuning.PLAYER_CRIT_CHANCE, 0.05) and is_equal_approx(Tuning.PLAYER_CRIT_MULTIPLIER, 2.0),
			"the base values are in Tuning: 5% and x2")
	_check(is_equal_approx(player.crit_chance, 0.05) and is_equal_approx(player.total_crit_chance(), 0.05),
			"Nico starts with the base chance")

	# Chance 0: never a crit.
	player.crit_chance = 0.0
	for i in 6:
		await _shoot(player, dummy)
	_check(_damages.size() == 6 and _damages.all(func(d: int) -> bool: return d == 1), "at 0.0 every arrow deals 1 (%s)" % [_damages])
	_check(_crits.is_empty(), "at 0.0 no crit event fires")

	# Chance 1: always a crit, doubled through the normal hit.
	_damages.clear()
	_hits.clear()
	player.crit_chance = 1.0
	var health_before: int = dummy.health.current
	await _shoot(player, dummy)
	_check(_damages == [2], "at 1.0 the arrow deals double damage (%s)" % [_damages])
	_check(dummy.health.current == health_before - 2, "the enemy's health really dropped by 2")
	_check(_crits == [2], "Events.player_crit(enemy, damage) fires with the multiplied damage (%s)" % [_crits])
	_check(_hits == [2], "Events.player_hit_enemy carries the real damage too")
	var gold_number := _crit_label(feel)
	_check(gold_number != null and gold_number.get_theme_color("font_color") == Tuning.DAMAGE_NUMBER_CRIT_COLOR
			and gold_number.get_theme_font_size("font_size") == Tuning.DAMAGE_NUMBER_CRIT_SIZE
			and gold_number.text == "2", "GameFeel shows that number gold and bigger")
	_check(Tuning.DAMAGE_NUMBER_CRIT_SIZE > Tuning.DAMAGE_NUMBER_SIZE, "the crit number is bigger than a normal one")

	# The off switch value: a chance only counts while crits are on.
	_check(is_equal_approx(player.total_crit_chance(), 1.0 if Tuning.CRITS_ENABLED else 0.0), "CRITS_ENABLED gates the chance")

	# The bow upgrade adds damage; a crit doubles the upgraded damage.
	_damages.clear()
	_crits.clear()
	state.add_upgrade(&"bow_damage")
	state.apply_upgrades(player)
	_check(player.arrow_damage() == player.attack_damage + 1, "bow_damage adds 1 to every arrow")
	player.crit_chance = 0.0
	await _shoot(player, dummy)
	_check(_damages == [2] and _crits.is_empty(), "an upgraded plain arrow deals 2")
	player.crit_chance = 1.0
	await _shoot(player, dummy)
	_check(_damages == [2, 4] and _crits == [4], "an upgraded crit deals 4 (%s, %s)" % [_damages, _crits])
	state.add_upgrade(&"bow_damage")
	state.apply_upgrades(player)
	player.crit_chance = 0.0
	_damages.clear()
	await _shoot(player, dummy)
	_check(_damages == [3], "level 2 deals 3")

	# The crit upgrade adds to the chance.
	state.reset()
	state.apply_upgrades(player)
	_check(player.bonus_damage == 0 and is_zero_approx(player.crit_bonus), "a wiped GameState takes the bonuses off")
	state.add_upgrade(&"crit_chance")
	state.add_upgrade(&"crit_chance")
	state.apply_upgrades(player)
	player.crit_chance = 0.05
	_check(is_equal_approx(player.total_crit_chance(), 0.15), "two crit levels make 5% + 10% = 15%")

	state.reset()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _crit_label(feel: Node) -> Label:
	for child in feel.get_children():
		if child is Label and child.has_meta("crit"):
			return child
	return null


## Stands 40 px left of the dummy, waits out the cooldown, shoots and lets the arrow land; a shot that
## flew by (the dummy is pushed around) is repeated, so every call ends with exactly one new hit.
func _shoot(player: Node, dummy: Node) -> void:
	var before := _damages.size()
	for attempt in 4:
		# Open ground every time: the dummy is knocked back and could end against a wall.
		dummy.global_position = Vector2(340, 200)
		player.global_position = Vector2(300, 200)
		player.facing = Vector2.RIGHT
		await _frames(30)
		Input.action_press("attack")
		await physics_frame
		Input.action_release("attack")
		await _frames(25)
		if _damages.size() > before:
			return


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		print("FAIL ", message)
		_ok = false
