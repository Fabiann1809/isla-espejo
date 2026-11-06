class_name TemplePlan
extends RefCounted
## The plan of a temple room: 18 rows of 30 characters, one per 16 px cell, read into a height per
## cell, the cliff faces between levels, collision rectangles per physics layer, stair zones and a
## check of the design. Pure data: no nodes, no autoloads. A room is a stone island over lava with
## up to three height levels (0, 1, 2); the drawing, the physics bodies, the spawns and the lava
## surge are built elsewhere from what this class answers.
##
##   .  floor at height 0      1  floor at height 1      2  floor at height 2
##   ~  lava (height -1: a level-0 walker cannot enter it, arrows fly over)
##   ^ > < v  a stair that climbs one level toward the arrow; its own height is its low end
##   =  east-west bridge deck at height 0     |  north-south deck at height 0
##   b  bridge deck at height 1               B  bridge deck at height 2
##   #  solid temple masonry (blocks everybody)
##   p  pillar slot: floor of the height of its west neighbour, filled later by a TempleProp
##
## The outer ring is the room's wall (Room draws and collides it): masonry, except the door gaps,
## the 4 middle cells of each edge, which are floor of the room's base height.
##
## Faces: a cell directly south of a cell `d` levels higher (lava counts as -1) shows `d` rows of
## cliff face; it belongs to the lower side and is not walkable at its own height. A stair is never
## a face (it is the ramp) though its low end casts one like a floor; a deck is neither (it stands
## on supports); masonry has its own art.
##
## Layers (plain ints, see Heights for the actors' side): 1 masonry; 7 lava; 8 what level 0 may not
## enter (raised cells and faces: the cliff a level-0 shot sees); 9 what level 1 may not enter;
## 10 what level 2 may not enter; 11 the height-2 cells (the cliff a level-1 shot sees).

const COLUMNS := 30
const ROWS := 18
const TILE := 16
const MAX_HEIGHT := 2
const LAVA_HEIGHT := -1
const MASONRY_HEIGHT := 99

const FLOOR_0 := "."
const FLOOR_1 := "1"
const FLOOR_2 := "2"
const LAVA := "~"
const MASONRY := "#"
const PILLAR := "p"
const FLOORS := [FLOOR_0, FLOOR_1, FLOOR_2]
const STAIRS := {"^": Vector2i.UP, ">": Vector2i.RIGHT, "<": Vector2i.LEFT, "v": Vector2i.DOWN}
const DECKS := {"=": 0, "|": 0, "b": 1, "B": 2}
const ALPHABET := ".12~^><v=|bB#p"

const WORLD_LAYER := 1
const LAVA_LAYER := 7
const BLOCK_LEVEL_0_LAYER := 8
const BLOCK_LEVEL_1_LAYER := 9
const BLOCK_LEVEL_2_LAYER := 10
const HEIGHT_2_LAYER := 11

## The door gaps (Room.DOOR_WIDTH = 4 cells) are also the lanes that must stay passable.
const LANE_FIRST_COLUMN := 13
const LANE_FIRST_ROW := 7
const LANE_WIDTH := 4
const DOOR_NAMES := ["north", "east", "south", "west"]
## The share of the inner cells that must be something other than base-height floor.
const MIN_RELIEF_SHARE := 0.2
## A surge's safe level needs this many walkable cells in one connected region.
const SURGE_MIN_SAFE_CELLS := 60

var base_height := 0
var errors: Array[String] = []

var _cells: Array[String] = []
var _heights: Array[int] = []


static func parse(text: String) -> TemplePlan:
	var plan := TemplePlan.new()
	plan._read(text)
	return plan


## The door cells of every edge, by name: 4 cells per door on the outer ring.
static func door_cells() -> Dictionary:
	var doors := {}
	for name in DOOR_NAMES:
		var cells: Array[Vector2i] = []
		for i in LANE_WIDTH:
			match name:
				"north":
					cells.append(Vector2i(LANE_FIRST_COLUMN + i, 0))
				"south":
					cells.append(Vector2i(LANE_FIRST_COLUMN + i, ROWS - 1))
				"west":
					cells.append(Vector2i(0, LANE_FIRST_ROW + i))
				"east":
					cells.append(Vector2i(COLUMNS - 1, LANE_FIRST_ROW + i))
		doors[name] = cells
	return doors


static func in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < COLUMNS and cell.y < ROWS


static func is_inner(cell: Vector2i) -> bool:
	return cell.x > 0 and cell.y > 0 and cell.x < COLUMNS - 1 and cell.y < ROWS - 1


