class_name GroundHazard
extends Node2D
## A patch on the ground left by an enemy (hot crystals, a burning trail): it hurts the player who
## stands on it once every `tick` seconds through its own Hitbox (enemy attack layer), may slow
## them, and fades away after `lifetime`. Drawn on the ground, under every actor.

var radius := 8.0
var lifetime := 3.0
var tick := 0.5
var damage := 1
var color := Color(1.0, 0.5, 0.1, 0.7)
## Player speed factor while standing on it (1 = no slow), applied for `slow_time` seconds.
var slow_factor := 1.0
var slow_time := 0.3

var _age := 0.0
var _tick_left := 0.0
var _hitbox: Hitbox


## A hazard on `center` (in its parent's coordinates); add it to a node of the room.
static func create(center: Vector2, hazard_radius: float, seconds: float, hit_damage: int,
		hazard_color: Color) -> GroundHazard:
	var hazard := GroundHazard.new()
	hazard.position = center
	hazard.radius = hazard_radius
	hazard.lifetime = seconds
	hazard.damage = hit_damage
	hazard.color = hazard_color
	return hazard


func _ready() -> void:
	add_to_group(&"ground_hazards")
	z_as_relative = false
	z_index = RoomTheme.GROUND_FX_Z
	_hitbox = Hitbox.new()
	_hitbox.collision_layer = 1 << 4
	_hitbox.collision_mask = 1 << 1
	_hitbox.damage = damage
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	_hitbox.add_child(shape)
	add_child(_hitbox)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left = tick
		_hitbox.activate()
		_slow_player()
	queue_redraw()


func _slow_player() -> void:
	if slow_factor >= 1.0:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and player.has_method("apply_slow") and player.global_position.distance_to(global_position) <= radius:
		player.apply_slow(slow_factor, slow_time)


func _draw() -> void:
	# Fades out over its last quarter.
	var fade := clampf((lifetime - _age) / (lifetime * 0.25), 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(color, color.a * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(color.lightened(0.3), color.a * fade), 1.0)
