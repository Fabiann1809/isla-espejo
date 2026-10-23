extends SceneTree
## Boss animation: each step of an attack shows its own pose for as long as the step lasts
## (windup = first frame of attack, strike = slam or last frame of attack, recover = idle), instead
## of one short swing stretched with the generic enemy timings. Run:
## godot --headless --path . --script res://tests/test_boss_animation.gd

const ARENA := Vector2(300, 180)

var _ok := true
var _room: Node
var _player: Node2D


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	root.get_node("PlayerProfile").persistence_enabled = false
	root.get_node("GameState").reset()
	_room = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(_room)
	await _frames(4)
	for other in get_nodes_in_group("enemies"):
		other.queue_free()
	_player = _room.get_node("Player")
	_player.health.max_health = 999
	_player.health.heal(999)

	await _check_attack("forest_guardian", "ROOTS", Vector2(100, 0), &"attack")
	await _check_attack("forest_guardian", "SLAM", Vector2(30, 0), &"slam")
	await _check_attack("ancient_guardian", "SLAM", Vector2(30, 0), &"attack")

	root.get_node("GameState").reset()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check_attack(scene: String, pattern_name: String, offset: Vector2, strike_anim: StringName) -> void:
	for child in _room.get_children():
		if child is SkillZone:
			child.free()
	var boss: Node2D = load("res://scenes/enemies/%s.tscn" % scene).instantiate()
	boss.position = ARENA
	_room.add_child(boss)
	_player.global_position = ARENA + offset
	var wanted: int = boss.Pattern[pattern_name]
	await physics_frame
	# Not left to chance or to detection timing: last attack "slam" (so out of slam range it uses
	# roots), engaged at once, and the player kept at the chosen distance until it attacks.
	boss._last_pattern = boss.Pattern.SLAM
	boss._acquire_target(_player)
	for i in 400:
		if boss.state == boss.State.ATTACK and boss.pattern == wanted:
			break
		boss._last_pattern = boss.Pattern.SLAM
		if boss.state != boss.State.ATTACK:
			_player.global_position = boss.global_position + offset
		await physics_frame
	var sprite: AnimatedSprite2D = boss.get_node("Sprite")
	var label := "%s %s" % [scene, pattern_name]
	_check(boss.pattern == wanted, "%s: the boss starts that attack" % label)

	var windup_ok := true
	var ticks := 0
	while boss.step == boss.Step.WINDUP:
		windup_ok = windup_ok and sprite.animation == &"attack" and sprite.frame == 0
		ticks += 1
		await physics_frame
	_check(windup_ok and ticks > 20, "%s: the whole windup (%d ticks) holds the warning pose" % [label, ticks])

	var strike_ok := true
	var strike_frame := 0 if strike_anim == &"slam" else sprite.sprite_frames.get_frame_count(&"attack") - 1
	while boss.step == boss.Step.STRIKE:
		strike_ok = strike_ok and sprite.animation == strike_anim and sprite.frame == strike_frame
		await physics_frame
	_check(strike_ok, "%s: the strike shows %s (frame %d)" % [label, strike_anim, strike_frame])

	var recover_ok := true
	while boss.state == boss.State.ATTACK:
		recover_ok = recover_ok and sprite.animation == &"idle" and sprite.is_playing()
		await physics_frame
	_check(recover_ok, "%s: the recovery goes back to idle" % label)
	boss.free()
	await _frames(2)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
