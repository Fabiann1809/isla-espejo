extends SceneTree
## Boss test (Guardián del bosque): data, engagement, both attacks (and dodging them), super armor,
## phase two, territory, the reward (fragment + Raíces), the exit portal and the forest level flow.
## Run: godot --headless --path . --script res://tests/test_boss.gd
## `Boss`/`Enemy`/`Level` types must not be referenced here (autoload compile order).

const ARENA := Vector2(300, 180)

var _ok := true
var _room: Node
var _player: Node2D
var _messages: Array[String] = []
var _boss_bars: Array = []
var _defeated: Array = []
var _completed: Array = []
var _finished: Array = []


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var events: Node = root.get_node("Events")
	events.message_requested.connect(func(text: String) -> void: _messages.append(text))
	events.boss_health_changed.connect(func(id: StringName, current: int, maximum: int, boss_name: String) -> void:
		_boss_bars.append([id, current, maximum, boss_name]))
	events.boss_defeated.connect(func(id: StringName) -> void: _defeated.append(id))
	events.scenario_completed.connect(func(id: StringName) -> void: _completed.append(id))
	root.get_node("PlayerProfile").persistence_enabled = false
	root.get_node("PlayerProfile").run_finished.connect(func(summary: Dictionary) -> void: _finished.append(summary))
	root.get_node("GameState").reset()

	_test_data()
	await _make_room()
	await _test_engagement()
	await _test_slam()
	await _test_roots()
	await _test_super_armor()
	await _test_phase_two_and_territory()
	await _test_defeat_and_rewards()
	await _test_forest_level()

	root.get_node("GameState").reset()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


# --- Data -------------------------------------------------------------------------------------------

func _test_data() -> void:
	var boss: BossData = load("res://data/enemies/forest_guardian.tres")
	_check(boss != null and boss.id == &"forest_guardian" and boss.display_name == "Guardián del bosque", "the Guardián del bosque has its data")
	_check(boss.max_health >= 20 and boss.slam_damage >= 1 and boss.slam_windup >= 0.5 and boss.roots_windup >= 0.5,
			"it has real health and warning times long enough to react to")
	_check(boss.intro_lines.size() == 2 and "Nadie abandona la isla" in boss.intro_lines[1], "it has its two intro lines")
	_check(boss.pickup_scene != null and boss.defeated_flag == &"forest_boss_defeated", "it drops the fragment and sets the story flag")
	_check(boss.knockback_resistance == 1.0, "it cannot be knocked back")
	var scenario: ScenarioData = load("res://data/scenarios/forest.tres")
	_check(scenario.boss_scene != null and scenario.exit_scene != null and scenario.completion_text != "",
			"the forest scenario has its boss, exit and closing text")


# --- Arena setup ---------------------------------------------------------------------------------

func _make_room() -> void:
	if _room != null:
		_room.free()
	_room = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(_room)
	await _frames(4)
	_player = _room.get_node("Player")
	_player.global_position = ARENA + Vector2(600, 0)
	_player.health.heal(10)


func _spawn_boss() -> Node2D:
	# Warning circles of a previous section may still be alive and would expire during a check.
	for child in _room.get_children():
		if child is SkillZone:
			child.free()
	var boss: Node2D = load("res://scenes/enemies/forest_guardian.tscn").instantiate()
	boss.position = ARENA
	_room.add_child(boss)
	return boss


func _zones() -> int:
	var count := 0
	for child in _room.get_children():
		if child is SkillZone:
			count += 1
	return count


# --- Engagement -----------------------------------------------------------------------------------

