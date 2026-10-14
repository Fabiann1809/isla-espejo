class_name RootsEffect
extends SkillEffect
## Raíces: a zone in front of the player that roots (immobilizes) every enemy inside while it lasts.
## Rooted enemies can still attack if the player is in reach.

@export var radius := 40.0
## How long the zone stays on the ground.
@export var duration := 3.0
## Root time refreshed on every tick; enemies stay stuck briefly after leaving the zone.
@export var root_time := 0.35


func activate(caster: Node2D, skill: SkillData, direction: Vector2) -> int:
	var center := caster.global_position + direction * skill.range
	var tree := caster.get_tree()
	var apply := func() -> void:
		for enemy in enemies_near(tree, center, radius):
			if enemy.has_method("apply_root"):
				enemy.apply_root(root_time)
	var zone := SkillZone.circle(center, radius, skill.color, duration, apply)
	caster.get_parent().add_child(zone)
	apply.call()

	var affected := 0
	for enemy in enemies_near(tree, center, radius):
		damage_enemy(enemy, skill.damage, caster.global_position)
		affected += 1
	return affected
