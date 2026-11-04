extends SceneTree
## Builds the Sombra errante's TeleporterData (data/enemies/sombra_errante.tres): it fades out,
## reappears behind or beside Nico after a warning circle and strikes (scripts/enemies/teleporter.gd).
## Its SpriteFrames come from tools/make_character_frames.gd; the scene
## scenes/enemies/sombra_errante.tscn is hand-written.
## Run from the repo root: godot --headless --path . --script res://tools/make_sombra_errante.gd

func _initialize() -> void:
	var data := TeleporterData.new()
	data.id = &"sombra_errante"
	data.display_name = "Sombra errante"
	data.placeholder_color = Color(0.36, 0.26, 0.5)
	data.sprite_frames = load("res://data/enemies/sombra_errante_frames.tres")
	data.sprite_scale = 1.0
	data.sprite_offset = Vector2(0, -7)
	data.max_health = 4
	# It drifts slowly: it closes the distance by teleporting.
	data.move_speed = 34.0
	data.chase_speed = 52.0
	data.detection_range = 140.0
	data.lose_range = 240.0
	data.attack_range = 22.0
	data.attack_damage = 1
	# The strike after reappearing (and up close): its telegraph shows for attack_windup.
	data.attack_windup = 0.4
	data.attack_time = 0.15
	data.attack_cooldown = 1.2
	data.hurt_time = 0.2
	data.knockback_speed = 120.0
	data.patrol_radius = 70.0
	data.teleport_range = 150.0
	data.teleport_min_range = 40.0
	data.teleport_cooldown = 2.6
	data.fade_time = 0.35
	data.hidden_time = 0.45
	data.appear_time = 0.2
	data.appear_distance = 30.0
	data.warn_radius = 9.0
	ResourceSaver.save(data, "res://data/enemies/sombra_errante.tres")
	print("sombra errante written")
	quit()
