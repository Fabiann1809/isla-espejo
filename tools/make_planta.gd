extends SceneTree
## Builds the Planta tiradora's SpriteFrames (data/enemies/planta_tiradora_frames.tres) from the
## strips in assets/sprites/planta/ (made by tools/make_planta_art.py, 32x32 cells) and its
## ShooterData (data/enemies/planta_tiradora.tres). The scenes scenes/enemies/planta_tiradora.tscn
## and orb.tscn are hand-written.
## Run: godot --headless --path . --script res://tools/make_planta.gd

const STRIP := "res://assets/sprites/planta/planta_%s.png"
const CELL := 32

## animation -> [strip, frames per second, loops]. `run` (repositioning) reuses the scurry.
const ANIMATIONS := {
	&"idle": [&"idle", 6.0, true],
	&"walk": [&"walk", 10.0, true],
	&"run": [&"walk", 10.0, true],
	&"attack": [&"attack", 8.0, false],
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
	ResourceSaver.save(frames, "res://data/enemies/planta_tiradora_frames.tres")

	var data := ShooterData.new()
	data.id = &"planta_tiradora"
	data.display_name = "Planta tiradora"
	data.placeholder_color = Color(0.96, 0.56, 0.12)
	data.sprite_frames = load("res://data/enemies/planta_tiradora_frames.tres")
	# The cell's ground line is row 27: put it a few pixels below the body's center.
	data.sprite_offset = Vector2(0, -5)
	data.max_health = 3
	# It plants itself to shoot and, between shots, scurries sideways in short bursts (see Shooter).
	data.move_speed = 0.0
	data.chase_speed = 45.0
	data.detection_range = 190.0
	data.lose_range = 280.0
	data.attack_range = 120.0
	data.attack_damage = 1
	# The 6-frame attack charges for 4 frames (windup) and spits on the 5th (attack_time).
	data.attack_windup = 0.5
	data.attack_time = 0.25
	data.attack_cooldown = 1.8
	data.knockback_speed = 60.0
	data.patrol_radius = 0.0
	data.projectile_scene = load("res://scenes/enemies/orb.tscn")
	data.projectile_speed = 90.0
	data.projectile_range = 220.0
	data.muzzle_distance = 10.0
	data.shuffle_time = 0.5
	data.shuffle_wait = 0.7
	ResourceSaver.save(data, "res://data/enemies/planta_tiradora.tres")
	print("planta written")
	quit()
