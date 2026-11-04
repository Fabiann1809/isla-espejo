class_name IdleBreath
extends Node
## Makes a character breathe while it stands still: the body (waist, chest and head) rises a pixel or two
## as a rigid piece and settles again while the legs, with the feet fixed to the ground, stretch to fill the
## gap, so only the lower part of the picture changes. Add it as a child of the actor (Nico, an NPC); it
## finds the actor's AnimatedSprite2D and only works while the animation is an `idle*` one, so walking,
## attacking and being hurt are never touched.
##
## It never changes the actor's sprite: while the body is raised a copy of the current frame, with its rows
## rearranged (see `breathe_image`), is drawn over it (a Sprite2D that follows the sprite's position, scale,
## flip and tint) and the original is made see-through; at rest nothing is drawn but the original. The pictures
## are cached per frame and height. Values and the off switch are in `Tuning`.

var _sprite: AnimatedSprite2D
var _overlay: Sprite2D
var _phase := 0.0
var _hidden_sprite := false
var _saved_self_modulate := Color.WHITE
## (frame texture, pixels) -> the rearranged picture.
var _cache := {}


func _ready() -> void:
	# Out of step with every other character, but the same on every run.
	_phase = float(hash(str(get_path())) % 1000) / 1000.0 * TAU


func _process(delta: float) -> void:
	if not Tuning.BREATH_ENABLED:
		_rest()
		return
	if _sprite == null:
		_sprite = _find_sprite()
		if _sprite == null:
			return
	_phase += delta * TAU / Tuning.BREATH_SECONDS
	var pixels := 0
	if _sprite.sprite_frames != null and String(_sprite.animation).begins_with("idle") and _sprite.is_playing():
		pixels = _stretch_pixels()
	var texture := _picture(pixels) if pixels > 0 else null
	if texture == null:
		_rest()
		return
	_show(texture)


## The rise in whole pixels for the current phase: 0 when the chest is down, `BREATH_PIXELS` at the top.
func _stretch_pixels() -> int:
	return roundi(Tuning.BREATH_PIXELS * (0.5 - 0.5 * cos(_phase)))


## A frame of `image` with the body raised `pixels` rows: everything above the legs moves up as it is (the top
## rows that would leave the picture are lost) and the legs, the lowest `leg_share` of the figure, are stretched
## to meet it, so the last row of the feet stays where it was. `image` is not changed.
static func breathe_image(image: Image, pixels: int, leg_share: float) -> Image:
	var used := image.get_used_rect()
	if pixels <= 0 or not used.has_area():
		return image
	var legs := clampi(roundi(float(used.size.y) * leg_share), 1, used.size.y - 1)
	var feet_end := used.end.y
	var legs_top := feet_end - legs
	var result := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	var source := image.duplicate()
	source.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		var from := -1
		if y < legs_top - pixels:
			from = y + pixels
		elif y < feet_end:
			# The legs, stretched from `legs` rows to `legs + pixels`: nearest row.
			var along := float(y - (legs_top - pixels)) / float(legs + pixels)
			from = clampi(legs_top + int(along * legs), legs_top, feet_end - 1)
		if from >= 0:
			result.blit_rect(source, Rect2i(0, from, image.get_width(), 1), Vector2i(0, y))
	return result


func _picture(pixels: int) -> Texture2D:
	var frames := _sprite.sprite_frames
	if not frames.has_animation(_sprite.animation) or frames.get_frame_count(_sprite.animation) == 0:
		return null
	var frame := clampi(_sprite.frame, 0, frames.get_frame_count(_sprite.animation) - 1)
	var texture := frames.get_frame_texture(_sprite.animation, frame)
	if texture == null:
		return null
	var key := [texture.get_rid(), pixels]
	if not _cache.has(key):
		var image := texture.get_image()
		if image == null or image.is_empty():
			return null
		if image.is_compressed():
			image.decompress()
		_cache[key] = ImageTexture.create_from_image(breathe_image(image, pixels, Tuning.BREATH_LEG_SHARE))
	return _cache[key]


func _show(texture: Texture2D) -> void:
	if _overlay == null:
		_overlay = Sprite2D.new()
		_overlay.name = "Breath"
		_sprite.get_parent().add_child(_overlay)
	var parent := _sprite.get_parent()
	if _overlay.get_parent() != parent:
		return
	parent.move_child(_overlay, _sprite.get_index() + 1)
	_overlay.texture = texture
	_overlay.centered = _sprite.centered
	_overlay.offset = _sprite.offset
	_overlay.flip_h = _sprite.flip_h
	_overlay.flip_v = _sprite.flip_v
	_overlay.position = _sprite.position
	_overlay.scale = _sprite.scale
	_overlay.rotation = _sprite.rotation
	_overlay.modulate = _sprite.modulate
	_overlay.z_index = _sprite.z_index
	_overlay.z_as_relative = _sprite.z_as_relative
	_overlay.texture_filter = _sprite.texture_filter
	_overlay.material = _sprite.material
	_overlay.visible = _sprite.visible
	if not _hidden_sprite:
		_hidden_sprite = true
		_saved_self_modulate = _sprite.self_modulate
		_sprite.self_modulate = Color(_saved_self_modulate, 0.0)


## Back to the plain sprite.
func _rest() -> void:
	if _overlay != null:
		_overlay.visible = false
	if _hidden_sprite and _sprite != null:
		_hidden_sprite = false
		_sprite.self_modulate = _saved_self_modulate


func _find_sprite() -> AnimatedSprite2D:
	for child in get_parent().get_children():
		if child is AnimatedSprite2D:
			return child
	return null


func _exit_tree() -> void:
	_rest()
