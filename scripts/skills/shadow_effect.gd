class_name ShadowEffect
extends SkillEffect
## Sombra: short teleport in the facing direction (stopping before walls) that also makes the player
## harder to detect for a while. Attacking breaks the stealth.

const WORLD_MASK := 1
const WALL_GAP := 1.0

@export var stealth_time := 3.0
## Detection range multiplier while hidden (0.3 = enemies notice the player from 30% as far).
@export_range(0.05, 1.0) var visibility := 0.3


func activate(caster: Node2D, skill: SkillData, direction: Vector2) -> int:
	var origin := caster.global_position
	var destination := _safe_destination(caster, direction * skill.range)

	# Enemies that were hunting the player: the AI reads this as an escape.
	var hunters := 0
	for node in caster.get_tree().get_nodes_in_group("enemies"):
		if node.get("target") == caster:
			hunters += 1

	Placement.teleport(caster, destination)
	if caster.has_method("start_stealth"):
		caster.start_stealth(stealth_time, visibility)

	var parent := caster.get_parent()
	parent.add_child(SkillZone.circle(origin, 14.0, skill.color, 0.4))
	parent.add_child(SkillZone.circle(destination, 14.0, skill.color, 0.4))
	return hunters


## Where the player ends up: the full distance, or just before the first wall.
func _safe_destination(caster: Node2D, motion: Vector2) -> Vector2:
	var body := caster.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body == null:
		return caster.global_position + motion
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = body.shape
	params.transform = Transform2D(0.0, caster.global_position)
	params.motion = motion
	params.collision_mask = WORLD_MASK
	var result := caster.get_world_2d().direct_space_state.cast_motion(params)
	var fraction: float = result[0] if result.size() == 2 else 1.0
	var travelled := maxf(motion.length() * fraction - WALL_GAP, 0.0)
	return caster.global_position + motion.normalized() * travelled
