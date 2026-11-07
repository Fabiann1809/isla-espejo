class_name TempleShape
extends Node2D
## The floor plan of a room of the Templo del Eclipse, drawn and made solid: a stone island with up to
## three height levels over a sea of lava. The plan is text (`rows`, see TemplePlan for the alphabet)
## and this node, named `Shape` in the room scene, turns it into pictures, bodies, stairs and props.
##
## Pictures are tile layers at the floor's z, bottom to top: the animated lava (the sea's macro,
## picked by WORLD tile through `LavaBackdrop.lava_animation`, at `LavaBackdrop.SEA_Z` like every
## lava of the map, so the room's lava and the sea around it are one body with no seam at the room's
## rectangle and the backdrop's drifting plates and crust lie over both) with bubbles bursting at
## random over a few cells; the cliff faces on the
## south side of every drop (one row per level, moss on some, the foot lit by the lava where it
## stands in it); the floor of every level in its own stone (macro plans of slabs) with moss, cracks
## and glowing runes off the door lanes; the crust rims on the lava around every island, their cracks
## pulsing; the lit lip of every raised edge; the shadows the platforms cast south and east; the
## stairs' steps (with a balustrade on the open sides of a flight) and the bridges' decks. A `#`
## masonry cell inside the room is a built wall: a capped top (`masonry_cap` blob) and a carved front
## (`masonry_face*`, lit by the lava where it stands in it). Rails and posts stand upright, y-sorted
## with the actors at z 0, so Nico walks behind a bridge's near parapet. Pillars (`p` cells), a
## brazier at each top corner of every flight of stairs, lava lights along the rims and ember vents
## on the lava are props of the room. The room's own wall (the outer ring) is drawn as lava: the
## island floats, and `hides_wall_at` is true for every wall cell so no wall art is planted there.
## Every extra of this kind has its switch in `Tuning` (`TEMPLE_MASONRY_ART`, `TEMPLE_*_SHADOWS`,
## `TEMPLE_STAIR_WALLS`, `TEMPLE_STAIR_TOP_BRAZIERS`).
##
## Physics come from the plan alone (`TemplePlan.collision_rects`, one body per layer) plus one
## StairZone per flight; nothing here depends on the pictures.

@export_multiline var rows := ""

const TEMPLE_PROFILE := "res://data/tilesets/temple.tres"
const TILE := TemplePlan.TILE
const MACRO := 4
const LAYER_NAMES := ["Lava", "Bubbles", "LavaShadows", "Faces", "Floor0", "Floor1", "Floor2", "FloorDetail", "Rims", "RimGlow",
		"Ledges", "Shadows", "ShadowsEast", "Stairs", "Bridges"]
const COLLISION_LAYERS: Array[int] = [TemplePlan.WORLD_LAYER, TemplePlan.LAVA_LAYER, TemplePlan.BLOCK_LEVEL_0_LAYER,
		TemplePlan.BLOCK_LEVEL_1_LAYER, TemplePlan.BLOCK_LEVEL_2_LAYER, TemplePlan.HEIGHT_2_LAYER]
const CARDINALS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
## Animations whose cells start in step (the lava sea must flow as one); every other one starts at a
## random frame so neighbours never blink together.
const IN_STEP_PREFIX := "lava_m_"

var plan: TemplePlan

var _rng: RandomNumberGenerator
## Cell covered by a cliff face -> {kind (tile prefix or "foot"), side ("l", "m", "r"), on_floor,
## owner (the height of the plateau that casts it)}.
var _faces := {}
## Per-cell caches filled once by _cache_cells (index y * columns + x): whether a ring cell is the
## room's wall, and the art height of every cell. Big rooms ask both many times per cell.
var _wall_cache := PackedByteArray()
var _art_cache := PackedInt32Array()
var _caches_ready := false
var _layers := {}
var _rim_cells: Array[Vector2i] = []

## Profile path -> a TileSet of the profile's sheet whose animated tiles play their frames.
static var _tile_sets := {}
static var _ember_texture: Texture2D


func _ready() -> void:
	y_sort_enabled = true
	# A room opened on its own (the editor, a test) has no theme to activate the temple's tileset.
	if not TileArt.profile().tiles.has(&"lava_m_0_0"):
		TileArt.use_profile(load(TEMPLE_PROFILE))
	plan = TemplePlan.parse(rows)
	var mismatch := size_problem(plan, get_parent())
	if mismatch != "":
		plan.errors.append(mismatch)
	if not plan.errors.is_empty():
		push_error("TempleShape: %s" % ", ".join(plan.errors))
		return
	_rng = RandomNumberGenerator.new()
	_rng.seed = hash(Vector2i(global_position))
	_cache_cells()
	for layer_name in LAYER_NAMES:
		_layers[layer_name] = _new_layer(layer_name, LavaBackdrop.SEA_Z if layer_name == "Lava" else RoomTheme.FLOOR_Z)
	_layers["LavaShadows"].z_index = LavaBackdrop.SEA_Z + 1
	_apply_modulates()
	_find_faces()
	_build_lava()
	_build_faces()
	_build_floors()
	_build_rims()
	_build_ledges()
	_build_shadows()
	_build_stairs()
	_build_bridges()
	_build_collision()
	_build_stair_zones()
	_build_pillars()
	_build_stair_braziers()
	_build_lights()
	_build_vents()