static func is_door(cell: Vector2i) -> bool:
	var on_lane_x := cell.x >= LANE_FIRST_COLUMN and cell.x < LANE_FIRST_COLUMN + LANE_WIDTH
	var on_lane_y := cell.y >= LANE_FIRST_ROW and cell.y < LANE_FIRST_ROW + LANE_WIDTH
	return ((cell.y == 0 or cell.y == ROWS - 1) and on_lane_x) or ((cell.x == 0 or cell.x == COLUMNS - 1) and on_lane_y)


# --- reading ---------------------------------------------------------------------------------------------------------
func _read(text: String) -> void:
	_cells.clear()
	_heights.clear()
	for line in text.strip_edges().split("\n"):
		_cells.append(line.strip_edges())
	if _cells.size() != ROWS:
		errors.append("the plan has %d rows, it needs %d" % [_cells.size(), ROWS])
		_cells.clear()
		return
	for y in ROWS:
		if _cells[y].length() != COLUMNS:
			errors.append("row %d has %d characters, it needs %d" % [y, _cells[y].length(), COLUMNS])
	if not errors.is_empty():
		_cells.clear()
		return
	for y in ROWS:
		for x in COLUMNS:
			if not ALPHABET.contains(_cells[y][x]):
				errors.append("unknown character '%s' at (%d, %d)" % [_cells[y][x], x, y])
	if not errors.is_empty():
		_cells.clear()
		return
	_read_ring()
	_read_heights()


## The outer ring is masonry, except the doors: floor, all at the same height, which is the base.
func _read_ring() -> void:
	var door_heights: Array[int] = []
	for y in ROWS:
		for x in COLUMNS:
			var cell := Vector2i(x, y)
			if is_inner(cell):
				continue
			var c := cell_at(cell)
			if is_door(cell):
				if FLOORS.has(c):
					door_heights.append(FLOORS.find(c))
				else:
					errors.append("the door cell (%d, %d) must be floor of the room's base height" % [x, y])
			elif c != MASONRY:
				errors.append("the wall cell (%d, %d) must be '%s'" % [x, y, MASONRY])
	if door_heights.is_empty():
		return
	base_height = door_heights[0]
	if door_heights.any(func(h: int) -> bool: return h != base_height):
		errors.append("the doors are not all at the same height")


func _read_heights() -> void:
	_heights.resize(ROWS * COLUMNS)
	_heights.fill(0)
	# Floors, lava, masonry and decks first; a pillar slot copies its west neighbour (resolved in
	# the same pass, left to right); stairs last, from the cell they climb toward.
	for y in ROWS:
		for x in COLUMNS:
			var cell := Vector2i(x, y)
			var c := cell_at(cell)
			if FLOORS.has(c):
				_heights[_index(cell)] = FLOORS.find(c)
			elif c == LAVA:
				_heights[_index(cell)] = LAVA_HEIGHT
			elif c == MASONRY:
				_heights[_index(cell)] = MASONRY_HEIGHT
			elif DECKS.has(c):
				_heights[_index(cell)] = DECKS[c]
			elif c == PILLAR:
				var west := cell + Vector2i.LEFT
				var wc := cell_at(west)
				if in_grid(west) and (FLOORS.has(wc) or DECKS.has(wc) or wc == PILLAR):
					_heights[_index(cell)] = _heights[_index(west)]
				else:
					errors.append("the pillar slot at (%d, %d) needs floor to its west" % [x, y])
	for y in ROWS:
		for x in COLUMNS:
			var cell := Vector2i(x, y)
			var c := cell_at(cell)
			if not STAIRS.has(c):
				continue
			var step: Vector2i = STAIRS[c]
			var target := cell + step
			while cell_at(target) == c:
				target += step
			var top := MASONRY_HEIGHT if STAIRS.has(cell_at(target)) else _heights[_index(target)]
			if top < 1 or top > MAX_HEIGHT:
				errors.append("the stair at (%d, %d) climbs to nothing" % [x, y])
			else:
				_heights[_index(cell)] = top - 1


func _index(cell: Vector2i) -> int:
	return cell.y * COLUMNS + cell.x


# --- cells -----------------------------------------------------------------------------------------------------------
## The character of a cell; outside the plan (or an unreadable plan) counts as masonry.
func cell_at(cell: Vector2i) -> String:
	if _cells.is_empty() or not in_grid(cell):
		return MASONRY
	return _cells[cell.y][cell.x]


## -1 for lava, the deck height for a bridge, the low end for a stair, 99 for masonry.
func height_at(cell: Vector2i) -> int:
	if _heights.is_empty() or not in_grid(cell):
		return MASONRY_HEIGHT
	return _heights[_index(cell)]


