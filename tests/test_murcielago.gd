extends SceneTree
## Murciélago test: it circles Nico (weaving, changing direction) instead of flying straight at him;
## its dive is warned (a lane on the ground, no damage yet), then goes straight through where Nico
## stood and past him, hurts him and climbs away; bats of one room dive one after another; the
## director's speed and vision multipliers still apply, and it keeps to its room.
## Run: godot --headless --path . --script res://tests/test_murcielago.gd

const ARENA := Vector2(300, 180)
const LANE_SCRIPT := "res://scripts/enemies/attack_lane.gd"

var _ok := true
var _room: Node
var _player: Node2D


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_room = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(_room)
	await _frames(3)
	_player = _room.get_node("Player")
	_player.global_position = ARENA

	await _check_data()
	await _check_circling()
	await _check_dive()
	await _check_group()
	await _check_director()
	await _check_territory()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check_data() -> void:
	var bat = _spawn(ARENA + Vector2(400, 0))
	_check(bat.data.get("dive_speed") != null and bat.data.id == &"murcielago", "the bat uses a DiverData")
	_check(bat.data.max_health <= 2 and bat.data.chase_speed >= 90.0, "it is fast and fragile (%d hp, %.0f px/s)" % [bat.data.max_health, bat.data.chase_speed])
	_check(bat.data.attack_windup >= 0.3, "its dive is warned for %.2f s" % bat.data.attack_windup)
	var bank = root.get_node("Sound").bank
	_check(bank.has_cue(&"attack_murcielago") and bank.has_cue(&"death_murcielago"), "the bat has its dive and death sounds")
	bat.queue_free()
	await _frames(2)


## Without dives, it circles around Nico instead of coming straight at him.
func _check_circling() -> void:
	_player.global_position = ARENA
	var bat = _spawn(ARENA + Vector2(110, 0))
	bat.data.dive_trigger_range = 0.0
	var swept := 0.0
	var last_angle: float = (bat.global_position - ARENA).angle()
	var turns := 0
	var last_sign := 0.0
	var near := 0
	var samples := 0
	var closest := INF
	for i in 300:
		await physics_frame
		_player.global_position = ARENA
		var offset: Vector2 = bat.global_position - ARENA
		var step := wrapf(offset.angle() - last_angle, -PI, PI)
		last_angle = offset.angle()
		if i < 60:
			continue
		swept += absf(step)
		if absf(step) > 0.002:
			if last_sign != 0.0 and signf(step) != last_sign:
				turns += 1
			last_sign = signf(step)
		samples += 1
		closest = minf(closest, offset.length())
		if offset.length() >= 20.0 and offset.length() <= 80.0:
			near += 1
	_check(bat.target == _player, "it hunts Nico")
	_check(swept > PI, "it flies around Nico (%.1f rad swept in 4 s)" % swept)
	_check(turns >= 1, "it changes direction now and then (%d times)" % turns)
	_check(near > samples * 0.8 and closest > 15.0, "it keeps circling near him without touching him (closest %.0f px)" % closest)
	bat.queue_free()
	await _frames(2)


## The dive: warning first (lane, no damage), then a straight fast pass through his spot, then away.
func _check_dive() -> void:
	_player.global_position = ARENA
	var health_before: int = _player.health.current
	var sound = root.get_node("Sound")
	sound.played.clear()
	var bat = _spawn(ARENA + Vector2(70, 10))
	var warn_frames := 0
	var lane_seen := false
	var damage_during_warning := false
	var aim := Vector2.ZERO
	var start := Vector2.ZERO
	while not bat.is_diving():
		await physics_frame
		_player.global_position = ARENA
	start = bat.global_position
	aim = _player.global_position
	while bat.state == bat.State.ATTACK and bat._attack_phase == bat.AttackPhase.WINDUP:
		warn_frames += 1
		lane_seen = lane_seen or _lanes().size() == 1
		damage_during_warning = damage_during_warning or _player.health.current < health_before
		await physics_frame
	_check(lane_seen, "a lane on the ground warns of the dive")
	_check(warn_frames >= int(bat.data.attack_windup * 60) - 1 and not damage_during_warning,
			"the warning lasts %d ticks and does no damage" % warn_frames)
	_check(_lanes().is_empty(), "the lane goes away when it dives")
	var top_speed := 0.0
	var closest_to_aim := INF
	var path_offset := 0.0
	var dir: Vector2 = (aim - start).normalized()
	while bat.state == bat.State.ATTACK and bat._attack_phase == bat.AttackPhase.STRIKE:
		top_speed = maxf(top_speed, bat.velocity.length())
		closest_to_aim = minf(closest_to_aim, bat.global_position.distance_to(aim))
		var rel: Vector2 = bat.global_position - start
		path_offset = maxf(path_offset, absf(rel.cross(dir)))
		await physics_frame
	var end_pos: Vector2 = bat.global_position
	_check(absf(top_speed - bat.data.dive_speed) < 1.0, "it dives at its dive speed (%.0f px/s)" % top_speed)
	_check(closest_to_aim < 6.0 and path_offset < 8.0, "the dive goes straight through Nico's spot (closest %.1f, off line %.1f)" % [closest_to_aim, path_offset])
	_check((end_pos - aim).dot(dir) > 10.0, "and on past him")
	_check(_player.health.current < health_before, "the dive hurts Nico (%d -> %d)" % [health_before, _player.health.current])
	_check(sound.played.has(&"attack_murcielago"), "the dive is heard")
	var after_dive: float = bat.global_position.distance_to(_player.global_position)
	await _frames(25)
	_check(bat.state == bat.State.ATTACK and bat._attack_phase == bat.AttackPhase.RECOVER, "it recovers after the dive")
	_check(bat.global_position.distance_to(_player.global_position) > after_dive, "it climbs away after the dive")
	bat.queue_free()
	_heal()
	await _frames(60)


