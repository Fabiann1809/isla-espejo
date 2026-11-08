extends SceneTree
## Temporary power-ups (arrow fan, pierce, frost, haste, shield): several run at once, taking one again
## restarts its time, pierce hits three enemies once each, frost slows what an arrow hits, haste changes the
## walking speed and the time between shots and gives them back, the shield absorbs two hits and expires,
## a kill leaves at most one buff, new maps and death end them all, and the HUD shows one row each.
## Run: godot --headless --path . --script res://tests/test_power_ups.gd

var _ok := true
var _events: Node
var _changes := []


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_events = root.get_node("Events")
	_events.player_buff_changed.connect(func(id: StringName, duration: float, _c: Color) -> void: _changes.append([id, duration]))

	var data := {}
	for id in [&"arrows", &"pierce", &"frost", &"haste", &"shield"]:
		data[id] = load("res://data/resources/%s.tres" % id)
	_check_data(data)

	var room: Node = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(room)
	await _frames(3)
	# Nothing else may fight Nico or the dummies.
	for node_name in ["Grunt1", "Grunt2", "Trap1", "Trap2"]:
		room.get_node(node_name).free()
	var player = room.get_node("Player")

	await _test_several_and_refresh(player, data)
	await _test_pierce(room, player, data)
	await _test_frost(room, player, data)
	await _test_haste(player, data)
	await _test_shield(player, data)
	await _test_drop_rule(room, data)
	await _test_end_all(player, data)
	await _test_pickups_without_art(room, data)
	await _test_hud(data)

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check_data(data: Dictionary) -> void:
	var names := {&"pierce": "Flechas perforantes", &"frost": "Flechas de escarcha", &"haste": "Viento veloz", &"shield": "Escudo de eco"}
	for id in names:
		_check(data[id].id == id and data[id].display_name == names[id] and data[id].message != "" and data[id].is_buff(),
				"%s is a buff with its Spanish name and message" % id)
	_check(data[&"pierce"].pierce_count == 3 and is_equal_approx(data[&"pierce"].duration, 12.0), "pierce: 3 enemies, 12 s")
	_check(is_equal_approx(data[&"frost"].slow_factor, 0.5) and is_equal_approx(data[&"frost"].slow_seconds, 2.0)
			and is_equal_approx(data[&"frost"].duration, 12.0), "frost: x0.5 for 2 s, lasts 12 s")
	_check(is_equal_approx(data[&"haste"].speed_bonus, 0.35) and is_equal_approx(data[&"haste"].cooldown_cut, 0.4)
			and is_equal_approx(data[&"haste"].duration, 10.0), "haste: +35% speed, 40% shorter cooldown, 10 s")
	_check(data[&"shield"].shield_charges == 2 and is_equal_approx(data[&"shield"].duration, 20.0), "shield: 2 hits, 20 s")
	for id in names:
		_check(data[id].max_on_floor == 1 and is_equal_approx(data[id].lifetime, 10.0) and data[id].drop_chance <= 0.03,
				"%s is a rare drop (one on the floor, 10 s)" % id)


func _test_several_and_refresh(player: Node, data: Dictionary) -> void:
	_changes.clear()
	data[&"arrows"].apply(player)
	data[&"haste"].apply(player)
	data[&"frost"].apply(player)
	_check(player.buff_ids().size() == 3 and player.has_buff(&"arrows") and player.has_buff(&"haste") and player.has_buff(&"frost"),
			"three different buffs run at once")
	_check(_changes.size() == 3 and _changes[2] == [&"frost", 12.0], "each start is announced on Events.player_buff_changed")
	player._buffs[&"haste"]["left"] = 2.0
	player._buffs[&"arrows"]["left"] = 5.0
	data[&"haste"].apply(player)
	_check(player.buff_ids().size() == 3 and is_equal_approx(player.buff_left(&"haste"), 10.0)
			and is_equal_approx(player.buff_left(&"arrows"), 5.0), "taking the same buff again restarts only its time")
	player._buffs[&"frost"]["left"] = 0.01
	await _frames(3)
	_check(not player.has_buff(&"frost") and player.has_buff(&"haste") and _changes[-1][0] == &"frost" and _changes[-1][1] == 0.0,
			"one buff ends alone and says so; the others go on")
	player.end_all_buffs()
	_check(player.buff_ids().is_empty(), "end_all_buffs clears them")


