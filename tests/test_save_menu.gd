extends SceneTree
## Menus, save and options test: SaveGame round trip, Settings, texts, credits, main menu, pause
## menu and the HUD's fragments and objective.
## Run: godot --headless --path . --script res://tests/test_save_menu.gd

const TEST_SAVE := "user://test_save.json"

var _ok := true
var _save: Node
var _state: Node
var _settings: Node
var _events: Node


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_save = root.get_node("SaveGame")
	_state = root.get_node("GameState")
	_settings = root.get_node("Settings")
	_events = root.get_node("Events")
	# Never touch the real save: use a test file and turn persistence on only for this test.
	_save.save_path = TEST_SAVE
	_save.persistence_enabled = true
	_save.delete_save()
	_state.reset()

	_test_save_round_trip()
	_test_settings()
	_test_texts_and_credits()
	await _test_main_menu()
	await _test_pause_menu()
	await _test_hud_and_objective()

	_save.delete_save()
	_save.persistence_enabled = false
	_state.reset()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		print("FAIL: ", label)
		_ok = false


func _test_save_round_trip() -> void:
	_check(not _save.has_save(), "no save at first")
	_state.collect_fragment(&"green")
	_state.learn_skill(&"roots")
	_state.set_flag(&"forest_boss_defeated")
	_save.scenario_id = &"forest"
	_save.save()
	_check(_save.has_save(), "saving writes the file")

	_state.reset()
	_save.scenario_id = &""
	_check(_save.load_save(), "the save loads")
	_check(_state.has_fragment(&"green") and _state.skills.has(&"roots") and _state.has_flag(&"forest_boss_defeated"),
			"fragments, skills and flags come back")
	_check(_save.scenario_id == &"forest" and _save.pending_scenario_id == &"forest", "the chapter is remembered")
	var scenario: ScenarioData = _save.take_pending_scenario()
	_check(scenario != null and scenario.id == &"forest", "continue resolves the saved chapter")
	_check(_save.take_pending_scenario() == null, "the pending chapter is taken only once")

	_check(not _save.from_dict({"version": 99, "game": {}}), "a save of another version is rejected")
	_check(not _save.from_dict({"version": 1}), "a save without game data is rejected")

	# Earning something saves by itself.
	_save.delete_save()
	_state.collect_fragment(&"blue")
	_check(_save.has_save(), "collecting a fragment saves")

	_save.new_game()
	_check(not _save.has_save() and _state.fragments.is_empty(), "a new journey erases the save and the progress")


func _test_settings() -> void:
	_settings.persistence_enabled = false
	_settings.set_volume(2.0)
	_check(is_equal_approx(_settings.volume, 1.0), "volume is clamped to 1")
	_settings.set_volume(-1.0)
	_check(_settings.volume == 0.0 and AudioServer.is_bus_mute(0), "volume 0 mutes the master bus")
	_settings.set_volume(0.5)
	_check(not AudioServer.is_bus_mute(0), "volume above 0 unmutes")
	var data: Dictionary = _settings.to_dict()
	_settings.set_volume(0.1)
	_check(_settings.from_dict(data) and is_equal_approx(_settings.volume, 0.5), "settings round trip")
	_check(not _settings.from_dict({"version": 99}), "settings of another version are rejected")
	_settings.set_volume(0.8)


func _test_texts_and_credits() -> void:
	var ui_text: GDScript = load("res://scripts/core/ui_text.gd")
	for key in ["menu_start", "menu_continue", "menu_options", "menu_credits", "menu_quit",
			"pause_resume", "pause_menu", "options_volume", "options_fullscreen", "credits_title"]:
		_check(ui_text.t(key) != key, "text exists: " + key)
	_check(ui_text.t("menu_start") == "Comenzar viaje", "the main menu keeps the names from the design")

	var credits: GDScript = load("res://scripts/ui/credits_screen.gd")
	var text: String = credits.format("# Créditos\n\nIntro **fuerte**\n\n| Recurso | Autor | Licencia |\n|---|---|---|\n| Pack | Kenney | CC0 |\n")
	_check(text.contains("- Pack (Kenney, CC0)") and not text.contains("**") and not text.contains("Créditos"),
			"markdown becomes plain credits")
	var real: String = credits.read_credits()
	_check(real.contains("Kenney"), "the real CREDITS.md is shown")


func _test_main_menu() -> void:
	var scene: PackedScene = load("res://scenes/ui/main_menu.tscn")
	var menu: Control = scene.instantiate()
	root.add_child(menu)
	await process_frame
	_check(menu.start_button.text == "Comenzar viaje" and menu.quit_button.text == "Abandonar la isla", "menu buttons are labeled")
	_check(menu.continue_button.disabled, "continue is disabled without a save")
	menu.queue_free()
	await process_frame

	_state.collect_fragment(&"green")
	_save.save()
	menu = scene.instantiate()
	root.add_child(menu)
	await process_frame
	_check(not menu.continue_button.disabled, "continue is enabled with a save")
	menu.start_button.pressed.emit()
	_check(menu.start_button.text == "¿Borrar el progreso? Pulsa de nuevo" and _save.has_save() and _state.has_fragment(&"green"),
			"starting over asks first and erases nothing yet")
	menu.options_button.pressed.emit()
	_check(menu.options.visible and not menu.continue_button.is_visible_in_tree(), "options open over the menu")
	menu.options.close()
	_check(menu.continue_button.is_visible_in_tree(), "closing options shows the menu again")
	menu.queue_free()
	await process_frame
	_save.new_game()


func _test_pause_menu() -> void:
	var pause: CanvasLayer = (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate()
	root.add_child(pause)
	await process_frame
	_check(not pause.is_open() and not paused, "the pause menu starts closed")
	pause.pause()
	_check(pause.is_open() and paused, "pausing opens the menu and stops the game")
	pause.options_button.pressed.emit()
	_settings.set_volume(0.3)
	pause.options.refresh()
	_check(is_equal_approx(pause.options.volume_slider.value, 0.3), "the options slider shows the volume")
	pause.options.close()
	pause.resume()
	_check(not pause.is_open() and not paused, "resuming closes the menu and continues")
	_settings.set_volume(0.8)
	pause.queue_free()
	await process_frame


func _test_hud_and_objective() -> void:
	_state.reset()
	var objectives: Array[String] = []
	_events.objective_changed.connect(func(text: String) -> void: objectives.append(text))
	var level: Node = (load("res://scenes/levels/forest_level.tscn") as PackedScene).instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	_check(objectives.size() > 0 and objectives[0] == "Encuentra al Guardián del bosque", "the HUD is told the objective")
	var hud: CanvasLayer = level.get_node("Hud")
	_check(hud._fragment_icons[&"green"].color == hud.FRAGMENT_MISSING, "fragment icons start dim")

	_state.set_flag(&"forest_boss_defeated")
	_events.boss_defeated.emit(&"forest_guardian")
	_state.collect_fragment(&"green")
	_check(objectives.back() == "Cruza el portal", "the objective changes when the boss falls")
	_check(hud._fragment_icons[&"green"].color == hud.FRAGMENT_COLORS[&"green"], "a collected fragment lights its icon")
	_check(level.get_node("PauseMenu") != null, "the level has a pause menu")
	level.queue_free()
	await process_frame