func _test_engagement() -> void:
	var boss := _spawn_boss()
	_check(boss.health.max_health == 30, "the boss starts with 30 health")
	_player.global_position = ARENA + Vector2(0, 400)
	_messages.clear()
	await _frames(30)
	_check(boss.state == boss.State.IDLE and boss.target == null and _messages.is_empty(), "far away the boss stays quiet and idle")

	_player.global_position = ARENA + Vector2(150, 0)
	await _frames(25)
	_check(boss.target == _player, "when the player comes close the boss notices them")
	_check(_messages.size() == 2 and _messages[0].begins_with("Nico:") and _messages[1].begins_with("Guardián:"),
			"the fight opens with the two intro lines (%s)" % [_messages])
	_check(_boss_bars.size() > 0 and _boss_bars[-1] == [&"forest_guardian", 30, 30, "Guardián del bosque"], "the boss health bar is announced")
	_player.global_position = ARENA + Vector2(0, 400)
	await _frames(5)
	boss.free()


# --- The slam -------------------------------------------------------------------------------------

func _test_slam() -> void:
	# Staying inside the circle hurts.
	var boss := _spawn_boss()
	_player.global_position = ARENA + Vector2(36, 0)
	_player.health.heal(10)
	var before: int = _player.health.current
	var zones_before := _zones()
	await _frames(30)
	_check(boss.state == boss.State.ATTACK and boss.pattern == boss.Pattern.SLAM and boss.step == boss.Step.WINDUP,
			"next to the player the boss starts a slam and warns first")
	_check(_zones() > zones_before, "the warning circle is drawn")
	_check(_player.health.current == before, "no damage during the warning")
	await _frames(50)
	_check(_player.health.current == before - 2, "standing in the slam costs 2 health (%d -> %d)" % [before, _player.health.current])
	boss.free()
	await _frames(70)

	# Leaving the circle during the warning avoids it.
	boss = _spawn_boss()
	_player.global_position = ARENA + Vector2(36, 0)
	_player.health.heal(10)
	before = _player.health.current
	await _frames(30)
	_check(boss.state == boss.State.ATTACK and boss.step == boss.Step.WINDUP, "a second slam is warned")
	_player.global_position = ARENA + Vector2(120, 0)
	await _frames(70)
	_check(_player.health.current == before, "stepping out of the warned circle avoids the slam")
	boss.free()
	await _frames(5)


# --- The roots ----------------------------------------------------------------------------------------

func _test_roots() -> void:
	var boss := _spawn_boss()
	boss._last_pattern = boss.Pattern.SLAM
	_player.global_position = ARENA + Vector2(110, 0)
	_player.health.heal(10)
	var before: int = _player.health.current
	await _frames(25)
	_check(boss.state == boss.State.ATTACK and boss.pattern == boss.Pattern.ROOTS, "at range the boss calls the roots")
	_check(boss._roots_spots.size() == 3 and boss._roots_spots[0].distance_to(_player.global_position) < 2.0,
			"3 eruptions, the first one right where the player stands")
	await _frames(80)
	_check(_player.health.current == before - 1, "an eruption under the player costs 1 health (%d -> %d)" % [before, _player.health.current])
	boss.free()
	await _frames(70)

	boss = _spawn_boss()
	boss._last_pattern = boss.Pattern.SLAM
	_player.global_position = ARENA + Vector2(110, 0)
	_player.health.heal(10)
	before = _player.health.current
	await _frames(25)
	_check(boss.state == boss.State.ATTACK and boss.pattern == boss.Pattern.ROOTS, "the roots are warned again")
	_player.global_position = ARENA + Vector2(110, 140)
	await _frames(80)
	_check(_player.health.current == before, "moving away from the warned spots avoids the eruptions")
	boss.free()
	await _frames(5)


# --- Super armor ------------------------------------------------------------------------------------------

