extends SceneTree
## Ponds are water (physics layer 7): Nico and enemies cannot walk into them, but arrows and enemy
## orbs fly over, so a fight across a pond is not a stalemate. A bridge (planks between two ponds)
## lets the water run on under it and only changes the drawing.
## Run: godot --headless --path . --script res://tests/test_water.gd

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var room: Node = load("res://scenes/levels/test_room.tscn").instantiate()
	for name in ["Trap1", "Trap2", "Grunt1", "Grunt2", "Dummy1", "Dummy2", "Dummy3"]:
		room.get_node(name).free()
	var pond = load("res://scripts/world/room_prop.gd").new()
	pond.kind = 5  # RoomProp.Kind.POND
	pond.size_tiles = Vector2i(3, 3)
	pond.position = Vector2(192, 96)
	room.add_child(pond)
	root.add_child(room)
	await _frames(3)
	var player: Node2D = room.get_node("Player")
	var water_body: StaticBody2D = null
	for child in pond.get_children():
		if child is StaticBody2D:
			water_body = child
	_check(water_body != null and water_body.collision_layer == 1 << 6, "a pond's body is on the water layer")

	# Nico walks right into the pond from its left side and stops at the shore.
	player.global_position = Vector2(170, 120)
	Input.action_press("move_right")
	await _frames(40)
	Input.action_release("move_right")
	_check(player.global_position.x < 200.0, "Nico cannot walk into the water (x = %.0f)" % player.global_position.x)

	# An arrow shot over the pond keeps flying past it.
	var arrow = load("res://scenes/player/arrow.tscn").instantiate()
	arrow.setup(Vector2.RIGHT, 300.0, 200.0, 1)
	room.add_child(arrow)
	arrow.global_position = Vector2(170, 120)
	await _frames(25)
	_check(is_instance_valid(arrow) and arrow.global_position.x > 250.0, "an arrow flies over the pond")
	room.queue_free()
	await _frames(1)
	await _check_bridge()
	quit(0 if _ok else 1)


## The river room: its two ponds and the planks between them are one river with a bridge over it.
func _check_bridge() -> void:
	var water_art = load("res://scripts/world/water_art.gd")
	if not water_art.available():
		print("PASS the tileset's own pond and planks are drawn (Tuning.WATER_ART_ENABLED is off)")
		return
	var river: Node2D = load("res://scenes/levels/rooms/forest/river.tscn").instantiate()
	root.add_child(river)
	await _frames(2)
	var north: Node2D = river.get_node("Prop1")
	var south: Node2D = river.get_node("Prop2")
	var planks: Node2D = river.get_node("Prop3")
	var layer: TileMapLayer = north.get_node("Water")
	var last_row: int = north.size_tiles.y - 1
	var row: int = layer.get_cell_atlas_coords(Vector2i(1, last_row)).y
	_check(row in load("res://scripts/world/area_art.gd").MIDDLE_ROWS, "the water runs on under the bridge (no shore where it starts)")
	var bodies := planks.get_children().filter(func(n: Node) -> bool: return n is CollisionObject2D)
	_check(bodies.is_empty(), "a bridge adds no collision: Nico walks over it as before")
	var railing: Node2D = planks.get_node_or_null("Railing")
	_check(railing != null and not railing.z_as_relative and railing.z_index == 0 and planks.y_sort_enabled,
			"the near rail stands with the actors and is y-sorted with them")
	_check(planks.z_index < 0 and planks.get_node("Deck").global_position.y > south.global_position.y,
			"the deck lies with the floor and over the pond below it (its shade and piles show)")
	river.queue_free()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
