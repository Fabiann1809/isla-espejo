class_name DirectorLogic
extends RefCounted
## The director's decision, as a pure function: profile scores + rule table -> DirectorPlan.
## No nodes, no autoloads, so every decision can be tested exhaustively.


static func plan_for(aggression: float, stealth: float, style: StringName, config: DirectorConfig) -> DirectorPlan:
	var plan := DirectorPlan.new()
	plan.style = style
	plan.aggression = aggression
	plan.stealth = stealth

	var rule: DirectorRule = config.rules.get(style) if config != null else null
	if rule == null:
		plan.reasons.append("no rule for style '%s': the island does not react" % style)
		return plan

	var intensity := config.balanced_intensity
	if style != &"balanced":
		intensity = clampf(absf(aggression - stealth) / config.full_intensity_difference, 0.0, 1.0)
	plan.intensity = intensity

	plan.health_multiplier = lerpf(1.0, rule.health_multiplier, intensity)
	plan.speed_multiplier = lerpf(1.0, rule.speed_multiplier, intensity)
	plan.damage_multiplier = lerpf(1.0, rule.damage_multiplier, intensity)
	plan.vision_multiplier = lerpf(1.0, rule.vision_multiplier, intensity)
	plan.patrol_multiplier = lerpf(1.0, rule.patrol_multiplier, intensity)
	plan.count_multiplier = lerpf(1.0, rule.count_multiplier, intensity)
	plan.room_weights = _blend_weights(rule.room_weights, intensity)
	plan.enemy_weights = _blend_weights(rule.enemy_weights, intensity)

	# Say it only when the reaction is strong enough to be noticed.
	if intensity >= 0.25:
		plan.island_line = rule.island_line
		plan.hints = rule.hints.duplicate()

	plan.reasons.append("profile: aggression %.2f, stealth %.2f -> style '%s' at %d%% intensity"
			% [aggression, stealth, style, roundi(intensity * 100.0)])
	plan.reasons.append("enemies: hp x%.2f, speed x%.2f, damage x%.2f, vision x%.2f, patrol x%.2f, count x%.2f"
			% [plan.health_multiplier, plan.speed_multiplier, plan.damage_multiplier,
			plan.vision_multiplier, plan.patrol_multiplier, plan.count_multiplier])
	if not plan.room_weights.is_empty():
		plan.reasons.append("rooms favoured: %s" % [plan.room_weights])
	return plan


## Blends each weight with "no change" (1.0) by `intensity`.
static func _blend_weights(weights: Dictionary, intensity: float) -> Dictionary:
	var blended := {}
	for key in weights:
		blended[key] = lerpf(1.0, float(weights[key]), intensity)
	return blended
