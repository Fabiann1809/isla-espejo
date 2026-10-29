class_name DropSpawner
extends Node
## Leaves basic resources where enemies die. The list comes from the scenario's `drops`; every
## resource rolls its own chance, with a "pity" kill count so a long dry streak never happens.

const SCATTER := 10.0
const PICKUP_SCENE := preload("res://scenes/world/pickup.tscn")

var drops: Array[ResourceData] = []
var rng := RandomNumberGenerator.new()

var _dry_kills := {}
var _placed: Array[Pickup] = []


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)


func _on_enemy_killed(enemy: Node) -> void:
	var node := enemy as Node2D
	if node == null or node.get_parent() == null or not "data" in node or node.data == null:
		return
	var luck: float = node.data.drop_multiplier
	if luck <= 0.0:
		return
	var player := get_tree().get_first_node_in_group("player")
	var hurt: bool = player != null and player.health.current * 2 <= player.health.max_health
	for resource in drops:
		var chance := resource.drop_chance * luck * (resource.hurt_chance_multiplier if hurt else 1.0)
		var dry: int = _dry_kills.get(resource.id, 0) + 1
		var guaranteed := resource.pity_kills > 0 and dry >= resource.pity_kills
		if (guaranteed or rng.randf() < chance) and _room_on_floor(resource):
			_dry_kills[resource.id] = 0
			_spawn(resource, node)
		else:
			_dry_kills[resource.id] = dry


func _room_on_floor(resource: ResourceData) -> bool:
	# Own list: a pickup added this very frame is not in the tree yet (kills can come in bursts).
	var count := 0
	var alive: Array[Pickup] = []
	for pickup in _placed:
		if is_instance_valid(pickup) and not pickup.is_queued_for_deletion():
			alive.append(pickup)
			if pickup.data == resource:
				count += 1
	_placed = alive
	return count < resource.max_on_floor


func _spawn(resource: ResourceData, enemy: Node2D) -> void:
	var pickup: Pickup = PICKUP_SCENE.instantiate()
	pickup.setup(resource)
	pickup.position = enemy.position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, SCATTER)
	_placed.append(pickup)
	enemy.get_parent().add_child.call_deferred(pickup)
