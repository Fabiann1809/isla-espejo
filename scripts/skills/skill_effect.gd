class_name SkillEffect
extends Resource
## Base class of skill behaviours. Subclass it, override `activate` and expose the tunable numbers
## as @export variables so they can be edited in the skill's `.tres`.


## Runs the skill. `caster` is the player, `direction` where it faces. Returns how many enemies
## were affected (reported on the Events bus for the adaptive AI).
func activate(_caster: Node2D, _skill: SkillData, _direction: Vector2) -> int:
	push_error("SkillEffect.activate() must be overridden by the skill's effect.")
	return 0


## Living enemies whose center is within `radius` of `center`.
static func enemies_near(tree: SceneTree, center: Vector2, radius: float) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for node in tree.get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		if enemy.global_position.distance_to(center) <= radius:
			found.append(enemy)
	return found


## Damages an enemy through its Hurtbox, like any other attack.
static func damage_enemy(enemy: Node, amount: int, from_position: Vector2) -> void:
	if amount <= 0:
		return
	var hurtbox := enemy.get_node_or_null("Hurtbox") as Hurtbox
	if hurtbox != null:
		hurtbox.receive_hit(amount, from_position)
