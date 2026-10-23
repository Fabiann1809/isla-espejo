extends SceneTree
## Builds the Sombra errante EnemyData (the scene scenes/enemies/sombra_errante.tscn just inherits enemy.tscn).
## Its SpriteFrames come from tools/make_character_frames.gd. Run from the repo root: godot --headless --path . --script res://tools/make_sombra_errante.gd

func _initialize() -> void:
	var data := EnemyData.new()
	data.id = &"sombra_errante"
	data.display_name = "Sombra errante"
	data.sprite_frames = load("res://data/enemies/sombra_errante_frames.tres")
	data.sprite_scale = 1.0
	data.sprite_offset = Vector2(0, -7)
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
