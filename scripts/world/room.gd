class_name Room
extends Node2D
## One room of a generated map. The room scene provides obstacles and spawn markers; this script
## builds the floor and walls (leaving gaps for the open doors), fills the room with enemies and
## reports when the player enters, leaves and clears it (the adaptive AI listens to those events).
##
## Marker conventions in a room scene (positions are local to the room):
##   PlayerSpawn (Marker2D), EnemySpawns / BossSpawn / NpcSpawn / ChestSpawn (Node2D with Marker2D children).
## Keep a clear lane through the middle cross of the room so the doors are always reachable.

signal cleared

const TILE := 16
const WALL := 16
const DOOR_WIDTH := 64
const FLOOR_COLORS := {
	RoomData.RoomType.START: Color(0.2, 0.42, 0.28),
	RoomData.RoomType.COMBAT: Color(0.18, 0.3, 0.2),
	RoomData.RoomType.EVENT: Color(0.2, 0.3, 0.45),
	RoomData.RoomType.REWARD: Color(0.45, 0.38, 0.15),
	RoomData.RoomType.SPECIAL: Color(0.42, 0.28, 0.12),
	RoomData.RoomType.BOSS: Color(0.35, 0.18, 0.42),
}

@export var size_tiles := Vector2i(30, 18)
## Shows the room type over the floor (debugging aid).
@export var debug_label := true

var data: RoomData
## Set by the Level before the room enters the tree; null draws flat-colored placeholders.
var theme: RoomTheme
var open_doors: Array[Vector2i] = []
var visited := false
var player_inside := false
var enemies_alive := 0

var _had_enemies := false


## Call before adding the room to the tree.
func setup(room_data: RoomData, doors: Array[Vector2i]) -> void:
	data = room_data
	open_doors = doors


func _ready() -> void:
	# Merged into the map's y-sort: actors and upright props of every room are ordered together, so
	# an enemy that walks into a room built later is not hidden by its trees.
	y_sort_enabled = true
	if theme != null:
		_build_themed_floor()
	else:
		_build_floor()
	WallBuilder.add_walls(self, _wall_rects(), WallBuilder.WALL_COLOR, theme == null)
	_build_trigger()


func pixel_size() -> Vector2:
	return Vector2(size_tiles * TILE)


func center() -> Vector2:
	return pixel_size() / 2.0


## Local position of the player spawn (the room center if the scene has no marker).
func player_spawn() -> Vector2:
	var marker := get_node_or_null("PlayerSpawn") as Marker2D
	return marker.position if marker != null else center()


## Local positions of every Marker2D inside the child node `container`.
func spawn_points(container: String) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var node := get_node_or_null(container)
	if node == null:
		return points
	for child in node.get_children():
		if child is Marker2D:
			points.append((child as Marker2D).position)
	return points