func _test_pierce(room: Node, player: Node, data: Dictionary) -> void:
	data[&"pierce"].apply(player)
	var dummies := []
	for i in 4:
		var dummy: Node = load("res://scenes/enemies/training_dummy.tscn").instantiate()
		dummy.position = Vector2(350 + i * 26, 200)
		room.add_child(dummy)
		dummy.health.set_max_health(50)
		dummies.append(dummy)
	await _shoot(player, Vector2(300, 200))
	var hits: Array = dummies.map(func(d: Node) -> int: return d.hits)
	_check(hits == [1, 1, 1, 0], "a piercing arrow hits three enemies once each and stops (%s)" % [hits])
	for dummy in dummies:
		dummy.free()
	player.end_all_buffs()

	var plain: Node = load("res://scenes/enemies/training_dummy.tscn").instantiate()
	var behind: Node = load("res://scenes/enemies/training_dummy.tscn").instantiate()
	plain.position = Vector2(350, 200)
	behind.position = Vector2(376, 200)
	room.add_child(plain)
	room.add_child(behind)
	await _shoot(player, Vector2(300, 200))
	_check(plain.hits == 1 and behind.hits == 0, "without the buff the arrow ends on the first enemy")
	plain.free()
	behind.free()


func _test_frost(room: Node, player: Node, data: Dictionary) -> void:
	var grunt: Node = load("res://scenes/enemies/grunt.tscn").instantiate()
	grunt.position = Vector2(360, 200)
	room.add_child(grunt)
	await _frames(2)
	# Enough health that two arrows (one may roll a crit) never kill it.
	grunt.health.set_max_health(99)
	_check(not grunt.is_slowed(), "a fresh enemy is not slowed")
	await _shoot(player, Vector2(300, 200))
	_check(not grunt.is_slowed(), "without frost an arrow does not slow")
	data[&"frost"].apply(player)
	grunt.position = Vector2(360, 200)
	await _shoot(player, Vector2(300, 200))
	_check(grunt.is_slowed() and is_equal_approx(grunt._slow_factor, 0.5), "a frost arrow slows the enemy to half speed")
	player.end_all_buffs()
	grunt.free()


func _test_haste(player: Node, data: Dictionary) -> void:
	var speed: float = player.speed
	var cooldown: float = player.attack_cooldown
	_check(is_equal_approx(player.move_speed(), speed) and is_equal_approx(player.shot_cooldown(), cooldown), "no haste: base numbers")
	data[&"haste"].apply(player)
	_check(is_equal_approx(player.move_speed(), speed * 1.35), "haste: +35% speed")
	_check(is_equal_approx(player.shot_cooldown(), cooldown * 0.6), "haste: 40% shorter time between shots")
	player.global_position = Vector2(-200, 100)
	Input.action_press("move_right")
	await _frames(6)
	var fast: float = player.velocity.length()
	Input.action_release("move_right")
	_check(absf(fast - speed * 1.35) < 1.0, "Nico really walks faster (%.0f)" % fast)
	player._buffs[&"haste"]["left"] = 0.01
	await _frames(3)
	_check(is_equal_approx(player.move_speed(), speed) and is_equal_approx(player.shot_cooldown(), cooldown),
			"when haste ends the numbers come back")
	player.end_all_buffs()


