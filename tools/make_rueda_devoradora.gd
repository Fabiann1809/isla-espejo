extends SceneTree
## Writes the Rueda devoradora's data (data/enemies/rueda_devoradora.tres). Its SpriteFrames come from
## tools/make_temple_enemy_frames.gd; the scene scenes/enemies/rueda_devoradora.tscn is hand-written.
## Run: godot --headless --path . --script res://tools/make_rueda_devoradora.gd


func _initialize() -> void:
	var data := DevouringWheelData.new()
	data.id = &"rueda_devoradora"
	data.display_name = "Rueda devoradora"
	data.placeholder_color = Color(0.55, 0.4, 0.3)
	data.sprite_frames = load("res://data/enemies/rueda_devoradora_frames.tres")
	data.sprite_offset = Vector2(0, -30)
	data.max_health = 6
	data.move_speed = 25.0
	data.chase_speed = 35.0
	data.detection_range = 180.0
	data.lose_range = 280.0
	# It starts a burst from afar: this is the distance at which its faces start to glow.
	data.attack_range = 170.0
	data.attack_damage = 1
	data.attack_cooldown = 0.4
	data.hurt_time = 0.25
	data.knockback_speed = 80.0
	data.knockback_resistance = 0.8
	# A rolling stone is not stopped by arrows; the rest after a burst is the moment to hit it.
	data.attack_armor = true
	data.patrol_radius = 40.0
	data.patrol_wait = 1.2
	data.windup_time = 0.5
	data.roll_speed = 170.0
	data.roll_time = 2.4
	data.max_bounces = 4
	data.brake_time = 0.5
	data.rest_time = 0.9
	data.aim_bias = 0.35
	data.min_leave = 0.3
	data.wheel_radius = 13.0
	data.hub_offset = 22.0
	data.launch_time = 0.25
	ResourceSaver.save(data, "res://data/enemies/rueda_devoradora.tres")
	print("rueda_devoradora written")
	quit()
