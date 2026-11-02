extends SceneTree
## Soot manta test, with real physics: it flies over a pond that stops a walking enemy, marks Nico's
## spot, swoops through it hurting him (dropping low over the ground) and climbs back to hover.
## Run: godot --headless --path . --script res://tests/test_manta_hollin.gd

const WATER_LAYER := 7
## The pond of the test: 3x3 tiles with its corner here.
const POND_AT := Vector2(192, 96)
const POND_TILES := Vector2i(3, 3)
const TILE := 16.0

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var room: Node2D = load("res://scenes/levels/test_room.tscn").instantiate()
	for node_name in ["Trap1", "Trap2", "Grunt1", "Grunt2", "Dummy1", "Dummy2", "Dummy3"]:
		room.get_node(node_name).free()
	var pond = load("res://scripts/world/room_prop.gd").new()
	pond.kind = 5  # RoomProp.Kind.POND
	pond.size_tiles = POND_TILES
	pond.position = POND_AT
	room.add_child(pond)
	root.add_child(room)
	await _frames(3)
	var pond_rect := Rect2(POND_AT, Vector2(POND_TILES) * TILE)
	var player: Node2D = room.get_node("Player")
	player.health.set_max_health(50)
	player.global_position = Vector2(400, -200)

	var manta = load("res://scenes/enemies/manta_hollin.tscn").instantiate()
	manta.data = manta.data.duplicate()
	manta.data.patrol_radius = 0.0
	room.add_child(manta)
	manta.global_position = Vector2(170, 120)
	var walker = load("res://scenes/enemies/grunt.tscn").instantiate()
	walker.data = walker.data.duplicate()
	walker.data.patrol_radius = 0.0
	room.add_child(walker)
	walker.global_position = Vector2(170, 125)
	await _frames(2)

	# --- The pond stops a walking enemy but not the manta
	var across := Vector2(90, 0)
	_check(walker.test_move(walker.global_transform, across), "a pond blocks a walking enemy")
	_check(not manta.test_move(manta.global_transform, across), "the manta's body is not blocked by the pond")
	_check(not manta.get_collision_mask_value(WATER_LAYER), "the manta ignores the water layer")
	walker.queue_free()
	var sprite: Node2D = manta.get_node("Sprite")
	var shadow: Node2D = manta.get_node("Shadow")
	_check(sprite.position.y < shadow.position.y - manta.data.fly_height,
			"its art flies above its shadow (art %.0f, shadow %.0f)" % [sprite.position.y, shadow.position.y])

	# --- Nico on the far side of the pond: it flies over the water toward him
	player.global_position = Vector2(300, 120)
	var flew_over := false
	for i in 240:
		await physics_frame
		if pond_rect.has_point(manta.global_position):
			flew_over = true
		if manta.state == manta.State.ATTACK:
			break
	_check(flew_over, "it glides over the pond")
	_check(manta.state == manta.State.ATTACK and manta._attack_phase == manta.AttackPhase.WINDUP,
			"it marks a dive")
	if manta.state != manta.State.ATTACK:
		_finish()
		return

	# --- The mark is where Nico stands; the swoop goes through it and hurts him
	var marked: Vector2 = manta._dive_target
	_check(marked.distance_to(player.global_position) < 2.0, "the dive is aimed at Nico's spot")
	_check(_warning_at(room, marked), "a warning circle marks that spot")
	var hp: int = player.health.current
	var closest := INF
	var lowest: float = manta.height
	for i in 120:
		await physics_frame
		if manta.state == manta.State.ATTACK and manta._attack_phase == manta.AttackPhase.STRIKE:
			closest = minf(closest, manta.global_position.distance_to(marked))
			lowest = minf(lowest, manta.height)
		if manta.state == manta.State.ATTACK and manta._attack_phase == manta.AttackPhase.RECOVER:
			break
	_check(closest < 6.0, "the swoop passes through the marked spot (%.1f px)" % closest)
	_check(lowest <= manta.data.dive_height + 1.0, "it drops close to the ground (%.1f px)" % lowest)
	_check(player.health.current < hp, "the swoop hurts Nico there (%d -> %d)" % [hp, player.health.current])
	_check(manta.global_position.distance_to(marked) > manta.data.dive_overshoot * 0.5,
			"it keeps going past the spot")

	# --- It climbs back and hovers again
	for i in 120:
		await physics_frame
		if manta.state == manta.State.CHASE and is_equal_approx(manta.height, manta.data.fly_height):
			break
	_check(manta.state == manta.State.CHASE, "after the swoop it goes back to hovering")
	_check(is_equal_approx(manta.height, manta.data.fly_height), "it climbs back to its flying height")
	_check(manta._attack_cooldown_left > 0.0, "and must wait before the next dive")
	_finish()


func _warning_at(room: Node2D, spot: Vector2) -> bool:
	var zone_script: Script = load("res://scripts/skills/skill_zone.gd")
	for child in room.get_children():
		if child.get_script() == zone_script and child.global_position.distance_to(spot) < 1.0:
			return true
	return false


func _finish() -> void:
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
