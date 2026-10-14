class_name ProfileModel
extends RefCounted
## What the island has learned about the player: an `aggression` and a `stealth` score (0..1) that
## move toward each run's behaviour with a moving average, so recent runs weigh more but the past
## is not forgotten. Pure logic (no nodes, no Events, no files): PlayerProfile wires it to the game.

enum Style { BALANCED, AGGRESSIVE, STEALTH }

const VERSION := 1
const NEUTRAL := 0.5

var config: ProfileConfig
var aggression := NEUTRAL
var stealth := NEUTRAL
var runs := 0
## Counters summed over every merged run.
var totals := {}
var last_run := {}


func _init(profile_config: ProfileConfig = null) -> void:
	config = profile_config if profile_config != null else ProfileConfig.new()


## Score (0..1) of a single run, plus how much to trust it. Components that cannot be measured
## (e.g. no enemy rooms visited) are skipped instead of counting as zero.
func score_run(stats: RunStats) -> Dictionary:
	var rooms := maxf(stats.rooms_with_enemies, 1)
	var has_rooms := stats.rooms_with_enemies > 0
	var has_skills := stats.total_skill_uses() > 0

	var aggression_parts: Array = [
		[config.w_attack_rate, clampf(stats.attacks_per_minute() / config.attacks_per_minute_max, 0.0, 1.0), true],
		[config.w_fight_ratio, stats.rooms_fought / rooms, has_rooms],
		[config.w_aggressive_skills, float(stats.aggressive_skill_uses) / maxf(stats.total_skill_uses(), 1), has_skills],
	]
	var stealth_parts: Array = [
		[config.w_stealth_time, clampf(stats.stealth_fraction() / config.stealth_fraction_max, 0.0, 1.0), true],
		[config.w_evasion_ratio, stats.rooms_evaded / rooms, has_rooms],
		[config.w_low_detection, 1.0 - clampf(stats.detections / rooms / config.detections_per_room_max, 0.0, 1.0), has_rooms],
		[config.w_stealth_skills, float(stats.stealth_skill_uses) / maxf(stats.total_skill_uses(), 1), has_skills],
	]
	return {
		"aggression": _weighted(aggression_parts),
		"stealth": _weighted(stealth_parts),
		"confidence": clampf(stats.play_time / config.full_confidence_seconds, 0.0, 1.0),
	}


## Folds a finished run into the saved profile. Returns false if the run was too short to count.
func merge_run(stats: RunStats) -> bool:
	if stats.play_time < config.min_run_seconds:
		return false
	var score := score_run(stats)
	var rate: float = config.learning_rate * score.confidence
	aggression = lerpf(aggression, score.aggression, rate)
	stealth = lerpf(stealth, score.stealth, rate)
	runs += 1
	var summary := stats.to_dict()
	for key in summary:
		if key != "average_room_seconds":
			totals[key] = totals.get(key, 0) + summary[key]
	last_run = summary
	return true


## The profile as the director should see it mid-run: the saved profile nudged toward what the
## player is doing right now, once the current run has enough data.
func live_scores(stats: RunStats) -> Dictionary:
	var score := score_run(stats)
	var weight := clampf(stats.play_time / config.live_full_seconds, 0.0, 1.0) * config.live_weight
	return {
		"aggression": lerpf(aggression, score.aggression, weight),
		"stealth": lerpf(stealth, score.stealth, weight),
	}


func style() -> Style:
	return style_of(aggression, stealth)


func style_of(aggression_value: float, stealth_value: float) -> Style:
	var difference := aggression_value - stealth_value
	if difference > config.style_threshold:
		return Style.AGGRESSIVE
	if difference < -config.style_threshold:
		return Style.STEALTH
	return Style.BALANCED


static func style_key(value: Style) -> StringName:
	match value:
		Style.AGGRESSIVE:
			return &"aggressive"
		Style.STEALTH:
			return &"stealth"
		_:
			return &"balanced"


func reset() -> void:
	aggression = NEUTRAL
	stealth = NEUTRAL
	runs = 0
	totals = {}
	last_run = {}


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"aggression": snappedf(aggression, 0.0001),
		"stealth": snappedf(stealth, 0.0001),
		"runs": runs,
		"totals": totals,
		"last_run": last_run,
	}


## Loads a saved profile. Returns false (and keeps the current values) if the data is unusable.
func load_dict(data: Dictionary) -> bool:
	if int(data.get("version", 0)) != VERSION:
		return false
	var saved_aggression = data.get("aggression")
	var saved_stealth = data.get("stealth")
	if not (saved_aggression is float or saved_aggression is int) \
			or not (saved_stealth is float or saved_stealth is int):
		return false
	aggression = clampf(float(saved_aggression), 0.0, 1.0)
	stealth = clampf(float(saved_stealth), 0.0, 1.0)
	runs = maxi(int(data.get("runs", 0)), 0)
	totals = data.get("totals", {}) if data.get("totals") is Dictionary else {}
	last_run = data.get("last_run", {}) if data.get("last_run") is Dictionary else {}
	return true


## Weighted average of [weight, value, available] parts; neutral if nothing could be measured.
func _weighted(parts: Array) -> float:
	var total := 0.0
	var weight_sum := 0.0
	for part in parts:
		if part[2]:
			total += part[0] * part[1]
			weight_sum += part[0]
	return total / weight_sum if weight_sum > 0.0 else NEUTRAL
