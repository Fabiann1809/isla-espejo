extends SceneTree
## Nico's three drawn views (side, front, back): which one is picked for each direction, the flip
## (side only), the fallback to the side art and the hysteresis on diagonals.
## Run: godot --headless --path . --script res://tests/test_player_views.gd

const ARENA := Vector2(300, 180)

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_pure_logic()
	await _real_player()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _pure_logic() -> void:
	var script: GDScript = load("res://scripts/player/facing_view.gd")
	var picker = script.new()
	var side: int = script.View.SIDE
	var down: int = script.View.DOWN
	var up: int = script.View.UP
	_check(picker.update(Vector2.RIGHT, 0.2) == side, "moving right shows the side view")
	_check(picker.update(Vector2(1, 1).normalized(), 0.2) == side, "a 45 degree diagonal keeps the side view")
	_check(picker.update(Vector2(1, 1.2).normalized(), 0.2) == side, "a slightly vertical diagonal stays on the side (needs 1.3x)")
	_check(picker.update(Vector2(1, 1.4).normalized(), 0.2) == down, "a clearly vertical diagonal switches to the front view")
	_check(picker.update(Vector2(1.2, 1).normalized(), 0.2) == down, "back near 45 degrees it stays in front (hysteresis)")
	_check(picker.update(Vector2.UP, 0.2) == up, "moving up shows the back view")
	_check(picker.update(Vector2.LEFT, 0.01) == up, "a view is held for a minimum time after a change")
	_check(picker.update(Vector2.LEFT, 0.2) == side, "after the hold the side view comes back")
	_check(picker.update(Vector2.ZERO, 0.2) == side, "standing still keeps the last view")
	picker.update(Vector2.UP, 0.2)
	picker.update(Vector2.ZERO, 0.2)
	_check(picker.update(Vector2(1, -1).normalized(), 0.01) == side, "a diagonal started from standing still goes to the side")

	# A wobbling diagonal walk (+-6 degrees; the 1.3x thresholds sit at about +-7.4 degrees): the naive rule (bigger axis wins) flips views often, the picker not.
	var naive_changes := 0
	var picker_changes := 0
	var last_naive := -1
	var walker = script.new()
	var last_view: int = walker.view
	for i in 240:
		var angle := deg_to_rad(45.0 + 6.0 * sin(i * 0.7))
		var dir := Vector2(cos(angle), sin(angle))
		var naive: int = side if absf(dir.x) >= absf(dir.y) else down
		if naive != last_naive:
			naive_changes += 1
			last_naive = naive
		var v: int = walker.update(dir, 1.0 / 60.0)
		if v != last_view:
			picker_changes += 1
			last_view = v
	print("  diagonal walk, 240 ticks: naive view changes %d, with hysteresis %d" % [naive_changes, picker_changes])
	_check(picker_changes <= 1 and naive_changes > 10, "a wobbling diagonal does not flicker between views (%d vs %d)" % [picker_changes, naive_changes])

	var frames := SpriteFrames.new()
	frames.add_animation(&"walk_side")
	_check(script.animation_for(&"walk", up, frames) == &"walk_side", "a view without art falls back to the side animation")
	_check(script.animation_for(&"walk", side, frames) == &"walk_side", "the side view uses <base>_side")
	frames.add_animation(&"walk_up")
	_check(script.animation_for(&"walk", up, frames) == &"walk_up", "a view with art uses its own animation (by name)")


func _real_player() -> void:
	var room = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(room)
	await _frames(3)
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	var player = room.get_node("Player")
	player.global_position = ARENA
	var sprite: AnimatedSprite2D = player.get_node("Sprite")
	var has_idle_up: bool = sprite.sprite_frames.has_animation(&"idle_up")

	var cases := [
		["move_right", [], &"walk_side", false],
		["move_left", [], &"walk_side", true],
		["move_down", [], &"walk_down", false],
		["move_up", [], &"walk_up", false],
		["move_right", ["move_down"], &"walk_side", false],
		["move_left", ["move_up"], &"walk_side", true],
	]
	for case in cases:
		_press([case[0]] + case[1])
		await _frames(15)
		_check(sprite.animation == case[2] and sprite.flip_h == case[3],
				"%s %s shows %s, flip %s (got %s, %s)" % [case[0], case[1], case[2], case[3], sprite.animation, sprite.flip_h])
		_release()
		await _frames(2)

	_press(["move_up"])
	await _frames(15)
	_release()
	await _frames(5)
	var expected_rest: StringName = &"idle_up" if has_idle_up else &"idle_side"
	_check(sprite.animation == expected_rest and not sprite.flip_h,
			"stopping after walking up rests in that view (%s, falls back to the side if there is no idle_up)" % sprite.animation)
	_press(["move_down"])
	await _frames(15)
	_release()
	await _frames(5)
	_check(sprite.animation == &"idle_down", "stopping after walking down rests facing the front")

	# Diagonal path with a wobble, counted on the real sprite (short enough not to reach a wall).
	player.global_position = ARENA
	await _frames(2)
	var changes := 0
	var last := sprite.animation
	for i in 60:
		_release()
		if i % 9 < 5:
			_press(["move_right", "move_down"])
		else:
			_press(["move_right"])
		await physics_frame
		if sprite.animation != last:
			changes += 1
			last = sprite.animation
	_release()
	print("  real player, wobbling diagonal for 60 ticks: %d animation changes" % changes)
	_check(changes <= 2, "a wobbling diagonal path barely changes the animation (%d changes)" % changes)


func _press(actions: Array) -> void:
	for action in actions:
		Input.action_press(action)


func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