## Tuning's darkening of the lava and floor layers (Color.WHITE = off).
func _apply_modulates() -> void:
	for layer_name in ["Lava", "Bubbles"]:
		_layers[layer_name].modulate = Tuning.TEMPLE_LAVA_MODULATE
	for layer_name in ["Floor0", "Floor1", "Floor2", "Stairs", "Bridges"]:
		_layers[layer_name].modulate = Tuning.TEMPLE_FLOOR_MODULATE


## The plan's size must be its room's: "" when they agree (or the plan is unreadable, which reports
## itself, or `room` is not a Room), else the message `_ready` raises.
static func size_problem(plan: TemplePlan, room: Node) -> String:
	if plan == null or not plan.errors.is_empty() or room == null or not "size_tiles" in room:
		return ""
	var wanted: Vector2i = room.size_tiles
	if plan.size_cells() == wanted:
		return ""
	return "the plan is %d x %d cells but its room is %d x %d tiles (RoomData.size_tiles)" 			% [plan.columns, plan.rows, wanted.x, wanted.y]


## True for a border cell that is the room's wall (not an open door's gap): the island's edge drops
## into lava there, so the room must plant no wall art on it.
func hides_wall_at(cell: Vector2i) -> bool:
	return plan != null and plan.errors.is_empty() and _is_wall(cell)


## The island's cells (room tiles): everything of the plan that is not lava or the wall ring (floors,
## stairs, masonry, pillar slots, decks). The sea measures its crust from them, never from the
## room's rectangle.
func island_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if plan == null or not plan.errors.is_empty():
		return cells
	for y in plan.rows:
		for x in plan.columns:
			var cell := Vector2i(x, y)
			if not _is_wall(cell) and plan.cell_at(cell) != TemplePlan.LAVA:
				cells.append(cell)
	return cells


# --- reading the plan for the pictures ----------------------------------------------------------------
## A wall cell of the outer ring: every border cell but the gaps of the open doors (the room knows
## which are open; without a room, the plan's door cells).
## Fills the wall and art-height caches once the plan is known (the room is already the parent, so
## its open doors decide the ring). Same answers as the uncached functions, computed once per cell.
func _cache_cells() -> void:
	_caches_ready = false
	var count := plan.columns * plan.rows
	_wall_cache.resize(count)
	_art_cache.resize(count)
	# Both are filled with the cache off (art heights ask about walls and other cells), then switched on.
	for y in plan.rows:
		for x in plan.columns:
			var cell := Vector2i(x, y)
			_wall_cache[y * plan.columns + x] = 1 if _is_wall(cell) else 0
			_art_cache[y * plan.columns + x] = _art_height(cell)
	_caches_ready = true


func _is_wall(cell: Vector2i) -> bool:
	if not plan.in_grid(cell) or plan.is_inner(cell):
		return false
	if _caches_ready:
		return _wall_cache[cell.y * plan.columns + cell.x] == 1
	var parent := get_parent()
	if parent != null and parent.has_method("is_wall_cell"):
		return parent.is_wall_cell(cell)
	return not plan.is_door(cell)


## The height a cell shows: -1 for lava, the wall ring and the sea beyond the room; what lies under a
## deck; masonry is a block as tall as the top level; a stair shows its low end; else the plan's height.
func _art_height(cell: Vector2i) -> int:
	if _caches_ready and plan.in_grid(cell):
		return _art_cache[cell.y * plan.columns + cell.x]
	if not plan.in_grid(cell) or _is_wall(cell):
		return TemplePlan.LAVA_HEIGHT
	var c := plan.cell_at(cell)
	if c == TemplePlan.LAVA:
		return TemplePlan.LAVA_HEIGHT
	if c == TemplePlan.MASONRY:
		return TemplePlan.MAX_HEIGHT
	if TemplePlan.DECKS.has(c):
		return _under_deck_height(cell)
	return plan.height_at(cell)


## What a deck crosses: lava under a ground deck or a raised one with lava beside it, else the floor
## beside it (one level below the deck at most).
func _under_deck_height(cell: Vector2i) -> int:
	var h := plan.height_at(cell)
	if h <= 0:
		return TemplePlan.LAVA_HEIGHT
	var under := h - 1
	# Two literals in one ternary lose their type: the array is built from the chosen pair instead.
	var across: Array[Vector2i] = []
	across.assign([Vector2i.UP, Vector2i.DOWN] if _deck_along_x(cell) else [Vector2i.LEFT, Vector2i.RIGHT])
	for dir in across:
		var n := cell + dir
		var nc := plan.cell_at(n)
		if nc == TemplePlan.LAVA or _is_wall(n):
			return TemplePlan.LAVA_HEIGHT
		if TemplePlan.FLOORS.has(nc) or nc == TemplePlan.PILLAR:
			under = mini(under, plan.height_at(n))
	return under


func _is_deck(cell: Vector2i) -> bool:
	return TemplePlan.DECKS.has(plan.cell_at(cell))