## Fills the room with `count` enemies from `pool`, on the EnemySpawns markers. With a director
## `plan`, enemies are picked by the plan's weights and tuned by its multipliers.
## An enemy's id is the file name of its scene (grunt.tscn -> "grunt").
func spawn_enemies(pool: Array[PackedScene], count: int, rng: RandomNumberGenerator,
		plan: DirectorPlan = null, base_weights: Dictionary = {}) -> void:
	var points := spawn_points("EnemySpawns")
	if pool.is_empty() or points.is_empty():
		return
	for i in range(points.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := points[i]
		points[i] = points[j]
		points[j] = tmp
	var picks := pick_enemies(pool, mini(count, points.size()), rng, plan, base_weights)
	for i in picks.size():
		var enemy: Node2D = picks[i].instantiate()
		enemy.position = points[i]
		if plan != null:
			plan.apply_to_enemy(enemy)
		add_child(enemy)
		Placement.reset(enemy)
		register_enemy(enemy)


## Which enemies fill `count` spots. Each enemy gets its share of the spots by weight (the scenario's
## `base_weights` times the director's, a missing id counts as 1), rounded up or down at random so
## that its expected number is exactly that share: the weights hold over many rooms, but a room never
## repeats one enemy by chance (one independent draw per spot put three of a kind in a three-spot room
## one time in nine with equal weights).
static func pick_enemies(pool: Array[PackedScene], count: int, rng: RandomNumberGenerator,
		plan: DirectorPlan = null, base_weights: Dictionary = {}) -> Array[PackedScene]:
	var picks: Array[PackedScene] = []
	if pool.is_empty() or count <= 0:
		return picks
	var weights: Array[float] = []
	var total := 0.0
	for scene in pool:
		var id := StringName(scene.resource_path.get_file().get_basename())
		var weight := maxf(float(base_weights.get(id, 1.0)), 0.0)
		if plan != null:
			weight *= maxf(plan.enemy_weight(id), 0.0)
		weights.append(weight)
		total += weight
	if total <= 0.0:
		weights.fill(1.0)
		total = pool.size()
	# Systematic sampling: `count` evenly spaced marks, with one random offset, over the weights
	# laid end to end (scaled so they span `count`).
	var mark := rng.randf()
	var edge := 0.0
	for i in pool.size():
		edge += weights[i] * count / total
		while mark < edge and picks.size() < count:
			picks.append(pool[i])
			mark += 1.0
	while picks.size() < count:
		picks.append(pool[pool.size() - 1])
	# Spread the kinds over the spots in any order.
	for i in range(picks.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := picks[i]
		picks[i] = picks[j]
		picks[j] = tmp
	return picks


## The room in world coordinates: the territory of every enemy that lives in it (see Enemy.home_area).
func home_rect() -> Rect2:
	return Rect2(global_position, pixel_size())


func register_enemy(enemy: Node) -> void:
	enemies_alive += 1
	_had_enemies = true
	enemy.connect("died", _on_enemy_died)


func _on_enemy_died() -> void:
	enemies_alive -= 1
	if enemies_alive == 0 and _had_enemies:
		cleared.emit()
		Events.room_cleared.emit(self)


func _build_floor() -> void:
	var type: RoomData.RoomType = data.type if data != null else RoomData.RoomType.COMBAT
	var floor_rect := ColorRect.new()
	floor_rect.name = "Floor"
	floor_rect.color = FLOOR_COLORS[type]
	floor_rect.z_index = RoomTheme.FLOOR_Z
	floor_rect.size = pixel_size()
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor_rect)
	move_child(floor_rect, 0)
	if debug_label and data != null:
		var label := Label.new()
		label.text = "%s (%s)" % [RoomData.RoomType.keys()[type], data.id]
		label.position = Vector2(WALL + 4, WALL + 2)
		label.modulate = Color(1, 1, 1, 0.5)
		add_child(label)


## Floor, decoration, border and paths drawn with the theme's tiles. Nothing here affects collision.
func _build_themed_floor() -> void:
	var ground := theme.new_layer(self, "Ground")
	var patch_layer := theme.new_layer(self, "Patches")
	var decor := theme.new_layer(self, "Decor")
	var border := theme.new_layer(self, "Border")
	# Below the props the room scene places by hand.
	move_child(ground, 0)
	move_child(patch_layer, 1)
	move_child(decor, 2)
	move_child(border, 3)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(position))
	# Irregular patches of a second grass, continuous across rooms (sampled in world tiles).
	var patches := FastNoiseLite.new()
	patches.frequency = Tuning.GRASS_PATCH_FREQUENCY
	var origin := Vector2i(position) / TILE
	var in_patch := func(cell: Vector2i) -> bool:
		return patches.get_noise_2d(origin.x + cell.x, origin.y + cell.y) > Tuning.GRASS_PATCH_THRESHOLD
	for y in size_tiles.y:
		for x in size_tiles.x:
			var tile: StringName = theme.floor_tile
			if in_patch.call(Vector2i(x, y)):
				# Rounded edges and inner corners where the patch ends (the same rule as the dirt paths).
				patch_layer.set_cell(Vector2i(x, y), 0, TileArt.blob_tile(
						TileArt.GRASS_PATCH, TileArt.GRASS_PATCH_INNER, in_patch, Vector2i(x, y)))
			if not theme.floor_variants.is_empty() and rng.randf() < theme.floor_variant_chance:
				tile = theme.floor_variants[rng.randi_range(0, theme.floor_variants.size() - 1)]
			ground.set_cell(Vector2i(x, y), 0, TileArt.coords(tile))
			if not theme.decor_tiles.is_empty() and rng.randf() < theme.decor_chance and not _is_border(x, y):
				decor.set_cell(Vector2i(x, y), 0, TileArt.coords(theme.decor_tiles[rng.randi_range(0, theme.decor_tiles.size() - 1)]))

	for y in size_tiles.y:
		for x in size_tiles.x:
			if not _is_border(x, y):
				continue
			var cell := Vector2i(x, y)
			if _is_door_cell(cell):
				ground.set_cell(cell, 0, TileArt.coords(theme.path_tile))
				patch_layer.erase_cell(cell)
				decor.erase_cell(cell)
			else:
				border.set_cell(cell, 0, TileArt.coords(theme.border_tile))
	_add_detail_groups(decor, rng)
	_paint_door_paths(ground, decor, patch_layer)


