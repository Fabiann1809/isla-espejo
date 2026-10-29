extends SceneTree
## Builds the Esqueleto's SpriteFrames (data/enemies/esqueleto_frames.tres) from the strips in
## assets/sprites/esqueleto/ (made by tools/make_esqueleto_art.py, 32x32 cells) and its EnemyData
## (data/enemies/esqueleto.tres). It uses the generic melee behaviour: its attack is the club swing
## drawn in the `attack` strip. The scene scenes/enemies/esqueleto.tscn is hand-written.
## Run: godot --headless --path . --script res://tools/make_esqueleto.gd

const STRIP := "res://assets/sprites/esqueleto/esqueleto_%s.png"
const CELL := 32

## animation -> [strip, frames per second, loops]. `run` (chasing) reuses the walk.
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
	ResourceSaver.save(frames, "res://data/enemies/esqueleto_frames.tres")

	var data := EnemyData.new()
	data.id = &"esqueleto"
	data.display_name = "Esqueleto"
	data.placeholder_color = Color(0.91, 0.78, 0.6)
	data.sprite_frames = load("res://data/enemies/esqueleto_frames.tres")
	# The cell's ground line is row 27: put it a few pixels below the body's center.
	data.sprite_offset = Vector2(0, -5)
	data.max_health = 4
	data.move_speed = 28.0
	data.chase_speed = 55.0
	data.detection_range = 120.0
	data.lose_range = 220.0
	data.attack_range = 22.0
	data.attack_damage = 1
	# The 7-frame swing raises the club for 5 frames (windup) and strikes on the 6th.
	data.attack_windup = 0.45
	data.attack_time = 0.2
	data.attack_cooldown = 1.0
	data.knockback_speed = 130.0
	data.patrol_radius = 60.0
	ResourceSaver.save(data, "res://data/enemies/esqueleto.tres")
	print("esqueleto written")
	quit()
