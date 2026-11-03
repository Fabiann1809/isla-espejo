extends SceneTree
## Salamandra de cristal test: it lobs a crystal at where Nico stands (a warning circle marks the
## landing during the flight), the crystal leaves a patch that hurts and slows and burns for as long
## as the salamander lives; with its patches at the maximum it spits no more, no two patches are
## too close, and when it leaves or dies they go out. Both its patrol and its repositioning keep to
## the edges of its room.
## Run: godot --headless --path . --script res://tests/test_salamandra_cristal.gd

const ARENA := Vector2(300, 180)
## How long a patch lasted before they stopped going out by themselves.
const OLD_LIFETIME := 4.5

var _ok := true
var _room: Node
var _player: Node2D
var _scene: PackedScene


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_room = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(_room)
	await _frames(3)
	_player = _room.get_node("Player")
	_scene = load("res://scenes/enemies/salamandra_cristal.tscn")

	var salamander = _spawn(ARENA + Vector2(110, 0))
	var frames: SpriteFrames = salamander.data.sprite_frames
	for anim: StringName in [&"idle", &"walk", &"run", &"attack", &"special", &"hurt", &"death"]:
		_check(frames.has_animation(anim) and frames.get_frame_count(anim) > 0, "salamander has %s" % anim)
	_check(salamander.data is CrystalSalamanderData, "the salamander uses a CrystalSalamanderData")
	salamander.free()
	await _spit_leaves_a_patch()
	await _patch_limit_and_death()
	await _keeps_to_the_edges()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _spit_leaves_a_patch() -> void:
	_player.global_position = ARENA
	var salamander = _spawn(ARENA + Vector2(110, 0))
	var hp: int = _player.health.current
	var warning: Node2D = null
	var saw_special := false
	for i in 240:
		await physics_frame
		saw_special = saw_special or salamander.get_node("Sprite").animation == &"special"
		warning = _find(func(node: Node) -> bool: return node is SkillZone)
		if warning != null:
			break
	_check(saw_special, "the spit plays the special animation")
	_check(warning != null and warning.global_position.distance_to(ARENA) < 2.0,
			"a warning circle marks where Nico stands")
	var crystal: Node2D = _find(func(node: Node) -> bool: return node is Polygon2D)
	_check(crystal != null and _find_hazard() == null, "a crystal is in the air and has not landed yet")
	var hazard: Node2D = null
	for i in 90:
		await physics_frame
		hazard = _find_hazard()
		if hazard != null:
			break
	_check(hazard != null and hazard.global_position.distance_to(ARENA) < 2.0, "the crystal lands on the warned spot")
	await _frames(4)
	_check(_player.health.current == hp - 1, "the hot crystals hurt Nico (%d -> %d)" % [hp, _player.health.current])
	_check(_player.is_slowed(), "and slow him")
	# Off the patch; it goes on spitting at him, so keep him alive.
	_player.global_position = ARENA + Vector2(0, 80)
	await _wait_healing(OLD_LIFETIME + 1.0)
	_check(is_instance_valid(hazard) and not hazard.is_expiring(),
			"the patch still burns long after its old %.1f s" % OLD_LIFETIME)
	# It leaves (its room or the arena changes): its patches go out, also those still in the air.
	var cool: float = salamander.data.hazard_cool_time + salamander.data.flight_time
	var patches: Array = salamander.patches()
	salamander.queue_free()
	await _frames(2)
	var all_out := not patches.is_empty()
	for patch in patches:
		all_out = all_out and (not is_instance_valid(patch) or patch.is_expiring())
	_check(all_out, "when the salamander leaves its patches go out (%d)" % patches.size())
	await create_timer(cool + 0.4).timeout
	_check(get_nodes_in_group(&"ground_hazards").is_empty(), "and they are gone after cooling down")


