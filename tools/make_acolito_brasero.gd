extends SceneTree
## Writes the Acólito del brasero's BrazierAcolyteData (data/enemies/acolito_brasero.tres). Its
## SpriteFrames come from tools/make_temple_enemy_frames.gd; the scene
## scenes/enemies/acolito_brasero.tscn is hand-written. Its flames are orb.tscn tinted with fire.
## Run: godot --headless --path . --script res://tools/make_acolito_brasero.gd


func _initialize() -> void:
	var data := BrazierAcolyteData.new()
	data.id = &"acolito_brasero"
	data.display_name = "Acólito del brasero"
	data.placeholder_color = Color(0.9, 0.42, 0.12)
	data.sprite_frames = load("res://data/enemies/acolito_brasero_frames.tres")
	# 64x64 cells: the feet sit a few pixels below the body's center.
	data.sprite_offset = Vector2(0, -16)
	data.max_health = 5
	data.move_speed = 26.0
	data.chase_speed = 40.0
	data.detection_range = 180.0
	data.lose_range = 270.0
	data.attack_range = 140.0
	data.attack_damage = 1
	data.attack_windup = 0.7
	data.attack_time = 0.25
	data.attack_cooldown = 2.4
	data.knockback_speed = 110.0
	data.patrol_radius = 40.0
	data.patrol_wait = 1.4
	data.hurt_time = 0.2
	data.shuffle_time = 0.4
	data.shuffle_wait = 1.0
	data.projectile_scene = load("res://scenes/enemies/orb.tscn")
	data.projectile_speed = 85.0
	data.projectile_range = 200.0
	data.muzzle_distance = 10.0
	data.fan_count = 5
	data.fan_angle = 70.0
	data.fire_tint = Color(1.0, 0.62, 0.35)
	data.preferred_distance = 90.0
	data.retreat_speed = 50.0
	data.retreat_max_time = 1.4
	data.retreat_lookahead = 24.0
	ResourceSaver.save(data, "res://data/enemies/acolito_brasero.tres")
	print("acolito_brasero written")
	quit()
