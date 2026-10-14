extends Node
## Player profile (AI layer 1), registered as the autoload "PlayerProfile".
## Listens to the Events bus while a run is active, learns from each finished run and keeps the
## result in `user://profile.json`, so the island "remembers" the player between games.
##
## The director (AI layer 2) reads `live_scores()` / `live_style()`; nothing here touches combat code.

signal profile_updated
## Emitted when a run ends. `summary` is described in `_build_summary`.
signal run_finished(summary: Dictionary)

const CONFIG_PATH := "res://data/ai/profile_config.tres"

var config: ProfileConfig
var model: ProfileModel
var stats: RunStats
var save_path := "user://profile.json"
## Saving is off in headless mode (automated tests and CI must not touch the player's profile) and
## when the game is started with the user argument `--no-save` (screenshot or demo scripts):
##   godot --path . -- --no-save
var persistence_enabled := true
## Tests turn this off and call `advance()` themselves.
var auto_tick := true

var _run_active := false


func _ready() -> void:
	config = load(CONFIG_PATH)
	if config == null:
		push_error("Missing %s; using default profile settings." % CONFIG_PATH)
		config = ProfileConfig.new()
	model = ProfileModel.new(config)
	persistence_enabled = not OS.get_cmdline_user_args().has("--no-save") and DisplayServer.get_name() != "headless"
	if persistence_enabled:
		load_profile()
	_connect_events()
	begin_run()


func _process(delta: float) -> void:
	if auto_tick:
		advance(delta)


## Moves the clock of the current run forward.
func advance(delta: float) -> void:
	if _run_active:
		stats.advance(delta)


func begin_run() -> void:
	stats = RunStats.new(config)
	_run_active = true


## Ends the current run, learns from it and saves. `reason`: "death", "victory" or "abandoned".
func finish_run(reason: String) -> Dictionary:
	if not _run_active:
		return {}
	_run_active = false
	stats.finalize()
	var run_score := model.score_run(stats)
	var merged := model.merge_run(stats)
	if merged and persistence_enabled:
		save_profile()
	var summary := _build_summary(reason, merged, run_score)
	profile_updated.emit()
	run_finished.emit(summary)
	return summary


## Profile as the director should read it mid-run: {"aggression": 0..1, "stealth": 0..1}.
func live_scores() -> Dictionary:
	if not _run_active:
		return {"aggression": model.aggression, "stealth": model.stealth}
	return model.live_scores(stats)


func live_style() -> ProfileModel.Style:
	var scores := live_scores()
	return model.style_of(scores.aggression, scores.stealth)


func reset_profile() -> void:
	model.reset()
	if persistence_enabled:
		save_profile()
	profile_updated.emit()


func save_profile() -> bool:
	var temp_path := save_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save the profile: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(model.to_dict(), "\t"))
	file.close()
	var error := DirAccess.rename_absolute(
			ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(save_path))
	if error != OK:
		push_warning("Could not replace the profile file: %s" % error_string(error))
		return false
	return true


## Loads the saved profile. A missing, corrupt or incompatible file leaves a fresh profile.
func load_profile() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var json := JSON.new()
	var parsed = json.data if json.parse(FileAccess.get_file_as_string(save_path)) == OK else null
	if not (parsed is Dictionary) or not model.load_dict(parsed):
		push_warning("Ignoring an unreadable profile file (%s)." % save_path)
		return false
	return true


func _connect_events() -> void:
	Events.player_attacked.connect(func(_direction: Vector2) -> void: _record(stats.on_attack))
	Events.player_dashed.connect(func(_direction: Vector2) -> void: _record(stats.on_dash))
	Events.player_hit_enemy.connect(func(_enemy: Node, _damage: int) -> void: _record(stats.on_hit))
	Events.player_damaged.connect(func(amount: int, _from: Vector2) -> void:
		if _run_active:
			stats.on_damage(amount))
	Events.skill_used.connect(func(id: StringName, _direction: Vector2, _affected: int) -> void:
		if _run_active:
			stats.on_skill(id))
	Events.enemy_killed.connect(func(_enemy: Node) -> void: _record(stats.on_kill))
	Events.enemy_detected_player.connect(func(_enemy: Node) -> void: _record(stats.on_detected))
	Events.player_stealth_changed.connect(func(active: bool) -> void:
		if _run_active:
			stats.on_stealth(active))
	Events.room_entered.connect(func(room: Node) -> void:
		if _run_active:
			stats.on_room_entered(int(room.get("enemies_alive"))))
	Events.room_exited.connect(func(_room: Node) -> void: _record(stats.on_room_exited))
	Events.room_cleared.connect(func(_room: Node) -> void: _record(stats.on_room_cleared))
	Events.player_died.connect(func() -> void: finish_run("death"))
	Events.scenario_completed.connect(func(_scenario_id: StringName) -> void: finish_run("victory"))
	Events.level_started.connect(_on_level_started)


func _record(action: Callable) -> void:
	if _run_active:
		action.call()


## A new map starts a new run. A run in progress that was really played counts as abandoned;
## one with no activity is simply discarded.
func _on_level_started(_scenario_id: StringName, _map_seed: int) -> void:
	if _run_active and stats.play_time >= config.min_run_seconds:
		finish_run("abandoned")
	begin_run()


## Everything the summary screen (and tests) need:
## reason, merged, style, style_name, message, aggression/stealth (saved profile after learning),
## run_aggression/run_stealth (this run alone), runs, stats (RunStats.to_dict()).
func _build_summary(reason: String, merged: bool, run_score: Dictionary) -> Dictionary:
	var style_key := ProfileModel.style_key(model.style())
	return {
		"reason": reason,
		"merged": merged,
		"style": style_key,
		"style_name": config.texts.get("style_" + style_key, ""),
		"message": config.texts.get("message_" + style_key, ""),
		"aggression": model.aggression,
		"stealth": model.stealth,
		"run_aggression": run_score.aggression,
		"run_stealth": run_score.stealth,
		"runs": model.runs,
		"stats": stats.to_dict(),
	}
