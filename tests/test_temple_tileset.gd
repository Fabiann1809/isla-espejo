extends SceneTree
## The tileset profile of the Templo del Eclipse (data/tilesets/temple.tres, made by
## tools/make_tileset_temple.gd from the sheet of tools/make_temple_tileset_art.py) and its theme
## (data/themes/temple.tres, tools/make_temple_theme.gd): every named tile and pattern exists, the
## rim and ledge blobs have their 47 tiles, the animations have their frames, the floors tile
## without seams, the sheet uses only the temple palette and the theme walls are LAVA.
## Run: godot --headless --path . --script res://tests/test_temple_tileset.gd

const PROFILE := "res://data/tilesets/temple.tres"
const THEME := "res://data/themes/temple.tres"
const PALETTE := "res://tools/temple_palette.py"
## Average colour distance (RGB, 0..441) two edge columns may differ by and still read as one floor.
const SEAM_THRESHOLD := 60.0

const TILES: Array[String] = [
	"floor_a", "floor_b", "floor_c", "floor_d", "floor_e", "floor_f",
	"floor_moss_a", "floor_moss_b", "floor_crack_a", "floor_crack_b",
	"floor_rune_a", "floor_rune_b", "floor_rune_c", "floor_rune_d",
	"lava_a", "lava_b", "lava_c", "lava_d",
	"cliff_face_l", "cliff_face_m", "cliff_face_r",
	"cliff_face2_top_l", "cliff_face2_top_m", "cliff_face2_top_r",
	"cliff_face2_bot_l", "cliff_face2_bot_m", "cliff_face2_bot_r",
	"cliff_foot_lava_l", "cliff_foot_lava_m", "cliff_foot_lava_r",
	"cliff_moss_l", "cliff_moss_m", "cliff_moss_r",
	"cliff_moss2_top_l", "cliff_moss2_top_m", "cliff_moss2_top_r",
	"cliff_moss2_bot_l", "cliff_moss2_bot_m", "cliff_moss2_bot_r",
	"shadow_s_1", "shadow_s_2",
	"stairs_up_steps", "stairs_up_rail_l", "stairs_up_rail_r",
	"stairs_side_steps", "stairs_side_rail_t", "stairs_side_rail_b",
	"bridge_stone_deck_h", "bridge_stone_deck_v", "bridge_stone_rail_n", "bridge_stone_rail_s",
	"bridge_stone_rail_e", "bridge_stone_rail_w", "bridge_stone_post",
	"bridge_wood_deck_h", "bridge_wood_deck_v", "bridge_wood_rail_n", "bridge_wood_rail_s",
	"bridge_wood_rail_e", "bridge_wood_rail_w", "bridge_rope_post",
]
const PATTERNS_47: Array[String] = ["lava_rim", "ledge"]
const ANIMATIONS := {"lava_flow": 8, "lava_bubble": 6, "floor_rune_glow": 4, "lava_rim_glow": 4, "cliff_foot_lava_m": 4}
const FLOORS: Array[String] = ["floor_a", "floor_b", "floor_c", "floor_d", "floor_e", "floor_f"]

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var profile: TilesetProfile = load(PROFILE) if ResourceLoader.exists(PROFILE) else null
	_check(profile != null, "the temple profile exists")
	if profile == null:
		_finish()
		return
	_check(profile.tile_size == 16 and profile.separation == 0 and profile.texture != null,
			"it is 16x16 tiles with no spacing and has a sheet")
	_check(profile.problems(TileArt.ROLES, TileArt.PATTERNS).is_empty(),
			"it has a tile for every role and pattern of the game")

	var missing: Array[String] = []
	for tile_name in TILES:
		if not profile.tiles.has(StringName(tile_name)):
			missing.append(tile_name)
	for pattern_name in PATTERNS_47:
		if not profile.patterns.has(StringName(pattern_name)):
			missing.append(pattern_name)
	_check(missing.is_empty(), "every named temple tile exists (missing %s)" % [missing])

	var short: Array[String] = []
	for pattern_name in PATTERNS_47:
		if profile.patterns.has(StringName(pattern_name)) and profile.patterns[StringName(pattern_name)].size() != 47:
			short.append("%s: %d" % [pattern_name, profile.patterns[StringName(pattern_name)].size()])
	_check(short.is_empty(), "rim and ledge patterns have 47 tiles (%s)" % [short])

	var wrong: Array[String] = []
	for anim_name: String in ANIMATIONS:
		var frames: int = profile.animations[StringName(anim_name)].size() if profile.animations.has(StringName(anim_name)) else 0
		if frames != ANIMATIONS[anim_name]:
			wrong.append("%s: %d, needs %d" % [anim_name, frames, ANIMATIONS[anim_name]])
	_check(wrong.is_empty(), "animations have the promised frame counts (%s)" % [wrong])

	var image: Image = profile.texture.get_image()
	var seams: Array[String] = []
	for a in FLOORS:
		for b in FLOORS:
			if not (profile.tiles.has(StringName(a)) and profile.tiles.has(StringName(b))):
				continue
			var left := _column(image, profile, StringName(a), 0)
			var right := _column(image, profile, StringName(b), 15)
			var top := _row(image, profile, StringName(a), 0)
			var bottom := _row(image, profile, StringName(b), 15)
			var horizontal := _distance(left, right)
			var vertical := _distance(top, bottom)
			if horizontal >= SEAM_THRESHOLD or vertical >= SEAM_THRESHOLD:
				seams.append("%s|%s %.0f/%.0f" % [b, a, horizontal, vertical])
	_check(seams.is_empty(), "temple floors tile without seams (%s)" % [seams])

	var palette := _palette()
	_check(palette.size() >= 40, "the palette file lists %d colours" % palette.size())
	var strangers := {}
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			var key := Vector3i(roundi(pixel.r * 255.0), roundi(pixel.g * 255.0), roundi(pixel.b * 255.0))
			if not _in_palette(key, palette):
				strangers[key] = true
	_check(strangers.is_empty(), "the sheet uses only the palette (%d strangers: %s)" % [strangers.size(), strangers.keys().slice(0, 6)])

	var theme: RoomTheme = load(THEME) if ResourceLoader.exists(THEME) else null
	_check(theme != null and theme.wall_style == RoomTheme.WallStyle.LAVA, "the temple theme uses the LAVA wall style")
	_check(theme != null and theme.tileset == profile and theme.floor_tile == &"floor_a" and not theme.ambient_life
			and theme.world_tint == Tuning.TEMPLE_WORLD_TINT, "the theme draws with the temple profile, warm and still")

	# The game asks for roles: with this profile active 'grass' is a flagstone floor.
	TileArt.use_profile(profile)
	_check(TileArt.coords(TileArt.GRASS) == profile.tiles[&"floor_a"], "asking for 'grass' gives the temple floor")
	TileArt.use_profile(null)
	_finish()


