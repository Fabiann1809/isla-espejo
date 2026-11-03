extends SceneTree
## Manos del abismo test, with real physics: burrowed it shows nothing and cannot be hurt; it comes
## out on the edge of its room nearest Nico after a warning circle (special animation), its arm
## reaches toward him and the hand catches him: it hurts him and holds him in place, a dodge breaks
## free; out it can be hit; it winds back, rests at the edge and sinks again. A Nico who steps out of
## the line during the warning is missed, and a hit on the hand lets a caught Nico go.
## Run: godot --headless --path . --script res://tests/test_manos_abismo.gd

## A room-sized home (30x18 tiles) inside the test room's walls.
const HOME := Rect2(-140, -104, 480, 288)
## Nico near the bottom edge of the room (54 px from it).
const NEAR_EDGE := Vector2(100, 130)

var _ok := true
var _room: Node2D
var _player: Node2D
var _scene: PackedScene
var _zone_script: Script


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_room = load("res://scenes/levels/test_room.tscn").instantiate()
	for node_name in ["Trap1", "Trap2", "Grunt1", "Grunt2", "Dummy1", "Dummy2", "Dummy3"]:
		_room.get_node(node_name).free()
	root.add_child(_room)
	await _frames(3)
	_player = _room.get_node("Player")
	_player.health.set_max_health(50)
	_player.global_position = NEAR_EDGE
	_scene = load("res://scenes/enemies/manos_abismo.tscn")
	# Its warning is a SkillZone drawn with its own pixel art.
	_zone_script = load("res://scripts/enemies/manos_abismo_warning.gd")

	var hand = _spawn(HOME.get_center() + Vector2(-60, -40))
	var frames: SpriteFrames = hand.data.sprite_frames
	for anim: StringName in [&"idle", &"attack", &"special", &"hurt", &"death"]:
		_check(frames.has_animation(anim) and frames.get_frame_count(anim) > 0, "hand has %s" % anim)
	_check(hand.data is AbyssHandsData, "the hand uses an AbyssHandsData")
	_check(hand.health.max_health >= 4 and hand.health.max_health <= 8 and hand.data.attack_damage == 1,
			"hard-roguelike stats (%d hp)" % hand.health.max_health)
	await _frames(2)
	await _grab_cycle(hand)
	await _missed(hand)
	await _hit_lets_go(hand)
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _grab_cycle(hand) -> void:
	_check(hand.phase == hand.Phase.UNDER and not hand.get_node("Sprite").visible, "it starts under the ground, unseen")
	_check(not _hit(hand), "burrowed it cannot be hurt")
	var hp: int = _player.health.current
	await _until(func() -> bool: return hand.phase == hand.Phase.RISING, 300)
	_check(hand.phase == hand.Phase.RISING, "it comes out")
	var spot: Vector2 = hand.anchor()
	var edge: Rect2 = HOME.grow(-hand.data.edge_margin)
	_check(absf(spot.y - edge.end.y) < 0.5 and absf(spot.x - NEAR_EDGE.x) <= hand.data.edge_jitter + 0.5,
			"on the edge of its room nearest Nico (%s)" % spot)
	_check(_warning_at(spot), "a warning circle marks the spot")
	_check(hand.get_node("Sprite").animation == &"special", "rising plays the special animation")
	_check(not _hit(hand), "rising it cannot be hurt yet")
	_check(_player.health.current == hp, "the warning does not hurt")
	await _until(func() -> bool: return hand.phase == hand.Phase.HOLDING, 120)
	_check(hand.is_holding() and _player.is_pulled(), "the hand reaches him and grabs him")
	_check(hand.get_node("Arm").visible, "its arm stretches from the edge")
	await _frames(4)
	_check(_player.health.current < hp, "the grab hurts (%d -> %d)" % [hp, _player.health.current])
	var held_at: Vector2 = _player.global_position
	await _frames(10)
	_check(_player.global_position.distance_to(held_at) < 1.0, "held: he does not move")
	_player._start_dash()
	await _frames(3)
	_check(not _player.is_pulled(), "a dodge breaks free")
	await _until(func() -> bool: return hand.phase == hand.Phase.RESTING, 120)
	_check(hand.phase == hand.Phase.RESTING and hand.global_position.distance_to(spot) < 0.5,
			"its arm winds back to the edge")
	_check(_hit(hand), "out, the hand can be hit")
	await _until(func() -> bool: return hand.phase == hand.Phase.UNDER, 240)
	_check(hand.phase == hand.Phase.UNDER and not hand.get_node("Sprite").visible, "and it sinks again")
	_check(not _hit(hand), "under again, it cannot be hurt")


func _missed(hand) -> void:
	_player.global_position = NEAR_EDGE
	await _until(func() -> bool: return hand.phase == hand.Phase.RISING, 300)
	var hp: int = _player.health.current
	# Nico steps out of the line and beyond its reach.
	_player.global_position = Vector2(hand.anchor().x + 200, HOME.position.y + 60)
	var caught := false
	for i in 240:
		await physics_frame
		caught = caught or _player.is_pulled()
		if hand.phase == hand.Phase.RESTING:
			break
	_check(not caught and _player.health.current == hp, "stepping out of the line during the warning, it misses")
	await _until(func() -> bool: return hand.phase == hand.Phase.UNDER, 240)


func _hit_lets_go(hand) -> void:
	await create_timer(1.0).timeout
	_player.global_position = NEAR_EDGE
	await _until(func() -> bool: return hand.phase == hand.Phase.HOLDING, 400)
	_check(hand.is_holding(), "it grabs him again")
	hand.get_node("Hurtbox").receive_hit(1, _player.global_position)
	await _frames(2)
	_check(not _player.is_pulled() and not hand.is_holding(), "a hit on the hand lets him go")
	hand.health.take_damage(100, _player.global_position)
	await _frames(2)
	_check(hand.is_dead() and not hand.get_node("Arm").visible, "killed, the arm is gone")
	await create_timer(1.5).timeout
	_check(not is_instance_valid(hand), "and the hand goes away")


func _hit(hand) -> bool:
	var hp: int = hand.health.current
	var accepted: bool = hand.get_node("Hurtbox").receive_hit(1, _player.global_position)
	return accepted and hand.health.current < hp


func _until(condition: Callable, max_frames: int) -> void:
	for i in max_frames:
		if condition.call():
			return
		await physics_frame


func _warning_at(spot: Vector2) -> bool:
	for child in _room.get_children():
		if child.get_script() == _zone_script and child.global_position.distance_to(spot) < 1.0:
			return true
	return false


func _spawn(at: Vector2) -> Node:
	var hand = _scene.instantiate()
	hand.data = hand.data.duplicate()
	hand.position = at
	hand.home_area = HOME
	_room.add_child(hand)
	return hand


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
