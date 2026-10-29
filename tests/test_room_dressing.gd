extends SceneTree
## Decoration of the special rooms (RoomDressing) and the exit portal's look, on real forest maps:
## the boss arena has its stones, roots, shade and door torches, the reward glade its light, the
## event camp its fire light and signpost; nothing of it collides, blocks a door lane or is drawn over
## the actors; and the portal's base shows from the start while its light waits for the boss to fall.
## Run: godot --headless --path . --script res://tests/test_room_dressing.gd
## `Level` and `Room` types must not be referenced here (autoload compile order).

const SEEDS := [4242, 1, 2, 3]
const BOSS := 5
const REWARD := 3
const EVENT := 2

var _ok := true


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var level: Node2D = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.use_director = false
	level.seed_value = SEEDS[0]
	root.add_child(level)
	await physics_frame

	var arenas_ok := true
	var torches_ok := true
	var lanes_ok := true
	var glades_ok := true
	var camps_ok := true
	var no_collision := true
	var under_actors := true
	var stones := 0
	var glades := 0
	var camps := 0
	for map_seed in SEEDS:
		level.generate(map_seed)
		await physics_frame
		for coord in level.layout.cells:
			var room: Node2D = level.rooms[coord]
			var dressing := _dressing_of(room)
			for node in dressing:
				if node is CollisionObject2D or node is CollisionShape2D or not node.find_children("*", "CollisionShape2D", true, false).is_empty():
					no_collision = false
				# The flame, the stones and the signpost stand up (sorted with the actors); the rest
				# (the torch's light too) lies on the ground.
				var holder: String = String(node.get_parent().name)
				var upright: bool = node is AnimatedSprite2D or node.get_parent() == room \
						or (node is Sprite2D and node.material == null and (holder.begins_with("ArenaStone") or holder == "CampSign"))
				if node is CanvasItem and not upright and _drawn_z(node) >= 0:
					under_actors = false
			match int(room.data.type):
				BOSS:
					var room_stones := dressing.filter(func(n: Node) -> bool: return n.name.begins_with("ArenaStone"))
					stones += room_stones.size()
					arenas_ok = arenas_ok and room_stones.size() >= 6 and room.get_node_or_null("ArenaFloor") != null \
							and room.find_children("ArenaRoot*", "Line2D", true, false).size() >= 3
					var torches := dressing.filter(func(n: Node) -> bool: return n.name.begins_with("DoorTorch"))
					torches_ok = torches_ok and torches.size() == room.open_doors.size() * 2
					for stone in room_stones:
						var from_center: Vector2 = stone.position - Vector2(240, 144)
						if absf(from_center.x) < 40.0 or absf(from_center.y) < 40.0:
							lanes_ok = false
				REWARD:
					glades += 1
					glades_ok = glades_ok and room.get_node_or_null("GladeLight") != null
				EVENT:
					camps += 1
					camps_ok = camps_ok and room.get_node_or_null("CampfireLight") != null and room.get_node_or_null("CampSign") != null
	_check(arenas_ok, "every boss arena has standing stones, roots and its darker floor (%d stones)" % stones)
	_check(torches_ok, "every door of the boss arena has a torch on each side")
	_check(lanes_ok, "no standing stone stands in a door lane of the arena")
	_check(glades > 0 and glades_ok, "every reward glade has its pool of light (%d glades)" % glades)
	_check(camps > 0 and camps_ok, "every event camp has its fire light and a signpost (%d camps)" % camps)
	var torch_lane_ok := true
	for coord in level.layout.cells:
		for torch in level.rooms[coord].get_children().filter(func(n: Node) -> bool: return n.name.begins_with("DoorTorch")):
			# Sprite from 16 px above its base to the base, 8 px to each side.
			var art := Rect2(torch.position + Vector2(-8, -16), Vector2(16, 16))
			if art.intersects(Rect2(208, 0, 64, 288)) or art.intersects(Rect2(0, 112, 480, 64)):
				torch_lane_ok = false
	_check(torch_lane_ok, "the door torches stand beside the door gaps, not in them")
	_check(no_collision, "the decoration has no collision")
	_check(under_actors, "lights, shade, roots and flowers are drawn under the actors")

	# The portal: base from the start, light and sparks once the boss has fallen.
	var portal: Node2D = get_nodes_in_group("exit_portals").filter(func(n: Node) -> bool: return level.is_ancestor_of(n))[0]
	var game_state: Node = root.get_node("GameState")
	var closed_ok: bool = portal.get_node("Base").visible and not portal.get_node("Light").visible \
			and not portal.get_node("Sparks").emitting and not portal.is_open()
	_check(closed_ok, "a closed portal shows its stone base but no light")
	game_state.set_flag(portal.required_flag)
	root.get_node("Events").boss_defeated.emit(&"test")
	await physics_frame
	_check(portal.get_node("Light").visible and portal.get_node("Sparks").emitting and portal.get_node("Glow").visible,
			"once the boss falls the portal glows, lights the ground and sparks")
	game_state.call("reset")

	# Same seed, same decoration (it has its own random numbers: the map does not change).
	level.generate(SEEDS[1])
	await physics_frame
	var first := _positions(level)
	level.generate(SEEDS[1])
	await physics_frame
	_check(first == _positions(level) and not first.is_empty(), "the same seed dresses the rooms the same way")
	level.free()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


## The z a canvas item is drawn at (its own z plus its parents' while relative).
func _drawn_z(item: CanvasItem) -> int:
	var z := item.z_index
	var node: Node = item
	while node is CanvasItem and (node as CanvasItem).z_as_relative and node.get_parent() is CanvasItem:
		node = node.get_parent()
		z += (node as CanvasItem).z_index
	return z


## The nodes RoomDressing added to a room (and what they hold).
func _dressing_of(room: Node) -> Array:
	var found := []
	for child in room.get_children():
		if String(child.name).begins_with("Arena") or String(child.name).begins_with("DoorTorch") \
				or String(child.name).begins_with("Glade") or String(child.name).begins_with("Camp"):
			found.append(child)
			found.append_array(child.find_children("*", "", true, false))
	return found


func _positions(level: Node) -> Array:
	var list := []
	for coord in level.layout.cells:
		for node in _dressing_of(level.rooms[coord]):
			if node is Node2D:
				list.append([String(level.rooms[coord].data.id), node.get_index(), node.position])
	return list


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
