class_name IronBlock
extends StaticBody2D
## A glowing iron block called down by a doomed forger (DoomedForger). It falls on a warned spot,
## its own Hitbox hurts around its footprint on impact, and then it stands as a solid obstacle on the
## world layer (it blocks Nico, enemies, arrows and sight) that cools down and goes away after a
## while. If anybody is under it when it lands it shatters instead: the impact hurts, but nobody is
## ever shut inside a block. It lives in the room, y-sorted with the actors (its origin is the middle
## of its footprint), so it outlasts the forger.

enum Phase { FALLING, SOLID, SHATTERED }

const WORLD_LAYER := 1
const PLAYER_LAYER := 2
const ENEMY_LAYER := 3
const ENEMY_ATTACK_LAYER := 5
const WATER_LAYER := 7
const SHATTER_TIME := 0.35
## Frames of `art` (square cells, footprint centered on ART_ORIGIN of each cell), drawn by
## tools/make_forjador_condenado_art.py for the default 22x14 block, 14 px tall.
const ART_ORIGIN := Vector2(24, 30)
const ART_SHADOW := 0
const ART_SHADOW_FRAMES := 4
const ART_FALLING := 4
const ART_IMPACT := 5
const ART_HEAT := 6
const ART_HEAT_FRAMES := 5
const ART_SHARDS := 11
const ART_SHARD_FRAMES := 4

var phase: Phase = Phase.FALLING
var size := Vector2(22, 14)
var height := 14.0
var fall_time := 0.8
var fall_height := 70.0
var damage := 1
var impact_time := 0.15
var impact_margin := 3.0
var lifetime := 7.0
var fade_time := 0.6
var cool_time := 3.0
var hot_color := Color.ORANGE
var cold_color := Color.DIM_GRAY
var edge_color := Color.YELLOW
## Optional pixel-art strip instead of the plain rectangles (see the ART_* frames).
var art: Texture2D

var _phase_left := 0.0
var _age := 0.0
var _body_shape: CollisionShape2D
var _hitbox: Hitbox


## A falling block landing on `spot` (in its parent's coordinates), set up from the forger's data.
static func create(spot: Vector2, data: DoomedForgerData, hit_damage: int) -> IronBlock:
	var block := IronBlock.new()
	block.name = "IronBlock"
	block.position = spot
	block.size = data.block_size
	block.height = data.block_height
	block.fall_time = data.fall_time
	block.fall_height = data.fall_height
	block.damage = hit_damage
	block.impact_time = data.impact_time
	block.impact_margin = data.impact_margin
	block.lifetime = data.block_lifetime
	block.fade_time = data.fade_time
	block.cool_time = data.cool_time
	block.hot_color = data.hot_color
	block.cold_color = data.cold_color
	block.edge_color = data.edge_color
	block.art = data.block_art
	return block


func _ready() -> void:
	add_to_group(&"iron_blocks")
	collision_layer = 1 << (WORLD_LAYER - 1)
	collision_mask = 0
	_body_shape = _rect_shape(size)
	_body_shape.disabled = true
	add_child(_body_shape)
	_hitbox = Hitbox.new()
	_hitbox.collision_layer = 1 << (ENEMY_ATTACK_LAYER - 1)
	_hitbox.collision_mask = 1 << (PLAYER_LAYER - 1)
	_hitbox.damage = damage
	_hitbox.add_child(_rect_shape(size + Vector2.ONE * impact_margin * 2.0))
	add_child(_hitbox)
	_phase_left = fall_time


## True once it stands as an obstacle.
func is_solid() -> bool:
	return phase == Phase.SOLID


func _physics_process(delta: float) -> void:
	_phase_left -= delta
	match phase:
		Phase.FALLING:
			if _phase_left <= 0.0:
				_land()
		Phase.SOLID, Phase.SHATTERED:
			_age += delta
			if _age >= impact_time:
				_hitbox.deactivate()
			if _age >= lifetime or (phase == Phase.SHATTERED and _phase_left <= 0.0):
				queue_free()
	queue_redraw()


func _land() -> void:
	_hitbox.activate()
	_age = 0.0
	if _anybody_under():
		phase = Phase.SHATTERED
		_phase_left = SHATTER_TIME
		return
	phase = Phase.SOLID
	_body_shape.set_deferred("disabled", false)