func _test_shield(player: Node, data: Dictionary) -> void:
	var hurtbox: Node = player.get_node("Hurtbox")
	var health_before: int = player.health.current
	var damaged := []
	_events.player_damaged.connect(func(amount: int, _from: Vector2) -> void: damaged.append(amount))
	var charges := []
	_events.player_buff_charges_changed.connect(func(id: StringName, left: int) -> void: charges.append([id, left]))
	data[&"shield"].apply(player)
	_check(player.shield_charges() == 2 and _has_bubble_alive(player),
			"the shield starts with 2 charges and a bubble around Nico")
	_check(hurtbox.receive_hit(1, Vector2(0, 0)) and player.health.current == health_before and player.shield_charges() == 1,
			"the first hit is absorbed: no damage, one charge left")
	_check(player.is_invulnerable() and player.state != player.State.HURT, "it leaves the i-frames of a hit, without knockback")
	_check(not hurtbox.receive_hit(1, Vector2.ZERO), "during the i-frames nothing lands")
	player._invulnerable_left = 0.0
	_check(hurtbox.receive_hit(1, Vector2(0, 0)) and player.health.current == health_before and not player.has_buff(&"shield"),
			"the second hit is absorbed and the shield is spent")
	_check(not _has_bubble_alive(player), "the bubble is gone with the shield")
	_check(charges == [[&"shield", 2], [&"shield", 1], [&"shield", 0]] and damaged.is_empty(),
			"the charges are reported and no damage event fired (%s)" % [charges])
	player._invulnerable_left = 0.0
	player.state = player.State.IDLE
	hurtbox.receive_hit(1, Vector2(0, 0))
	_check(player.health.current == health_before - 1, "the third hit hurts as usual")
	player.health.heal(5)
	player._invulnerable_left = 0.0
	player.state = player.State.IDLE
	await _frames(2)

	# It also wears off by time.
	data[&"shield"].apply(player)
	player._buffs[&"shield"]["left"] = 0.01
	await _frames(3)
	_check(not player.has_buff(&"shield") and player.shield_charges() == 0, "an unused shield expires after its time")
	var before: int = player.health.current
	player._invulnerable_left = 0.0
	hurtbox.receive_hit(1, Vector2.ZERO)
	_check(player.health.current == before - 1, "an expired shield protects nothing")
	player.health.heal(5)
	player._invulnerable_left = 0.0
	player.state = player.State.IDLE
	player.end_all_buffs()


func _has_bubble_alive(player: Node) -> bool:
	for child in player.get_children():
		if child.get_script() != null and child.get_script().get_global_name() == &"ShieldBubble" and not child.is_queued_for_deletion():
			return true
	return false


func _test_drop_rule(room: Node, data: Dictionary) -> void:
	var spawner = load("res://scripts/world/drop_spawner.gd").new()
	var list: Array[Resource] = []
	for resource in [load("res://data/resources/heart.tres"), load("res://data/resources/gold.tres"), data[&"arrows"],
			data[&"pierce"], data[&"frost"], data[&"haste"], data[&"shield"]]:
		var copy: Resource = resource.duplicate()
		copy.drop_chance = 1.0
		copy.max_on_floor = 99
		list.append(copy)
	spawner.drops.assign(list)
	spawner.rng.seed = 11
	root.add_child(spawner)
	var enemy: Node2D = load("res://scenes/enemies/grunt.tscn").instantiate()
	enemy.data = enemy.data.duplicate()
	enemy.data.drop_multiplier = 1.0
	enemy.position = Vector2(200, 100)
	room.add_child(enemy)
	var kinds := {}
	var worst := 0
	var always_gold := true
	for kill in 8:
		var buffs_before := _count_buffs()
		var gold_before := _count_gold()
		_events.enemy_killed.emit(enemy)
		await _frames(1)
		worst = maxi(worst, _count_buffs() - buffs_before)
		always_gold = always_gold and _count_gold() == gold_before + 1
		for pickup in root.get_tree().get_nodes_in_group("pickups"):
			if pickup.data.is_buff():
				kinds[pickup.data.id] = true
	_check(worst == 1, "every kill leaves exactly one buff even when all five win (%d)" % worst)
	_check(always_gold, "gold is not limited by the buff rule")
	_check(kinds.size() >= 2, "the buff that is left varies (%s)" % [kinds.keys()])
	for pickup in root.get_tree().get_nodes_in_group("pickups"):
		pickup.free()
	spawner.free()
	enemy.free()


