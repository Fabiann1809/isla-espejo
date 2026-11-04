extends SceneTree
## Fog beast test: its art and data load; it hunts Nico and charges him: it stands still while a lane
## on the ground warns of the charge (following Nico, then locking), rushes along it at its charge
## speed, past him, and hurts him; crashing into a wall stuns it; a pack joins the hunt together,
## spreads around Nico and charges from several sides one after another; the director's speed and
## vision multipliers still apply, and it keeps to its room.
## Run: godot --headless --path . --script res://tests/test_fog_beast.gd

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

	await _check_hunt()
	await _check_charge()
	await _check_wall()
	await _check_pack()
	await _check_director()
	await _check_territory()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check_hunt() -> void:
	var beast = _spawn(ARENA + Vector2(140, 0))
	_check(beast.data.get("charge_speed") != null, "the fog beast uses a ChargerData")
	var bank = root.get_node("Sound").bank
	_check(bank.has_cue(&"attack_bestia_de_la_niebla") and bank.has_cue(&"death_bestia_de_la_niebla"), "the beast has its charge and death sounds")
	await _frames(30)
	_check(beast.target == _player, "fog beast detects the player")
	_check(beast.state in [beast.State.CHASE, beast.State.ATTACK], "fog beast chases the player")
	var start_distance: float = beast.global_position.distance_to(_player.global_position)
	var health_before: int = _player.health.current
	await _frames(140)
	_check(beast.global_position.distance_to(_player.global_position) < start_distance, "it closes the distance")
	_check(_player.health.current < health_before, "its charge damages the player (%d -> %d)" % [health_before, _player.health.current])
	_check(beast.data.sprite_frames.has_animation(&"run"), "wolf has run animation")
	_check(beast.data.sprite_frames.has_animation(&"attack"), "wolf has attack animation")
	_check(beast.data.sprite_frames.get_frame_count(&"walk") == 8, "wolf walk has 8 complete frames")
	_check(beast.data.sprite_frames.get_frame_count(&"run") == 6, "wolf run has 6 complete frames")
	_check(beast.data.sprite_frames.get_frame_count(&"attack") == 8, "wolf attack has 8 complete frames")
	beast.queue_free()
	_heal()
	await _frames(60)


## Warning (still, lane that follows then locks), then a straight rush past Nico.
func _check_charge() -> void:
	_player.global_position = ARENA
	var health_before: int = _player.health.current
	var sound = root.get_node("Sound")
	sound.played.clear()
	var beast = _spawn(ARENA + Vector2(90, 0))
	while not beast.is_charging():
		await physics_frame
		_player.global_position = ARENA
	var start: Vector2 = beast.global_position
	var still := true
	var lane_seen := false
	var warn_frames := 0
	var hurt_in_warning := false
	var followed := false
	var aim_at_lock := Vector2.ZERO
	var moved_after_lock := false
	var lock_ticks := int(beast.data.aim_lock_time * 60.0)
	while beast.state == beast.State.ATTACK and beast._attack_phase == beast.AttackPhase.WINDUP:
		warn_frames += 1
		# Nico steps sideways during the warning: early on the lane follows him, at the end it does not.
		_player.global_position = ARENA + Vector2(0, 12 if warn_frames > 10 else 0)
		lane_seen = lane_seen or _lanes().size() == 1
		still = still and beast.global_position.distance_to(start) < 0.5
		hurt_in_warning = hurt_in_warning or _player.health.current < health_before
		if warn_frames == 16:
			followed = absf(beast._charge_dir.angle_to((ARENA + Vector2(0, 12) - start).normalized())) < 0.02
		if beast._attack_time_left <= beast.data.aim_lock_time and aim_at_lock == Vector2.ZERO:
			aim_at_lock = beast._charge_dir
			_player.global_position = ARENA + Vector2(0, -20)
		elif aim_at_lock != Vector2.ZERO and beast._charge_dir != aim_at_lock:
			moved_after_lock = true
		await physics_frame
	_check(lane_seen and still, "it stands still while a lane on the ground warns of the charge")
	_check(warn_frames >= int(beast.data.attack_windup * 60) - 1 and not hurt_in_warning, "the warning lasts %d ticks and does no harm" % warn_frames)
	_check(followed, "the lane follows Nico during the warning")
	_check(aim_at_lock != Vector2.ZERO and not moved_after_lock, "and locks %d ticks before the charge" % lock_ticks)
	_check(_lanes().is_empty(), "the lane goes away when it charges")
	_player.global_position = ARENA + Vector2(0, 12)
	var top := 0.0
	var dir: Vector2 = beast._charge_dir
	while beast.state == beast.State.ATTACK and beast._attack_phase == beast.AttackPhase.STRIKE:
		top = maxf(top, beast.velocity.length())
		await physics_frame
	var travelled: float = (beast.global_position - start).dot(dir)
	var aimed: float = start.distance_to(ARENA + Vector2(0, 12))
	var full: float = minf(aimed + beast.data.charge_overshoot, beast.data.charge_speed * beast.data.attack_time)
	_check(absf(top - beast.data.charge_speed) < 1.0, "it charges at its charge speed (%.0f px/s)" % top)
	_check(absf(travelled - full) < 6.0 and travelled > aimed + 20.0, "the charge goes on past Nico (%.0f px, he stood %.0f px away)" % [travelled, aimed])
	_check(_player.health.current < health_before, "the charge hurts Nico (%d -> %d)" % [health_before, _player.health.current])
	_check(sound.played.has(&"attack_bestia_de_la_niebla"), "the charge is heard")
	beast.queue_free()
	_heal()
	await _frames(60)