func _patch_limit_and_death() -> void:
	_player.global_position = ARENA
	var salamander = _spawn(ARENA + Vector2(110, 0))
	salamander.data.hazard_max = 3
	salamander.data.attack_cooldown = 0.3
	var spacing: float = salamander.data.hazard_spacing
	var timer := create_timer(15.0)
	while salamander.patches().size() < 3 and timer.time_left > 0.0:
		await physics_frame
		_player.health.heal(_player.health.max_health)
	# Let the last crystal land.
	await _wait_healing(salamander.data.flight_time + 0.2)
	var landed := get_nodes_in_group(&"ground_hazards")
	_check(landed.size() == 3, "it spits up to its maximum of patches (%d)" % landed.size())
	var spaced := true
	for i in landed.size():
		for j in range(i + 1, landed.size()):
			spaced = spaced and landed[i].global_position.distance_to(landed[j].global_position) >= spacing - 0.5
	_check(spaced, "no two patches lie closer than %.0f px, though Nico stood still" % spacing)
	var attacked := false
	var full := create_timer(3.0)
	while full.time_left > 0.0:
		await physics_frame
		_player.health.heal(_player.health.max_health)
		attacked = attacked or salamander.state == salamander.State.ATTACK
	_check(not attacked and get_nodes_in_group(&"ground_hazards").size() == 3,
			"with its patches at the maximum it spits no more")
	# Even a spit forced on it throws nothing.
	salamander._spit()
	await _frames(2)
	_check(salamander.patches().size() == 3 and _find(func(node: Node) -> bool: return node is Polygon2D) == null,
			"one crystal more leaves no patch")
	var cool: float = salamander.data.hazard_cool_time
	salamander.health.take_damage(salamander.health.max_health, _player.global_position)
	await _frames(1)
	var all_out := true
	for patch in landed:
		all_out = all_out and patch.is_expiring()
	_check(all_out, "when the salamander dies its patches go out")
	await create_timer(cool + 0.4).timeout
	_check(get_nodes_in_group(&"ground_hazards").is_empty(), "and they are gone after cooling down")
	await _frames(30)


func _keeps_to_the_edges() -> void:
	var home := Rect2(ARENA.x - 150.0, ARENA.y - 100.0, 300.0, 200.0)
	var salamander = _spawn(ARENA + Vector2(0, -40), home)
	var inside: Rect2 = home.grow(-salamander.data.edge_margin)
	# Patrol only: nobody to hunt.
	_player.remove_from_group("player")
	_player.global_position = ARENA
	_player.health.heal(_player.health.max_health)
	var points := {}
	var start: Vector2 = salamander.global_position
	for i in 300:
		await physics_frame
		if salamander.state == salamander.State.PATROL:
			points[salamander._patrol_point] = true
	var on_edge := points.size() >= 2
	for point: Vector2 in points:
		on_edge = on_edge and _on_edge(point, inside)
	_check(on_edge, "its patrol goes along the edges of its room (%d spots)" % points.size())
	_check(_on_edge(salamander.global_position, inside.grow(2.0)) or salamander.global_position.distance_to(start) > 20.0,
			"and it actually runs there")
	# Hunting: its repositioning spots lie on the edges too.
	_player.add_to_group("player")
	var spots := {}
	for i in 360:
		await physics_frame
		# Its crystals keep landing on him: keep him alive, only its moves matter here.
		_player.health.heal(_player.health.max_health)
		var spot: Vector2 = salamander.current_spot()
		if spot != salamander.global_position:
			spots[spot] = true
	var spots_on_edge := spots.size() >= 2
	for spot: Vector2 in spots:
		spots_on_edge = spots_on_edge and _on_edge(spot, inside)
	_check(spots_on_edge, "while hunting it repositions along the edges (%d spots)" % spots.size())
	salamander.queue_free()
	await _frames(2)


## Waits `seconds` keeping Nico alive: the salamander keeps spitting at him meanwhile.
func _wait_healing(seconds: float) -> void:
	var timer := create_timer(seconds)
	while timer.time_left > 0.0:
		await physics_frame
		_player.health.heal(_player.health.max_health)


func _on_edge(point: Vector2, inside: Rect2) -> bool:
	if not inside.grow(0.5).has_point(point):
		return false
	var nearest := minf(minf(point.x - inside.position.x, inside.end.x - point.x),
			minf(point.y - inside.position.y, inside.end.y - point.y))
	return nearest < 0.5


func _find(matches: Callable) -> Node:
	for child in _room.get_children():
		if matches.call(child) and not child.is_queued_for_deletion():
			return child
	return null


func _find_hazard() -> Node2D:
	var hazards := get_nodes_in_group(&"ground_hazards")
	return hazards[0] if not hazards.is_empty() else null


func _spawn(at: Vector2, home := Rect2()) -> Node:
	var salamander = _scene.instantiate()
	salamander.data = salamander.data.duplicate()
	salamander.position = at
	salamander.home_area = home
	_room.add_child(salamander)
	return salamander


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