func _count_buffs() -> int:
	var count := 0
	for pickup in root.get_tree().get_nodes_in_group("pickups"):
		if pickup.data.is_buff():
			count += 1
	return count


func _count_gold() -> int:
	var count := 0
	for pickup in root.get_tree().get_nodes_in_group("pickups"):
		if pickup.data.id == &"gold":
			count += 1
	return count


func _test_end_all(player: Node, data: Dictionary) -> void:
	for id in data:
		data[id].apply(player)
	_check(player.buff_ids().size() == 5, "all five buffs can run together")
	_changes.clear()
	player.reset_for_new_map()
	_check(player.buff_ids().is_empty() and _changes.size() == 5 and _changes.all(func(c: Array) -> bool: return c[1] == 0.0),
			"a new map ends every buff and announces each end")
	for id in data:
		data[id].apply(player)
	player.clear_run_resources()
	_check(player.buff_ids().is_empty() and not _has_bubble_alive(player), "ending the run ends every buff")


func _test_pickups_without_art(room: Node, data: Dictionary) -> void:
	var drawn := true
	for id in data:
		var pickup: Node = load("res://scenes/world/pickup.tscn").instantiate()
		pickup.setup(data[id])
		pickup.position = Vector2(-300, -150)
		room.add_child(pickup)
		await _frames(2)
		if ResourceLoader.exists("res://assets/sprites/pickups/buff_%s.png" % id):
			drawn = drawn and pickup.art != null
		else:
			drawn = drawn and pickup.art == null
		pickup.free()
	_check(drawn, "a buff pickup uses its strip when the file exists and the code-drawn orb when it does not")


func _test_hud(data: Dictionary) -> void:
	var hud = load("res://scenes/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await process_frame
	_events.player_buff_changed.emit(&"arrows", 12.0, data[&"arrows"].color)
	_events.player_buff_changed.emit(&"shield", 20.0, data[&"shield"].color)
	_events.player_buff_charges_changed.emit(&"shield", 2)
	await process_frame
	_check(hud._buff_rows.size() == 2, "the HUD shows two rows for two buffs")
	var rows: Array = hud._buff_rows.values()
	_check(rows[0]["row"].position.y != rows[1]["row"].position.y, "the rows are stacked")
	_check(rows[1]["charges"].text == "x2", "the shield row shows its charges")
	_events.player_buff_charges_changed.emit(&"shield", 1)
	_check(rows[1]["charges"].text == "x1", "and updates them")
	await create_timer(0.5).timeout
	_check(rows[0]["fill"].size.x < hud.BUFF_BAR_SIZE.x, "the bar shrinks with time")
	_events.player_buff_changed.emit(&"arrows", 0.0, Color.WHITE)
	await process_frame
	await process_frame
	_check(hud._buff_rows.size() == 1 and is_equal_approx(hud._buff_rows[&"shield"]["row"].position.y, 0.0),
			"an ended buff loses its row and the rest close the gap")
	_events.player_buff_changed.emit(&"shield", 0.0, Color.WHITE)
	await process_frame
	_check(hud._buff_rows.is_empty(), "no rows when no buff runs")
	hud.free()


## Waits out the cooldown with Nico at `from` facing right, shoots once and lets the arrow fly.
func _shoot(player: Node, from: Vector2) -> void:
	player.global_position = from
	player.facing = Vector2.RIGHT
	await _frames(40)
	Input.action_press("attack")
	await physics_frame
	Input.action_release("attack")
	await _frames(30)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		print("FAIL ", message)
		_ok = false
