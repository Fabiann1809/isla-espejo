extends SceneTree
## Basic run resources: data, pickups, the drop spawner (chance, pity, floor limit, minions that
## drop nothing), the arrow orb's fan of arrows, gold and the loss of everything at the end of a run.
## Run: godot --headless --path . --script res://tests/test_resources.gd

var _ok := true


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame

	var heart: Resource = load("res://data/resources/heart.tres")
	var arrows: Resource = load("res://data/resources/arrows.tres")
	var gold: Resource = load("res://data/resources/gold.tres")
	_check(heart.display_name != "" and arrows.display_name != "" and gold.display_name != "" and arrows.message != "",
			"the resources have their Spanish texts in data")
	var scenario: Resource = load("res://data/scenarios/forest.tres")
	_check(scenario.drops.size() == 3, "the forest leaves hearts, arrow orbs and gold")
	_check(load("res://data/enemies/brote.tres").drop_multiplier == 0.0 and load("res://data/enemies/ente.tres").drop_multiplier > 1.0,
			"minions drop nothing and the mini boss drops more")

	var room: Node = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(room)
	await _frames(3)
	var player = room.get_node("Player")
	var events = root.get_node("Events")

	# Pickups: gold and arrows apply; a heart waits while health is full and is taken once it is not.
	var health_before: int = player.health.current
	_check(not heart.apply(player), "a heart is not used at full health")
	player.health.take_damage(2)
	_check(heart.apply(player) and player.health.current == player.health.max_health - 1, "a heart heals 1")
	player.health.heal(5)
	var totals := []
	events.player_gold_changed.connect(func(total: int) -> void: totals.append(total))
	gold.apply(player)
	_check(player.gold >= 1 and player.gold <= 3 and totals.size() == 1, "gold adds 1 to 3 coins and tells the HUD")

	# The drop spawner: guaranteed pity drop, floor limit, no drops from minions.
	var spawner = load("res://scripts/world/drop_spawner.gd").new()
	spawner.drops.assign([heart])
	spawner.rng.seed = 5
	root.add_child(spawner)
	var dummy = _fake_enemy(room, 1.0)
	player.health.take_damage(3)
	for i in 11:
		events.enemy_killed.emit(dummy)
	await _frames(1)
	for pickup in root.get_tree().get_nodes_in_group("pickups"):
		pickup.free()
	spawner._dry_kills.clear()
	for i in 12:
		events.enemy_killed.emit(dummy)
	await _frames(1)
	_check(_pickups(heart) >= 1, "pity: a heart is guaranteed after 12 kills without one")
	for i in 80:
		events.enemy_killed.emit(dummy)
	await _frames(1)
	_check(_pickups(heart) <= heart.max_on_floor, "no more hearts than the floor limit lie around (%d)" % _pickups(heart))
	for pickup in root.get_tree().get_nodes_in_group("pickups"):
		pickup.free()
	var minion = _fake_enemy(room, 0.0)
	spawner._dry_kills.clear()
	for i in 40:
		events.enemy_killed.emit(minion)
	await _frames(1)
	_check(root.get_tree().get_nodes_in_group("pickups").is_empty(), "enemies with drop_multiplier 0 never drop")

	# Walking over a pickup takes it.
	var pickup: Node = load("res://scenes/world/pickup.tscn").instantiate()
	pickup.setup(gold)
	pickup.position = player.position
	room.add_child(pickup)
	var gold_before: int = player.gold
	await _frames(4)
	_check(player.gold > gold_before and not is_instance_valid(pickup) or pickup.is_queued_for_deletion(), "touching a pickup takes it")

	# The arrow orb: shots become a fan of 3, one real shot for the AI.
	arrows.apply(player)
	var buffs := []
	events.player_buff_changed.connect(func(id: StringName, duration: float, _c: Color) -> void: buffs.append([id, duration]))
	player.global_position = Vector2(300, 200)
	player.facing = Vector2.RIGHT
	await _frames(2)
	await _tap("attack")
	await _frames(25)
	var fan := 0
	for node in room.get_children():
		if node is Arrow:
			fan += 1
	_check(fan == 3, "with the orb a shot sends 3 arrows (%d)" % fan)
	# The effect ends by itself.
	player._buff_left = 0.01
	await _frames(3)
	_check(not buffs.is_empty() and buffs[-1][1] == 0.0 and player._extra_arrows == 0, "the orb wears off and says so")

	# Everything of the run is lost together.
	player.add_gold(10)
	arrows.apply(player)
	player.clear_run_resources()
	_check(player.gold == 0 and player._extra_arrows == 0 and player._buff_left == 0.0, "ending the run drops gold and the orb")

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


## A real enemy (never fighting: it is only the position and data the spawner reads).
func _fake_enemy(room: Node, luck: float) -> Node2D:
	var enemy: Node2D = load("res://scenes/enemies/grunt.tscn").instantiate()
	enemy.data = enemy.data.duplicate()
	enemy.data.drop_multiplier = luck
	enemy.position = Vector2(200, 100)
	room.add_child(enemy)
	return enemy


func _pickups(resource: Resource) -> int:
	var count := 0
	for pickup in root.get_tree().get_nodes_in_group("pickups"):
		if pickup.data == resource:
			count += 1
	return count


func _tap(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
