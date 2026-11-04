class_name IdleBreath
extends Node
## Makes a character breathe while it stands still: its picture stretches a pixel or two upward and settles
## again, feet fixed to the ground, slowly and out of step with the others. Add it as a child of the actor
## (Nico, an NPC); it finds the actor's AnimatedSprite2D and only works while the animation is an `idle*` one,
## so walking, attacking and being hurt are never touched. The stretch is a whole number of pixels, so
## the nearest-filtered art repeats a row instead of blurring. Values and the off switch are in `Tuning`.

var _sprite: AnimatedSprite2D
var _base_scale := Vector2.ONE
var _base_position := Vector2.ZERO
var _feet_local := 0.0
var _height := 0.0
var _ready_to_breathe := false
var _phase := 0.0
var _last_frames: SpriteFrames
var _shown := -1


func _ready() -> void:
	# Out of step with every other character, but the same on every run.
	_phase = float(hash(str(get_path())) % 1000) / 1000.0 * TAU


func _process(delta: float) -> void:
	if not Tuning.BREATH_ENABLED:
		return
	if _sprite == null:
		_sprite = _find_sprite()
		if _sprite == null:
			return
	if _sprite.sprite_frames == null or _sprite.sprite_frames != _last_frames:
		_measure()
	if not _ready_to_breathe:
		return
	_phase += delta * TAU / Tuning.BREATH_SECONDS
	if String(_sprite.animation).begins_with("idle") and _sprite.is_playing():
		_apply(_stretch_pixels())
	else:
		_apply(0)


## The stretch in whole pixels for the current phase: 0 when the chest is down, `BREATH_PIXELS` at the top.
func _stretch_pixels() -> int:
	return roundi(Tuning.BREATH_PIXELS * (0.5 - 0.5 * cos(_phase)))


func _apply(pixels: int) -> void:
	if pixels == _shown:
		return
	_shown = pixels
	var factor := 1.0 + float(pixels) / maxf(_height, 1.0)
	_sprite.scale = Vector2(_base_scale.x, _base_scale.y * factor)
	# Scaling happens around the sprite's origin: move it so the feet stay where they were.
	_sprite.position.y = _base_position.y + _feet_local * _base_scale.y * (1.0 - factor)


func _find_sprite() -> AnimatedSprite2D:
	for child in get_parent().get_children():
		if child is AnimatedSprite2D:
			return child
	return null


## Reads the sprite's rest scale and position and where the feet and the top of the figure are in its first
## idle frame (the opaque rows), once per set of frames.
func _measure() -> void:
	_last_frames = _sprite.sprite_frames
	_ready_to_breathe = false
	var frames := _sprite.sprite_frames
	if frames == null:
		return
	var animation := &""
	for candidate in frames.get_animation_names():
		if String(candidate).begins_with("idle"):
			animation = candidate
			break
	if animation == &"" or frames.get_frame_count(animation) == 0:
		return
	var texture := frames.get_frame_texture(animation, 0)
	var image := texture.get_image() if texture != null else null
	if image == null or image.is_empty():
		return
	if image.is_compressed():
		image.decompress()
	var used := image.get_used_rect()
	if not used.has_area():
		return
	_base_scale = _sprite.scale
	_base_position = _sprite.position
	var origin := -float(image.get_height()) / 2.0 if _sprite.centered else 0.0
	_feet_local = _sprite.offset.y + origin + float(used.end.y)
	_height = float(used.size.y) * absf(_base_scale.y)
	_ready_to_breathe = true
