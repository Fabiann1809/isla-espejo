class_name ActorShadow
extends Node2D
## A soft ellipse on the ground under an actor (Nico, an enemy, an NPC), drawn just before its art.
## Its place and size come from the actor's sprite: the lowest opaque row of the first idle frame.

const NODE_NAME := "Shadow"

static var _feet_cache := {}

var size := Vector2(12, 4)


## Adds a shadow to `actor` if it has none yet (and shadows are on).
static func attach(actor: Node2D) -> void:
	if not Tuning.SHADOWS_ENABLED or actor.has_node(NODE_NAME):
		return
	var shadow := ActorShadow.new()
	shadow.name = NODE_NAME
	var sprite := _sprite_of(actor)
	var feet := Vector2(0, 7)
	var width := 12.0
	if sprite != null:
		var measure := _measure(sprite)
		feet = sprite.position + (sprite.offset + Vector2(0, measure.bottom)) * sprite.scale
		width = measure.width * absf(sprite.scale.x)
	shadow.position = feet
	shadow.size = Vector2(width * Tuning.SHADOW_WIDTH_FACTOR, width * Tuning.SHADOW_WIDTH_FACTOR * Tuning.SHADOW_HEIGHT_FACTOR)
	actor.add_child(shadow)
	actor.move_child(shadow, 0)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, size.y / maxf(size.x, 0.01)))
	draw_circle(Vector2.ZERO, size.x / 2.0, Color(0, 0, 0, Tuning.SHADOW_ALPHA))


static func _sprite_of(actor: Node) -> AnimatedSprite2D:
	for child in actor.get_children():
		if child is AnimatedSprite2D and child.visible and child.sprite_frames != null:
			return child
	return null


## Bottom of the drawn figure (relative to the frame's center) and its width, in frame pixels.
static func _measure(sprite: AnimatedSprite2D) -> Dictionary:
	var frames := sprite.sprite_frames
	var anim := &"idle" if frames.has_animation(&"idle") else sprite.animation
	var key := [frames.get_rid(), anim]
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