## True if a body (Nico, an enemy) or a solid thing already stands where it would land.
func _anybody_under() -> bool:
	var square := RectangleShape2D.new()
	square.size = size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = square
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = (1 << (WORLD_LAYER - 1)) | (1 << (PLAYER_LAYER - 1)) \
			| (1 << (ENEMY_LAYER - 1)) | (1 << (WATER_LAYER - 1))
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


static func _rect_shape(extent: Vector2) -> CollisionShape2D:
	var rect := RectangleShape2D.new()
	rect.size = extent
	var shape := CollisionShape2D.new()
	shape.shape = rect
	return shape


func _draw() -> void:
	if art != null:
		_draw_art()
		return
	match phase:
		Phase.FALLING:
			var progress := 1.0 - clampf(_phase_left / maxf(fall_time, 0.001), 0.0, 1.0)
			_draw_shadow(progress)
			_draw_box(-fall_height * (1.0 - progress * progress), 1.0, 1.0)
		Phase.SOLID:
			var fade := clampf((lifetime - _age) / maxf(fade_time, 0.001), 0.0, 1.0)
			_draw_box(0.0, clampf(1.0 - _age / maxf(cool_time, 0.001), 0.0, 1.0), fade)
		Phase.SHATTERED:
			_draw_shards(1.0 - clampf(_phase_left / SHATTER_TIME, 0.0, 1.0))


## Same phases and timing as the plain drawing, with frames of `art` picked by time.
func _draw_art() -> void:
	match phase:
		Phase.FALLING:
			var progress := 1.0 - clampf(_phase_left / maxf(fall_time, 0.001), 0.0, 1.0)
			_draw_art_frame(ART_SHADOW + mini(ART_SHADOW_FRAMES - 1, int(progress * ART_SHADOW_FRAMES)),
					0.0, 0.35 * progress)
			# Whole pixels, so the falling block stays as crisp as the standing one.
			_draw_art_frame(ART_FALLING, roundf(-fall_height * (1.0 - progress * progress)), 1.0)
		Phase.SOLID:
			var fade := clampf((lifetime - _age) / maxf(fade_time, 0.001), 0.0, 1.0)
			var frame := ART_IMPACT
			if _age >= impact_time:
				var cooled := clampf(_age / maxf(cool_time, 0.001), 0.0, 1.0)
				frame = ART_HEAT + mini(ART_HEAT_FRAMES - 1, int(cooled * ART_HEAT_FRAMES))
			_draw_art_frame(frame, 0.0, fade)
		Phase.SHATTERED:
			var progress := 1.0 - clampf(_phase_left / SHATTER_TIME, 0.0, 1.0)
			_draw_art_frame(ART_SHARDS + mini(ART_SHARD_FRAMES - 1, int(progress * ART_SHARD_FRAMES)),
					0.0, 1.0)


func _draw_art_frame(frame: int, lift: float, alpha: float) -> void:
	var cell := float(art.get_height())
	draw_texture_rect_region(art, Rect2(-ART_ORIGIN + Vector2(0.0, lift), Vector2(cell, cell)),
			Rect2(frame * cell, 0.0, cell, cell), Color(1.0, 1.0, 1.0, alpha))


func _draw_shadow(progress: float) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, size.y / size.x))
	draw_circle(Vector2.ZERO, size.x * 0.5 * (0.4 + 0.6 * progress), Color(0, 0, 0, 0.35 * progress))
	draw_set_transform(Vector2.ZERO)


## The block standing on its footprint, lifted by `lift` (negative is up); `heat` 1 glows, 0 is cold.
func _draw_box(lift: float, heat: float, alpha: float) -> void:
	var color := cold_color.lerp(hot_color, heat)
	var top := Rect2(-size.x / 2.0, -size.y / 2.0 - height + lift, size.x, size.y)
	var front := Rect2(-size.x / 2.0, size.y / 2.0 - height + lift, size.x, height)
	draw_rect(front, Color(color.darkened(0.25), alpha))
	draw_rect(top, Color(color.lightened(0.15), alpha))
	var edge := Color(edge_color, alpha * (0.25 + 0.75 * heat))
	draw_rect(top.merge(front), edge, false, 1.0)
	draw_line(front.position, front.position + Vector2(size.x, 0.0), edge, 1.0)


func _draw_shards(progress: float) -> void:
	var color := Color(hot_color, 1.0 - progress)
	for i in 6:
		var direction := Vector2.from_angle(TAU * i / 6.0 + 0.3)
		var at := direction * size.x * 0.6 * progress - Vector2(0, height * 0.5 * (1.0 - progress))
		draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), color)
