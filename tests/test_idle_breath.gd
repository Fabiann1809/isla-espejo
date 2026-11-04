extends SceneTree
## Idle breathing: a standing character stretches a whole number of pixels with its feet fixed, and nothing
## else is touched while it moves or attacks.
## Run: godot --headless --path . --script res://tests/test_idle_breath.gd

var _ok := true


func _initialize() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var actor := Node2D.new()
	root.add_child(actor)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = _frames()
	sprite.scale = Vector2(0.5, 0.5)
	sprite.position = Vector2(0, -6)
	actor.add_child(sprite)
	sprite.play(&"idle")
	var breath := IdleBreath.new()
	actor.add_child(breath)
	await process_frame
	await process_frame

	var base_y := -6.0
	# The figure in the 64x64 cell: rows 8..62 opaque, so its feet are 31 px below the center of the cell.
	var feet := func() -> float: return sprite.position.y + 31.0 * sprite.scale.y
	var feet_rest: float = base_y + 31.0 * 0.5
	var scales := {}
	var feet_fixed := true
	var top := 0.0
	for i in 160:
		await create_timer(0.025).timeout
		scales[snappedf(sprite.scale.y, 0.0001)] = true
		top = maxf(top, sprite.scale.y)
		feet_fixed = feet_fixed and absf(feet.call() - feet_rest) < 0.001
	_check(scales.size() >= 2 and top > 0.5, "while idle the picture stretches (%d different heights, top %.3f)" % [scales.size(), top])
	_check(top <= 0.5 * (1.0 + Tuning.BREATH_PIXELS / (55.0 * 0.5)) + 0.001, "by no more than %.0f px" % Tuning.BREATH_PIXELS)
	_check(feet_fixed, "with its feet fixed to the ground")
	_check(is_equal_approx(sprite.scale.x, 0.5), "and never wider")

	sprite.play(&"walk")
	await process_frame
	await process_frame
	_check(is_equal_approx(sprite.scale.y, 0.5) and is_equal_approx(sprite.position.y, base_y), "walking puts it back as it was")
	await create_timer(0.6).timeout
	_check(is_equal_approx(sprite.scale.y, 0.5), "and it does not breathe while walking")
	_check(Tuning.BREATH_ENABLED, "breathing is on in Tuning")
	actor.free()
	quit(0 if _ok else 1)


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
