extends SceneTree
## Writes the Monje sin rostro's FacelessMonkData (data/enemies/monje_sin_rostro.tres). Its
## SpriteFrames (96x96 cells) are data/enemies/monje_sin_rostro_frames.tres; the scene
## scenes/enemies/monje_sin_rostro.tscn is hand-written. Its shots are orb.tscn tinted violet.
## Run: godot --headless --path . --script res://tools/make_monje_sin_rostro.gd


func _initialize() -> void:
	var data := FacelessMonkData.new()
	data.id = &"monje_sin_rostro"
	data.display_name = "Monje sin rostro"
	data.placeholder_color = Color(0.55, 0.3, 0.7)
	data.sprite_frames = load("res://data/enemies/monje_sin_rostro_frames.tres")
	# 96x96 cells: the feet sit a few pixels below the body's center.
	data.sprite_offset = Vector2(0, -30)
	data.max_health = 5
	data.move_speed = 26.0
	data.chase_speed = 36.0
	data.detection_range = 180.0
	data.lose_range = 270.0
	data.attack_range = 190.0
	data.attack_damage = 1
	data.attack_windup = 0.45
	data.attack_time = 0.2
	data.attack_cooldown = 2.2
	data.hurt_time = 0.2
	data.knockback_speed = 110.0
	data.patrol_radius = 40.0
	data.patrol_wait = 1.5
	data.symbol_count = 4
	data.symbol_margin = 40.0
	data.symbol_spread = 110.0
	data.symbol_gap = 70.0
	data.symbol_clearance = 12.0
	data.symbol_tries = 80
	data.symbol_radius = 10.0
	data.vanish_time = 0.35
	data.hidden_time = 0.55
	data.appear_time = 0.25
	data.min_player_distance = 50.0
	data.max_player_distance = 170.0
	data.preferred_distance = 120.0
	data.recover_time = 0.5
	data.shot_count = 3
	data.shot_spread = 45.0
	data.projectile_scene = load("res://scenes/enemies/orb.tscn")
	data.projectile_speed = 95.0
	data.projectile_range = 220.0
	data.muzzle_distance = 10.0
	ResourceSaver.save(data, "res://data/enemies/monje_sin_rostro.tres")
	print("monje_sin_rostro written")
	quit()
