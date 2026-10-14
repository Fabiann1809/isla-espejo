extends SceneTree
## Player profile test: simulated players (aggressive, stealthy, balanced), learning across runs,
## persistence (including corrupt files), and the autoload wired to the Events bus.
## Run: godot --headless --path . --script res://tests/test_profile.gd

const TEST_SAVE := "user://test_profile.json"

## A runtime error inside a check helper does not stop GDScript, so a test that silently skipped
## checks must still fail: the number of executed checks has to match.
const EXPECTED_CHECKS := 47

var _ok := true
var _checks := 0
var _fake_rooms: Array[Node] = []
var _config: ProfileConfig


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	# Autoloads only run their _ready() once the tree has started.
	await process_frame
	_config = load("res://data/ai/profile_config.tres")
	_check(_config != null and _config.texts.has("title"), "the profile config loads with its Spanish texts")

	_test_simulated_players()
	_test_learning_across_runs()
	_test_run_filtering()
	_test_live_scores()
	_test_persistence()
	await _test_autoload_wiring()

	for room in _fake_rooms:
		room.free()
	if _checks != EXPECTED_CHECKS:
		printerr("Executed %d checks, expected %d (a check was skipped by an error)" % [_checks, EXPECTED_CHECKS])
		_ok = false
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


# --- Simulated players ----------------------------------------------------------------

func _test_simulated_players() -> void:
	var aggressive := ProfileModel.new(_config)
	var stealthy := ProfileModel.new(_config)
	var balanced := ProfileModel.new(_config)
	var a := aggressive.score_run(_aggressive_run())
	var s := stealthy.score_run(_stealth_run())
	var b := balanced.score_run(_balanced_run())
	print("aggressive run: agg %.2f stealth %.2f | stealth run: agg %.2f stealth %.2f | balanced run: agg %.2f stealth %.2f"
			% [a.aggression, a.stealth, s.aggression, s.stealth, b.aggression, b.stealth])

	_check(a.aggression > 0.85 and a.stealth < 0.2, "an aggressive run scores high aggression, low stealth")
	_check(s.stealth > 0.85 and s.aggression < 0.2, "a stealthy run scores high stealth, low aggression")
	_check(absf(b.aggression - 0.5) < 0.15 and absf(b.stealth - 0.5) < 0.15, "a mixed run scores in the middle")

	aggressive.merge_run(_aggressive_run())
	stealthy.merge_run(_stealth_run())
	balanced.merge_run(_balanced_run())
	_check(aggressive.style() == ProfileModel.Style.AGGRESSIVE, "one aggressive run classifies the player as aggressive")
	_check(stealthy.style() == ProfileModel.Style.STEALTH, "one stealthy run classifies the player as stealthy")
	_check(balanced.style() == ProfileModel.Style.BALANCED, "a mixed run classifies the player as balanced")
	_check(ProfileModel.style_key(aggressive.style()) == &"aggressive", "style keys match the config texts")

	var idle := RunStats.new(_config)
	idle.advance(100.0)
	var idle_score := ProfileModel.new(_config).score_run(idle)
	_check(idle_score.aggression == 0.0 and idle_score.stealth == 0.0, "a player who does nothing scores zero on both")
	var nothing := ProfileModel.new(_config)
	_check(nothing.score_run(RunStats.new(_config)).confidence == 0.0, "an empty run has no confidence")


# --- Learning ----------------------------------------------------------------------------

func _test_learning_across_runs() -> void:
	var learned := ProfileModel.new(_config)
	for i in 3:
		learned.merge_run(_aggressive_run())
	var after_aggressive := learned.aggression
	_check(learned.runs == 3 and after_aggressive > 0.85, "three aggressive runs strengthen the profile (%.2f)" % after_aggressive)

	learned.merge_run(_stealth_run())
	var fresh := ProfileModel.new(_config)
	fresh.merge_run(_stealth_run())
	_check(learned.aggression < after_aggressive, "a stealthy run moves the profile away from aggression")
	_check(learned.aggression > fresh.aggression + 0.1,
			"the island remembers: past runs still weigh (%.2f vs %.2f for a fresh profile)" % [learned.aggression, fresh.aggression])
	_check(learned.style() != ProfileModel.Style.AGGRESSIVE, "one stealthy run is enough to leave 'aggressive'")
	learned.merge_run(_stealth_run())
	learned.merge_run(_stealth_run())
	_check(learned.style() == ProfileModel.Style.STEALTH, "sustained stealthy play ends up classified as stealthy")
	_check(learned.totals.melee_attacks > 0 and learned.last_run.has("rooms_evaded"), "totals and the last run are kept")