## A deck runs west-east when its neighbours along x are deck too (a `=` always does, a `|` never).
func _deck_along_x(cell: Vector2i) -> bool:
	var c := plan.cell_at(cell)
	if c == "=":
		return true
	if c == "|":
		return false
	return _is_deck(cell + Vector2i.LEFT) or _is_deck(cell + Vector2i.RIGHT)


## Whether a cell is open lava for the rims and the rails: it shows lava and no face stands on it.
## A deck over lava counts as lava (the sea flows under it), so the rim never closes across a bridge.
func _is_open_lava(cell: Vector2i) -> bool:
	return _art_height(cell) < 0 and not _faces.has(cell)


## A cell that casts a face south when the cell below it is lower: floors, pillar slots, stairs (their
## low end) and masonry. Decks stand on supports and lava is flat.
func _casts_face(cell: Vector2i) -> bool:
	if _is_wall(cell) or not plan.in_grid(cell):
		return false
	var c := plan.cell_at(cell)
	return TemplePlan.FLOORS.has(c) or c == TemplePlan.PILLAR or TemplePlan.STAIRS.has(c) or c == TemplePlan.MASONRY


## A cell a face may extend onto with its second and third rows: lava or masonry of the lower height,
## where nothing walks, or a floor cell the plan itself reserves for a face (`face_rows` > 0). Plain
## floor the plan lets Nico stand on never takes a face row, so the art agrees with the physics.
func _takes_face_row(cell: Vector2i, below: int) -> bool:
	# The wall ring ends the room's physics, not its visible basalt foundation.
	if not plan.in_grid(cell):
		return below < 0
	if _art_height(cell) != below:
		return false
	var c := plan.cell_at(cell)
	if c == TemplePlan.LAVA or _is_wall(cell):
		return true
	return TemplePlan.FLOORS.has(c) and plan.face_rows(cell) > 0


## True for the cells of the cross of lanes that joins the doors (kept free of floor details).
func _in_lanes(cell: Vector2i) -> bool:
	return absi(cell.x - plan.columns / 2) <= 2 or absi(cell.y - plan.rows / 2) <= 2


## A `#` cell drawn as a built wall (cap and carved front) rather than a slab with a cliff.
func _is_masonry_art(cell: Vector2i) -> bool:
	return Tuning.TEMPLE_MASONRY_ART and plan.in_grid(cell) and not _is_wall(cell) \
			and plan.cell_at(cell) == TemplePlan.MASONRY


## The height of the block a cell belongs to, for the shadows: a face belongs to the plateau that
## casts it, anything else shows its own art height.
func _block_height(cell: Vector2i) -> int:
	if _faces.has(cell):
		return _faces[cell]["owner"]
	return _art_height(cell)


# --- faces -----------------------------------------------------------------------------------------------------------
## Every drop seen from the south: `h - below` rows of cliff under the plateau's edge (one per level),
## carved blocks with the ends outlined, moss on a share of them and, where the foot stands in lava,
## the lava's light climbing it. The receiving cells belong to the lower side.
func _find_faces() -> void:
	_faces.clear()
	for y in plan.rows:
		for x in plan.columns:
			var cell := Vector2i(x, y)
			if not _casts_face(cell):
				continue
			var h := _art_height(cell)
			var south := cell + Vector2i.DOWN
			# A stair south of the edge is the ramp down it: no face (its steps would hide one anyway).
			if not plan.in_grid(south) or TemplePlan.STAIRS.has(plan.cell_at(south)):
				continue
			var below := _art_height(south)
			if below >= h:
				continue
			var drop := h - below
			if below < 0:
				drop += Tuning.TEMPLE_LAVA_CLIFF_EXTRA_ROWS
			var same := func(nx: int) -> bool:
				return _art_height(Vector2i(nx, y)) == h and _art_height(Vector2i(nx, y + 1)) == below
			var side := "m"
			if not same.call(x - 1) and same.call(x + 1):
				side = "l"
			elif same.call(x - 1) and not same.call(x + 1):
				side = "r"
			var mossy := _rng.randf() < Tuning.TEMPLE_FACE_MOSS_SHARE
			# A masonry block shows a built wall's front; everything else a natural cliff.
			var prefix := "masonry_" if _is_masonry_art(cell) else "cliff_"
			# The first row always lands on the cell south; the others only where nothing walks (lava)
			# or where the plan reserves the face (see _takes_face_row).
			var cells: Array[Vector2i] = [south]
			for row in range(1, drop):
				var next := cell + Vector2i(0, 1 + row)
				if not _takes_face_row(next, below):
					break
				cells.append(next)
			var last := cells.size() - 1
			for row in cells.size():
				var into_lava := below < 0 and row == last
				var kind: String
				if cells.size() == 1:
					kind = "foot" if into_lava else (prefix + ("moss_" if mossy else "face_"))
				elif row == 0:
					kind = prefix + ("moss2_top_" if mossy else "face2_top_")
				elif row == last:
					kind = "foot" if into_lava else (prefix + ("moss2_bot_" if mossy else "face2_bot_"))
				else:
					kind = prefix + "face_mid_"
				_faces[cells[row]] = {"kind": kind, "side": side, "on_floor": row == last and not into_lava, "owner": h,
						"prefix": prefix}


