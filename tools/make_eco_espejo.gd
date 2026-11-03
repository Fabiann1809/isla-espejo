extends SceneTree
## Writes the Eco del Espejo's art and data: its SpriteFrames (data/enemies/eco_espejo_frames.tres),
## built from Nico's side strips (assets/sprites/nico/nico_<animation>_side.png, 32x32 cells, facing
## right; see tools/make_nico_frames.gd), and its MirrorEchoData (data/enemies/eco_espejo.tres). The
## mirror look (tint, transparency) is applied by the enemy from its data. The scene
## scenes/enemies/eco_espejo.tscn is hand-written.
## Run: godot --headless --path . --script res://tools/make_eco_espejo.gd

const STRIP := "res://assets/sprites/nico/nico_%s_side.png"
const CELL := 32
## animation -> [Nico's strip, frames per second, loops]. Nico never runs: run is his walk, faster.
const ANIMATIONS := {
	&"idle": [&"idle", 6.0, true],
	&"walk": [&"walk", 12.0, true],
	&"run": [&"walk", 12.0, true],
	&"attack": [&"attack", 12.0, false],
	&"hurt": [&"hurt", 8.0, false],
	&"death": [&"death", 6.0, false],
}


func _initialize() -> void:
	var frames := _build_frames()
	ResourceSaver.save(frames, "res://data/enemies/eco_espejo_frames.tres")
	print("eco_espejo frames written")
	_write_data(load("res://data/enemies/eco_espejo_frames.tres"))
	quit()


func _build_frames() -> SpriteFrames:
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
	return frames


func _write_data(frames: SpriteFrames) -> void:
	var data := MirrorEchoData.new()
	data.id = &"eco_espejo"
	data.display_name = "Eco del Espejo"
	data.placeholder_color = Color(0.72, 0.85, 1.0)
	data.sprite_frames = frames
	# Same place as Nico's art over his body.
	data.sprite_offset = Vector2(0, -11)
	data.max_health = 5
	data.move_speed = 40.0
	# Nico's walking speed: what its run cycle is drawn for.
	data.chase_speed = 120.0
	data.detection_range = 200.0
	data.lose_range = 320.0
	# The damage of each echoed shot.
	data.attack_damage = 1
	data.knockback_speed = 140.0
	data.patrol_radius = 40.0
	data.patrol_wait = 1.0
	data.hurt_time = 0.2
	data.echo_delay = 1.0
	data.follow_speed = 150.0
	data.shot_pose_time = 0.25
	data.projectile_scene = load("res://scenes/enemies/orb.tscn")
	data.projectile_speed = 150.0
	data.projectile_range = 200.0
	data.muzzle_distance = 10.0
	data.shot_tint = Color(0.75, 0.88, 1.0)
	data.touch_damage = 1
	data.touch_radius = 7.0
	data.touch_interval = 0.6
	data.echo_tint = Color(0.72, 0.85, 1.0, 0.7)
	ResourceSaver.save(data, "res://data/enemies/eco_espejo.tres")
	print("eco_espejo written")
