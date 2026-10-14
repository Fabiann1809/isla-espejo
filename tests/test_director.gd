extends SceneTree
## Director test (AI layer 2): the pure decision (profile -> plan), how the plan changes enemies and
## maps, and the visible reactions (island line, death screen hints).
## Run: godot --headless --path . --script res://tests/test_director.gd
## `Level`, `Room` and `Enemy` types must not be referenced here (autoload compile order).

const ARENA := Vector2(300, 180)

var _ok := true
var _config: DirectorConfig
var _profile: Node
var _director: Node
var _plans_announced := 0


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_profile = root.get_node("PlayerProfile")
	_director = root.get_node("Director")
	_profile.persistence_enabled = false
	_profile.auto_tick = false
	_director.log_to_console = false
	_director.plan_made.connect(func(_plan: DirectorPlan) -> void: _plans_announced += 1)
	_config = load("res://data/ai/director_rules.tres")

	_test_rule_table()
	_test_decision()
	_test_scaling()
	_test_plan_helpers()
	await _test_enemy_effects()
	_test_map_generation()
	await _test_level_integration()
	await _test_visible_reactions()

	_profile.model.reset()
	_profile.auto_tick = true
	_director.enabled = true
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


# --- The rule table ---------------------------------------------------------------------------

func _test_rule_table() -> void:
	_check(_config != null, "the director rule table loads")
	for style in [&"aggressive", &"stealth", &"balanced"]:
		var rule: DirectorRule = _config.rules.get(style)
		_check(rule != null and not rule.hints.is_empty(), "there is a rule with Spanish hints for '%s'" % style)
	_check(_config.rules[&"aggressive"].island_line != "" and _config.rules[&"stealth"].island_line != "",
			"aggressive and stealth have a line the island says")
	_check(_config.texts.get("prepare_title", "") != "", "the death screen title is in the data")


# --- The decision ---------------------------------------------------------------------------------

func _test_decision() -> void:
	var aggressive := DirectorLogic.plan_for(0.95, 0.05, &"aggressive", _config)
	_check(aggressive.intensity == 1.0, "a clearly aggressive player gets the full reaction")
	_check(aggressive.health_multiplier > 1.3 and aggressive.speed_multiplier > 1.05 and aggressive.count_multiplier > 1.2,
			"aggressive: tougher, faster and more numerous enemies (hp x%.2f, count x%.2f)" % [aggressive.health_multiplier, aggressive.count_multiplier])
	_check(aggressive.room_weights.get(&"ambush", 1.0) > 1.0, "aggressive: ambush rooms are favoured")
	_check(aggressive.vision_multiplier == 1.0, "aggressive: enemy sight is left alone")
	_check(aggressive.island_line == _config.rules[&"aggressive"].island_line, "aggressive: the island says its line")

	var stealthy := DirectorLogic.plan_for(0.05, 0.95, &"stealth", _config)
	_check(stealthy.vision_multiplier > 1.4 and stealthy.patrol_multiplier > 1.8,
			"stealth: enemies see farther and patrol wider (vision x%.2f, patrol x%.2f)" % [stealthy.vision_multiplier, stealthy.patrol_multiplier])
	_check(stealthy.room_weights.get(&"watch", 1.0) > 1.0 and stealthy.room_weights.get(&"ambush", 1.0) < 1.0,
			"stealth: guarded rooms are favoured over ambushes")
	_check(stealthy.health_multiplier == 1.0, "stealth: enemy health is left alone")

	var balanced := DirectorLogic.plan_for(0.5, 0.5, &"balanced", _config)
	_check(balanced.health_multiplier > 1.0 and balanced.health_multiplier < aggressive.health_multiplier
			and balanced.vision_multiplier > 1.0 and balanced.vision_multiplier < stealthy.vision_multiplier,
			"balanced: a mild mix of both reactions")

	var unknown := DirectorLogic.plan_for(0.9, 0.1, &"unheard-of", _config)
	_check(unknown.health_multiplier == 1.0 and unknown.count_multiplier == 1.0 and unknown.room_weights.is_empty()
			and unknown.reasons.size() == 1, "a style without a rule leaves everything unchanged and explains why")
	var no_config := DirectorLogic.plan_for(0.9, 0.1, &"aggressive", null)
	_check(no_config.health_multiplier == 1.0, "a missing rule table leaves everything unchanged")

	_check(aggressive.reasons.size() >= 3 and "aggressive" in aggressive.reasons[0] and "100%" in aggressive.reasons[0],
			"the plan explains its decision (%s)" % aggressive.reasons[0])
	_check("aggressive" in aggressive.summary_line(), "the summary line names the style")