# --- pictures ------------------------------------------------------------------------------------------------------
func _new_layer(layer_name: String, z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.z_index = z
	layer.tile_set = animated_tile_set()
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.scale = Vector2.ONE * TileArt.draw_scale()
	add_child(layer)
	return layer


## Paints a still tile. Animated roles must go through `_paint_animated`: the animated tile set only
## creates the first frame of an animation as a tile, so any other frame would paint nothing.
func _paint(layer_name: String, cell: Vector2i, role: StringName, alternative := 0) -> void:
	_layers[layer_name].set_cell(cell, 0, TileArt.coords(role), alternative)


## Paints an animated tile (the profile's animation name): its first frame, which plays the rest.
func _paint_animated(layer_name: String, cell: Vector2i, animation: StringName) -> void:
	var frames := TileArt.profile().animation(animation)
	if frames.is_empty():
		push_error("TempleShape: the profile has no animation '%s'" % animation)
		return
	_layers[layer_name].set_cell(cell, 0, frames[0])


## The lava sea under everything (the sea's own macro, by world tile, so the room's lava continues
## the sea around it) and bubbles bursting over a few open cells, each at its own moment.
func _build_lava() -> void:
	var origin := Vector2i((global_position / TILE).floor())
	for y in plan.rows:
		for x in plan.columns:
			var cell := Vector2i(x, y)
			_paint_animated("Lava", cell, LavaBackdrop.lava_animation(origin + cell))
			if _is_open_lava(cell) and not _is_deck(cell) and _rng.randf() < Tuning.TEMPLE_BUBBLE_SHARE:
				_paint_animated("Bubbles", cell, &"lava_bubble_over")


func _build_faces() -> void:
	for cell in _faces:
		var face: Dictionary = _faces[cell]
		if face["kind"] == "foot":
			_paint_animated("Faces", cell, StringName(face["prefix"] + "foot_lava_" + face["side"]))
		else:
			var role := StringName(face["kind"] + face["side"])
			if Tuning.TEMPLE_BASALT_VARIANTS and face["prefix"] == "cliff_" and not "moss" in face["kind"]:
				role = StringName("basalt_face_%d" % posmod(cell.x * 7 + cell.y * 3, 8))
			_paint("Faces", cell, role)


## The floor of every level in its own stone, cell (x, y) of the macro plan, and the details off the
## door lanes: moss, cracks (transparent overlays, so the slabs stay whole) and runes that glow.
func _build_floors() -> void:
	for y in plan.rows:
		for x in plan.columns:
			var cell := Vector2i(x, y)
			var h := _art_height(cell)
			if h < 0 or _faces.has(cell):
				continue
			if _is_masonry_art(cell):
				# A built wall's capped top: its rim follows the wall's outline (a 47-blob).
				_layers["Floor%d" % h].set_cell(cell, 0, TileArt.blob47_tile(&"masonry_cap", TileArt.blob_mask(_is_masonry_art, cell)))
				continue
			_paint("Floor%d" % h, cell, StringName("floor%d_m_%d_%d" % [h, x % MACRO, y % MACRO]))
			var c := plan.cell_at(cell)
			if not TemplePlan.FLOORS.has(c) or _in_lanes(cell) or _is_wall(cell):
				continue
			var roll := _rng.randf()
			if roll < Tuning.TEMPLE_FLOOR_MOSS_SHARE:
				var moss: StringName = &"moss_over_c" if h == 2 else [&"moss_over_a", &"moss_over_b"][_rng.randi() % 2]
				_paint("FloorDetail", cell, moss)
			elif roll < Tuning.TEMPLE_FLOOR_MOSS_SHARE + Tuning.TEMPLE_FLOOR_CRACK_SHARE:
				_paint("FloorDetail", cell, StringName("floor%d_crack_over_%s" % [h, ["a", "b"][_rng.randi() % 2]]))
			elif h > 0 and roll < Tuning.TEMPLE_FLOOR_MOSS_SHARE + Tuning.TEMPLE_FLOOR_CRACK_SHARE + Tuning.TEMPLE_FLOOR_RUNE_SHARE:
				_paint_animated("FloorDetail", cell, &"floor2_rune_glow" if h == 2 else &"floor_rune_glow")


## The cooled crust on every lava cell that touches an island or a cliff's foot (a 47-tile blob by the
## lava around it), with its cracks pulsing on the layer above. Never on a deck: the sea flows under it.
func _build_rims() -> void:
	_layers["Rims"].modulate.a = Tuning.TEMPLE_SHORE_CRUST_ALPHA
	_layers["RimGlow"].modulate.a = Tuning.TEMPLE_SHORE_CRACK_ALPHA
	var stone := {}
	for y in plan.rows:
		for x in plan.columns:
			var cell := Vector2i(x, y)
			if not _is_open_lava(cell) or _is_deck(cell):
				stone[cell] = true
	LavaBackdrop.paint_shore(_layers["Rims"], stone)
	_rim_cells.clear()
	for y in plan.rows:
		for x in plan.columns:
			var cell := Vector2i(x, y)
			if not _is_open_lava(cell) or _is_deck(cell):
				continue
			var mask := TileArt.blob_mask(_is_open_lava, cell)
			if mask == 255:
				continue
			_layers["Rims"].set_cell(cell, 0, TileArt.blob47_tile(&"lava_rim", mask))
			_paint_animated("RimGlow", cell, &"lava_rim_glow")
			_rim_cells.append(cell)


## The lit lip on the high side of every change of height: a neighbour counts as part of the block
## when it stands at the cell's level or higher, when it is the face of a plateau rising above it
## (never the face dropping from it), or when a deck continues the floor at that height. A masonry
## wall's cap brings its own rim.
func _build_ledges() -> void:
	for y in plan.rows:
		for x in plan.columns:
			var cell := Vector2i(x, y)
			var h := _art_height(cell)
			var c := plan.cell_at(cell)
			if h < 0 or _faces.has(cell) or _is_deck(cell) or TemplePlan.STAIRS.has(c) or _is_masonry_art(cell):
				continue
			var inside := func(n: Vector2i) -> bool:
				if not plan.in_grid(n):
					return true
				if _faces.has(n):
					return _faces[n]["owner"] > h
				if _is_deck(n):
					return plan.height_at(n) >= h
				return _art_height(n) >= h
			var mask := TileArt.blob_mask(inside, cell)
			if mask != 255:
				_layers["Ledges"].set_cell(cell, 0, TileArt.blob47_tile(&"ledge", mask))


## A platform's drop shadow on the lower floor: two bands south of a face that ends on floor (darkest
## against the cliff's foot, fading away from it) and a band east of every cell whose west neighbour
## belongs to a higher block, so the light from the upper left leaves every platform a shadow to its
## south and east. Never on lava, a face, a deck or a stair.
func _build_shadows() -> void:
	if Tuning.TEMPLE_DROP_SHADOWS:
		for cell in _faces:
			if _faces[cell]["kind"] == "foot":
				for distance in [1, 2]:
					var receiver: Vector2i = cell + Vector2i(0, distance)
					if _is_open_lava(receiver) and not _faces.has(receiver) and not _is_deck(receiver):
						_paint("LavaShadows", receiver, &"shadow_s_1" if distance == 1 else &"shadow_s_2")
			if not _faces[cell]["on_floor"]:
				continue
			for i in [1, 2]:
				var below: Vector2i = cell + Vector2i(0, i)
				if _shadow_fits(below):
					_paint("Shadows", below, &"shadow_s_1" if i == 1 else &"shadow_s_2")
	if not Tuning.TEMPLE_EAST_SHADOWS:
		return
	for y in plan.rows:
		for x in plan.columns:
			var cell := Vector2i(x, y)
			if _shadow_fits(cell) and _block_height(cell + Vector2i.LEFT) > _art_height(cell):
				_paint("ShadowsEast", cell, &"shadow_e_1")


## Floor someone walks on, where a shadow may lie.
func _shadow_fits(cell: Vector2i) -> bool:
	if not plan.in_grid(cell) or _art_height(cell) < 0 or _faces.has(cell) or _is_deck(cell):
		return false
	var c := plan.cell_at(cell)
	return (TemplePlan.FLOORS.has(c) or c == TemplePlan.PILLAR) and not _is_wall(cell)


## Steps on every stair cell, turned to climb toward the stair's arrow, with a balustrade on each
## side of the flight that no other cell of the same flight continues.
func _build_stairs() -> void:
	for y in plan.rows:
		for x in plan.columns:
			var cell := Vector2i(x, y)
			var c := plan.cell_at(cell)
			if not TemplePlan.STAIRS.has(c):
				continue
			var vertical := c == "^" or c == "v"
			var sides: Array = [[Vector2i.LEFT, "l"], [Vector2i.RIGHT, "r"]] if vertical else [[Vector2i.UP, "t"], [Vector2i.DOWN, "b"]]
			var walls := ""
			if Tuning.TEMPLE_STAIR_WALLS:
				for side in sides:
					var beside: Vector2i = cell + side[0]
					if not plan.in_grid(beside) or plan.cell_at(beside) != c:
						walls += side[1]
			var role := StringName(("stairs_up_steps" if vertical else "stairs_side_steps") + ("_" + walls if walls != "" else ""))
			match c:
				"^":
					_paint("Stairs", cell, role)
				"v":
					_paint("Stairs", cell, role, TileSetAtlasSource.TRANSFORM_FLIP_V)
				">":
					_paint("Stairs", cell, role)
				"<":
					_paint("Stairs", cell, role, TileSetAtlasSource.TRANSFORM_FLIP_H)


## Decks (wood on the ground, stone when raised) with rails where lava or a cliff lies beside them: the
## side rails of a north-south deck are tiles, the near and far parapets of a west-east deck and the
## posts at every end stand upright, y-sorted with the actors, so Nico walks behind the near one.
func _build_bridges() -> void:
	var rails := Node2D.new()
	rails.name = "Rails"
	rails.y_sort_enabled = true
	add_child(rails)
	for y in plan.rows:
		for x in plan.columns:
			var cell := Vector2i(x, y)
			if not _is_deck(cell):
				continue
			var material := "wood" if plan.height_at(cell) == 0 else "stone"
			var along_x := _deck_along_x(cell)
			_paint("Bridges", cell, StringName("bridge_%s_deck_%s" % [material, "h" if along_x else "v"]))
			var post: StringName = &"bridge_rope_post" if material == "wood" else &"bridge_stone_post"
			# Rope bridges need their posts; stone ones only when Tuning asks for them (square stone
			# posts on every shore read like scattered boxes).
			var posts := material == "wood" or Tuning.TEMPLE_BRIDGE_END_POSTS
			if along_x:
				for side in [[Vector2i.UP, "n"], [Vector2i.DOWN, "s"]]:
					var beside: Vector2i = cell + side[0]
					if _rail_fits(beside):
						rails.add_child(_standing(StringName("bridge_%s_rail_%s" % [material, side[1]]), beside))
				for end in [Vector2i.LEFT, Vector2i.RIGHT]:
					if _is_deck(cell + end):
						continue
					# A post caps each rail: only at the deck's outer rows, never a row of posts
					# across a wide deck's end.
					for side in [Vector2i.UP, Vector2i.DOWN]:
						var corner: Vector2i = cell + end + side
						if posts and not _is_deck(cell + side) and _post_fits(corner):
							rails.add_child(_standing(post, corner))
			else:
				for side in [[Vector2i.LEFT, "w"], [Vector2i.RIGHT, "e"]]:
					var beside: Vector2i = cell + side[0]
					if _rail_fits(beside):
						_paint("Bridges", beside, StringName("bridge_%s_rail_%s" % [material, side[1]]))
				for end in [Vector2i.UP, Vector2i.DOWN]:
					if _is_deck(cell + end):
						continue
					for side in [Vector2i.LEFT, Vector2i.RIGHT]:
						var corner: Vector2i = cell + end + side
						if posts and not _is_deck(cell + side) and _post_fits(corner):
							rails.add_child(_standing(post, corner))


## A rail stands beside a deck over lava or against a cliff, never over floor someone walks on.
func _rail_fits(cell: Vector2i) -> bool:
	return plan.in_grid(cell) and not _is_deck(cell) and (_is_open_lava(cell) or _faces.has(cell))


## A post caps a rail on the floor at the deck's end.
func _post_fits(cell: Vector2i) -> bool:
	return plan.in_grid(cell) and not _is_wall(cell) and not _is_deck(cell) and not _faces.has(cell) \
			and _art_height(cell) >= 0 and not TemplePlan.STAIRS.has(plan.cell_at(cell))


## A tile as a sprite standing on `cell`: its origin at the cell's bottom edge, so the parent's y-sort
## puts it among the actors by its foot.
func _standing(role: StringName, cell: Vector2i) -> Sprite2D:
	var sprite := TileArt.sprite(role, Vector2(cell.x * TILE, (cell.y + 1) * TILE))
	sprite.offset = Vector2(0, -TILE)
	return sprite


# --- collision, stairs and props ----------------------------------------------------------------------------
## One body per physics layer, with every rectangle the plan needs on it.
func _build_collision() -> void:
	for layer in COLLISION_LAYERS:
		var rects := plan.collision_rects(layer)
		if rects.is_empty():
			continue
		var body := StaticBody2D.new()
		body.name = "Collision%d" % layer
		body.collision_layer = 1 << (layer - 1)
		body.collision_mask = 0
		for rect in rects:
			var shape := CollisionShape2D.new()
			var rectangle := RectangleShape2D.new()
			rectangle.size = rect.size
			shape.shape = rectangle
			shape.position = rect.get_center()
			body.add_child(shape)
		add_child(body)


## A StairZone over every flight: its low end is the stair's own level.
func _build_stair_zones() -> void:
	var count := 0
	for stair in plan.stairs():
		var cells: Rect2i = stair["cells"]
		var zone := StairZone.new()
		zone.name = "StairZone%d" % count
		count += 1
		zone.direction = Vector2(stair["direction"])
		zone.low_level = stair["low_level"]
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(cells.size) * TILE
		shape.shape = rectangle
		zone.add_child(shape)
		zone.position = Vector2(cells.position) * TILE + rectangle.size / 2.0
		add_child(zone)


## A pillar on every `p` cell, standing at the cell's foot on the cell's level (its body is the prop's).
func _build_pillars() -> void:
	var count := 0
	for y in plan.rows:
		for x in plan.columns:
			var cell := Vector2i(x, y)
			if plan.cell_at(cell) != TemplePlan.PILLAR:
				continue
			var pillar := TempleProp.new()
			pillar.name = "Pillar%d" % count
			count += 1
			pillar.kind = TempleProp.Kind.PILLAR_BLOCK if _rng.randf() < Tuning.TEMPLE_PILLAR_BLOCK_CHANCE else TempleProp.Kind.PILLAR_CARVED
			pillar.level = plan.height_at(cell)
			pillar.position = Vector2(cell) * TILE + Vector2(TILE / 2.0, TILE * 0.75)
			add_child(pillar)


## A pair of small braziers on the high floor's corners past the last step of a flight of stairs, so
## the way up is easy to spot. Only a few flights get one: none within TEMPLE_STAIR_BRAZIER_SPACING
## cells of another pair, and at most TEMPLE_STAIR_BRAZIER_MAX_PAIRS per room, so a room of many
## flights does not fill with small objects (the other flights stay bare; no posts). They do not block;
## a brazier is left out where its corner is not floor of the high level or a prop already stands there.
func _build_stair_braziers() -> void:
	if not Tuning.TEMPLE_STAIR_TOP_BRAZIERS:
		return
	var count := 0
	var pairs := 0
	var lit: Array[Vector2i] = []
	var near_fire := func(cell: Vector2i) -> bool:
		for other in lit:
			if maxi(absi(other.x - cell.x), absi(other.y - cell.y)) < Tuning.TEMPLE_STAIR_BRAZIER_SPACING:
				return true
		return false
	for stair in plan.stairs():
		var cells: Rect2i = stair["cells"]
		var direction: Vector2i = stair["direction"]
		var high: int = stair["low_level"] + 1
		var corners: Array[Vector2i] = []
		match direction:
			Vector2i.UP:
				corners = [Vector2i(cells.position.x - 1, cells.position.y - 1), Vector2i(cells.end.x, cells.position.y - 1)]
			Vector2i.DOWN:
				corners = [Vector2i(cells.position.x - 1, cells.end.y), Vector2i(cells.end.x, cells.end.y)]
			Vector2i.LEFT:
				corners = [Vector2i(cells.position.x - 1, cells.position.y - 1), Vector2i(cells.position.x - 1, cells.end.y)]
			Vector2i.RIGHT:
				corners = [Vector2i(cells.end.x, cells.position.y - 1), Vector2i(cells.end.x, cells.end.y)]
		# Both corners of a flight get a brazier, so the pair reads as a gate; a flight near another
		# pair, or past the room's budget, stays bare.
		if corners.any(near_fire) or pairs >= Tuning.TEMPLE_STAIR_BRAZIER_MAX_PAIRS:
			continue
		var placed := false
		for corner in corners:
			if not _brazier_fits(corner, high):
				continue
			var brazier := TempleProp.new()
			brazier.name = "StairBrazier%d" % count
			brazier.kind = TempleProp.Kind.BRAZIER
			brazier.level = high
			brazier.position = Vector2(corner) * TILE + Vector2(TILE / 2.0, TILE - 4.0)
			add_child(brazier)
			lit.append(corner)
			placed = true
			count += 1
		if placed:
			pairs += 1


## Floor of `level` the plan lets someone stand on, with no prop of the room on it.
func _brazier_fits(cell: Vector2i, level: int) -> bool:
	if not plan.in_grid(cell) or _is_wall(cell) or _faces.has(cell) or not TemplePlan.FLOORS.has(plan.cell_at(cell)):
		return false
	if plan.height_at(cell) != level:
		return false
	var parent := get_parent()
	if parent != null:
		for child in parent.get_children():
			if child is TempleProp and Vector2i((child.position / TILE).floor()) == cell:
				return false
	return true


## Flickering lava lights spread along the rims (one every TEMPLE_RIM_LIGHT_EVERY rim cells), over the
## floors and the actors like every RuinLight.
func _build_lights() -> void:
	var color := Tuning.TEMPLE_RIM_LIGHT
	if not Tuning.RUIN_LIGHTS_ENABLED or color.a <= 0.0 or Tuning.TEMPLE_RIM_LIGHT_EVERY <= 0:
		return
	var lights := Node2D.new()
	lights.name = "Lights"
	lights.z_as_relative = false
	lights.z_index = Tuning.RUIN_LIGHT_Z
	add_child(lights)
	for cell in _spread(_rim_cells, Tuning.TEMPLE_RIM_LIGHT_EVERY):
		var spot := Vector2(cell) * TILE + Vector2.ONE * TILE / 2.0
		if not TempleProp.light_spot_free(get_tree(), global_position + spot):
			continue
		var glow := RuinLight.glow(color, Vector2.ONE * Tuning.TEMPLE_RIM_LIGHT_RADIUS * 2.0)
		glow.position = spot
		lights.add_child(glow)
		glow.add_to_group(TempleProp.LIGHT_GROUP)
		var dim := Color(color.r, color.g, color.b, color.a * (1.0 - Tuning.RUIN_LIGHT_FLICKER))
		var seconds := TempleProp.flicker_seconds(global_position + glow.position)
		var tween := glow.create_tween().set_loops()
		tween.tween_property(glow, "modulate", dim, seconds)
		tween.tween_property(glow, "modulate", color, seconds)


## Ember vents on a few open lava cells (one every TEMPLE_EMBER_VENT_EVERY), each with embers rising
## over every layer, y-sorted at z 0 so they drift in front of what stands north of them.
func _build_vents() -> void:
	if Tuning.TEMPLE_EMBER_VENT_EVERY <= 0:
		return
	var open: Array[Vector2i] = []
	for y in range(1, plan.rows - 1):
		for x in range(1, plan.columns - 1):
			var cell := Vector2i(x, y)
			if plan.is_lava(cell) and _is_open_lava(cell):
				open.append(cell)
	var embers := Node2D.new()
	embers.name = "Embers"
	embers.y_sort_enabled = true
	add_child(embers)
	var count := 0
	for cell in _spread(open, Tuning.TEMPLE_EMBER_VENT_EVERY):
		var vent := TempleProp.new()
		vent.name = "Vent%d" % count
		vent.kind = TempleProp.Kind.EMBER_VENT
		var foot: Array = vent.spec().get("foot", [TILE / 2, TILE / 2])
		vent.position = Vector2(cell) * TILE + Vector2(foot[0], foot[1])
		add_child(vent)
		if Tuning.TEMPLE_EMBERS > 0:
			var rising := _embers()
			rising.name = "Embers%d" % count
			rising.position = Vector2(cell) * TILE + Vector2.ONE * TILE / 2.0
			embers.add_child(rising)
		count += 1


## Every `every`-th cell of a shuffled copy of `cells`: a fixed count spread at random.
func _spread(cells: Array[Vector2i], every: int) -> Array[Vector2i]:
	var pool: Array[Vector2i] = cells.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var picked: Array[Vector2i] = []
	for i in floori(float(pool.size()) / every):
		picked.append(pool[i])
	return picked


## Small orange sparks drifting up and fading, a pixel or two each.
func _embers() -> CPUParticles2D:
	if _ember_texture == null:
		var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_ember_texture = ImageTexture.create_from_image(image)
	var particles := CPUParticles2D.new()
	particles.texture = _ember_texture
	particles.amount = Tuning.TEMPLE_EMBERS
	particles.lifetime = Tuning.TEMPLE_EMBER_LIFETIME
	particles.preprocess = Tuning.TEMPLE_EMBER_LIFETIME
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 3.0
	particles.direction = Vector2.UP
	particles.spread = 25.0
	particles.gravity = Vector2(0, -Tuning.TEMPLE_EMBER_RISE)
	particles.initial_velocity_min = Tuning.TEMPLE_EMBER_SPEED.x
	particles.initial_velocity_max = Tuning.TEMPLE_EMBER_SPEED.y
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, Tuning.TEMPLE_EMBER_COLOR)
	ramp.set_color(1, Color(Tuning.TEMPLE_EMBER_COLOR.r, Tuning.TEMPLE_EMBER_COLOR.g * 0.5, 0.0, 0.0))
	particles.color_ramp = ramp
	particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return particles


