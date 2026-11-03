class_name GroundHazard
extends Node2D
## A patch on the ground left by an enemy (hot crystals, a burning trail): it hurts the player who
## stands on it once every `tick` seconds through its own Hitbox (enemy attack layer), may slow
## them, and fades away after `lifetime` (or never, with `lifetime <= 0`, until `expire()` puts it
## out). Drawn on the ground, under every actor.

var radius := 8.0
## Seconds before it is gone (its last quarter cools it down); 0 or less: it burns until `expire()`.
var lifetime := 3.0
## How long `expire()` takes to cool it down and take it away.
var expire_time := 1.0
var tick := 0.5
var damage := 1
var color := Color(1.0, 0.5, 0.1, 0.7)
## Player speed factor while standing on it (1 = no slow), applied for `slow_time` seconds.
var slow_factor := 1.0
var slow_time := 0.3
## Optional drawn patch instead of the plain circle: a strip of square cells, `art_frames.x` that
## spread it, `art_frames.y` that loop while it burns, then `art_frames.z` that cool it down over
## its last quarter (or over `expire_time` once put out).
var art: Texture2D
var art_frames := Vector3i(3, 4, 4)
var art_fps := 8.0
var art_flip := false

var _age := 0.0
var _tick_left := 0.0
var _hitbox: Hitbox
## Set by `expire()`: from when it cools and when it is gone (in its own age).
var _expiring := false
var _cool_from := INF
var _gone_at := INF


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


## Puts it out: it stops hurting, cools down over `expire_time` and goes away. Safe to call again
## or before it is in the tree (it then cools as soon as it is placed).
func expire() -> void:
	if _expiring:
		return
	_gone_at = minf(_age + expire_time, _ends_at())
	_cool_from = minf(_age, _cools_at())
	_expiring = true
	if _hitbox != null:
		_hitbox.deactivate()


func is_expiring() -> bool:
	return _expiring


## Age at which it is gone (INF: never).
func _ends_at() -> float:
	if _expiring:
		return _gone_at
	return lifetime if lifetime > 0.0 else INF


## Age from which it cools down (INF: never).
func _cools_at() -> float:
	if _expiring:
		return _cool_from
	return lifetime * 0.75 if lifetime > 0.0 else INF


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= _ends_at():
		queue_free()
		return
	if _expiring:
		queue_redraw()
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
	if art != null:
		_draw_art()
		return
	# Fades out over its last quarter (its cooling).
	var fade := _fade(1.0)
	draw_circle(Vector2.ZERO, radius, Color(color, color.a * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(color.lightened(0.3), color.a * fade), 1.0)


func _draw_art() -> void:
	var cool_start := _cools_at()
	var frame: int
	if _age >= cool_start:
		var cooled := (_age - cool_start) / maxf(_ends_at() - cool_start, 0.001)
		frame = art_frames.x + art_frames.y + mini(art_frames.z - 1, int(cooled * art_frames.z))
	elif _age < art_frames.x / art_fps:
		frame = int(_age * art_fps)
	else:
		frame = art_frames.x + int((_age - art_frames.x / art_fps) * art_fps) % art_frames.y
	# The cooled crust only fades in the very last moments.
	var fade := _fade(0.4)
	var cell := float(art.get_height())
	if art_flip:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
	draw_texture_rect_region(art, Rect2(-cell / 2.0, -cell / 2.0, cell, cell),
			Rect2(frame * cell, 0.0, cell, cell), Color(1.0, 1.0, 1.0, fade))


## 1 until the last `share` of its cooling, then down to 0 when it is gone; 1 if it never cools.
func _fade(share: float) -> float:
	var cool_start := _cools_at()
	if is_inf(cool_start):
		return 1.0
	var end := _ends_at()
	return clampf((end - _age) / maxf((end - cool_start) * share, 0.001), 0.0, 1.0)
