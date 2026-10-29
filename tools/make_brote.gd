extends SceneTree
## Builds the Brote's SpriteFrames (data/enemies/brote_frames.tres) from the strips in
## assets/sprites/brote/ (made by tools/make_brote_art.py, 32x32 cells) and its EnemyData
## (data/enemies/brote.tres). The Brote is the minion the Ente del bosque grows from its body; it
## uses the generic melee behaviour. The scene scenes/enemies/brote.tscn is hand-written.
## Run: godot --headless --path . --script res://tools/make_brote.gd

const STRIP := "res://assets/sprites/brote/brote_%s.png"
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
	ResourceSaver.save(frames, "res://data/enemies/brote_frames.tres")

	var data := EnemyData.new()
	data.id = &"brote"
	data.display_name = "Brote"
	data.placeholder_color = Color(0.4, 0.25, 0.14)
	data.sprite_frames = load("res://data/enemies/brote_frames.tres")
	# The feet are on row 29 of the cell: put them a few pixels below the body's origin.
	data.sprite_offset = Vector2(0, -7)
	data.max_health = 2
	data.move_speed = 30.0
	data.chase_speed = 58.0
	# It is born next to the player: it hunts from far away and never gives up.
	data.detection_range = 260.0
	data.lose_range = 400.0
	data.attack_range = 20.0
	data.attack_damage = 1
	data.attack_windup = 0.35
	data.attack_time = 0.2
	data.attack_cooldown = 1.0
	data.knockback_speed = 130.0
	data.patrol_radius = 0.0
	# Minions grow back, so they must not be a source of resources.
	data.drop_multiplier = 0.0
	ResourceSaver.save(data, "res://data/enemies/brote.tres")
	print("brote written")
	quit()
