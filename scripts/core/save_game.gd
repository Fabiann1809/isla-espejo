extends Node
## Saves and loads the player's progress (autoload "SaveGame"): what GameState keeps (fragments,
## learned skills, story flags) plus the chapter being played, in `user://save.json` ("version": 1).
## The adaptive profile has its own file (`user://profile.json`, see PlayerProfile).
## It saves by itself when a map starts or when a fragment, skill or boss is earned.
## Disabled in headless mode and with `--no-save`, like the profile.

const VERSION := 1
const SCENARIO_PATH := "res://data/scenarios/%s.tres"

var save_path := "user://save.json"
var persistence_enabled := true
## The chapter being played (its ScenarioData id), empty before the first map.
var scenario_id: StringName = &""
## Chapter to start when the next Level opens (set by `load_save`, consumed by the Level).
var pending_scenario_id: StringName = &""


func _ready() -> void:
	persistence_enabled = not OS.get_cmdline_user_args().has("--no-save") and DisplayServer.get_name() != "headless"
	Events.level_started.connect(_on_level_started)
	Events.fragment_collected.connect(func(_id: StringName) -> void: save())
	Events.boss_defeated.connect(func(_id: StringName) -> void: save())
	GameState.skill_learned.connect(func(_id: StringName) -> void: save())


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save() -> void:
	if not persistence_enabled:
		return
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(to_dict(), "\t"))


func to_dict() -> Dictionary:
	return {"version": VERSION, "scenario": scenario_id, "game": GameState.to_dict()}


## Restores GameState and remembers the chapter to continue. False if there is nothing valid to load.
func load_save() -> bool:
	if not has_save():
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	return parsed is Dictionary and from_dict(parsed)


func from_dict(data: Dictionary) -> bool:
	if int(data.get("version", 0)) != VERSION or not data.get("game") is Dictionary:
		return false
	if not GameState.from_dict(data["game"]):
		return false
	scenario_id = StringName(str(data.get("scenario", "")))
	pending_scenario_id = scenario_id
	return true


## A fresh journey: forgets the story progress and the save.
func new_game() -> void:
	GameState.reset()
	scenario_id = &""
	pending_scenario_id = &""
	delete_save()


func delete_save() -> void:
	if persistence_enabled and has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


## The chapter chosen by "continue", or null if there is none (the Level keeps its own).
func take_pending_scenario() -> ScenarioData:
	var id := pending_scenario_id
	pending_scenario_id = &""
	if id == &"":
		return null
	var path := SCENARIO_PATH % id
	return load(path) if ResourceLoader.exists(path) else null


func _on_level_started(new_scenario_id: StringName, _map_seed: int) -> void:
	scenario_id = new_scenario_id
	save()