func _test_super_armor() -> void:
	var boss := _spawn_boss()
	_player.global_position = ARENA + Vector2(0, 400)
	await _frames(3)
	var hurtbox: Hurtbox = boss.get_node("Hurtbox")
	_boss_bars.clear()
	hurtbox.receive_hit(1, ARENA + Vector2(-20, 0))
	_check(boss.health.current == 29 and boss.state != boss.State.HURT, "a hit hurts the boss but does not interrupt it")
	_check(boss.target == _player, "being hit makes the boss aware of the player")
	_check(_boss_bars.size() > 0 and _boss_bars[-1][1] == 29 and _boss_bars[-1][2] == 30, "the health bar shows the new health after a hit")
	boss.apply_knockback(Vector2(300, 0))
	_check(boss.state != boss.State.HURT and boss.velocity.length() < 1.0, "the Corriente cannot push the boss")
	boss.apply_root(5.0)
	_check(not boss.is_rooted(), "Raíces cannot hold the boss")
	boss.apply_slow(0.4, 2.0)
	_check(boss.is_slowed() and is_equal_approx(boss._slow_factor, 0.7), "slows are only half as strong on the boss (x%.2f)" % boss._slow_factor)
	boss.free()
	await _frames(3)


# --- Phase two and territory ------------------------------------------------------------------------------

func _test_phase_two_and_territory() -> void:
	var boss := _spawn_boss()
	_player.global_position = ARENA + Vector2(0, 400)
	await _frames(3)
	_check(boss.phase == 1 and is_equal_approx(boss._scaled(1.0), 1.0), "the boss starts in phase one")
	boss.get_node("Hurtbox").receive_hit(14, ARENA)
	_check(boss.health.current == 16 and boss.phase == 1, "still phase one above half health")
	boss.get_node("Hurtbox").receive_hit(1, ARENA)
	_check(boss.health.current == 15 and boss.phase == 2, "at half health the boss enters phase two")
	_check(is_equal_approx(boss._scaled(1.0), 0.75), "phase two gives the player 25% less time to react")
	_player.global_position = ARENA + Vector2(100, 0)
	boss._last_pattern = boss.Pattern.SLAM
	boss._attack_cooldown_left = 0.0
	await _frames(25)
	_check(boss.state == boss.State.ATTACK and boss.pattern == boss.Pattern.ROOTS and boss._roots_spots.size() == 5,
			"phase two calls 5 eruptions instead of 3 (%d)" % boss._roots_spots.size())
	boss.free()
	await _frames(3)

	boss = _spawn_boss()
	await _frames(3)
	boss.global_position = ARENA + Vector2(500, 0)
	await _frames(3)
	_check(boss.global_position.distance_to(ARENA) <= 150.5, "the boss is territorial: it never leaves its arena (%.0f px from home)" % boss.global_position.distance_to(ARENA))
	boss.free()
	await _frames(3)


# --- Defeat, fragment, skill and exit ------------------------------------------------------------------

func _test_defeat_and_rewards() -> void:
	var state: Node = root.get_node("GameState")
	state.reset()
	var portal: Node2D = load("res://scenes/world/exit_portal.tscn").instantiate()
	portal.position = ARENA + Vector2(0, -120)
	portal.scenario_id = &"forest"
	_room.add_child(portal)
	await _frames(3)
	_check(not portal.is_open() and not portal.get_node("Glow").visible and not portal.get_node("Use").enabled,
			"before the boss falls the exit is closed and hidden")

	var boss := _spawn_boss()
	_player.global_position = ARENA + Vector2(0, 400)
	await _frames(3)
	_defeated.clear()
	boss.get_node("Hurtbox").receive_hit(999, ARENA)
	await _frames(3)
	_check(_defeated == [&"forest_guardian"], "Events.boss_defeated is emitted")
	_check(state.has_flag(&"forest_boss_defeated"), "the story flag is set")
	_check(boss.state == boss.State.DEAD, "the boss dies")
	var pickups := get_nodes_in_group("fragments")
	_check(pickups.size() == 1 and pickups[0].global_position.distance_to(ARENA) < 2.0, "a green fragment appears where the boss fell")
	_check(portal.is_open() and portal.get_node("Glow").visible and portal.get_node("Use").enabled, "the exit opens")

	# Take the fragment
	_messages.clear()
	_player.global_position = pickups[0].global_position + Vector2(0, 20)
	var prompts: Array[String] = []
	root.get_node("Events").interaction_prompt_changed.connect(func(text: String) -> void: prompts.append(text))
	await _frames(4)
	_check(prompts.size() > 0 and prompts[-1] == "Recoger", "the fragment can be picked up with E ('%s')" % (prompts[-1] if prompts.size() > 0 else "-"))
	_check(not _player.skills.is_unlocked(0), "before the fragment the player has no skills")
	await _tap("interact")
	_check(state.has_fragment(&"green"), "the green fragment is recorded")
	_check(state.skills.has(&"roots") and _player.skills.is_unlocked(0) and _player.skills.get_skill(0).id == &"roots",
			"the player learns Raíces")
	_check(_messages == ["Fragmento de brújula obtenido.", "Habilidad aprendida: Raíces"], "the player is told what they got (%s)" % [_messages])
	await _frames(3)
	_check(get_nodes_in_group("fragments").is_empty(), "the fragment disappears once taken")

	# Leave through the exit
	_player.global_position = portal.global_position + Vector2(0, 20)
	_completed.clear()
	_finished.clear()
	root.get_node("PlayerProfile").begin_run()
	root.get_node("PlayerProfile").advance(30.0)
	await _frames(4)
	_check(prompts[-1] == "Continuar el viaje", "the open exit offers to continue the journey")
	await _tap("interact")
	_check(_completed == [&"forest"], "using the exit completes the scenario (Events.scenario_completed)")
	_check(_finished.size() == 1 and _finished[0].reason == "victory", "the run ends as a victory and the profile learns from it")
	portal.free()


