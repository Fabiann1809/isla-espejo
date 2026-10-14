class_name CurrentEffect
extends SkillEffect
## Corriente: a wave in front of the player that pushes enemies away and slows them down.

@export_range(10.0, 360.0) var arc_degrees := 100.0
@export var push_speed := 260.0
## Movement speed multiplier while slowed (0.4 = 60% slower).
@export_range(0.05, 1.0) var slow_factor := 0.4
@export var slow_time := 2.5


func activate(caster: Node2D, skill: SkillData, direction: Vector2) -> int:
	caster.get_parent().add_child(
			SkillZone.wave(caster.global_position, direction, skill.range, arc_degrees, skill.color))
	var affected := 0
	for enemy in enemies_near(caster.get_tree(), caster.global_position, skill.range):
		var offset := enemy.global_position - caster.global_position
		if absf(direction.angle_to(offset)) > deg_to_rad(arc_degrees) / 2.0:
			continue
		# Damage first: a damaging hit sets its own small knockback, the push must win.
		damage_enemy(enemy, skill.damage, caster.global_position)
		if enemy.has_method("apply_knockback"):
			enemy.apply_knockback(offset.normalized() * push_speed)
		if enemy.has_method("apply_slow"):
			enemy.apply_slow(slow_factor, slow_time)
		affected += 1
	return affected
