extends SceneTree
## Writes the Máscara parásita's ParasiteMaskData (data/enemies/mascara_parasita.tres). Its
## SpriteFrames come from tools/make_temple_enemy_frames.gd (its art is drawn by
## tools/make_mascara_parasita_art.py); the scene
## scenes/enemies/mascara_parasita.tscn is hand-written.
## Run: godot --headless --path . --script res://tools/make_mascara_parasita.gd


func _initialize() -> void:
	var data := ParasiteMaskData.new()
	data.id = &"mascara_parasita"
	data.display_name = "Máscara parásita"
	data.placeholder_color = Color(0.62, 0.25, 0.75)
	data.sprite_frames = load("res://data/enemies/mascara_parasita_frames.tres")
	# 64x64 cells, its art drawn by tools/make_mascara_parasita_art.py: it floats, the lowest tip of
	# its tentacles on row 50 (where its shadow goes), a few pixels below the body's center.
	data.sprite_offset = Vector2(0, -12)
	data.max_health = 4
	data.move_speed = 40.0
	data.chase_speed = 70.0
	data.detection_range = 160.0
	data.lose_range = 260.0
	# Alone, a weak bite.
	data.attack_range = 18.0
	data.attack_damage = 1
	data.attack_windup = 0.45
	data.attack_time = 0.15
	data.attack_cooldown = 1.2
	data.knockback_speed = 150.0
	data.patrol_radius = 50.0
	data.patrol_wait = 0.8
	data.hurt_time = 0.2
	data.seek_range = 220.0
	data.seek_speed = 85.0
	data.attach_distance = 8.0
	data.ride_height = 14.0
	data.frenzy_speed = 1.45
	data.frenzy_cooldown_rate = 1.8
	data.frenzy_refresh = 0.3
	data.flee_speed = 95.0
	data.flee_time = 0.8
	data.reattach_delay = 1.0
	ResourceSaver.save(data, "res://data/enemies/mascara_parasita.tres")
	print("mascara_parasita written")
	quit()
