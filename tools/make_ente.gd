extends SceneTree
## Builds the Ente del bosque's SpriteFrames (data/enemies/ente_frames.tres) from the strips in
## assets/sprites/ente/ (made by tools/make_ente_art.py, 64x64 cells) and its EnemyData
## (data/enemies/ente.tres). It uses the generic melee behaviour: its attack is the slam drawn in the
## `attack` strip. The scene scenes/enemies/ente.tscn is hand-written.
## Run: godot --headless --path . --script res://tools/make_ente.gd

const STRIP := "res://assets/sprites/ente/ente_%s.png"
const CELL := 64

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
	ResourceSaver.save(frames, "res://data/enemies/ente_frames.tres")

	var data := EnemyData.new()
	data.id = &"ente"
	data.display_name = "Ente del bosque"
	data.placeholder_color = Color(0.4, 0.25, 0.14)
	data.sprite_frames = load("res://data/enemies/ente_frames.tres")
	# The feet are on row 61 of the 64x64 cell: put them a few pixels below the body's origin.
	data.sprite_offset = Vector2(0, -23)
	data.max_health = 5
	data.move_speed = 18.0
	data.chase_speed = 34.0
	data.detection_range = 110.0
	data.lose_range = 200.0
	data.attack_range = 26.0
	data.attack_damage = 1
	# The 7-frame slam spreads the arms for 5 frames (windup) and strikes on the 6th.
	data.attack_windup = 0.55
	data.attack_time = 0.25
	data.attack_cooldown = 1.5
	data.knockback_speed = 90.0
	data.knockback_resistance = 0.3
	data.patrol_radius = 40.0
	ResourceSaver.save(data, "res://data/enemies/ente.tres")
	print("ente written")
	quit()
