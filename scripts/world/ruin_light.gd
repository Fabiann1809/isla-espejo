class_name RuinLight
extends RefCounted
## Soft round lights and shades of the Ruinas: a radial gradient sprite, additive for light. It does
## not touch any autoload, so props and tests can use it freely.

static var _texture: Texture2D


## A soft round spot of `color` (fading to nothing at its edge), `size` across, centered on its position.
static func glow(color: Color, size: Vector2, additive := true) -> Sprite2D:
	if _texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 64
		texture.height = 64
		_texture = texture
	var sprite := Sprite2D.new()
	sprite.texture = _texture
	sprite.scale = size / 64.0
	sprite.modulate = color
	if additive:
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sprite.material = material
	return sprite
