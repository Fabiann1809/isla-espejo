extends SceneTree
## Sound (autoload): the bank has every cue the game asks for, events play their cues, enemies far
## away are not heard, and the music follows the run (scenario, boss fight, victory, death).
## Run: godot --headless --path . --script res://tests/test_sound.gd

const NEEDED_CUES := [
	&"shot", &"arrow_hit", &"arrow_wall", &"enemy_hurt", &"enemy_death", &"death_slime", &"death_esqueleto",
	&"death_planta_tiradora", &"death_ente", &"death_brote", &"death_forest_guardian", &"player_hurt",
	&"player_death", &"dash", &"step", &"pickup_heart", &"pickup_gold", &"pickup_arrows", &"chest",
	&"ui_click", &"ui_hover", &"boss_warn", &"boss_slam", &"boss_roots", &"boss_defeated",
	&"skill_roots", &"skill_current", &"skill_shadow", &"fragment", &"portal", &"alert",
	&"attack_shot", &"attack_summon", &"attack_planta_tiradora", &"dialogue",
	&"attack_melee", &"attack_trap", &"attack_charge", &"attack_dive", &"death_centinela_obsidiana",
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

	# The test room reloads the scene when Nico dies: remove it before the death below.
	room.queue_free()
	await process_frame

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
	# The temple: its own track, an urgent one while a lava surge is up, and back after it.
	events.level_started.emit(&"temple", 1)
	_check(sound.current_music == &"temple", "the temple plays its own music")
	events.lava_surge_started.emit(null, 1)
	_check(sound.current_music == &"temple_surge", "a lava surge switches to the surge track")
	events.lava_surge_receded.emit(null)
	_check(sound.current_music == &"temple", "when the lava recedes the temple music comes back")

	# Cross-fade: the new track starts rising at once, and a change in the middle of a fade keeps
	# the audible track instead of cutting it.
	sound.play_music(&"forest")
	await create_timer(0.3).timeout
	var players: Array = sound.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer and n.bus == &"Music")
	var forest_player = players.filter(func(p) -> bool: return p.playing and p.stream == bank.music[&"forest"])
	_check(forest_player.size() == 1 and forest_player[0].volume_db > -40.0, "the new track fades in while the old one fades out")
	sound.play_music(&"boss")
	await create_timer(0.2).timeout
	sound.play_music(&"forest")
	await create_timer(2.0).timeout
	var heard: Array = players.filter(func(p) -> bool: return p.playing)
	_check(heard.size() == 1 and heard[0].stream == bank.music[&"forest"], "changing track mid-fade ends with only the new track playing")
	_check(bank.volume_of(&"attack_shot") == bank.volumes_db[&"attack_shot"], "a cue keeps its own volume even when it borrows another cue's sound")

	quit(0 if _ok else 1)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
