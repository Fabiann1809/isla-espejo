extends SceneTree
## Writes the Campanero de bronce's BronzeBellRingerData (data/enemies/campanero_bronce.tres). Its
## SpriteFrames (96x96 cells) are data/enemies/campanero_bronce_frames.tres; the scene
## scenes/enemies/campanero_bronce.tscn is hand-written.
## Run: godot --headless --path . --script res://tools/make_campanero_bronce.gd


func _initialize() -> void:
	var data := BronzeBellRingerData.new()
	data.id = &"campanero_bronce"
	data.display_name = "Campanero de bronce"
	data.placeholder_color = Color(0.72, 0.5, 0.22)
	data.sprite_frames = load("res://data/enemies/campanero_bronce_frames.tres")
	# 96x96 cells: the feet sit a few pixels below the body's center.
	data.sprite_offset = Vector2(0, -30)
	data.max_health = 8
	data.move_speed = 18.0
	data.chase_speed = 28.0
	data.detection_range = 160.0
	data.lose_range = 250.0
	# Close enough to strike: its rings then reach far beyond it.
	data.attack_range = 70.0
	data.attack_damage = 1
	data.attack_windup = 0.8
	data.attack_time = 0.2
	data.attack_cooldown = 2.6
	data.hurt_time = 0.2
	data.knockback_speed = 80.0
	data.knockback_resistance = 0.6
	data.attack_armor = true
	data.patrol_radius = 30.0
	data.patrol_wait = 2.0
	data.warning_radius = 26.0
	data.recover_time = 0.9
	data.ring_count = 3
	data.ring_interval = 0.55
	data.ring_max_radius = 120.0
	data.ring_time = 0.9
	data.ring_band = 10.0
	data.ring_damage = 1
	ResourceSaver.save(data, "res://data/enemies/campanero_bronce.tres")
	print("campanero_bronce written")
	quit()
