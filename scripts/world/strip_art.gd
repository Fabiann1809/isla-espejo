class_name StripArt
extends RefCounted
## Optional art for a world object: a PNG that is one picture or a horizontal strip of square
## frames. `build` returns an AnimatedSprite2D, or null while the file does not exist, so callers
## keep drawing their own placeholder until the art is there.


## `path` is a res:// PNG. A strip plays at `fps` (one frame = a square as tall as the image).
static func build(path: String, fps: float = 8.0) -> AnimatedSprite2D:
	if not ResourceLoader.exists(path):
		return null
	var texture := load(path) as Texture2D
	if texture == null or texture.get_height() <= 0:
		return null
	var cell := texture.get_height()
	var count := maxi(texture.get_width() / cell, 1)
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", fps)
	frames.set_animation_loop(&"default", true)
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * cell, 0, cell, cell)
		frames.add_frame(&"default", atlas)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.play(&"default")
	return sprite