func _finish() -> void:
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _column(image: Image, profile: TilesetProfile, tile_name: StringName, x: int) -> Array[Color]:
	var rect := profile.region(profile.tiles[tile_name])
	var colors: Array[Color] = []
	for y in 16:
		colors.append(image.get_pixel(int(rect.position.x) + x, int(rect.position.y) + y))
	return colors


func _row(image: Image, profile: TilesetProfile, tile_name: StringName, y: int) -> Array[Color]:
	var rect := profile.region(profile.tiles[tile_name])
	var colors: Array[Color] = []
	for x in 16:
		colors.append(image.get_pixel(int(rect.position.x) + x, int(rect.position.y) + y))
	return colors


## Mean euclidean RGB distance (0..255 per channel) between two lines of pixels.
func _distance(a: Array[Color], b: Array[Color]) -> float:
	var total := 0.0
	for i in a.size():
		var d := Vector3(a[i].r - b[i].r, a[i].g - b[i].g, a[i].b - b[i].b) * 255.0
		total += d.length()
	return total / a.size()


## Every "#rrggbb" of tools/temple_palette.py.
func _palette() -> Array[Vector3i]:
	var colors: Array[Vector3i] = []
	var regex := RegEx.new()
	regex.compile("#([0-9a-fA-F]{6})")
	for found in regex.search_all(FileAccess.get_file_as_string(PALETTE)):
		var hex := found.get_string(1)
		colors.append(Vector3i(hex.substr(0, 2).hex_to_int(), hex.substr(2, 2).hex_to_int(), hex.substr(4, 2).hex_to_int()))
	return colors


func _in_palette(key: Vector3i, palette: Array[Vector3i]) -> bool:
	for color in palette:
		if absi(color.x - key.x) <= 1 and absi(color.y - key.y) <= 1 and absi(color.z - key.z) <= 1:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
