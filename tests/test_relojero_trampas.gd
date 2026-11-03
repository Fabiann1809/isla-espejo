extends SceneTree
## Relojero de trampas test, with real physics: when it appears it sets one trap per kind of its data
## on a ring around itself inside its room (spikes, a saw on a track, a fire jet); the traps idle
## while Nico is out of its room and, once he is in, it fires them one after another on its rhythm;
## spikes and fire hurt him, the saw runs from one end of its track to the other; it runs from Nico;
## dead, its traps go dormant and stop hurting; taken away alive, its traps go with it.
## Run: godot --headless --path . --script res://tests/test_relojero_trampas.gd

## A room-sized home (30x18 tiles) inside the test room's walls.
const HOME := Rect2(-140, -104, 480, 288)
const SPAWN := Vector2(0, 0)
## Out of its room (and its doors' margin).
const OUTSIDE := Vector2(-400, 220)

var _ok := true
var _room: Node2D
var _player: Node2D
var _scene: PackedScene


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
	_player.global_position = OUTSIDE
	_scene = load("res://scenes/enemies/relojero_trampas.tscn")

	var clockmaker = _spawn(SPAWN)
	var frames: SpriteFrames = clockmaker.data.sprite_frames
	for anim: StringName in [&"idle", &"walk", &"run", &"attack", &"special", &"hurt", &"death"]:
		_check(frames.has_animation(anim) and frames.get_frame_count(anim) > 0, "clockmaker has %s" % anim)
	_check(clockmaker.data is TrapClockmakerData, "the clockmaker uses a TrapClockmakerData")
	_check(clockmaker.health.max_health >= 4 and clockmaker.health.max_health <= 8 and clockmaker.data.attack_damage == 1,
			"hard-roguelike stats (%d hp)" % clockmaker.health.max_health)
	await _frames(3)
	await _sets_traps(clockmaker)
	await _rhythm_and_damage(clockmaker)
	await _flees(clockmaker)
	await _dormant_when_dead(clockmaker)
	await _taken_away_alive()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _sets_traps(clockmaker) -> void:
	var traps: Array = clockmaker.traps()
	_check(traps.size() == clockmaker.data.trap_kinds.size(), "it sets %d traps (%d)" % [clockmaker.data.trap_kinds.size(), traps.size()])
	var kinds := {}
	var inside := true
	var around := true
	var margin: float = clockmaker.data.trap_margin
	for trap in traps:
		kinds[trap.kind] = true
		inside = inside and HOME.grow(-margin + 0.5).has_point(trap.global_position)
		around = around and trap.global_position.distance_to(SPAWN) <= clockmaker.data.trap_ring_radius + 0.5
		_check(trap.get_parent() == _room, "its traps live in its room")
	_check(kinds.size() == 3, "spikes, a saw and a fire jet")
	_check(inside and around, "on a ring around it, inside its room")
	_check(clockmaker.get_node("Sprite").animation == &"special", "setting them plays the special animation")
	await create_timer(2.0).timeout
	_check(_count_active(traps) == 0 and _never_fired(traps), "while Nico is out of its room they idle")


func _rhythm_and_damage(clockmaker) -> void:
	var traps: Array = clockmaker.traps()
	var spikes = _trap_of(traps, 0)
	var saw = _trap_of(traps, 1)
	var fire = _trap_of(traps, 2)
	# Nico walks in, far from the traps.
	_player.global_position = SPAWN + Vector2(200, 120)
	var fired := {}
	var starts: Array[float] = []
	var clock := 0.0
	var saw_ends: Array[Vector2] = []
	var was_active := {}
	var was_warning := {}
	# Long enough for every trap to strike twice.
	var frames := ceili(clockmaker.traps().size() * clockmaker.data.tick_interval * 60.0 * 2.0) + 120
	for i in frames:
		await physics_frame
		clock += 1.0 / 60.0
		_player.health.heal(_player.health.max_health)
		for trap in traps:
			var active: bool = trap.is_active()
			var warning: bool = trap.phase == trap.Phase.WARNING
			if warning and not was_warning.get(trap, false):
				starts.append(clock)
			was_warning[trap] = warning
			if active:
				fired[trap] = true
			if not active and was_active.get(trap, false) and trap == saw:
				saw_ends.append(saw.saw_position())
			was_active[trap] = active
	_check(fired.size() == traps.size(), "once Nico is in its room it fires every trap (%d of %d)" % [fired.size(), traps.size()])
	var steady := starts.size() >= 4
	var tick: float = clockmaker.data.tick_interval
	for i in range(1, starts.size()):
		steady = steady and absf(starts[i] - starts[i - 1] - tick) < 0.1
	_check(steady, "one after another, on its rhythm (every %.1f s, %d triggers)" % [tick, starts.size()])
	_check(saw_ends.size() >= 2 and saw_ends[0].distance_to(saw_ends[1]) > saw.track_length - 1.0,
			"the saw runs from one end of its track to the other")
	_check(await _hurts_on(spikes, spikes.global_position), "the spikes hurt Nico")
	_check(await _hurts_on(fire, fire.global_position + fire.direction * fire.fire_length * 0.6),
			"the fire jet hurts him along its aim")