func is_stair(cell: Vector2i) -> bool:
	return STAIRS.has(cell_at(cell))


func is_lava(cell: Vector2i) -> bool:
	return cell_at(cell) == LAVA


## How many rows of cliff face are drawn in this cell: the drop from the cell north of it, when
## that is a floor, a pillar slot or a stair (its low end). Stairs, decks and masonry never show one.
func face_rows(cell: Vector2i) -> int:
	var c := cell_at(cell)
	if not (FLOORS.has(c) or c == LAVA or c == PILLAR):
		return 0
	var north := cell + Vector2i.UP
	var n := cell_at(north)
	if not in_grid(north) or not (FLOORS.has(n) or n == PILLAR or STAIRS.has(n)):
		return 0
	return maxi(height_at(north) - height_at(cell), 0)


## True when an actor on `level` may stand on this cell: floor of that height that is not a face,
## a deck of that height, or a stair at either of its levels. Lava, masonry and pillar slots never.
func is_walkable(cell: Vector2i, level: int) -> bool:
	var c := cell_at(cell)
	var h := height_at(cell)
	if STAIRS.has(c):
		return level == h or level == h + 1
	if DECKS.has(c):
		return level == h
	if FLOORS.has(c):
		return level == h and face_rows(cell) == 0
	return false


## A cell fit for an enemy or a prop: walkable at its own height, not a face, not a stair, no lava
## in the 8 cells around it.
func spawn_ok(cell: Vector2i) -> bool:
	var h := height_at(cell)
	if h < 0 or h > MAX_HEIGHT or is_stair(cell) or not is_walkable(cell, h):
		return false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if is_lava(cell + Vector2i(dx, dy)):
				return false
	return true


## Level -> the inner cells walkable at that level (a stair is in both of its levels). The ring
## (wall and doors) is left out: it belongs to Room.
func level_regions() -> Dictionary:
	var regions := {}
	for level in range(MAX_HEIGHT + 1):
		var cells: Array[Vector2i] = []
		for y in range(1, ROWS - 1):
			for x in range(1, COLUMNS - 1):
				if is_walkable(Vector2i(x, y), level):
					cells.append(Vector2i(x, y))
		regions[level] = cells
	return regions


# --- stairs ------------------------------------------------------------------------------------------------------------
## Stair zones: adjacent stair cells of the same direction and low level merged into one rectangle,
## `{cells: Rect2i, direction: Vector2i, low_level: int}`.
func stairs() -> Array[Dictionary]:
	var zones: Array[Dictionary] = []
	var used := {}
	for y in ROWS:
		for x in COLUMNS:
			var cell := Vector2i(x, y)
			if used.has(cell) or not is_stair(cell):
				continue
			var same := func(other: Vector2i) -> bool:
				return not used.has(other) and cell_at(other) == cell_at(cell) and height_at(other) == height_at(cell)
			var rect := _grow(cell, same, used)
			zones.append({"cells": rect, "direction": STAIRS[cell_at(cell)], "low_level": height_at(cell)})
	return zones


## The widest run of matching cells east of `cell`, then as many matching rows below it; marks them used.
func _grow(cell: Vector2i, matches: Callable, used: Dictionary) -> Rect2i:
	var width := 1
	while matches.call(Vector2i(cell.x + width, cell.y)):
		width += 1
	var height := 1
	while _row_matches(Vector2i(cell.x, cell.y + height), width, matches):
		height += 1
	for yy in height:
		for xx in width:
			used[cell + Vector2i(xx, yy)] = true
	return Rect2i(cell, Vector2i(width, height))


func _row_matches(start: Vector2i, width: int, matches: Callable) -> bool:
	for xx in width:
		if not matches.call(start + Vector2i(xx, 0)):
			return false
	return true