func _test_scaling() -> void:
	var previous_health := 1.0
	var previous_count := 1.0
	var monotonic := true
	for tenth in range(0, 8):
		var difference := tenth * 0.1
		var plan := DirectorLogic.plan_for(0.5 + difference / 2.0, 0.5 - difference / 2.0, &"aggressive", _config)
		if plan.health_multiplier < previous_health - 0.0001 or plan.count_multiplier < previous_count - 0.0001:
			monotonic = false
		previous_health = plan.health_multiplier
		previous_count = plan.count_multiplier
	_check(monotonic, "the clearer the style, the stronger the reaction (never weaker)")
	var capped := DirectorLogic.plan_for(1.0, 0.0, &"aggressive", _config)
	_check(is_equal_approx(capped.health_multiplier, _config.rules[&"aggressive"].health_multiplier),
			"the reaction never exceeds the rule's own numbers")

	var slight := DirectorLogic.plan_for(0.6, 0.4, &"aggressive", _config)
	_check(slight.intensity > 0.2 and slight.intensity < 0.5 and slight.health_multiplier > 1.0
			and slight.health_multiplier < capped.health_multiplier, "a slightly aggressive player gets a slight reaction (%d%%)" % roundi(slight.intensity * 100.0))
	var faint := DirectorLogic.plan_for(0.56, 0.44, &"aggressive", _config)
	_check(faint.intensity < 0.25 and faint.island_line == "" and faint.hints.is_empty() and faint.health_multiplier > 1.0,
			"a very faint style still nudges the numbers but the island stays silent")


func _test_plan_helpers() -> void:
	var plan := DirectorPlan.new()
	plan.count_multiplier = 1.3
	_check(plan.adjust_count(0) == 0, "a room with no enemies stays empty")
	_check(plan.adjust_count(3) == 4, "enemy counts scale and round (3 x 1.3 = %d)" % plan.adjust_count(3))
	plan.count_multiplier = 0.4
	_check(plan.adjust_count(1) == 1 and plan.adjust_count(5) == 2, "a room never loses its last enemy")
	plan.enemy_weights = {&"bat": 3.0}
	_check(plan.enemy_weight(&"bat") == 3.0 and plan.enemy_weight(&"grunt") == 1.0, "enemy weights default to 1")
	_check(DirectorPlan.neutral().adjust_count(4) == 4 and DirectorPlan.neutral().health_multiplier == 1.0,
			"the neutral plan changes nothing")


# --- Enemies -------------------------------------------------------------------------------------------

func _test_enemy_effects() -> void:
	var plan := DirectorLogic.plan_for(0.95, 0.05, &"aggressive", _config)
	var grunt: PackedScene = load("res://scenes/enemies/grunt.tscn")
	var enemy = grunt.instantiate()
	plan.apply_to_enemy(enemy)
	_check(is_equal_approx(enemy.health_multiplier, plan.health_multiplier)
			and is_equal_approx(enemy.speed_multiplier, plan.speed_multiplier)
			and is_equal_approx(enemy.vision_multiplier, plan.vision_multiplier), "the plan sets the enemy's modifiers")
	var room: Node = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(room)
	room.add_child(enemy)
	await _frames(3)
	_check(enemy.health.max_health == ceili(enemy.data.max_health * plan.health_multiplier),
			"the health modifier reaches the enemy's health (%d)" % enemy.health.max_health)
	enemy.queue_free()

	# Patrol multiplier: 0 keeps an idle enemy home, 2 sends it wandering.
	var still = _spawn_grunt(room, ARENA, 0.0)
	var wanderer = _spawn_grunt(room, ARENA + Vector2(0, -80), 2.0)
	await _frames(150)
	_check(still.global_position.distance_to(ARENA) < 0.5, "patrol multiplier 0 keeps the enemy where it stands")
	_check(wanderer.global_position.distance_to(ARENA + Vector2(0, -80)) > 5.0, "patrol multiplier 2 makes the enemy wander")
	room.free()


func _spawn_grunt(room: Node, at: Vector2, patrol: float) -> Node2D:
	var enemy = load("res://scenes/enemies/grunt.tscn").instantiate()
	enemy.data = enemy.data.duplicate()
	enemy.patrol_multiplier = patrol
	enemy.position = at
	room.add_child(enemy)
	return enemy


