extends SceneTree
## Builds Nico's SpriteFrames (data/player/nico_frames.tres) from the strips in assets/sprites/nico/
## named nico_<animation>_<view>.png (32x32 cells side by side). Animations are found by name:
## idle/walk come in the down (front), up (back) and side views; attack, hurt, death and dash only
## from the side. Side art faces right; the game flips it to go left.
## Run: godot --headless --path . --script res://tools/make_nico_frames.gd
## The sword is not part of these strips: it is assets/sprites/nico/sword.png, swung by Player.

const STRIP := "res://assets/sprites/nico/nico_%s.png"
const CELL := 32

## animation (= strip name) -> [frames per second, loops]
const ANIMATIONS := {
	&"idle_down": [6.0, true],
	&"idle_up": [6.0, true],
	&"idle_side": [6.0, true],
	&"walk_down": [12.0, true],
	&"walk_up": [12.0, true],
	&"walk_side": [12.0, true],
	&"attack_side": [12.0, false],
	&"hurt_side": [8.0, false],
	&"death_side": [6.0, false],
	&"dash_side": [12.0, false],
}
## Old names kept while the game migrates: they play the side animation.
const ALIASES := {
	&"idle": &"idle_side",
	&"walk": &"walk_side",
	&"attack": &"attack_side",
}


func _initialize() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim: StringName in ANIMATIONS:
		_add(frames, anim, anim)
	for alias: StringName in ALIASES:
		_add(frames, alias, ALIASES[alias])
	DirAccess.make_dir_recursive_absolute("res://data/player")
	ResourceSaver.save(frames, "res://data/player/nico_frames.tres")
	print("nico frames written")
	quit()


func _add(frames: SpriteFrames, anim: StringName, strip_name: StringName) -> void:
	var spec: Array = ANIMATIONS[strip_name]
	var strip: Texture2D = load(STRIP % strip_name)
	frames.add_animation(anim)
	frames.set_animation_speed(anim, spec[0])
	frames.set_animation_loop(anim, spec[1])
	for i in strip.get_width() / CELL:
		var atlas := AtlasTexture.new()
		atlas.atlas = strip
		atlas.region = Rect2(i * CELL, 0, CELL, CELL)
		frames.add_frame(anim, atlas)
