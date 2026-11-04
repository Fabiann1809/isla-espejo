extends SceneTree
## Idle breathing: a standing character raises its body a whole number of pixels while its legs stretch and its
## feet stay fixed; the sprite itself is never changed and nothing happens while it moves.
## Run: godot --headless --path . --script res://tests/test_idle_breath.gd

var _ok := true


func _initialize() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_test_rows()
	await _test_sprite()
	quit(0 if _ok else 1)


## The row arithmetic on a picture whose every row has its own color.
func _test_rows() -> void:
	var image := Image.create(4, 20, false, Image.FORMAT_RGBA8)
	for y in range(4, 18):
		image.fill_rect(Rect2i(0, y, 4, 1), Color(y / 20.0, 0.5, 0.5, 1.0))
	var before := image.duplicate()
	var out := IdleBreath.breathe_image(image, 2, 0.3)
	_check(image.get_data() == before.get_data(), "the original picture is not changed")
	# 14 rows of figure (4..17), legs = round(14 * 0.3) = 4 rows (14..17), body rows 4..13.
	_check(out.get_pixel(0, 2) == image.get_pixel(0, 4), "the top of the body rose 2 px")
	_check(out.get_pixel(0, 11) == image.get_pixel(0, 13), "the body moved as a piece (row 13 is now at row 11)")
	_check(out.get_pixel(0, 17) == image.get_pixel(0, 17), "the last row of the feet is where it was")
	_check(out.get_pixel(0, 18).a == 0.0 and out.get_pixel(0, 0).a == 0.0, "nothing is drawn above the head or under the feet")
	var legs := {}
	for y in range(12, 18):
		legs[out.get_pixel(0, y).r] = true
	_check(legs.size() >= 3, "the legs are stretched to fill the gap (%d different rows)" % legs.size())
	_check(IdleBreath.breathe_image(image, 0, 0.3) == image, "no rise means the same picture")


func _test_sprite() -> void:
	var actor := Node2D.new()
	root.add_child(actor)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = _frames()
	sprite.scale = Vector2(0.5, 0.5)
	sprite.position = Vector2(0, -6)
	actor.add_child(sprite)
	sprite.play(&"idle")
	actor.add_child(IdleBreath.new())
	await process_frame
	await process_frame
	var raised := 0
	var rested := 0
	var untouched := true
	var heights := {}
	for i in 160:
		await create_timer(0.025).timeout
		var overlay: Sprite2D = actor.get_node_or_null("Breath")
		untouched = untouched and sprite.scale == Vector2(0.5, 0.5) and sprite.position == Vector2(0, -6)
		if overlay != null and overlay.visible:
			raised += 1
			heights[overlay.texture.get_image().get_used_rect().position.y] = true
			untouched = untouched and sprite.self_modulate.a == 0.0 and overlay.scale == sprite.scale and overlay.position == sprite.position
		else:
			rested += 1
			untouched = untouched and sprite.self_modulate.a == 1.0
	_check(raised > 10 and rested > 10, "it rises and settles (%d frames raised, %d at rest)" % [raised, rested])
	_check(heights.size() >= 1 and heights.size() <= int(Tuning.BREATH_PIXELS), "by whole pixels (%d different heights)" % heights.size())
	_check(untouched, "the sprite's own scale and position never change, and it is see-through only while the copy is drawn")

	sprite.play(&"walk")
	await process_frame
	await process_frame
	await create_timer(0.6).timeout
	var overlay_now: Sprite2D = actor.get_node_or_null("Breath")
	_check(overlay_now == null or not overlay_now.visible, "it does not breathe while walking")
	_check(sprite.self_modulate.a == 1.0, "and the plain sprite is back")
	_check(Tuning.BREATH_ENABLED, "breathing is on in Tuning")
	actor.free()


func _frames() -> SpriteFrames:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(20, 8, 24, 55), Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var frames := SpriteFrames.new()
	for animation in [&"idle", &"walk"]:
		if not frames.has_animation(animation):
			frames.add_animation(animation)
		frames.add_frame(animation, texture)
		frames.set_animation_loop(animation, true)
	return frames


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
