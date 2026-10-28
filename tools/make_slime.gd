extends SceneTree
## Builds the slime's SpriteFrames (data/enemies/slime_frames.tres) from the strips in
## assets/sprites/slime/ (made by tools/make_slime_art.py, 32x32 cells, facing right) and its
## SlimeData (data/enemies/slime.tres). The scene scenes/enemies/slime.tscn is hand-written.
## Run: godot --headless --path . --script res://tools/make_slime.gd

const STRIP := "res://assets/sprites/slime/slime_%s.png"
const CELL := 32

## animation -> [strip, frames per second, loops]. `run` (chasing) reuses the hopping walk.
const ANIMATIONS := {
	&"idle": [&"idle", 6.0, true],
	&"walk": [&"walk", 10.0, true],
	&"run": [&"walk", 10.0, true],
	&"attack": [&"attack", 10.0, false],
	&"hurt": [&"hurt", 8.0, false],
	&"death": [&"death", 8.0, false],
}


func _initialize() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim: StringName in ANIMATIONS:
		var spec: Array = ANIMATIONS[anim]
		var strip: Texture2D = load(STRIP % spec[0])
		frames.add_animation(anim)
		frames.set_animation_speed(anim, spec[1])
		frames.set_animation_loop(anim, spec[2])
		for i in strip.get_width() / CELL:
			var atlas := AtlasTexture.new()
			atlas.atlas = strip
			atlas.region = Rect2(i * CELL, 0, CELL, CELL)
			frames.add_frame(anim, atlas)
	ResourceSaver.save(frames, "res://data/enemies/slime_frames.tres")

	var data := SlimeData.new()
	data.id = &"slime"
	data.display_name = "Slime"
	data.placeholder_color = Color(0.34, 0.69, 0.29)
	data.sprite_frames = load("res://data/enemies/slime_frames.tres")
	# The cell's ground line is row 27: put it a few pixels below the body's center.
	data.sprite_offset = Vector2(0, -5)
	data.max_health = 3
	data.move_speed = 22.0
	data.chase_speed = 42.0
	data.detection_range = 110.0
	data.lose_range = 200.0
	data.attack_range = 52.0
	data.attack_damage = 1
	data.attack_windup = 0.45
	data.attack_time = 0.35
	data.attack_cooldown = 1.4
	data.knockback_speed = 110.0
	data.patrol_radius = 50.0
	data.leap_speed = 170.0
	ResourceSaver.save(data, "res://data/enemies/slime.tres")
	print("slime written")
	quit()
