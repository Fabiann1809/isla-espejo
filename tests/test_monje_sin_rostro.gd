extends SceneTree
## Monje sin rostro test, with real physics: it draws its symbols on the floor of its room (on the
## ground layer, apart from each other and clear of walls), vanishes (it cannot be hit while gone),
## the destination symbol is warned, it reappears on that other symbol and fires three projectiles in
## different directions, one at Nico, which hurt him. Visible again, it can be hit.
## The arena is moved off the origin so the symbols are checked in room coordinates.
## Run: godot --headless --path . --script res://tests/test_monje_sin_rostro.gd

const ARENA_OFFSET := Vector2(40, 24)
const HOME := Rect2(60, 40, 440, 300)
## A block inside its room: no symbol may be drawn on it.
const BLOCK := Rect2(330, 60, 60, 140)

var _ok := true
var _arena: Node2D
var _player: Node2D


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_arena = Node2D.new()
	_arena.position = ARENA_OFFSET
	root.add_child(_arena)
	_add_wall(BLOCK)
	_player = load("res://scenes/player/player.tscn").instantiate()
	_player.position = Vector2(200, 290) - ARENA_OFFSET
	_arena.add_child(_player)
	var monk = load("res://scenes/enemies/monje_sin_rostro.tscn").instantiate()
	monk.data = monk.data.duplicate()
	monk.data.patrol_radius = 0.0
	monk.home_area = HOME
	monk.position = Vector2(200, 190) - ARENA_OFFSET
	_arena.add_child(monk)
	var data = monk.data
	var frames: SpriteFrames = data.sprite_frames
	for anim: StringName in [&"idle", &"walk", &"run", &"attack", &"special", &"hurt", &"death"]:
		_check(frames.has_animation(anim), "the monk has %s" % anim)
	_check(data.max_health >= 4 and data.max_health <= 8 and data.attack_damage == 1, "hard but fair stats")
	await _frames(2)

	# --- Symbols on the floor of its room
	var symbols: Array = monk.symbols()
	_check(symbols.size() == data.symbol_count, "it draws %d symbols (%d)" % [data.symbol_count, symbols.size()])
	_check(not symbols.is_empty() and symbols[0].distance_to(monk.global_position) < 1.0, "it stands on the first one")
	var inside := true
	var apart := true
	var clear := true
	for i in symbols.size():
		inside = inside and HOME.has_point(symbols[i])
		clear = clear and not BLOCK.grow(data.symbol_clearance - 1.0).has_point(symbols[i])
		for j in i:
			apart = apart and symbols[i].distance_to(symbols[j]) >= data.symbol_gap
	_check(inside, "every symbol is inside its room")
	_check(apart, "the symbols keep %.0f px apart" % data.symbol_gap)
	_check(clear, "no symbol is drawn on a wall")
	var art: Node2D = _arena.get_node_or_null("MonkSymbols")
	_check(art != null and art.z_index == -1 and not art.z_as_relative, "the symbols lie on the ground layer")

	# --- Vanish: cannot be hit, the destination is warned
	await _until(func() -> bool: return monk.state == monk.State.ATTACK, 200)
	var start: Vector2 = monk.global_position
	var hp: int = monk.health.current
	_check(monk.get_node("Hurtbox").receive_hit(1, _player.global_position), "fading out it can still be hit")
	monk.health.heal(monk.health.max_health)
	await _until(func() -> bool: return monk.state == monk.State.ATTACK, 200)
	start = monk.global_position
	await _until(func() -> bool: return monk.is_hidden(), 120)
	_check(monk.is_hidden() and monk.modulate.a < 0.01, "it vanishes")
	hp = monk.health.current
	var refused: bool = not monk.get_node("Hurtbox").receive_hit(1, _player.global_position)
	_check(refused and monk.health.current == hp, "while gone it cannot be hit")
	var warned: int = monk._warned_symbol
	_check(warned >= 0 and monk.global_position.distance_to(symbols[warned]) < 1.0
			and symbols[warned].distance_to(start) > 1.0, "the destination is another symbol, and it is warned")

	# --- Reappears there and fires three projectiles
	var orbs: Array = []
	for i in 200:
		await physics_frame
		orbs = _find_orbs()
		if not orbs.is_empty():
			break
	_check(not monk.is_hidden() and monk.modulate.a > 0.99, "it reappears")
	_check(monk.global_position.distance_to(symbols[warned]) < 2.0, "on the warned symbol")
	_check(orbs.size() == data.shot_count, "it fires %d projectiles (%d)" % [data.shot_count, orbs.size()])
	if orbs.size() >= 2:
		var from: Array = []
		for orb in orbs:
			from.append(orb.global_position)
		await _frames(3)
		var to_player: Vector2 = (_player.global_position - monk.global_position).normalized()
		var headings: Array = []
		var aimed := false
		for i in orbs.size():
			if is_instance_valid(orbs[i]):
				var heading: Vector2 = (orbs[i].global_position - from[i]).normalized()
				headings.append(heading)
				aimed = aimed or heading.dot(to_player) > 0.99
		var distinct := headings.size() == orbs.size()
		for i in headings.size():
			for j in i:
				distinct = distinct and headings[i].dot(headings[j]) < 0.95
		_check(distinct, "each flies in a different direction")
		_check(aimed, "one flies at Nico")
	var nico_hp: int = _player.health.current
	await _until(func() -> bool: return _player.health.current < nico_hp, 240)
	_check(_player.health.current < nico_hp, "a projectile hurts Nico (%d -> %d)" % [nico_hp, _player.health.current])
	hp = monk.health.current
	_check(monk.get_node("Hurtbox").receive_hit(1, _player.global_position) and monk.health.current < hp,
			"visible again, it can be hit")
	monk.queue_free()
	await _frames(2)
	_check(art == null or not is_instance_valid(art), "its symbols go away with it")
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _find_orbs() -> Array:
	var orbs: Array = []
	for child in _arena.get_children():
		if child is EnemyOrb and not child.is_queued_for_deletion():
			orbs.append(child)
	return orbs


func _add_wall(rect: Rect2) -> void:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	wall.add_child(shape)
	wall.position = rect.get_center() - ARENA_OFFSET
	_arena.add_child(wall)


func _until(condition: Callable, max_frames: int) -> void:
	for i in max_frames:
		if condition.call():
			return
		await physics_frame


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
