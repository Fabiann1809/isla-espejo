class_name ActorShadow
extends Node2D
## A soft ellipse on the ground under an actor (Nico, an enemy, an NPC), drawn just before its art.
## Its place and size come from the actor's sprite: the lowest opaque row of the first idle frame.

const NODE_NAME := "Shadow"

static var _feet_cache := {}
## The current map's shadow style (alpha, size scale, drop, bottom; see `attach`), set by the Level
## before it builds a map, so an enemy that appears later (a lava surge's wave, a brood, a summon)
## gets the same shadow as the ones placed with the map.
static var _style := [-1.0, 1.0, 0.0, -1.0]
## True on a map whose shadows are contact shadows (the Ruinas; see `_set_contact`).
static var _contact := false

var size := Vector2(12, 4)
var alpha := Tuning.SHADOW_ALPHA
## Size, position and alpha outside the Ruinas: Nico and his shadow outlive the map.
var _plain: Array = []
## The sprite whose pose a contact shadow follows, its scale at rest, and the shadow's y for a frame's centre row.
var _followed: AnimatedSprite2D
var _rest_scale := 1.0
var _centre_y := 0.0


## Adds a shadow to `actor` if it has none yet (and shadows are on).
## `alpha` < 0 uses Tuning.SHADOW_ALPHA (a dark floor needs a stronger shadow to ground the actor).
## `size_scale` grows the ellipse and `drop` moves it that many px below the feet: centred on the
## last row of the feet, only its lower half shows, so a floor that needs the actor plainly grounded
## (the temple's) asks for a bigger one a little lower.
## `bottom` >= 0 anchors the shadow by its lower edge, that many px below the feet, whatever its size
## (the temple: a wide enemy's shadow centred on its feet stuck out below them and made it float);
## < 0 keeps the shadow centred on the feet, `drop` px lower (the forest).
static func attach(actor: Node2D, alpha := -1.0, size_scale := 1.0, drop := 0.0, bottom := -1.0) -> void:
	if not Tuning.SHADOWS_ENABLED or actor.has_node(NODE_NAME):
		return
	var shadow := ActorShadow.new()
	shadow.name = NODE_NAME
	if alpha >= 0.0:
		shadow.alpha = alpha
	var sprite := _sprite_of(actor)
	shadow._fit(sprite, _measure(sprite) if sprite != null else {}, size_scale, drop, bottom)
	actor.add_child(shadow)
	actor.move_child(shadow, 0)


func _fit(sprite: AnimatedSprite2D, measure: Dictionary, size_scale: float, drop: float, bottom: float) -> void:
	var feet := Vector2(0, 7)
	var width := 12.0
	if sprite != null:
		feet = sprite.position + (sprite.offset + Vector2(0, measure.bottom)) * sprite.scale
		width = measure.width * absf(sprite.scale.x)
	size = Vector2(width * Tuning.SHADOW_WIDTH_FACTOR, width * Tuning.SHADOW_WIDTH_FACTOR * Tuning.SHADOW_HEIGHT_FACTOR) * size_scale
	if bottom >= 0.0:
		position = feet + Vector2(0, bottom - size.y / 2.0)
	else:
		position = feet + Vector2(0, drop)


## The Ruinas' contact shadow: as wide as the actor's own art asks and anchored just under its feet
## (lower and smaller for what flies), whatever the animation (the Serpiente's crawl is drawn 13 px
## higher in its cell than its coil). Off, the shadow goes back to what it was before the Ruinas.
func _set_contact(actor: Node2D, on: bool) -> void:
	if _plain.is_empty():
		if not on:
			return
		_plain = [size, position, alpha]
	size = _plain[0]
	position = _plain[1]
	alpha = _plain[2]
	if _followed != null:
		_followed.animation_changed.disconnect(_follow_pose)
		_followed = null
	var sprite := _sprite_of(actor)
	if on and sprite != null:
		# Asked by property: naming DiverData here would load it with every map, which shifts the random
		# start times of the temple's animated lava.
		var flies: bool = "data" in actor and actor.data != null and "dive_speed" in actor.data
		var size_scale := Tuning.RUIN_FLIER_SHADOW_SCALE if flies else 1.0
		var bottom := Tuning.RUIN_FLIER_SHADOW_BOTTOM if flies else Tuning.RUIN_SHADOW_BOTTOM
		var rest := _measure(sprite, true)
		_fit(sprite, rest, size_scale, 0.0, bottom)
		alpha = Tuning.RUIN_SHADOW_ALPHA
		if not flies:
			_followed = sprite
			_rest_scale = sprite.scale.y
			_centre_y = position.y - rest.bottom * _rest_scale
			sprite.animation_changed.connect(_follow_pose)
			_follow_pose()
	queue_redraw()


func _follow_pose() -> void:
	position.y = _centre_y + _measure(_followed, true, _followed.animation).bottom * _rest_scale


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, size.y / maxf(size.x, 0.01)))
	draw_circle(Vector2.ZERO, size.x / 2.0, Color(0, 0, 0, alpha))


static func _sprite_of(actor: Node) -> AnimatedSprite2D:
	for child in actor.get_children():
		if child is AnimatedSprite2D and child.visible and child.sprite_frames != null:
			return child
	return null


## Bottom of the drawn figure (relative to the frame's center) and its width, in frame pixels.
## A SpriteFrames has no RID of its own (always RID(0)), so without `own_art` every sprite gets the
## first one's measure of that animation; with it the cache is per SpriteFrames.
static func _measure(sprite: AnimatedSprite2D, own_art := false, pose := &"idle") -> Dictionary:
	var frames := sprite.sprite_frames
	var anim := pose if frames.has_animation(pose) else sprite.animation
	var key := [frames if own_art else frames.get_rid(), anim]
	if _feet_cache.has(key):
		return _feet_cache[key]
	var texture := frames.get_frame_texture(anim, 0)
	var result := {"bottom": 0.0, "width": 12.0}
	if texture != null:
		var frame_size := texture.get_size()
		result = {"bottom": frame_size.y / 2.0, "width": frame_size.x * 0.5}
		var image := texture.get_image()
		if image != null and not image.is_empty():
			var used := image.get_used_rect()
			if used.has_area():
				result = {"bottom": used.end.y - frame_size.y / 2.0 - 1.0, "width": float(used.size.x)}
	_feet_cache[key] = result
	return result


static func use_style(alpha: float, size_scale: float, drop: float, bottom: float, contact := false) -> void:
	_style = [alpha, size_scale, drop, bottom]
	_contact = contact


## Adds a shadow in the current map's style (see `use_style`).
static func attach_styled(actor: Node2D) -> void:
	attach(actor, _style[0], _style[1], _style[2], _style[3])
	var shadow := actor.get_node_or_null(NODE_NAME) as ActorShadow
	if shadow != null:
		shadow._set_contact(actor, _contact)
