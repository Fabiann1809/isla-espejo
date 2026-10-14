extends Node
## The island's director (AI layer 2), registered as the autoload "Director".
## Reads the player profile and turns it into a DirectorPlan for the next map. It never touches
## combat code: Level applies the plan when it builds a map.

signal plan_made(plan: DirectorPlan)

const CONFIG_PATH := "res://data/ai/director_rules.tres"

var config: DirectorConfig
var last_plan: DirectorPlan
## When false the island never reacts (every plan is neutral). For debugging.
var enabled := true
var log_to_console := true


func _ready() -> void:
	config = load(CONFIG_PATH)
	if config == null:
		push_error("Missing %s; the island will not react." % CONFIG_PATH)
		config = DirectorConfig.new()


## Decides how the next map should react to the player. `announce` = false only previews the
## decision (no signal, no log), e.g. for the death screen.
func make_plan(announce := true) -> DirectorPlan:
	var plan: DirectorPlan
	if enabled:
		var scores: Dictionary = PlayerProfile.live_scores()
		var style := ProfileModel.style_key(PlayerProfile.live_style())
		plan = DirectorLogic.plan_for(scores.aggression, scores.stealth, style, config)
	else:
		plan = DirectorPlan.neutral()
		plan.reasons.append("director disabled")
	if announce:
		last_plan = plan
		if log_to_console:
			print("[Director] ", " | ".join(plan.reasons))
		plan_made.emit(plan)
	return plan
