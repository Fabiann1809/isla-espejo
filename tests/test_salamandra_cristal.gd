extends SceneTree
## Salamandra de cristal test: it lobs a crystal at where Nico stands (a warning circle marks the
## landing during the flight), the crystal leaves a patch that hurts and slows and stays a few
## seconds after the salamander is gone, and both its patrol and its repositioning keep to the
## edges of its room.
## Run: godot --headless --path . --script res://tests/test_salamandra_cristal.gd

const ARENA := Vector2(300, 180)

var _ok := true
var _room: Node
var _player: Node2D
var _scene: PackedScene


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
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
	await _keeps_to_the_edges()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _spit_leaves_a_patch() -> void:
	_player.global_position = ARENA
	var salamander = _spawn(ARENA + Vector2(110, 0))
	var hp: int = _player.health.current
	var lifetime: float = salamander.data.hazard_lifetime
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
	salamander.queue_free()
	await _frames(4)
	_check(_player.health.current == hp - 1, "the hot crystals hurt Nico (%d -> %d)" % [hp, _player.health.current])
	_check(_player.is_slowed(), "and slow him")
	# Off the patch, or it would keep hurting him until the end.
	_player.global_position = ARENA + Vector2(0, 80)
	await create_timer(2.0).timeout
	_check(is_instance_valid(hazard), "the crystals stay on the ground after the salamander is gone")
	await create_timer(lifetime).timeout
	_check(not is_instance_valid(hazard), "and fade away after a few seconds")


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