## A charge into a wall stops there and leaves it stunned for longer.
func _check_wall() -> void:
	_player.global_position = ARENA
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 120)
	shape.shape = rect
	wall.add_child(shape)
	_room.add_child(wall)
	wall.global_position = ARENA + Vector2(30, 0)
	var beast = _spawn(ARENA + Vector2(-60, 0))
	var recover := -1.0
	for i in 200:
		await physics_frame
		_player.global_position = ARENA
		_heal()
		if beast.state == beast.State.ATTACK and beast._attack_phase == beast.AttackPhase.RECOVER:
			recover = beast._attack_time_left
			break
	var normal: float = beast.data.attack_cooldown * 0.5
	_check(recover >= normal + beast.data.wall_stun - 0.05, "crashing into a wall stuns it (%.2f s rest instead of %.2f)" % [recover, normal])
	_check(beast.global_position.x < wall.global_position.x, "and the wall stops it")
	beast.queue_free()
	wall.queue_free()
	await _frames(60)


## Only one of three sees Nico: the others join it, spread out and charge from other sides in turn.
func _check_pack() -> void:
	_player.global_position = ARENA
	var leader = _spawn(ARENA + Vector2(100, 0))
	var mates := [_spawn(ARENA + Vector2(170, 60)), _spawn(ARENA + Vector2(170, -60))]
	await _frames(12)
	_check(leader.target == _player and mates.all(func(m) -> bool: return m.target == _player),
			"when one beast notices Nico its pack joins the hunt")
	var pack: Array = [leader] + mates
	var starts: Array[int] = []
	var dirs: Array[Vector2] = []
	var was := {}
	for i in 360:
		await physics_frame
		_player.global_position = ARENA
		_heal()
		for beast in pack:
			var charging: bool = beast.is_charging()
			if charging and not was.get(beast, false):
				starts.append(i)
				dirs.append((beast.global_position - ARENA).normalized())
			was[beast] = charging
	var min_gap := 9999
	for k in range(1, starts.size()):
		min_gap = mini(min_gap, starts[k] - starts[k - 1])
	var widest := 0.0
	for a in dirs.size():
		for b in range(a + 1, dirs.size()):
			widest = maxf(widest, absf(dirs[a].angle_to(dirs[b])))
	_check(starts.size() >= 3, "the pack charges (%d charges in 6 s)" % starts.size())
	_check(min_gap >= int(leader.data.pack_gap * 60.0) - 1, "the charges take turns (closest %d ticks apart)" % min_gap)
	_check(widest >= deg_to_rad(60.0), "they come from different sides (widest %.0f degrees)" % rad_to_deg(widest))
	for beast in pack:
		beast.queue_free()
	await _frames(60)


func _check_director() -> void:
	_player.global_position = ARENA
	var fast = _spawn(ARENA + Vector2(90, 0))
	fast.speed_multiplier = 2.0
	var top := 0.0
	var start := Vector2.ZERO
	var travelled := 0.0
	for i in 150:
		await physics_frame
		_player.global_position = ARENA
		_heal()
		if fast.state == fast.State.ATTACK and fast._attack_phase == fast.AttackPhase.WINDUP:
			start = fast.global_position
		elif fast.state == fast.State.ATTACK and fast._attack_phase == fast.AttackPhase.STRIKE:
			top = maxf(top, fast.velocity.length())
			travelled = fast.global_position.distance_to(start)
	_check(absf(top - fast.data.charge_speed * 2.0) < 1.0, "the director's speed x2 doubles the charge (%.0f px/s)" % top)
	var expected: float = minf(start.distance_to(ARENA) + fast.data.charge_overshoot, fast.data.charge_speed * fast.data.attack_time)
	_check(absf(travelled - expected) < 12.0, "over the same distance (%.0f px)" % travelled)
	fast.queue_free()
	await _frames(2)
	var blind = _spawn(ARENA + Vector2(90, 0))
	blind.vision_multiplier = 0.1
	var charged := false
	for i in 120:
		await physics_frame
		charged = charged or blind.is_charging()
	_check(blind.target == null and not charged, "with little vision (x0.1) it never notices Nico nor charges")
	blind.queue_free()
	await _frames(30)


func _check_territory() -> void:
	var tuning: Script = load("res://scripts/core/tuning.gd")
	_player.global_position = ARENA
	var homebody = _spawn(ARENA + Vector2(100, 0))
	homebody.home_area = Rect2(ARENA + Vector2(70, -60), Vector2(160, 120))
	var hunted := false
	for i in 120:
		await physics_frame
		hunted = hunted or homebody.target != null
	_check(not hunted, "it ignores Nico while he is outside its room")
	homebody.queue_free()
	await _frames(2)
	var edge = _spawn(ARENA + Vector2(80, 0))
	edge.home_area = Rect2(ARENA + Vector2(-30, -80), Vector2(200, 160))
	var inside: Rect2 = edge.home_area.grow(-tuning.DASH_ROOM_MARGIN + 3.0)
	var charged := false
	var stayed := true
	for i in 150:
		await physics_frame
		_player.global_position = ARENA
		_heal()
		if edge.is_charging():
			charged = true
			stayed = stayed and inside.has_point(edge.global_position)
	_check(charged and stayed, "a charge never carries it out of its room")
	edge.queue_free()
	await _frames(2)


func _spawn(at: Vector2) -> Node:
	var beast = load("res://scenes/enemies/bestia_de_la_niebla.tscn").instantiate()
	beast.data = beast.data.duplicate()
	beast.data.patrol_radius = 0.0
	_room.add_child(beast)
	beast.global_position = at
	return beast


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