# --- the tileset with animated tiles ----------------------------------------------------------------------
## A TileSet of the active profile's sheet in which every animation of the profile is one animated
## tile (its first frame, playing the rest at the pace Tuning gives it), built once per profile. The
## profile's own `tile_set()` keeps every cell as a still tile, which other layers may need.
static func animated_tile_set() -> TileSet:
	var profile := TileArt.profile()
	var key := profile.resource_path
	if _tile_sets.has(key):
		return _tile_sets[key]
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(profile.tile_size, profile.tile_size)
	var source := TileSetAtlasSource.new()
	source.texture = profile.texture
	source.margins = Vector2i(profile.margin, profile.margin)
	source.separation = Vector2i(profile.separation, profile.separation)
	source.texture_region_size = Vector2i(profile.tile_size, profile.tile_size)
	var first := {}
	var covered := {}
	for animation in profile.animations:
		var frames := profile.animation(animation)
		first[frames[0]] = animation
		for frame in frames:
			covered[frame] = true
	var size := profile.texture.get_size() - Vector2(profile.margin, profile.margin)
	var columns := int((size.x + profile.separation) / (profile.tile_size + profile.separation))
	var rows_count := int((size.y + profile.separation) / (profile.tile_size + profile.separation))
	for row in rows_count:
		for column in columns:
			var coords := Vector2i(column, row)
			if first.has(coords):
				var animation: StringName = first[coords]
				var frames := profile.animation(animation)
				source.create_tile(coords)
				source.set_tile_animation_columns(coords, 0)
				# No pace (animation off, or an fps of 0 or less): the first frame, still.
				var fps := _fps_of(animation)
				if fps <= 0.0 or not Tuning.TEMPLE_SHAPE_ANIMATE:
					continue
				source.set_tile_animation_frames_count(coords, frames.size())
				for i in frames.size():
					source.set_tile_animation_frame_duration(coords, i, 1.0 / fps)
				if not String(animation).begins_with(IN_STEP_PREFIX):
					source.set_tile_animation_mode(coords, TileSetAtlasSource.TILE_ANIMATION_MODE_RANDOM_START_TIMES)
			elif not covered.has(coords):
				source.create_tile(coords)
	tile_set.add_source(source, 0)
	_tile_sets[key] = tile_set
	return tile_set


## The pace of a profile animation, by what it shows (see Tuning, "Temple: shape").
static func _fps_of(animation: StringName) -> float:
	var name := String(animation)
	if name.begins_with(IN_STEP_PREFIX) or name == "lava_flow":
		return Tuning.TEMPLE_LAVA_FPS
	if name.begins_with("lava_bubble"):
		return Tuning.TEMPLE_LAVA_BUBBLE_FPS
	if name == "lava_rim_glow":
		return Tuning.TEMPLE_LAVA_GLOW_FPS
	if name.begins_with("cliff_foot_lava") or name.begins_with("masonry_foot_lava"):
		return Tuning.TEMPLE_LAVA_FOOT_FPS
	if name.ends_with("rune_glow"):
		return Tuning.TEMPLE_RUNE_GLOW_FPS
	return Tuning.TEMPLE_FIRE_FPS
