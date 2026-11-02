extends SceneTree
## Writes the soot manta's data (data/enemies/manta_hollin.tres, a SootMantaData). Its art is
## data/enemies/manta_hollin_frames.tres (tools/make_temple_enemy_frames.gd). The scene
## scenes/enemies/manta_hollin.tscn is hand-written.
## Run: godot --headless --path . --script res://tools/make_manta_hollin.gd


func _initialize() -> void:
	var data := SootMantaData.new()
	data.id = &"manta_hollin"
	data.display_name = "Manta de hollín"
	data.placeholder_color = Color(0.95, 0.45, 0.15)
	data.sprite_frames = load("res://data/enemies/manta_hollin_frames.tres")
	data.sprite_offset = Vector2(0, -16)
	data.max_health = 6
	data.move_speed = 45.0
	data.chase_speed = 95.0
	data.detection_range = 170.0
	data.lose_range = 280.0
	data.attack_damage = 1
	# The mark: long enough to see the circle and step out of it.
	data.attack_windup = 0.55
	data.attack_cooldown = 1.6
	data.hurt_time = 0.2
	data.knockback_speed = 140.0
	data.patrol_radius = 80.0
	data.patrol_wait = 0.6
	data.fly_height = 14.0
	data.dive_height = 2.0
	data.height_speed = 30.0
	data.shadow_offset = Vector2(0, 6)
	data.shadow_size = Vector2(16, 5)
	data.hover_distance = 72.0
	data.orbit_lead_degrees = 35.0
	data.hover_tolerance = 22.0
	data.dive_warning_radius = 14.0
	data.windup_backoff_speed = 18.0
	data.dive_speed = 230.0
	data.dive_overshoot = 40.0
	data.climb_time = 0.55
	data.climb_drag = 400.0
	ResourceSaver.save(data, "res://data/enemies/manta_hollin.tres")
	print("manta_hollin written")
	quit()
