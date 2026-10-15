extends SceneTree
## Builds the Sombra errante: its SpriteFrames, EnemyData (the scene scenes/enemies/sombra_errante.tscn just inherits enemy.tscn).
## Source art: assets/sprites/enemies/sombra_errante.png (384x288 sheet, 48x48 cells, one row per
## animation). Run from the repo root: godot --headless --path . --script res://tools/make_sombra_errante.gd

const SHEET := "res://assets/sprites/enemies/sombra_errante.png"
const CELL := 48
## animation -> [row, frames, fps, loops]
const ANIMATIONS := {
	"idle": [0, 4, 6.0, true],
	"walk": [1, 6, 8.0, true],
	"run": [2, 8, 12.0, true],
	"attack": [3, 6, 10.0, false],
	"hurt": [4, 3, 10.0, false],
	"death": [5, 6, 10.0, false],
}


func _initialize() -> void:
	var sheet: Texture2D = load(SHEET)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim: String in ANIMATIONS:
		var spec: Array = ANIMATIONS[anim]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, spec[2])
		frames.set_animation_loop(anim, spec[3])
		for i: int in spec[1]:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * CELL, spec[0] * CELL, CELL, CELL)
			frames.add_frame(anim, atlas)
	ResourceSaver.save(frames, "res://data/enemies/sombra_errante_frames.tres")

	var data := EnemyData.new()
	data.id = &"sombra_errante"
	data.display_name = "Sombra errante"
	data.sprite_frames = load("res://data/enemies/sombra_errante_frames.tres")
	data.sprite_scale = 0.5
	data.sprite_offset = Vector2(0, -3)
	data.max_health = 3
	data.move_speed = 38.0
	data.chase_speed = 78.0
	data.detection_range = 130.0
	data.lose_range = 230.0
	data.attack_range = 22.0
	data.attack_damage = 1
	data.attack_windup = 0.5
	data.attack_time = 0.15
	data.attack_cooldown = 0.9
	data.patrol_radius = 70.0
	ResourceSaver.save(data, "res://data/enemies/sombra_errante.tres")

	# The scene is hand-written like grunt.tscn: it inherits enemy.tscn and only sets `data`.
	print("sombra errante written")
	quit()