## Three bats in one room: their dives come one after another, never together.
func _check_group() -> void:
	_player.global_position = ARENA
	var bats: Array = []
	for angle in [0.0, 2.1, 4.2]:
		bats.append(_spawn(ARENA + Vector2.from_angle(angle) * 70.0))
	var starts: Array[int] = []
	var was := {}
	for i in 420:
		await physics_frame
		_player.global_position = ARENA
		_heal()
		for bat in bats:
			var diving: bool = bat.is_diving()
			if diving and not was.get(bat, false):
				starts.append(i)
			was[bat] = diving
	var gap_ticks := int(bats[0].data.group_gap * 60.0)
	var min_gap := 9999
	for k in range(1, starts.size()):
		min_gap = mini(min_gap, starts[k] - starts[k - 1])
	_check(starts.size() >= 4, "the group keeps diving (%d dives in 7 s)" % starts.size())
	_check(min_gap >= gap_ticks - 1, "their dives take turns, at least %d ticks apart (closest %d)" % [gap_ticks, min_gap])
	for bat in bats:
		bat.queue_free()
	await _frames(30)


func _check_director() -> void:
	_player.global_position = ARENA
	var fast = _spawn(ARENA + Vector2(70, 0))
	fast.speed_multiplier = 2.0
	var top := 0.0
	for i in 120:
		await physics_frame
		_player.global_position = ARENA
		_heal()
		if fast.is_diving() and fast._attack_phase == fast.AttackPhase.STRIKE:
			top = maxf(top, fast.velocity.length())
	_check(absf(top - fast.data.dive_speed * 2.0) < 1.0, "the director's speed x2 doubles the dive (%.0f px/s)" % top)
	fast.queue_free()
	await _frames(2)
	var blind = _spawn(ARENA + Vector2(70, 0))
	blind.vision_multiplier = 0.1
	var dived := false
	for i in 120:
		await physics_frame
		dived = dived or blind.is_diving()
	_check(blind.target == null and not dived, "with little vision (x0.1) it never notices Nico nor dives")
	blind.queue_free()
	await _frames(30)


func _check_territory() -> void:
	var tuning: Script = load("res://scripts/core/tuning.gd")
	# Nico outside its room: it does not hunt him.
	_player.global_position = ARENA
	var homebody = _spawn(ARENA + Vector2(90, 0))
	homebody.home_area = Rect2(ARENA + Vector2(70, -60), Vector2(160, 120))
	var hunted := false
	for i in 120:
		await physics_frame
		hunted = hunted or homebody.target != null or homebody.is_diving()
	_check(not hunted, "it ignores Nico while he is outside its room")
	homebody.queue_free()
	await _frames(2)
	# Nico near its edge: the dive stops before it leaves the room.
	var edge = _spawn(ARENA + Vector2(70, 0))
	edge.home_area = Rect2(ARENA + Vector2(-10, -80), Vector2(200, 160))
	var inside: Rect2 = edge.home_area.grow(-tuning.DASH_ROOM_MARGIN + 2.0)
	var dove := false
	var stayed := true
	for i in 150:
		await physics_frame
		_player.global_position = ARENA
		_heal()
		if edge.is_diving():
			dove = true
			stayed = stayed and inside.has_point(edge.global_position)
	_check(dove and stayed, "a dive never carries it out of its room (dove: %s)" % dove)
	edge.queue_free()
	await _frames(2)


func _spawn(at: Vector2) -> Node:
	var bat = load("res://scenes/enemies/murcielago.tscn").instantiate()
	bat.data = bat.data.duplicate()
	bat.data.patrol_radius = 0.0
	_room.add_child(bat)
	bat.global_position = at
	return bat


func _lanes() -> Array:
	return _room.get_children().filter(func(n: Node) -> bool:
		return n.get_script() != null and n.get_script().resource_path == LANE_SCRIPT and not n.is_queued_for_deletion())


func _heal() -> void:
	_player.health.heal(5)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
