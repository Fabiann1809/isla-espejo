extends SceneTree
## Builds Nico's SpriteFrames (data/player/nico_frames.tres) from assets/sprites/nico/nico.png
## (see tools/make_nico_sheet.py). Run: godot --headless --path . --script res://tools/make_nico_frames.gd
## The sheet is one 58-frame cycle with the sword out, facing right: it plays as "walk" and its
## first frame is the "idle" pose. Add attack/hurt/death rows here when they exist.

const SHEET := "res://assets/sprites/nico/nico.png"
const CELL := 62
const COLS := 8
const FRAMES := 58


func _initialize() -> void:
	var sheet: Texture2D = load(SHEET)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"idle")
	frames.set_animation_speed(&"idle", 1.0)
	frames.add_animation(&"walk")
	frames.set_animation_speed(&"walk", 14.0)
	for i in FRAMES:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2((i % COLS) * CELL, (i / COLS) * CELL, CELL, CELL)
		frames.add_frame(&"walk", atlas)
		if i == 0:
			frames.add_frame(&"idle", atlas)
	# The sword-less pose used while the sword is swung as its own sprite (see Player).
	frames.add_animation(&"attack")
	frames.set_animation_speed(&"attack", 1.0)
	var pose := AtlasTexture.new()
	pose.atlas = sheet
	pose.region = Rect2((FRAMES % COLS) * CELL, (FRAMES / COLS) * CELL, CELL, CELL)
	frames.add_frame(&"attack", pose)
	DirAccess.make_dir_recursive_absolute("res://data/player")
	ResourceSaver.save(frames, "res://data/player/nico_frames.tres")
	print("nico frames written")
	quit()