## A few small natural groups of ground details: mushrooms, stones, flowers, a stump with mushrooms.
## Drawn on the decor layer (no collision); the door paths are cleared afterwards.
func _add_detail_groups(decor: TileMapLayer, rng: RandomNumberGenerator) -> void:
	var families: Array = [
		[TileArt.MUSHROOM_BROWN, TileArt.MUSHROOM_RED, TileArt.MUSHROOM_ORANGE, TileArt.MUSHROOM_PALE],
		[TileArt.PEBBLES, TileArt.ROCK_SMALL],
		[TileArt.FLOWER_PURPLE, TileArt.FLOWER_YELLOW],
		[TileArt.STUMP],
	]
	for group in Tuning.DETAIL_GROUPS_PER_ROOM:
		var family: Array = families[rng.randi_range(0, families.size() - 1)]
		var center := Vector2i(rng.randi_range(2, size_tiles.x - 3), rng.randi_range(2, size_tiles.y - 3))
		# One kind per group reads as natural (a ring of the same mushroom); a stump brings mushrooms.
		var kind: StringName = family[rng.randi_range(0, family.size() - 1)]
		var count := rng.randi_range(Tuning.DETAIL_GROUP_SIZE.x, Tuning.DETAIL_GROUP_SIZE.y)
		for i in count:
			var cell := center if i == 0 else center + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-1, 1))
			if _is_border(cell.x, cell.y):
				continue
			var tile := kind
			if kind == TileArt.STUMP and i > 0:
				tile = TileArt.MUSHROOM_BROWN
			decor.set_cell(cell, 0, TileArt.coords(tile))


func _is_border(x: int, y: int) -> bool:
	return x == 0 or y == 0 or x == size_tiles.x - 1 or y == size_tiles.y - 1


## True for the border cells that are the gap of an open door.
func _is_door_cell(cell: Vector2i) -> bool:
	var half := DOOR_WIDTH / TILE / 2
	var in_columns := cell.x >= size_tiles.x / 2 - half and cell.x < size_tiles.x / 2 + half
	var in_rows := cell.y >= size_tiles.y / 2 - half and cell.y < size_tiles.y / 2 + half
	if cell.y == 0:
		return open_doors.has(Vector2i.UP) and in_columns
	if cell.y == size_tiles.y - 1:
		return open_doors.has(Vector2i.DOWN) and in_columns
	if cell.x == 0:
		return open_doors.has(Vector2i.LEFT) and in_rows
	if cell.x == size_tiles.x - 1:
		return open_doors.has(Vector2i.RIGHT) and in_rows
	return false


## A two-tile-wide dirt path from every open door to the middle of the room.
func _paint_door_paths(ground: TileMapLayer, decor: TileMapLayer, patch_layer: TileMapLayer) -> void:
	var middle := size_tiles / 2
	for door in open_doors:
		var cells: Rect2i
		if door.y != 0:
			var rows := Vector2i(1, middle.y) if door == Vector2i.UP else Vector2i(middle.y, size_tiles.y - 1)
			cells = Rect2i(middle.x - 1, rows.x, 2, rows.y - rows.x)
		else:
			var columns := Vector2i(1, middle.x) if door == Vector2i.LEFT else Vector2i(middle.x, size_tiles.x - 1)
			cells = Rect2i(columns.x, middle.y - 1, columns.y - columns.x, 2)
		theme.fill(ground, cells, theme.path_tile)
		for y in range(cells.position.y, cells.end.y):
			for x in range(cells.position.x, cells.end.x):
				decor.erase_cell(Vector2i(x, y))
				patch_layer.erase_cell(Vector2i(x, y))


## Wall rectangles around the room, with a gap of DOOR_WIDTH on every open side.
func _wall_rects() -> Array[Rect2]:
	var size := pixel_size()
	var rects: Array[Rect2] = []
	var gap_w := (size.x - DOOR_WIDTH) / 2.0
	var gap_h := (size.y - DOOR_WIDTH) / 2.0
	if open_doors.has(Vector2i.UP):
		rects.append(Rect2(0, 0, gap_w, WALL))
		rects.append(Rect2(gap_w + DOOR_WIDTH, 0, gap_w, WALL))
	else:
		rects.append(Rect2(0, 0, size.x, WALL))
	if open_doors.has(Vector2i.DOWN):
		rects.append(Rect2(0, size.y - WALL, gap_w, WALL))
		rects.append(Rect2(gap_w + DOOR_WIDTH, size.y - WALL, gap_w, WALL))
	else:
		rects.append(Rect2(0, size.y - WALL, size.x, WALL))
	var side_h := size.y - 2.0 * WALL
	if open_doors.has(Vector2i.LEFT):
		rects.append(Rect2(0, WALL, WALL, gap_h - WALL))
		rects.append(Rect2(0, gap_h + DOOR_WIDTH, WALL, gap_h - WALL))
	else:
		rects.append(Rect2(0, WALL, WALL, side_h))
	if open_doors.has(Vector2i.RIGHT):
		rects.append(Rect2(size.x - WALL, WALL, WALL, gap_h - WALL))
		rects.append(Rect2(size.x - WALL, gap_h + DOOR_WIDTH, WALL, gap_h - WALL))
	else:
		rects.append(Rect2(size.x - WALL, WALL, WALL, side_h))
	return rects


## Detects the player inside the room (collision layer 2 = player body).
func _build_trigger() -> void:
	var area := Area2D.new()
	area.name = "Trigger"
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = pixel_size() - Vector2(WALL, WALL) * 2.0
	shape.shape = rectangle
	shape.position = center()
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	player_inside = true
	visited = true
	Events.room_entered.emit(self)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	player_inside = false
	Events.room_exited.emit(self)
