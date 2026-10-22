extends SceneTree
## Builds Nico's SpriteFrames (data/player/nico_frames.tres) from assets/sprites/nico/nico.png
## (see tools/make_nico_sheet.py). Run: godot --headless --path . --script res://tools/make_nico_frames.gd
## The sheet is Nico.gif as is: 64 cells of 32x32, 8 per row. Movement art faces right (the game
## flips it). The player only plays idle / walk / attack; the others are ready for later.

const SHEET := "res://assets/sprites/nico/nico.png"
const CELL := 32
const COLS := 8

## name -> [first cell, last cell, frames per second, loops]
const ANIMATIONS := {
	&"idle": [8, 15, 6.0, true],         # side view, standing
	&"walk": [23, 31, 12.0, true],       # side view
	&"run": [32, 39, 14.0, true],        # side view
	&"idle_down": [0, 4, 5.0, true],
	&"walk_down": [16, 19, 8.0, true],
	&"walk_up": [20, 22, 8.0, true],
	&"hurt": [57, 58, 8.0, false],
	&"death": [60, 63, 6.0, false],
}
## The GIF has no sword swing: the attack pose is a calm side cell and the sword is its own sprite
## (assets/sprites/nico/sword.png, swung by Player).
const ATTACK_CELL := 8


func _initialize() -> void:
	var sheet: Texture2D = load(SHEET)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim: StringName in ANIMATIONS:
		var spec: Array = ANIMATIONS[anim]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, spec[2])
		frames.set_animation_loop(anim, spec[3])
		for cell: int in range(spec[0], spec[1] + 1):
			frames.add_frame(anim, _cell(sheet, cell))
	frames.add_animation(&"attack")
	frames.set_animation_speed(&"attack", 1.0)
	frames.add_frame(&"attack", _cell(sheet, ATTACK_CELL))
	DirAccess.make_dir_recursive_absolute("res://data/player")
	ResourceSaver.save(frames, "res://data/player/nico_frames.tres")
	print("nico frames written")
	quit()


func _cell(sheet: Texture2D, index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2((index % COLS) * CELL, (index / COLS) * CELL, CELL, CELL)
	return atlas
