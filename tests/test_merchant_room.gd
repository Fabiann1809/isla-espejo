extends SceneTree
## The Mercader's shop: every map of the three chapters has exactly one special room (same seed, same
## map), the built level puts exactly one merchant there and none at the start, and the room is dressed
## as a shop (stall with a solid base, rug, lanterns, crates) with nothing of it on a door lane.
## Run: godot --headless --path . --script res://tests/test_merchant_room.gd
## `Level` and `Room` types must not be referenced here (autoload compile order).

const CHAPTERS := ["forest", "ruins", "temple"]
const LAYOUT_SEEDS := 20
## Seeds checked for the shop's distance from the start.
const DISTANCE_SEEDS := 300
## Seeds whose levels are built (a temple map takes 2-3 s).
const BUILD_SEEDS := {"forest": [4242, 7, 19], "ruins": [4242, 7, 19], "temple": [4242, 11]}
const LANE_HALF := 32.0

var _ok := true


func _initialize() -> void:
	create_timer(170.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	for chapter in CHAPTERS:
		_check_layouts(chapter)
	for chapter in CHAPTERS:
		for map_seed in BUILD_SEEDS[chapter]:
			await _check_level(chapter, map_seed)
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check_layouts(chapter: String) -> void:
	var scenario: ScenarioData = load("res://data/scenarios/%s.tres" % chapter)
	_check(scenario.start_npc_scene == null, "%s: no NPC waits in the start room" % chapter)
	_check(scenario.special_rooms == 1 and scenario.special_npc_scene == load("res://scenes/npcs/merchant.tscn"),
			"%s: its one special room holds the Mercader" % chapter)
	var bad := 0
	var repeated := 0
	for map_seed in range(1, LAYOUT_SEEDS + 1):
		var layout := MapGenerator.generate(scenario, map_seed)
		if layout.count_of_type(RoomData.RoomType.SPECIAL) != 1 or not layout.validate().is_empty():
			bad += 1
		if layout.get_cell(layout.start_cell).type == RoomData.RoomType.SPECIAL:
			bad += 1
		if MapGenerator.generate(scenario, map_seed).to_ascii() != layout.to_ascii():
			repeated += 1
	_check(bad == 0, "%s: %d seeds give exactly one special room and a valid map (bad: %d)" % [chapter, LAYOUT_SEEDS, bad])
	_check(repeated == 0, "%s: the same seed gives the same map (different: %d)" % [chapter, repeated])
	var near := 0
	var first_half := 0
	var beside_boss := 0
	for map_seed in range(1, DISTANCE_SEEDS + 1):
		var far_layout := MapGenerator.generate(scenario, map_seed)
		var dist := far_layout.distances_from(far_layout.start_cell)
		var farthest := 0
		var shop := Vector2i(-1, -1)
		for coord: Vector2i in far_layout.cells:
			var type := far_layout.get_cell(coord).type
			if type == RoomData.RoomType.SPECIAL:
				shop = coord
			elif type != RoomData.RoomType.START and type != RoomData.RoomType.BOSS and type != RoomData.RoomType.EVENT:
				farthest = maxi(farthest, dist[coord])
		if shop.x < 0:
			continue
		# At least 3 steps from the start (the farthest possible on a tiny map), never next to it.
		if dist[shop] < mini(3, farthest) or far_layout.are_connected(shop, far_layout.start_cell):
			near += 1
		if (far_layout.main_path.size() - 1) >> 1 > dist[shop] and dist[shop] < farthest:
			first_half += 1
		if far_layout.are_connected(shop, far_layout.boss_cell):
			beside_boss += 1
	_check(near == 0, "%s: the shop room is at least 3 steps from the start, never beside it (bad: %d of %d)" % [chapter, near, DISTANCE_SEEDS])
	_check(beside_boss == 0, "%s: the shop room is never next to the boss room (bad: %d)" % [chapter, beside_boss])
	print("%s: shop in the first half of the run, though farther cells existed: %d of %d" % [chapter, first_half, DISTANCE_SEEDS])
	# A map that asks for a special room and has none is reported.
	var layout := MapGenerator.generate(scenario, 1)
	for coord: Vector2i in layout.cells:
		if layout.get_cell(coord).type == RoomData.RoomType.SPECIAL:
			layout.get_cell(coord).type = RoomData.RoomType.COMBAT
	_check(layout.validate().size() == 1, "%s: validate() reports a missing special room" % chapter)


func _check_level(chapter: String, map_seed: int) -> void:
	var label := "%s, seed %d" % [chapter, map_seed]
	var level: Node2D = load("res://scenes/levels/%s_level.tscn" % chapter).instantiate()
	level.seed_value = map_seed
	level.use_director = false
	root.add_child(level)
	for i in 3:
		await process_frame
	var merchants := get_nodes_in_group("npcs").filter(func(n: Node) -> bool: return n.dialogue_id == &"merchant")
	_check(merchants.size() == 1, "%s: exactly one Mercader (%d)" % [label, merchants.size()])
	if merchants.size() != 1:
		level.queue_free()
		await process_frame
		return
	var merchant: Node2D = merchants[0]
	var room: Node2D = merchant.get_parent()
	_check(room.data.type == RoomData.RoomType.SPECIAL, "%s: he stands in the special room" % label)
	_check(level.layout.get_cell(level.layout.start_cell).type != RoomData.RoomType.SPECIAL, "%s: none in the start room" % label)
	var center: Vector2 = room.center()
	_check(absf(merchant.position.x - center.x) >= LANE_HALF and absf(merchant.position.y - center.y) >= LANE_HALF,
			"%s: his spot is off the door lanes" % label)
	var pieces := room.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Shop"))
	var names: Array = pieces.map(func(n: Node) -> String: return String(n.name))
	_check(names.has("ShopStall"), "%s: the shop has its stall (%s)" % [label, names])
	if chapter != "temple":
		_check(names.has("ShopRug") and names.has("ShopLantern1") and names.has("ShopLantern2") and names.has("ShopCrates1"),
				"%s: rug, two lanterns and crates stand around it" % label)
	else:
		_check(names.has("ShopRug") and names.has("ShopLantern1"), "%s: the temple shop has a rug and lantern on its floor" % label)
	var lane_hits := 0
	var bodies := 0
	for piece: Node2D in pieces:
		if piece.name.begins_with("ShopRug"):
			var half := Vector2(24, 16)
			lane_hits += int(absf(piece.position.x - center.x) - half.x < LANE_HALF or absf(piece.position.y - center.y) - half.y < LANE_HALF)
		elif not piece.name.contains("Light"):
			lane_hits += int(absf(piece.position.x - center.x) < LANE_HALF or absf(piece.position.y - center.y) < LANE_HALF)
		var shapes := piece.find_children("*", "CollisionShape2D", true, false)
		bodies += shapes.size()
		if not piece.name.begins_with("ShopStall"):
			_check(shapes.is_empty(), "%s: %s has no collision" % [label, piece.name])
	_check(lane_hits == 0, "%s: nothing of the shop lies on a door lane" % label)
	_check(bodies == 1, "%s: only the stall has a solid base (%d)" % [label, bodies])
	# The stall's base is behind the merchant, so the way to him stays open.
	var stall: Node2D = room.get_node_or_null("ShopStall")
	if stall != null:
		_check(stall.position.y < merchant.position.y, "%s: the stall stands behind the Mercader" % label)
	level.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