func _flees(clockmaker) -> void:
	await create_timer(0.5).timeout
	# Left of the middle of the room, with Nico stepping up to it from the right.
	clockmaker.global_position = HOME.get_center() + Vector2(-60, 0)
	_player.global_position = HOME.get_center()
	await _frames(2)
	var gap_before: float = clockmaker.global_position.distance_to(_player.global_position)
	await create_timer(0.8).timeout
	var gap_after: float = clockmaker.global_position.distance_to(_player.global_position)
	_check(gap_after > gap_before + 20.0, "it runs from Nico (%.0f -> %.0f px)" % [gap_before, gap_after])
	_check(HOME.has_point(clockmaker.global_position), "and stays in its room")


func _dormant_when_dead(clockmaker) -> void:
	var traps: Array = clockmaker.traps()
	var spikes = _trap_of(traps, 0)
	clockmaker.health.take_damage(100, _player.global_position)
	await _frames(2)
	_player.global_position = spikes.global_position
	var hp: int = _player.health.current
	var stayed_still := true
	for i in 180:
		await physics_frame
		stayed_still = stayed_still and _count_active(traps) == 0
	_check(stayed_still, "dead, its traps go dormant")
	_check(_player.health.current == hp, "and no longer hurt")
	await create_timer(1.0).timeout
	_check(not is_instance_valid(clockmaker), "the clockmaker is gone")
	var left := 0
	for trap in traps:
		left += 1 if is_instance_valid(trap) else 0
	_check(left == traps.size(), "its dormant traps stay in the room")
	for trap in traps:
		trap.queue_free()
	_player.global_position = OUTSIDE
	await _frames(2)


func _taken_away_alive() -> void:
	var clockmaker = _spawn(SPAWN)
	await _frames(3)
	var traps: Array = clockmaker.traps()
	clockmaker.queue_free()
	await _frames(2)
	var left := 0
	for trap in traps:
		left += 1 if is_instance_valid(trap) else 0
	_check(not traps.is_empty() and left == 0, "taken away alive, its traps go with it")


func _hurts_on(trap, spot: Vector2) -> bool:
	_player.global_position = spot
	_player.health.heal(_player.health.max_health)
	await create_timer(1.0).timeout
	var hp: int = _player.health.current
	for i in 300:
		await physics_frame
		_player.global_position = spot
		if trap.is_active():
			break
	await _frames(4)
	var hurt: bool = _player.health.current < hp
	_player.global_position = SPAWN + Vector2(200, 120)
	return hurt


func _trap_of(traps: Array, kind: int):
	for trap in traps:
		if trap.kind == kind:
			return trap
	return null


func _count_active(traps: Array) -> int:
	var count := 0
	for trap in traps:
		count += 1 if is_instance_valid(trap) and trap.is_active() else 0
	return count


func _never_fired(traps: Array) -> bool:
	for trap in traps:
		if trap.phase != trap.Phase.READY:
			return false
	return true


func _spawn(at: Vector2) -> Node:
	var clockmaker = _scene.instantiate()
	clockmaker.data = clockmaker.data.duplicate()
	clockmaker.position = at
	clockmaker.home_area = HOME
	_room.add_child(clockmaker)
	return clockmaker


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
