class_name RuinShape
extends Node2D
## The irregular floor plan of a room of the Ruinas, described as text (one character per 16 px cell)
## so a room is a plateau with its own outline, a river with its curves and a bridge, not a rectangle:
##
##   #  rock: solid, drawn as a mass of rock with columns along its edge
##   .  stone floor
##   ~  water: a river or pool (bodies cannot cross it, arrows fly over)
##   =  bridge planks over the water (walkable)
##   r  parapet of a bridge (solid)
##   w  a waterfall down a wall (solid, drawn instead of rock: its top, falling water, its foot)
##
## The outermost ring of cells is the room's own wall (see Room) and is always rock here; the doors
## are gaps in it that this plan never touches. The map has 18 rows of 30 characters.
## Collision is built by merging cells into rectangles; the pictures are tile layers (rock mass,
## water with its shore, planks) plus the columns of the rock edge, y-sorted with the actors.

@export_multiline var rows := ""

const COLUMNS := 30
const ROWS := 18
const WORLD_BITS := 1
const WATER_BITS := 1 << (Heights.WATER_LAYER - 1)
const ROCK := "#"
const FLOOR := "."
const WATER := "~"
const PLANKS := "="
const PARAPET := "r"
const FALL := "w"
## Seconds each frame of the water's shimmer lasts.
const WATER_FRAME_SECONDS := 0.45

var _cells: Array[String] = []
var _water_layers: Array[TileMapLayer] = []
var _water_time := 0.0


const RUINS_PROFILE := "res://data/tilesets/ruins.tres"


func _ready() -> void:
	y_sort_enabled = true
	# A room opened on its own (the editor, a test) has no theme to activate the ruins' tileset.
	if not TileArt.profile().tiles.has(&"rock_mass_a"):
		TileArt.use_profile(load(RUINS_PROFILE))
	_cells.clear()
	for line in rows.strip_edges().split("\n"):
		_cells.append(line.strip_edges())
	if _cells.size() != ROWS or _cells.any(func(line: String) -> bool: return line.length() != COLUMNS):
		push_error("RuinShape needs %d rows of %d characters." % [ROWS, COLUMNS])
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(global_position))
	_build_rock_mass()
	_build_floor_detail(rng)
	_build_water()
	_build_deck()
	_build_waterfalls()
	_build_collision()
	_build_rock_edge(rng)


func _process(delta: float) -> void:
	if _water_layers.size() < 3:
		return
	_water_time += delta
	var frame := int(_water_time / WATER_FRAME_SECONDS) % 3
	_water_layers[1].visible = frame == 1
	_water_layers[2].visible = frame == 2


