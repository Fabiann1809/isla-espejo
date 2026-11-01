extends SceneTree
## Sound (autoload): the bank has every cue the game asks for, events play their cues, enemies far
## away are not heard, and the music follows the run (scenario, boss fight, victory, death).
## Run: godot --headless --path . --script res://tests/test_sound.gd

const NEEDED_CUES := [
	&"shot", &"arrow_hit", &"enemy_hurt", &"enemy_death", &"death_slime", &"death_esqueleto",
	&"death_planta_tiradora", &"death_ente", &"death_brote", &"death_forest_guardian", &"player_hurt",
	&"player_death", &"dash", &"step", &"pickup_heart", &"pickup_gold", &"pickup_arrows", &"chest",
	&"ui_click", &"ui_hover", &"boss_warn", &"boss_slam", &"boss_roots", &"boss_defeated",
	&"skill_roots", &"skill_current", &"skill_shadow", &"fragment", &"portal", &"alert",
	&"attack_shot", &"attack_summon", &"attack_planta_tiradora", &"dialogue",
]

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var sound = root.get_node("Sound")
	var events = root.get_node("Events")
	var bank = sound.bank

	var missing := NEEDED_CUES.filter(func(cue: StringName) -> bool: return not bank.has_cue(cue))
	_check(missing.is_empty(), "the sound bank has every cue the game plays %s" % [missing])
	_check(bank.music.has(&"menu") and bank.music.has(&"forest") and bank.music.has(&"boss"),
			"there is music for the menu, the forest and the boss")
	_check(bank.music[&"forest"].loop and bank.music[&"boss"].loop, "the level and boss music loop")
	_check(AudioServer.get_bus_index(&"Music") > 0 and AudioServer.get_bus_index(&"SFX") > 0,
			"music and effects have their own audio buses")

	# Events -> cues.
	sound.played.clear()
	events.player_shot.emit(Vector2.RIGHT, -1.0)
	events.player_damaged.emit(1, Vector2.ZERO)
	events.resource_collected.emit(&"gold")
	events.skill_used.emit(&"roots", Vector2.RIGHT, 2)
	events.boss_attack_struck.emit(&"forest_guardian", &"slam", Vector2.ZERO)
	_check(sound.played == [&"shot", &"player_hurt", &"pickup_gold", &"skill_roots", &"boss_slam"],
			"each event plays its cue (%s)" % [sound.played])
	sound.played.clear()
	events.enemy_detected_player.emit(null)
	events.enemy_detected_player.emit(null)
	_check(sound.played == [&"alert"], "the same cue is not stacked in the same instant")

	# Enemies: their own death sound, and silence when they are far from Nico.
	var room: Node = load("res://scenes/levels/test_room.tscn").instantiate()
	for name in ["Trap1", "Trap2", "Grunt1", "Grunt2"]:
		room.get_node(name).free()
	root.add_child(room)
	await _frames(3)
	var player: Node2D = room.get_node("Player")
	var slime: Node2D = load("res://scenes/enemies/slime.tscn").instantiate()
	room.add_child(slime)
	slime.global_position = player.global_position + Vector2(40, 0)
	await _frames(2)
	sound.played.clear()
	events.enemy_killed.emit(slime)
	_check(sound.played == [&"death_slime"], "a slime dies with its own sound")
	slime.global_position = player.global_position + Vector2(2000, 0)
	sound.played.clear()
	await create_timer(0.1).timeout
	events.enemy_killed.emit(slime)
	_check(sound.played.is_empty(), "an enemy far away is not heard")

	# Footsteps while Nico walks.
	sound.played.clear()
	Input.action_press("move_right")
	await _frames(40)
	Input.action_release("move_right")
	_check(sound.played.count(&"step") >= 1, "Nico's steps are heard while he walks")

	# Music follows the run.
	events.level_started.emit(&"forest", 1)
	_check(sound.current_music == &"forest", "a forest run plays the forest music")
	events.boss_health_changed.emit(&"forest_guardian", 30, 30, "Guardián")
	_check(sound.current_music == &"boss", "the boss fight switches to the boss theme")
	events.boss_health_changed.emit(&"forest_guardian", 20, 30, "Guardián")
	_check(sound.current_music == &"boss", "hits on the boss keep the boss theme")
	events.boss_defeated.emit(&"forest_guardian")
	_check(sound.current_music == &"forest", "after the boss the forest music comes back")
	events.player_died.emit()
	_check(sound.current_music == StringName(), "dying fades the music out")
	sound.play_music(&"menu")
	_check(sound.current_music == &"menu", "the menu has its own music")

	quit(0 if _ok else 1)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