func _test_run_filtering() -> void:
	var model := ProfileModel.new(_config)
	var short := RunStats.new(_config)
	short.advance(5.0)
	short.on_attack()
	_check(not model.merge_run(short) and model.runs == 0 and model.aggression == 0.5, "a run shorter than the minimum is ignored")

	var brief := ProfileModel.new(_config)
	var brief_run := _aggressive_run(30.0)
	brief.merge_run(brief_run)
	var full := ProfileModel.new(_config)
	full.merge_run(_aggressive_run())
	_check(brief.aggression < full.aggression, "a short run moves the profile less than a long one (%.2f < %.2f)" % [brief.aggression, full.aggression])


func _test_live_scores() -> void:
	var model := ProfileModel.new(_config)
	var stats := RunStats.new(_config)
	var at_start := model.live_scores(stats)
	_check(at_start.aggression == 0.5 and at_start.stealth == 0.5, "at the start of a run the live estimate is the saved profile")
	var run := _aggressive_run()
	var live := model.live_scores(run)
	_check(live.aggression > 0.7 and live.stealth < 0.3, "mid-run, what the player does now moves the live estimate (%.2f / %.2f)" % [live.aggression, live.stealth])
	_check(model.style_of(live.aggression, live.stealth) == ProfileModel.Style.AGGRESSIVE, "the live estimate can already be classified")
	_check(model.aggression == 0.5, "the saved profile is not changed by the live estimate")


# --- Persistence -------------------------------------------------------------------------

func _test_persistence() -> void:
	var profile: Node = root.get_node("PlayerProfile")
	var saved_path: String = profile.save_path
	var saved_flag: bool = profile.persistence_enabled
	profile.save_path = TEST_SAVE
	profile.persistence_enabled = true
	_remove(TEST_SAVE)

	_check(not profile.load_profile(), "a missing profile file is not an error")

	profile.model.reset()
	profile.model.merge_run(_aggressive_run())
	profile.model.merge_run(_stealth_run())
	var expected_aggression: float = profile.model.aggression
	var expected_stealth: float = profile.model.stealth
	var expected_runs: int = profile.model.runs
	_check(profile.save_profile() and FileAccess.file_exists(TEST_SAVE), "the profile is saved to disk")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE))
	_check(parsed is Dictionary and parsed.version == 1, "the file is valid JSON with version 1")
	_check(not FileAccess.file_exists(TEST_SAVE + ".tmp"), "no temporary file is left behind")

	profile.model.reset()
	_check(profile.load_profile(), "the saved profile loads")
	_check(absf(profile.model.aggression - expected_aggression) < 0.001
			and absf(profile.model.stealth - expected_stealth) < 0.001 and profile.model.runs == expected_runs,
			"loading restores exactly what was saved")

	for case in [
		["corrupt JSON", "{this is not json"],
		["not an object", "[1, 2, 3]"],
		["an unknown version", '{"version": 99, "aggression": 0.9, "stealth": 0.1}'],
		["non-numeric scores", '{"version": 1, "aggression": "high", "stealth": null}'],
		["empty file", ""],
	]:
		_write(TEST_SAVE, case[1])
		profile.model.reset()
		var loaded: bool = profile.load_profile()
		_check(not loaded and profile.model.aggression == 0.5 and profile.model.stealth == 0.5,
				"%s is ignored and the profile stays neutral" % case[0])

	_write(TEST_SAVE, '{"version": 1, "aggression": 7.5, "stealth": -2}')
	profile.model.reset()
	_check(profile.load_profile() and profile.model.aggression == 1.0 and profile.model.stealth == 0.0,
			"out-of-range scores are clamped to 0..1")
	_write(TEST_SAVE, '{"version": 1, "aggression": 0.3, "stealth": 0.6}')
	profile.model.reset()
	_check(profile.load_profile() and profile.model.runs == 0 and profile.model.totals.is_empty(),
			"optional fields may be missing")

	_remove(TEST_SAVE)
	_remove(TEST_SAVE + ".tmp")
	profile.save_path = saved_path
	profile.persistence_enabled = saved_flag
	profile.model.reset()


# --- Autoload wired to the bus --------------------------------------------------------

