class_name RuinAnim
extends RefCounted
## Animated tiles of the Ruinas: a tile of the profile that cycles through several others.


## A tile that cycles through `frames` (names in the profile), starting at a random frame so a row of
## them does not blink together. `at` is its top-left corner.
static func sprite(frames: Array[StringName], fps: float, at: Vector2) -> AnimatedSprite2D:
	var node := AnimatedSprite2D.new()
	var sprite_frames := SpriteFrames.new()
	sprite_frames.set_animation_speed(&"default", fps)
	for frame_name in frames:
		sprite_frames.add_frame(&"default", TileArt.tile(frame_name))
	node.sprite_frames = sprite_frames
	node.centered = false
	node.position = at
	node.scale = Vector2.ONE * TileArt.draw_scale()
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.frame = randi() % frames.size()
	node.play()
	return node
