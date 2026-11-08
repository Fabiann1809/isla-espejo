extends SceneTree
## NPC gestures: the Mercader stands still on a one-frame "idle" (only breathing) and plays his
## "gesture" (showing the emerald) once now and then and when spoken to, never on a loop.
## Run: godot --headless --path . --script res://tests/test_npc_gesture.gd

var _ok := true


func _initialize() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_test_frames()
	await _test_npc()
	quit(0 if _ok else 1)


func _test_frames() -> void:
	var frames: SpriteFrames = load("res://data/npcs/merchant_frames.tres")
	_check(frames.get_frame_count(&"idle") == 1, "the merchant's idle is one still frame")
	_check(frames.has_animation(&"gesture") and frames.get_frame_count(&"gesture") > 1, "the merchant has a gesture")
	_check(not frames.get_animation_loop(&"gesture"), "the gesture plays once, not on a loop")


func _test_npc() -> void:
	var npc = load("res://scenes/npcs/merchant.tscn").instantiate()
	root.add_child(npc)
	await process_frame
	var sprite: AnimatedSprite2D = npc.get_node("Sprite")
	_check(sprite.animation == &"idle", "he starts standing still")
	npc.play_gesture()
	_check(sprite.animation == &"gesture", "a gesture can be played")
	var frames := 0
	while sprite.animation == &"gesture" and frames < 600:
		await process_frame
		frames += 1
	_check(sprite.animation == &"idle", "after the gesture he stands still again")
	_check(npc._gesture_left >= 5.9, "the next gesture waits several seconds (%.1f)" % npc._gesture_left)
	npc.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