func _test_autoload_wiring() -> void:
	var profile: Node = root.get_node("PlayerProfile")
	var events: Node = root.get_node("Events")
	profile.persistence_enabled = false
	profile.auto_tick = false
	profile.model.reset()
	profile.begin_run()

	var finished: Array = []
	profile.run_finished.connect(func(summary: Dictionary) -> void: finished.append(summary))

	# A stealthy player, told only through Events.
	var room := _fake_room(3)
	events.player_stealth_changed.emit(true)
	for i in 4:
		events.room_entered.emit(room)
		if i == 0:
			events.enemy_detected_player.emit(null)
		events.skill_used.emit(&"shadow", Vector2.RIGHT, 2)
		profile.advance(30.0)
		events.room_exited.emit(room)
	events.player_dashed.emit(Vector2.RIGHT)
	events.player_attacked.emit(Vector2.RIGHT)
	events.player_damaged.emit(1, Vector2.ZERO)

	var stats: RunStats = profile.stats
	_check(stats.rooms_visited == 4 and stats.rooms_evaded == 4 and stats.rooms_fought == 0,
			"room events become visited/evaded counts (%d/%d)" % [stats.rooms_visited, stats.rooms_evaded])
	_check(stats.stealth_skill_uses == 4 and stats.detections == 1 and stats.dashes == 1
			and stats.melee_attacks == 1 and stats.damage_taken == 1, "skill, detection, dash, attack and damage events are counted")
	_check(absf(stats.stealth_time - 120.0) < 0.01 and absf(stats.room_time_total - 120.0) < 0.01,
			"stealth time and time per room accumulate (%.0f s / %.0f s)" % [stats.stealth_time, stats.room_time_total])
	_check(profile.live_style() == ProfileModel.Style.STEALTH, "the live style already reads as stealthy mid-run")

	events.player_died.emit()
	_check(finished.size() == 1 and finished[0].reason == "death", "player_died ends the run and emits run_finished")
	var summary: Dictionary = finished[0]
	_check(summary.merged and summary.style == &"stealth" and summary.style_name == "Sigiloso",
			"the summary names the learned style in Spanish (%s)" % summary.style_name)
	_check(summary.message != "" and summary.stats.rooms_evaded == 4 and summary.runs == 1 and summary.stealth > summary.aggression,
			"the summary carries the message, stats and scores")
	_check(profile.model.runs == 1 and profile.model.stealth > 0.5, "the finished run was learned")

	events.player_attacked.emit(Vector2.RIGHT)
	_check(profile.stats.melee_attacks == 1, "events outside a run are not counted twice")

	# A fighter in a fresh run: kills inside a room count as fought, clears are tracked.
	profile.begin_run()
	var arena := _fake_room(2)
	events.room_entered.emit(arena)
	events.enemy_killed.emit(null)
	events.room_cleared.emit(arena)
	events.room_exited.emit(arena)
	var empty := _fake_room(0)
	events.room_entered.emit(empty)
	events.room_exited.emit(empty)
	_check(profile.stats.rooms_fought == 1 and profile.stats.rooms_cleared == 1 and profile.stats.rooms_with_enemies == 1
			and profile.stats.rooms_visited == 2, "a fought room counts as fought; an empty room is not an enemy room")

	# Level started: a run that was really played is closed as abandoned; an idle one is dropped.
	finished.clear()
	profile.advance(40.0)
	events.level_started.emit(&"test", 1)
	_check(finished.size() == 1 and finished[0].reason == "abandoned", "a new level closes a played run as abandoned")
	events.level_started.emit(&"test", 2)
	_check(finished.size() == 1 and profile.stats.play_time == 0.0, "a new level does not report an idle run")

	profile.model.reset()
	profile.auto_tick = true
	await physics_frame


# --- Helpers -------------------------------------------------------------------------

## 4 enemy rooms, all fought: lots of attacks, aggressive skills, no stealth, always detected.
func _aggressive_run(total_seconds := 120.0) -> RunStats:
	var stats := RunStats.new(_config)
	var per_room := total_seconds / 4.0
	for room in 4:
		stats.on_room_entered(3)
		for i in 20:
			stats.on_attack()
			stats.on_hit()
		stats.on_kill()
		stats.on_kill()
		stats.on_room_cleared()
		stats.on_skill(&"roots" if room % 2 == 0 else &"current")
		stats.on_detected()
		stats.on_detected()
		stats.advance(per_room)
		stats.on_room_exited()
	return stats


## 4 enemy rooms, all evaded while hidden: shadow skill, almost never detected, no fighting.
func _stealth_run(total_seconds := 120.0) -> RunStats:
	var stats := RunStats.new(_config)
	stats.on_stealth(true)
	var per_room := total_seconds / 4.0
	for room in 4:
		stats.on_room_entered(3)
		stats.on_skill(&"shadow")
		if room == 0:
			stats.on_detected()
		stats.advance(per_room)
		stats.on_room_exited()
	stats.on_attack()
	return stats


## 4 enemy rooms: half fought, half evaded; mixed skills; some stealth; moderate detections.
func _balanced_run() -> RunStats:
	var stats := RunStats.new(_config)
	for room in 4:
		stats.on_room_entered(3)
		if room % 2 == 0:
			for i in 15:
				stats.on_attack()
			stats.on_kill()
			stats.on_skill(&"roots")
		else:
			stats.on_skill(&"shadow")
		stats.on_detected()
		if room == 1:
			stats.on_stealth(true)
		stats.advance(15.0 if room != 1 else 30.0)
		if room == 1:
			stats.on_stealth(false)
			stats.advance(15.0)
		else:
			stats.advance(15.0)
		stats.on_room_exited()
	return stats


func _fake_room(enemies: int) -> Node:
	var script := GDScript.new()
	script.source_code = "extends Node\nvar enemies_alive := %d\n" % enemies
	script.reload()
	var room: Node = script.new()
	_fake_rooms.append(room)
	return room


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(condition: bool, message: String) -> void:
	_checks += 1
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