## The character of a cell; outside the plan counts as rock.
func cell_at(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= COLUMNS or cell.y >= ROWS:
		return ROCK
	return _cells[cell.y][cell.x]


func is_rock(cell: Vector2i) -> bool:
	return cell_at(cell) == ROCK


func is_water(cell: Vector2i) -> bool:
	return cell_at(cell) == WATER


## True for a cell that can be walked on (floor, planks).
func is_walkable(cell: Vector2i) -> bool:
	var c := cell_at(cell)
	return c == FLOOR or c == PLANKS


# --- pictures -----------------------------------------------------------------------------------------------------
func _new_layer(layer_name: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.z_index = RoomTheme.FLOOR_Z
	TileArt.prepare_layer(layer)
	add_child(layer)
	return layer


## The interior cell a border cell leans on (a corner leans on the corner of the interior).
func _inward(cell: Vector2i) -> Vector2i:
	return Vector2i(clampi(cell.x, 1, COLUMNS - 2), clampi(cell.y, 1, ROWS - 2))


## True for a border cell of the room whose wall must not be drawn on its own: the rock of the plan
## continues into it, so the cliff has no straight line where the room ends.
func hides_wall_at(cell: Vector2i) -> bool:
	if _cells.size() != ROWS:
		return false
	var on_border := cell.x == 0 or cell.y == 0 or cell.x == COLUMNS - 1 or cell.y == ROWS - 1
	return on_border and _cells[_inward(cell).y][_inward(cell).x] == ROCK


## The floor is not one stone: soft drifts of darker and paler slabs, a few big flagstones and patches of
## worn, mossy or broken floor (holes with dark ground, fallen stones). Only decoration (nothing here
## has collision) and never over the cross of lanes that joins the doors, so the way stays plain.
func _build_floor_detail(rng: RandomNumberGenerator) -> void:
	var layer := _new_layer("FloorDetail")
	var used := {}
	var drift := FastNoiseLite.new()
	drift.seed = rng.randi()
	drift.frequency = Tuning.RUIN_FLOOR_DRIFT_FREQUENCY
	for y in range(1, ROWS - 1):
		for x in range(1, COLUMNS - 1):
			var cell := Vector2i(x, y)
			if cell_at(cell) != FLOOR:
				continue
			var n := drift.get_noise_2d(x, y)
			if n > Tuning.RUIN_FLOOR_DIM_THRESHOLD:
				layer.set_cell(cell, 0, TileArt.coords([&"floor_dim_a", &"floor_dim_b"][rng.randi() % 2]))
			elif n < -Tuning.RUIN_FLOOR_DIM_THRESHOLD:
				layer.set_cell(cell, 0, TileArt.coords([&"floor_pale_a", &"floor_pale_b"][rng.randi() % 2]))
	_place_slabs(layer, rng, used)
	var kinds := [&"broken", &"worn", &"mossy"]
	var zones := rng.randi_range(Tuning.RUIN_FLOOR_ZONES_MIN, Tuning.RUIN_FLOOR_ZONES_MAX)
	for i in zones:
		_place_zone(layer, rng, used, kinds[i % kinds.size()])


## True for the cells of the cross that joins the doors (kept free of broken floor).
func _in_lanes(cell: Vector2i) -> bool:
	return absi(cell.x - COLUMNS / 2) <= 2 or absi(cell.y - ROWS / 2) <= 2


func _place_slabs(layer: TileMapLayer, rng: RandomNumberGenerator, used: Dictionary) -> void:
	for attempt in Tuning.RUIN_FLOOR_SLAB_TRIES:
		var cell := Vector2i(rng.randi_range(2, COLUMNS - 4), rng.randi_range(2, ROWS - 4))
		var block := [cell, cell + Vector2i.RIGHT, cell + Vector2i.DOWN, cell + Vector2i.ONE]
		if block.any(func(c: Vector2i) -> bool: return cell_at(c) != FLOOR or used.has(c) or _in_lanes(c)):
			continue
		var set_name: String = ["a", "b", "c"][rng.randi() % 3]
		for k in 4:
			used[block[k]] = true
			layer.set_cell(block[k], 0, TileArt.coords(StringName("floor_slab_%s_%s" % [set_name, ["tl", "tr", "bl", "br"][k]])))


func _place_zone(layer: TileMapLayer, rng: RandomNumberGenerator, used: Dictionary, kind: StringName) -> void:
	var center := Vector2i(rng.randi_range(3, COLUMNS - 4), rng.randi_range(3, ROWS - 4))
	var radius := rng.randf_range(Tuning.RUIN_FLOOR_ZONE_RADIUS_MIN, Tuning.RUIN_FLOOR_ZONE_RADIUS_MAX)
	for y in range(center.y - 5, center.y + 6):
		for x in range(center.x - 5, center.x + 6):
			var cell := Vector2i(x, y)
			if cell_at(cell) != FLOOR or used.has(cell):
				continue
			var reach := Vector2(cell - center).length() / radius + rng.randf_range(-0.25, 0.25)
			if reach > 1.0:
				continue
			var tile := _zone_tile(kind, reach, _in_lanes(cell), rng)
			if tile != &"":
				layer.set_cell(cell, 0, TileArt.coords(tile))


func _zone_tile(kind: StringName, reach: float, in_lanes: bool, rng: RandomNumberGenerator) -> StringName:
	var roll := rng.randf()
	match kind:
		&"worn":
			if roll < 0.5:
				return [&"floor_cracked_a", &"floor_cracked_b", &"floor_cracked_c"][rng.randi() % 3]
			return &"floor_rubbled_a" if roll < 0.6 and not in_lanes else &""
		&"mossy":
			if roll < 0.6:
				return [&"floor_moss_b", &"floor_moss_c", &"floor_moss"][rng.randi() % 3]
			return &""
		_:
			if in_lanes:
				return [&"floor_cracked_a", &"floor_cracked_c"][rng.randi() % 2] if roll < 0.4 else &""
			if reach < 0.5 and roll < 0.7:
				return [&"floor_debris_a", &"floor_debris_b"][rng.randi() % 2]
			if roll < 0.55:
				return [&"floor_broken_a", &"floor_broken_b", &"floor_broken_c", &"floor_rubbled_b"][rng.randi() % 4]
			return &""


## Rock mass over the floor on every rock cell of the plan, and over the border cells the rock leans on.
func _build_rock_mass() -> void:
	var layer := _new_layer("RockMass")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["mass", Vector2i(global_position)])
	var tiles: Array[Vector2i] = [TileArt.coords(&"rock_mass_a"), TileArt.coords(&"rock_mass_b"),
			TileArt.coords(&"rock_mass_dark"), TileArt.coords(&"rock_mass_dark")]
	for y in ROWS:
		for x in COLUMNS:
			var cell := Vector2i(x, y)
			var inside := x > 0 and y > 0 and x < COLUMNS - 1 and y < ROWS - 1
			if (inside and _cells[y][x] == ROCK) or hides_wall_at(cell):
				layer.set_cell(cell, 0, tiles[rng.randi_range(0, tiles.size() - 1)])


## Water with its shore: the edges and corners round themselves (TileArt.blob_tile); the middle cells
## are repeated on two more layers that take turns, so the water shimmers.
func _build_water() -> void:
	var base := _new_layer("Water")
	var shimmer_b := _new_layer("WaterB")
	var shimmer_c := _new_layer("WaterC")
	_water_layers = [base, shimmer_b, shimmer_c]
	var inside := func(cell: Vector2i) -> bool:
		# Planks and parapets lie over the river, and a waterfall pours into it: they count as water
		# for its shore.
		var c := cell_at(cell)
		return c == WATER or c == PLANKS or c == PARAPET or c == FALL
	var center := TileArt.coords(&"pond_4")
	for y in range(1, ROWS - 1):
		for x in range(1, COLUMNS - 1):
			var cell := Vector2i(x, y)
			if not inside.call(cell):
				continue
			var tile := TileArt.blob_tile(&"pond", &"pond_inner", inside, cell)
			base.set_cell(cell, 0, tile)
			if tile == center:
				shimmer_b.set_cell(cell, 0, TileArt.coords(&"pond_center_b"))
				shimmer_c.set_cell(cell, 0, TileArt.coords(&"pond_center_c"))
	shimmer_b.visible = false
	shimmer_c.visible = false


## Planks across the river and the parapets at their sides.
func _build_deck() -> void:
	var layer := _new_layer("Deck")
	for y in range(1, ROWS - 1):
		for x in range(1, COLUMNS - 1):
			var cell := Vector2i(x, y)
			var c := cell_at(cell)
			if c != PLANKS and c != PARAPET:
				continue
			# The deck runs along the direction in which the river is not: planks run with the bridge.
			var along_x := is_water(cell + Vector2i.UP) or is_water(cell + Vector2i.DOWN) \
					or cell_at(cell + Vector2i.UP) == PARAPET or cell_at(cell + Vector2i.DOWN) == PARAPET
			var role: StringName
			if c == PLANKS:
				role = &"bridge_planks_h" if along_x else &"bridge_planks_v"
			else:
				role = &"bridge_rail_h" if along_x else &"bridge_rail_v"
			layer.set_cell(cell, 0, TileArt.coords(role))


## The falling water of the `w` cells: its top, the animated stream and its foot.
func _build_waterfalls() -> void:
	var holder := Node2D.new()
	holder.name = "Waterfalls"
	holder.z_index = RoomTheme.FLOOR_Z
	add_child(holder)
	for y in range(1, ROWS - 1):
		for x in range(1, COLUMNS - 1):
			var cell := Vector2i(x, y)
			if cell_at(cell) != FALL:
				continue
			var at := Vector2(cell * TileArt.TILE)
			if cell_at(cell + Vector2i.UP) != FALL:
				holder.add_child(TileArt.sprite(&"waterfall_top", at))
			elif cell_at(cell + Vector2i.DOWN) == FALL:
				holder.add_child(RuinAnim.sprite([&"waterfall_mid_a", &"waterfall_mid_b", &"waterfall_mid_c"], 6.0, at))
			else:
				holder.add_child(RuinAnim.sprite([&"waterfall_base_a", &"waterfall_base_b", &"waterfall_base_c"], 6.0, at))


# --- collision ---------------------------------------------------------------------------------------------------------
## Rock and parapets stop everybody, water stops bodies (not arrows): cells merged into rectangles.
func _build_collision() -> void:
	for group in [[[ROCK, PARAPET, FALL], WORLD_BITS], [[WATER], WATER_BITS]]:
		var kinds: Array = group[0]
		var used := {}
		for y in range(1, ROWS - 1):
			for x in range(1, COLUMNS - 1):
				var cell := Vector2i(x, y)
				if used.has(cell) or not kinds.has(cell_at(cell)):
					continue
				var width := 1
				while x + width < COLUMNS - 1 and not used.has(Vector2i(x + width, y)) and kinds.has(cell_at(Vector2i(x + width, y))):
					width += 1
				var height := 1
				while y + height < ROWS - 1 and _row_matches(kinds, used, x, y + height, width):
					height += 1
				for yy in height:
					for xx in width:
						used[Vector2i(x + xx, y + yy)] = true
				_collide(Rect2(Vector2(x, y) * TileArt.TILE, Vector2(width, height) * TileArt.TILE), group[1])


func _row_matches(kinds: Array, used: Dictionary, x: int, y: int, width: int) -> bool:
	for xx in width:
		var cell := Vector2i(x + xx, y)
		if used.has(cell) or not kinds.has(cell_at(cell)):
			return false
	return true


func _collide(rect: Rect2, layer_bits: int) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = layer_bits
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.position = rect.get_center()
	body.add_child(shape)
	add_child(body)


# --- the edge of the rock ------------------------------------------------------------------------------------------
## Columns standing along every edge where rock meets floor or water: two staggered rows where the
## rock lies north of the floor (nobody walks behind them: baked into one picture), single y-sorted
## columns elsewhere, so the outline of the plan reads as cliffs of different heights.
func _build_rock_edge(rng: RandomNumberGenerator) -> void:
	var tile := float(TileArt.TILE)
	var back: Array[Vector2] = []
	var singles: Array[Vector2] = []
	for y in range(1, ROWS - 1):
		for x in range(1, COLUMNS - 1):
			var cell := Vector2i(x, y)
			if not is_rock(cell):
				continue
			var x0 := x * tile
			var bottom := (y + 1) * tile - 1.0
			var open_south := not is_rock(cell + Vector2i.DOWN)
			var open_north := not is_rock(cell + Vector2i.UP)
			var open_west := not is_rock(cell + Vector2i.LEFT)
			var open_east := not is_rock(cell + Vector2i.RIGHT)
			if open_south:
				singles.append_array(RockWall.feet_along(Vector2(x0, bottom), Vector2(x0 + tile, bottom), rng))
			elif open_north:
				# The far edge of a rock mass seen from the floor north of it: two rows baked together.
				back.append_array(RockWall.feet_along(Vector2(x0, y * tile + tile * 0.5), Vector2(x0 + tile, y * tile + tile * 0.5), rng))
				back.append_array(RockWall.feet_along(Vector2(x0 + Tuning.ROCK_WALL_STEP / 2.0, bottom), Vector2(x0 + tile, bottom), rng))
			if open_west or open_east:
				var edge_x := x0 + (tile * 0.25 if open_west else tile * 0.75)
				singles.append_array(RockWall.feet_along(Vector2(edge_x, y * tile), Vector2(edge_x, y * tile + tile), rng))
	var rocks := Node2D.new()
	rocks.name = "Rocks"
	rocks.y_sort_enabled = true
	add_child(rocks)
	if not back.is_empty():
		var row := RockWall.baked_row(back, rng)
		row.name = "BackRow"
		rocks.add_child(row)
	for foot in singles:
		rocks.add_child(RockWall.column(foot, rng))