# --- collision -----------------------------------------------------------------------------------------------------
## The cells of the inner plan that need a body on `layer`, merged into rectangles in room pixels
## (greedy row runs merged downward, as RuinShape does). The ring is Room's own wall.
func collision_rects(layer: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if _cells.is_empty():
		return rects
	var used := {}
	var member := func(cell: Vector2i) -> bool:
		return is_inner(cell) and not used.has(cell) and _on_layer(cell, layer)
	for y in range(1, ROWS - 1):
		for x in range(1, COLUMNS - 1):
			var cell := Vector2i(x, y)
			if not member.call(cell):
				continue
			var rect := _grow(cell, member, used)
			rects.append(Rect2(Vector2(rect.position) * TILE, Vector2(rect.size) * TILE))
	return rects


func _on_layer(cell: Vector2i, layer: int) -> bool:
	var c := cell_at(cell)
	match layer:
		WORLD_LAYER:
			return c == MASONRY
		LAVA_LAYER:
			return c == LAVA
		BLOCK_LEVEL_0_LAYER:
			if c == MASONRY:
				return false
			if c == LAVA:
				# Lava already stops level 0 on its own layer; here only the cliff of a platform over it.
				return face_rows(cell) > 0 and height_at(cell + Vector2i.UP) >= 1
			return not _passable(cell, 0)
		BLOCK_LEVEL_1_LAYER:
			return c != MASONRY and not _passable(cell, 1)
		BLOCK_LEVEL_2_LAYER:
			return c != MASONRY and not _passable(cell, 2)
		HEIGHT_2_LAYER:
			return c != MASONRY and height_at(cell) == MAX_HEIGHT
	return false


## Whether the cell needs no body on `level`'s layer: walkable there, a pillar slot of that height
## (its prop brings its own body) or the middle of a raised deck seen from below (only the ends,
## where the supports stand, block the actors under it).
func _passable(cell: Vector2i, level: int) -> bool:
	var c := cell_at(cell)
	var h := height_at(cell)
	if c == PILLAR:
		return level == h
	if DECKS.has(c) and h > 0 and level < h:
		return not _is_deck_end(cell)
	return is_walkable(cell, level)


## An end of a raised deck: the deck runs along the axis its neighbours of the same kind lie on, and
## its ends are the cells with no such neighbour on one side along it. A lone cell is an end.
func _is_deck_end(cell: Vector2i) -> bool:
	var c := cell_at(cell)
	var axis := Vector2i.RIGHT if cell_at(cell + Vector2i.LEFT) == c or cell_at(cell + Vector2i.RIGHT) == c else Vector2i.DOWN
	return cell_at(cell + axis) != c or cell_at(cell - axis) != c


# --- validation ------------------------------------------------------------------------------------------------------
## The problems of the design (empty when the plan is fine): every door reaches every other at base
## height (walking, changing level only on stairs), every stair has a free cell at both ends, the
## floor is not a plain rectangle, the center cross stays passable and, for a surge room, every
## level-0 cell is near a stair up and the safe level is big enough.
func validate(surge_stages := 0) -> Array[String]:
	if not errors.is_empty():
		return errors.duplicate()
	var problems: Array[String] = []
	var reached := _reach_from_doors()
	_check_doors(reached, problems)
	_check_stairs(problems)
	_check_relief(problems)
	_check_lanes(reached, problems)
	if surge_stages >= 1:
		_check_surge(surge_stages, problems)
	return problems


## BFS over (cell, level) from the north door at base height: a step onto a neighbour that is
## walkable at the current level, or a change of level on a stair cell.
func _reach_from_doors() -> Dictionary:
	var visited := {}
	var queue: Array[Vector3i] = []
	for cell in door_cells()["north"]:
		if is_walkable(cell, base_height):
			queue.append(Vector3i(cell.x, cell.y, base_height))
			visited[queue.back()] = true
	var head := 0
	while head < queue.size():
		var state := queue[head]
		head += 1
		var cell := Vector2i(state.x, state.y)
		var level := state.z
		var next: Array[Vector3i] = []
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = cell + dir
			if is_walkable(n, level):
				next.append(Vector3i(n.x, n.y, level))
		if is_stair(cell):
			var other := height_at(cell) + 1 if level == height_at(cell) else height_at(cell)
			next.append(Vector3i(cell.x, cell.y, other))
		for state2 in next:
			if not visited.has(state2):
				visited[state2] = true
				queue.append(state2)
	return visited


func _check_doors(reached: Dictionary, problems: Array[String]) -> void:
	var doors := door_cells()
	for name in DOOR_NAMES:
		var cells: Array[Vector2i] = doors[name]
		if not cells.any(func(c: Vector2i) -> bool: return reached.has(Vector3i(c.x, c.y, base_height))):
			problems.append("the %s door cannot be reached from the north door" % name)


func _check_stairs(problems: Array[String]) -> void:
	for zone in stairs():
		var rect: Rect2i = zone["cells"]
		var dir: Vector2i = zone["direction"]
		var low: int = zone["low_level"]
		var low_free := false
		var high_free := false
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				low_free = low_free or (not is_stair(cell - dir) and is_walkable(cell - dir, low))
				high_free = high_free or (not is_stair(cell + dir) and is_walkable(cell + dir, low + 1))
		if not low_free:
			problems.append("the stair at (%d, %d) has no free cell at its low end" % [rect.position.x, rect.position.y])
		if not high_free:
			problems.append("the stair at (%d, %d) has no free cell at its high end" % [rect.position.x, rect.position.y])


## No plain rectangle: enough of the inner cells are something other than base-height floor.
func _check_relief(problems: Array[String]) -> void:
	var total := (ROWS - 2) * (COLUMNS - 2)
	var relief := 0
	for y in range(1, ROWS - 1):
		for x in range(1, COLUMNS - 1):
			var c := cell_at(Vector2i(x, y))
			if not (FLOORS.has(c) and FLOORS.find(c) == base_height):
				relief += 1
	if relief < ceili(total * MIN_RELIEF_SHARE):
		problems.append("the floor is a plain rectangle: %d of %d inner cells are not base-height floor, at least %d%% are needed"
				% [relief, total, roundi(MIN_RELIEF_SHARE * 100)])


## The center cross (the lane columns and the lane rows) is never cut: every column crosses the lane
## rows on some reachable cell and every row crosses the lane columns on one, at any level.
func _check_lanes(reached: Dictionary, problems: Array[String]) -> void:
	var cells := {}
	for state in reached:
		cells[Vector2i(state.x, state.y)] = true
	for x in range(1, COLUMNS - 1):
		if not range(LANE_FIRST_ROW, LANE_FIRST_ROW + LANE_WIDTH).any(func(y: int) -> bool: return cells.has(Vector2i(x, y))):
			problems.append("the lane rows are cut at x=%d" % x)
	for y in range(1, ROWS - 1):
		if not range(LANE_FIRST_COLUMN, LANE_FIRST_COLUMN + LANE_WIDTH).any(func(x: int) -> bool: return cells.has(Vector2i(x, y))):
			problems.append("the lane columns are cut at y=%d" % y)


## A surge floods level 0 (and level 1 with two stages): every level-0 cell needs a stair up close
## by and the level left safe needs room to fight on.
func _check_surge(surge_stages: int, problems: Array[String]) -> void:
	if base_height != 0:
		problems.append("a surge room must have base height 0, not %d" % base_height)
	var regions := level_regions()
	var distances := _distances_to_stairs_up(regions[0])
	var farthest := Vector2i(-1, -1)
	var worst := 0
	var stranded := Vector2i(-1, -1)
	for cell in regions[0]:
		var d: int = distances.get(cell, -1)
		if d < 0:
			stranded = cell if stranded.x < 0 else stranded
		elif d > worst:
			worst = d
			farthest = cell
	if stranded.x >= 0:
		problems.append("level-0 cell (%d, %d) cannot reach any stair up" % [stranded.x, stranded.y])
	elif worst > Tuning.TEMPLE_SURGE_MAX_STAIR_DISTANCE:
		problems.append("level-0 cell (%d, %d) is %d steps from the nearest stair up, more than %d"
				% [farthest.x, farthest.y, worst, Tuning.TEMPLE_SURGE_MAX_STAIR_DISTANCE])
	var safe := 1 if surge_stages == 1 else MAX_HEIGHT
	var biggest := _biggest_region(regions[safe], safe)
	if biggest < SURGE_MIN_SAFE_CELLS:
		problems.append("the safe level %d has %d connected walkable cells, at least %d are needed" % [safe, biggest, SURGE_MIN_SAFE_CELLS])


## Steps over level-0 cells from the nearest stair whose low end is level 0 (multi-source BFS).
func _distances_to_stairs_up(cells: Array[Vector2i]) -> Dictionary:
	var distances := {}
	var queue: Array[Vector2i] = []
	for cell in cells:
		if is_stair(cell) and height_at(cell) == 0:
			distances[cell] = 0
			queue.append(cell)
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = cell + dir
			if not distances.has(n) and is_inner(n) and is_walkable(n, 0):
				distances[n] = distances[cell] + 1
				queue.append(n)
	return distances


## The most cells of `level` in one connected region; stairs connect but are not counted (their low
## half is flooded).
func _biggest_region(cells: Array[Vector2i], level: int) -> int:
	var seen := {}
	var biggest := 0
	for start in cells:
		if seen.has(start):
			continue
		var queue: Array[Vector2i] = [start]
		seen[start] = true
		var head := 0
		var count := 0
		while head < queue.size():
			var cell := queue[head]
			head += 1
			if not is_stair(cell):
				count += 1
			for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var n: Vector2i = cell + dir
				if not seen.has(n) and is_inner(n) and is_walkable(n, level):
					seen[n] = true
					queue.append(n)
		biggest = maxi(biggest, count)
	return biggest
