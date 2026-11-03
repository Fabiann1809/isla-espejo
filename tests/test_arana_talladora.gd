extends SceneTree
## Araña talladora test, with real physics: it drills (special animation) and the tiles under Nico
## crack first (a warning that does not hurt), then sink into a pit that holds him for a moment and
## hurts him; a dodge breaks the hold; a patch he left before it sank does not hurt him; the pits
## close again and go away, and between drills the spider scuttles fast to a new spot in its room.
## Run: godot --headless --path . --script res://tests/test_arana_talladora.gd

const ARENA := Vector2(100, 40)
## A room-sized home around the arena (30x18 tiles), inside the test room's walls.
const HOME := Rect2(-140, -104, 480, 288)

var _ok := true
var _room: Node2D
var _player: Node2D
var _scene: PackedScene
var _pit_script: Script


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
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
	_scene = load("res://scenes/enemies/arana_talladora.tscn")
	_pit_script = load("res://scripts/enemies/sinking_floor.gd")

	var spider = _spawn(ARENA + Vector2(100, 0))
	var frames: SpriteFrames = spider.data.sprite_frames
	for anim: StringName in [&"idle", &"walk", &"run", &"attack", &"special", &"hurt", &"death"]:
		_check(frames.has_animation(anim) and frames.get_frame_count(anim) > 0, "spider has %s" % anim)
	_check(spider.data is CarvingSpiderData, "the spider uses a CarvingSpiderData")
	_check(spider.health.max_health >= 4 and spider.health.max_health <= 8 and spider.data.attack_damage == 1,
			"hard-roguelike stats (%d hp)" % spider.health.max_health)
	spider.free()
	await _drill_sinks_the_floor()
	await _stepping_off_is_safe()
	await _scuttles_between_drills()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _drill_sinks_the_floor() -> void:
	_player.global_position = ARENA
	var spider = _spawn(ARENA + Vector2(100, 0))
	var hp: int = _player.health.current
	var saw_special := false
	var pits: Array = []
	for i in 240:
		await physics_frame
		saw_special = saw_special or spider.get_node("Sprite").animation == &"special"
		pits = _pits()
		if not pits.is_empty():
			break
	_check(saw_special, "the drill plays the special animation")
	_check(pits.size() == spider.data.pits_per_drill, "the drill cracks %d patches (%d)" % [spider.data.pits_per_drill, pits.size()])
	var under = _pit_under(ARENA)
	_check(under != null, "one patch is under Nico")
	if under == null:
		spider.queue_free()
		return
	_check(not under.is_sunk(), "it cracks first: a warning")
	_check(fmod(under.global_position.x, 16.0) == 0.0 and fmod(under.global_position.y, 16.0) == 0.0,
			"the patch lines up with the floor's tiles")
	await create_timer(spider.data.crack_time * 0.6).timeout
	_check(_player.health.current == hp, "the crack does not hurt")
	spider.queue_free()
	for i in 90:
		await physics_frame
		if under.is_sunk():
			break
	_check(under.is_sunk(), "then the patch sinks")
	_check(_player.is_pulled(), "and holds Nico in the hole")
	var held_at: Vector2 = _player.global_position
	await _frames(6)
	_check(_player.health.current < hp, "the pit hurts him (%d -> %d)" % [hp, _player.health.current])
	_check(_player.global_position.distance_to(held_at) < 1.0, "held: he does not move")
	_player._start_dash()
	await _frames(2)
	_check(not _player.is_pulled(), "a dodge breaks free")
	_player.global_position = ARENA + Vector2(0, 100)
	await create_timer(under.sunk_time + under.close_time + 0.2).timeout
	_check(not is_instance_valid(under), "the pit closes again and goes away")
	_check(_pits().is_empty(), "no patch is left")


func _stepping_off_is_safe() -> void:
	_player.global_position = ARENA
	_player.health.heal(_player.health.max_health)
	await create_timer(1.0).timeout
	var spider = _spawn(ARENA + Vector2(100, 0))
	spider.data.pits_per_drill = 1
	var under = null
	for i in 240:
		await physics_frame
		under = _pit_under(ARENA)
		if under != null:
			break
	_check(under != null, "the floor under Nico cracks")
	spider.queue_free()
	_player.global_position = ARENA + Vector2(0, 60)
	var hp: int = _player.health.current
	for i in 90:
		await physics_frame
		if under.is_sunk():
			break
	await _frames(6)
	_check(under.is_sunk() and _player.health.current == hp and not _player.is_pulled(),
			"stepping off the crack before it sinks is safe")
	await create_timer(under.sunk_time + under.close_time + 0.2).timeout


func _scuttles_between_drills() -> void:
	# Its next spot is picked at random and may land next to the last one; a fixed seed keeps the
	# check from failing now and then.
	seed(7)
	_player.global_position = ARENA
	var spider = _spawn(ARENA + Vector2(60, 0))
	var drill_spots: Array[Vector2] = []
	var top_speed := 0.0
	var outside := false
	var inside: Rect2 = HOME.grow(-spider.data.room_margin + 1.0)
	for i in 420:
		await physics_frame
		_player.health.heal(_player.health.max_health)
		if spider.state == spider.State.ATTACK and (drill_spots.is_empty()
				or drill_spots.back().distance_to(spider.global_position) > 1.0):
			drill_spots.append(spider.global_position)
		if spider.state == spider.State.CHASE:
			top_speed = maxf(top_speed, spider.velocity.length())
			var spot: Vector2 = spider.current_spot()
			outside = outside or (spot != spider.global_position and not inside.has_point(spot))
	_check(drill_spots.size() >= 2, "it drills again and again (%d drills)" % drill_spots.size())
	var moved := drill_spots.size() >= 2 and drill_spots[0].distance_to(drill_spots[1]) > 10.0
	_check(moved, "and drills from another spot each time")
	_check(top_speed >= spider.data.chase_speed * 0.9, "it scuttles fast between drills (%.0f px/s)" % top_speed)
	_check(not outside, "its spots stay inside its room")
	spider.queue_free()
	await _frames(2)


func _pits() -> Array:
	var found := []
	for child in _room.get_children():
		if child.get_script() == _pit_script and not child.is_queued_for_deletion():
			found.append(child)
	return found


func _pit_under(point: Vector2):
	for pit in _pits():
		if pit.covers(point):
			return pit
	return null


func _spawn(at: Vector2) -> Node:
	var spider = _scene.instantiate()
	spider.data = spider.data.duplicate()
	spider.position = at
	spider.home_area = HOME
	_room.add_child(spider)
	return spider


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