# --- The forest level ---------------------------------------------------------------------------------------

func _test_forest_level() -> void:
	var state: Node = root.get_node("GameState")
	var director: Node = root.get_node("Director")
	director.log_to_console = false
	state.reset()
	var level: Node2D = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.seed_value = 4242
	level.use_director = false
	level.completion_delay = 0.2
	root.add_child(level)
	await _frames(5)

	var boss_room = null
	for room in level.rooms.values():
		if room.data.type == RoomData.RoomType.BOSS:
			boss_room = room
	var bosses := get_nodes_in_group("enemies").filter(func(n: Node) -> bool: return n.name == "ForestGuardian" and n.health.current > 0)
	var portals := get_nodes_in_group("exit_portals")
	_check(bosses.size() == 1 and bosses[0].get_parent() == boss_room, "the forest level puts the Guardián in the boss room")
	_check(portals.size() == 1 and portals[0].get_parent() == boss_room and portals[0].scenario_id == &"forest", "and the exit next to it, closed")
	_check(not level.player.skills.is_unlocked(0), "a new game starts without skills (they are earned from the bosses)")

	# What the player earned is remembered by the next player/map (dying or moving on).
	state.learn_skill(&"roots")
	state.collect_fragment(&"green")
	state.set_flag(&"forest_boss_defeated")
	var first_seed: int = level.current_seed
	level.generate(777)
	await _frames(3)
	_check(level.current_seed == 777, "a new map is generated")
	var fresh: Node2D = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(fresh)
	state.apply_to_player(fresh)
	_check(fresh.skills.is_unlocked(0) and fresh.skills.get_skill(0).id == &"roots", "a new player gets the skills already learned (they survive death)")
	fresh.free()

	# Taking the exit moves on to a new map after the closing text
	_messages.clear()
	var portal = get_nodes_in_group("exit_portals")[0]
	level.player.global_position = portal.global_position + Vector2(0, 20)
	await _frames(4)
	await _tap("interact")
	_check(_messages.size() > 0 and _messages[-1].begins_with("Capítulo 1 completado"), "the closing text is shown (\"%s\")" % (_messages[-1] if _messages.size() > 0 else ""))
	await create_timer(0.5).timeout
	await _frames(3)
	_check(level.current_seed != 777 and level.current_seed != first_seed, "after the exit the next map starts")
	_check(level.player.skills.is_unlocked(0), "the player keeps their skills on the new map")
	level.free()


# --- Helpers ----------------------------------------------------------------------------------------------

func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _tap(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(3)
	await process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(2)
