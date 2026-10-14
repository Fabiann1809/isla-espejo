class_name MapLayout
extends RefCounted
## Result of the map generator: which room goes in which grid cell and which cells are connected.
## Pure data (no nodes), so it can be generated and verified without running the game.

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]


class Cell:
	var coord := Vector2i.ZERO
	var type: RoomData.RoomType = RoomData.RoomType.COMBAT
	var room_data: RoomData
	## Directions (as grid offsets) with an open door.
	var doors: Array[Vector2i] = []


var map_seed := 0
var scenario: ScenarioData
var grid_size := Vector2i.ZERO
var start_cell := Vector2i.ZERO
var boss_cell := Vector2i.ZERO
## Cells from start to boss, in order.
var main_path: Array[Vector2i] = []
var cells: Dictionary = {}


func has_cell(coord: Vector2i) -> bool:
	return cells.has(coord)


func get_cell(coord: Vector2i) -> Cell:
	return cells.get(coord)


func add_cell(coord: Vector2i) -> Cell:
	var cell := Cell.new()
	cell.coord = coord
	cells[coord] = cell
	return cell


func connect_cells(a: Vector2i, b: Vector2i) -> void:
	if not get_cell(a).doors.has(b - a):
		get_cell(a).doors.append(b - a)
	if not get_cell(b).doors.has(a - b):
		get_cell(b).doors.append(a - b)


func are_connected(a: Vector2i, b: Vector2i) -> bool:
	return has_cell(a) and get_cell(a).doors.has(b - a)


func neighbors_connected(coord: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir in get_cell(coord).doors:
		result.append(coord + dir)
	return result


func in_grid(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.y >= 0 and coord.x < grid_size.x and coord.y < grid_size.y


## Number of doors steps from `from` to every reachable cell.
func distances_from(from: Vector2i) -> Dictionary:
	var dist := {from: 0}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for next in neighbors_connected(current):
			if not dist.has(next):
				dist[next] = dist[current] + 1
				queue.append(next)
	return dist


func count_of_type(type: RoomData.RoomType) -> int:
	var total := 0
	for cell: Cell in cells.values():
		if cell.type == type:
			total += 1
	return total


## Returns a list of problems; empty means the layout is valid and fully playable.
func validate() -> Array[String]:
	var problems: Array[String] = []
	if cells.is_empty():
		return ["no cells"]
	if not has_cell(start_cell):
		problems.append("start cell missing")
	if not has_cell(boss_cell):
		problems.append("boss cell missing")
	if not problems.is_empty():
		return problems

	for coord: Vector2i in cells:
		var cell: Cell = cells[coord]
		if not in_grid(coord):
			problems.append("cell %s outside the grid" % coord)
		if cell.room_data == null or cell.room_data.scene == null:
			problems.append("cell %s has no room scene" % coord)
		for dir in cell.doors:
			var other: Vector2i = coord + dir
			if not DIRS.has(dir):
				problems.append("cell %s has a non-adjacent door %s" % [coord, dir])
			elif not are_connected(other, coord):
				problems.append("door %s -> %s is not mirrored" % [coord, other])

	var dist := distances_from(start_cell)
	if dist.size() != cells.size():
		problems.append("%d cells unreachable from the start" % (cells.size() - dist.size()))
	if get_cell(boss_cell).doors.size() != 1:
		problems.append("boss room must have exactly one door")
	if get_cell(start_cell).type != RoomData.RoomType.START:
		problems.append("start cell has the wrong type")
	if get_cell(boss_cell).type != RoomData.RoomType.BOSS:
		problems.append("boss cell has the wrong type")
	if count_of_type(RoomData.RoomType.START) != 1 or count_of_type(RoomData.RoomType.BOSS) != 1:
		problems.append("there must be exactly one start and one boss room")
	return problems


## Text drawing of the map for logs and debugging. S start, B boss, C combat, E event,
## R reward, X special.
func to_ascii() -> String:
	const LETTERS := {
		RoomData.RoomType.START: "S", RoomData.RoomType.BOSS: "B", RoomData.RoomType.COMBAT: "C",
		RoomData.RoomType.EVENT: "E", RoomData.RoomType.REWARD: "R", RoomData.RoomType.SPECIAL: "X",
	}
	var lines: Array[String] = []
	for y in grid_size.y:
		var row := ""
		var below := ""
		for x in grid_size.x:
			var coord := Vector2i(x, y)
			row += LETTERS[get_cell(coord).type] if has_cell(coord) else "."
			row += "-" if are_connected(coord, coord + Vector2i.RIGHT) else " "
			below += "| " if are_connected(coord, coord + Vector2i.DOWN) else "  "
		lines.append(row)
		lines.append(below)
	return "\n".join(lines)