# --- Maps ---------------------------------------------------------------------------------------------

func _test_map_generation() -> void:
	var scenario: ScenarioData = load("res://data/scenarios/test.tres")
	var aggressive := DirectorLogic.plan_for(0.95, 0.05, &"aggressive", _config)
	var stealthy := DirectorLogic.plan_for(0.05, 0.95, &"stealth", _config)
	var ambush_when_aggressive := _share(scenario, &"test_combat_c", aggressive.room_weights)
	var ambush_when_stealthy := _share(scenario, &"test_combat_c", stealthy.room_weights)
	var watch_when_aggressive := _share(scenario, &"test_combat_d", aggressive.room_weights)
	var watch_when_stealthy := _share(scenario, &"test_combat_d", stealthy.room_weights)
	print("ambush rooms: %.0f%% aggressive / %.0f%% stealthy | watch rooms: %.0f%% aggressive / %.0f%% stealthy" % [
			ambush_when_aggressive * 100, ambush_when_stealthy * 100, watch_when_aggressive * 100, watch_when_stealthy * 100])
	_check(ambush_when_aggressive > ambush_when_stealthy * 2.0, "aggressive players meet far more ambush rooms")
	_check(watch_when_stealthy > watch_when_aggressive * 2.0, "stealthy players meet far more guarded rooms")
	var all_valid := true
	for map_seed in range(1, 51):
		if not MapGenerator.generate(scenario, map_seed, aggressive.room_weights).validate().is_empty():
			all_valid = false
	_check(all_valid, "maps shaped by the director are still valid and fully reachable")


func _share(scenario: ScenarioData, room_id: StringName, weights: Dictionary) -> float:
	var combat := 0
	var matching := 0
	for map_seed in range(1, 101):
		for cell: MapLayout.Cell in MapGenerator.generate(scenario, map_seed, weights).cells.values():
			if cell.type == RoomData.RoomType.COMBAT:
				combat += 1
				if cell.room_data.id == room_id:
					matching += 1
	return float(matching) / maxf(combat, 1)


# --- The level asks the director ----------------------------------------------------------------

func _test_level_integration() -> void:
	# Aggressive profile
	_set_profile(0.95, 0.05)
	var announced_before := _plans_announced
	var level = await _build_level(11)
	_check(_plans_announced == announced_before + 1, "building a map asks the director exactly once")
	_check(level.plan == _director.last_plan and level.plan.style == &"aggressive", "the level uses the director's plan (%s)" % level.plan.style)
	var aggressive_stats := _enemy_stats(level)
	_check(aggressive_stats.count > 0 and aggressive_stats.all_health_tuned, "every enemy of an aggressive profile has the health modifier")
	level.free()

	# Stealthy profile, same seed
	_set_profile(0.05, 0.95)
	level = await _build_level(11)
	var stealthy_stats := _enemy_stats(level)
	_check(stealthy_stats.all_vision_tuned and stealthy_stats.all_patrol_tuned, "every enemy of a stealthy profile has sharper senses")
	level.free()

	var aggressive_total := 0.0
	var stealthy_total := 0.0
	for map_seed in range(20, 24):
		_set_profile(0.95, 0.05)
		level = await _build_level(map_seed)
		aggressive_total += _enemy_stats(level).per_combat_room
		level.free()
		_set_profile(0.05, 0.95)
		level = await _build_level(map_seed)
		stealthy_total += _enemy_stats(level).per_combat_room
		level.free()
	_check(aggressive_total > stealthy_total * 1.2,
			"aggressive profiles face more enemies per room (%.1f vs %.1f)" % [aggressive_total / 4.0, stealthy_total / 4.0])

	# Director off: nothing is modified
	_director.enabled = false
	level = await _build_level(11)
	var untouched := _enemy_stats(level)
	_check(untouched.count > 0 and untouched.all_neutral and level.plan.health_multiplier == 1.0, "with the director disabled enemies are not modified")
	level.free()
	_director.enabled = true
	level = await _build_level(11, false)
	_check(_enemy_stats(level).all_neutral, "a level with use_director = false is not modified")
	level.free()

	# A previewed plan neither announces nor changes last_plan
	var announced := _plans_announced
	var last: DirectorPlan = _director.last_plan
	_director.make_plan(false)
	_check(_plans_announced == announced and _director.last_plan == last, "previewing a plan does not announce it")

	# Order: the run that was just played is learned BEFORE the new map is planned
	_profile.model.reset()
	_profile.begin_run()
	for room_number in 4:
		_profile.stats.on_room_entered(3)
		for i in 15:
			_profile.stats.on_attack()
		_profile.stats.on_kill()
		_profile.stats.on_room_cleared()
		_profile.advance(20.0)
		_profile.stats.on_room_exited()
	_check(_profile.model.runs == 0 and _profile.model.style() == ProfileModel.Style.BALANCED, "before the next map the profile has not learned the run yet")
	level = await _build_level(5)
	_check(_profile.model.runs == 1 and level.plan.style == &"aggressive",
			"the new map is planned with what the previous run taught the island (%s)" % level.plan.style)
	level.free()


