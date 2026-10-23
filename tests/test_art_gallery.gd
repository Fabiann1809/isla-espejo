extends SceneTree
## Art gallery test: the debug scene loads every character with real SpriteFrames and lets you step
## through their animations. Run: godot --headless --path . --script res://tests/test_art_gallery.gd

const CHARACTERS := 11

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var gallery = load("res://scenes/levels/art_gallery.tscn").instantiate()
	root.add_child(gallery)
	await process_frame

	_check(gallery.sprites.size() == CHARACTERS, "the gallery shows %d characters" % gallery.sprites.size())
	var all_ok := true
	for i in gallery.sprites.size():
		var sprite = gallery.sprites[i]
		var good: bool = sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"idle") and sprite.is_playing()
		if not good:
			print("  missing art: ", gallery.ENTRIES[i].label)
		all_ok = all_ok and good
	_check(all_ok, "every character has its SpriteFrames and plays idle")

	gallery.select(4)
	gallery.step_animation(1)
	_check(gallery.current_animation() == &"walk" and gallery.sprites[4].animation == &"walk", "stepping plays the next animation of the selected one")
	gallery.step_animation(-1)
	_check(gallery.current_animation() == &"idle", "stepping back returns to idle")
	gallery.select(99)
	_check(gallery.selected == CHARACTERS - 1, "selection stays inside the row")

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
