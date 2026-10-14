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
const DOOR_WIDTH := 48
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
	_build_floor()
	WallBuilder.add_walls(self, _wall_rects())
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
		plan: DirectorPlan = null) -> void:
	var points := spawn_points("EnemySpawns")
	if pool.is_empty() or points.is_empty():
		return
	for i in range(points.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := points[i]
		points[i] = points[j]
		points[j] = tmp
	for i in mini(count, points.size()):
		var enemy: Node2D = _pick_enemy(pool, rng, plan).instantiate()
		enemy.position = points[i]
		if plan != null:
			plan.apply_to_enemy(enemy)
		add_child(enemy)
		register_enemy(enemy)


func _pick_enemy(pool: Array[PackedScene], rng: RandomNumberGenerator, plan: DirectorPlan) -> PackedScene:
	if plan == null or plan.enemy_weights.is_empty():
		return pool[rng.randi_range(0, pool.size() - 1)]
	var total := 0.0
	var weights: Array[float] = []
	for scene in pool:
		var weight := plan.enemy_weight(StringName(scene.resource_path.get_file().get_basename()))
		weights.append(weight)
		total += weight
	var roll := rng.randf() * total
	for i in pool.size():
		roll -= weights[i]
		if roll < 0.0:
			return pool[i]
	return pool[pool.size() - 1]


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
