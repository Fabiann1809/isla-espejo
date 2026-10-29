class_name TilesetProfile
extends Resource
## A tileset pack described by ROLES: the texture, its tile size and spacing, and which tile of the
## sheet plays each role the game asks for ("grass", "pine", "pond"...). The game never uses sheet
## coordinates directly: it asks `TileArt` for a role and the active profile answers. Changing the
## art of a scenario means writing a new profile (see docs/GUIA_TILESET.md), not touching code.
## The role names and what each one is for are listed in `TileArt`.

## The sheet with every tile.
@export var texture: Texture2D
## Side of one tile in the sheet, in pixels (16 for the current pack).
@export var tile_size := 16
## Pixels between two tiles of the sheet.
@export var separation := 0
## Pixels before the first tile (top and left).
@export var margin := 0
## Role -> (column, row) of its tile in the sheet.
@export var tiles: Dictionary[StringName, Vector2i] = {}
## Role -> several tiles. Nine-slice areas list 9, row by row (top-left, top, top-right, left,
## center, right, bottom-left, bottom, bottom-right); inner corners list 4 (SE, SW, NE, NW: the
## diagonal that is NOT part of the area).
@export var patterns: Dictionary[StringName, Array] = {}

var _tile_set: TileSet
var _textures := {}
var _typed_patterns := {}


func coords(role: StringName) -> Vector2i:
	if not tiles.has(role):
		push_error("Tileset profile %s has no tile for the role '%s'." % [resource_path, role])
		return Vector2i.ZERO
	return tiles[role]


## The tiles of a pattern role (shared: do not modify the array).
func pattern(role: StringName) -> Array[Vector2i]:
	if not _typed_patterns.has(role):
		var result: Array[Vector2i] = []
		if patterns.has(role):
			result.assign(patterns[role])
		else:
			push_error("Tileset profile %s has no pattern for the role '%s'." % [resource_path, role])
		_typed_patterns[role] = result
	return _typed_patterns[role]


## Where a tile is in the sheet, in pixels.
func region(tile: Vector2i) -> Rect2:
	var stride := tile_size + separation
	return Rect2(margin + tile.x * stride, margin + tile.y * stride, tile_size, tile_size)


## One tile of the sheet as a texture (shared, so equal tiles batch together).
func texture_of(tile: Vector2i) -> AtlasTexture:
	if not _textures.has(tile):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = region(tile)
		_textures[tile] = atlas
	return _textures[tile]


## A TileSet with every tile of the sheet as atlas source 0 (built once).
func tile_set() -> TileSet:
	if _tile_set == null:
		_tile_set = TileSet.new()
		_tile_set.tile_size = Vector2i(tile_size, tile_size)
		var source := TileSetAtlasSource.new()
		source.texture = texture
		source.margins = Vector2i(margin, margin)
		source.separation = Vector2i(separation, separation)
		source.texture_region_size = Vector2i(tile_size, tile_size)
		var size := texture.get_size() - Vector2(margin, margin)
		var columns := int((size.x + separation) / (tile_size + separation))
		var rows := int((size.y + separation) / (tile_size + separation))
		for row in rows:
			for column in columns:
				source.create_tile(Vector2i(column, row))
		_tile_set.add_source(source, 0)
	return _tile_set


## Roles of `wanted` (single tiles) and `wanted_patterns` (role -> tile count) this profile lacks,
## or whose tiles fall outside the sheet. Empty = the profile can dress the game.
func problems(wanted: Array, wanted_patterns: Dictionary) -> Array[String]:
	var found: Array[String] = []
	if texture == null:
		found.append("no texture")
		return found
	var source := tile_set().get_source(0) as TileSetAtlasSource
	for role in wanted:
		if not tiles.has(role):
			found.append("missing tile '%s'" % role)
		elif not source.has_tile(tiles[role]):
			found.append("tile '%s' %s is outside the sheet" % [role, tiles[role]])
	for role in wanted_patterns:
		if not patterns.has(role):
			found.append("missing pattern '%s'" % role)
		elif patterns[role].size() != wanted_patterns[role]:
			found.append("pattern '%s' has %d tiles, needs %d" % [role, patterns[role].size(), wanted_patterns[role]])
		else:
			for tile in patterns[role]:
				if not (tile is Vector2i) or not source.has_tile(tile):
					found.append("pattern '%s': tile %s is outside the sheet" % [role, tile])
	return found