func _enemy_stats(level: Node) -> Dictionary:
	var count := 0
	var combat_rooms := 0
	var tuned_health := true
	var tuned_vision := true
	var tuned_patrol := true
	var neutral := true
	for room in level.rooms.values():
		if room.data.type != RoomData.RoomType.COMBAT:
			continue
		combat_rooms += 1
		for child in room.get_children():
			if not child.has_signal("player_detected"):
				continue
			count += 1
			tuned_health = tuned_health and child.health_multiplier > 1.0
			tuned_vision = tuned_vision and child.vision_multiplier > 1.0
			tuned_patrol = tuned_patrol and child.patrol_multiplier > 1.0
			neutral = neutral and child.health_multiplier == 1.0 and child.vision_multiplier == 1.0 \
					and child.speed_multiplier == 1.0 and child.patrol_multiplier == 1.0
	return {
		"count": count,
		"per_combat_room": float(count) / maxf(combat_rooms, 1),
		"all_health_tuned": tuned_health,
		"all_vision_tuned": tuned_vision,
		"all_patrol_tuned": tuned_patrol,
		"all_neutral": neutral,
	}


# --- Visible reactions ---------------------------------------------------------------------------

func _test_visible_reactions() -> void:
	# The island speaks when the map starts
	_set_profile(0.95, 0.05)
	var level = await _build_level(3)
	var toast: Label = level.get_node("Hud/Toast")
	_check(toast.visible and toast.text == _config.rules[&"aggressive"].island_line,
			"an aggressive profile makes the island speak at the start of the map (\"%s\")" % toast.text)
	level.free()
	_set_profile(0.05, 0.95)
	level = await _build_level(3)
	toast = level.get_node("Hud/Toast")
	_check(toast.visible and toast.text == _config.rules[&"stealth"].island_line, "a stealthy profile gets its own line (\"%s\")" % toast.text)
	level.free()
	_profile.model.reset()
	level = await _build_level(3)
	toast = level.get_node("Hud/Toast")
	_check(not toast.visible, "a balanced profile makes the island say nothing")

	# The death screen announces what the island prepares
	_profile.begin_run()
	for room_number in 4:
		_profile.stats.on_room_entered(3)
		for i in 20:
			_profile.stats.on_attack()
		_profile.stats.on_kill()
		_profile.stats.on_room_cleared()
		_profile.advance(40.0)
		_profile.stats.on_room_exited()
	var summary: Dictionary = _profile.finish_run("death")
	await _frames(2)
	var texts := _summary_texts(level)
	var expected_plan: DirectorPlan = _director.make_plan(false)
	_check(summary.reason == "death" and not expected_plan.hints.is_empty(), "the run ended and the director has hints for the updated profile")
	_check(_config.texts.prepare_title in texts, "the death screen shows 'the island prepares' (%s)" % _config.texts.prepare_title)
	var all_hints := true
	for hint in expected_plan.hints:
		all_hints = all_hints and ("- " + hint) in texts
	_check(all_hints, "the death screen lists what will change (%d hints)" % expected_plan.hints.size())
	level.free()


func _summary_texts(level: Node) -> Array[String]:
	var texts: Array[String] = []
	for label in level.get_node("ProfileSummary/Panel/Margin/Content").find_children("*", "Label", true, false):
		if not label.is_queued_for_deletion():
			texts.append(label.text)
	return texts


# --- Helpers -----------------------------------------------------------------------------------------

func _set_profile(aggression: float, stealth: float) -> void:
	_profile.model.reset()
	_profile.model.aggression = aggression
	_profile.model.stealth = stealth
	_profile.begin_run()


func _build_level(map_seed: int, use_director := true) -> Node2D:
	var level: Node2D = load("res://scenes/levels/test_level.tscn").instantiate()
	level.seed_value = map_seed
	level.use_director = use_director
	root.add_child(level)
	await _frames(3)
	return level


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
