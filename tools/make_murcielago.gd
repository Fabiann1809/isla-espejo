extends SceneTree
## Builds the Murciélago's DiverData (data/enemies/murcielago.tres): fast and fragile, it circles Nico
## and dives through him (scripts/enemies/diver.gd). Its SpriteFrames come from
## tools/make_character_frames.gd; the scene scenes/enemies/murcielago.tscn is hand-written.
## Run: godot --headless --path . --script res://tools/make_murcielago.gd


func _initialize() -> void:
	var data := DiverData.new()
	data.id = &"murcielago"
	data.display_name = "Murciélago"
	data.placeholder_color = Color(0.42, 0.3, 0.5)
	data.sprite_frames = load("res://data/enemies/murcielago_frames.tres")
	data.sprite_scale = 0.5
	data.sprite_offset = Vector2(0, -1)
	data.max_health = 2
	data.move_speed = 55.0
	data.chase_speed = 95.0
	data.detection_range = 140.0
	data.lose_range = 240.0
	data.attack_range = 18.0
	data.attack_damage = 1
	# Warning (rear back, blink, lane on the ground), then a dive of at most attack_time.
	data.attack_windup = 0.4
	data.attack_time = 0.5
	# Half climbing away after the dive, half circling before the next one.
	data.attack_cooldown = 2.0
	data.hurt_time = 0.2
	data.knockback_speed = 160.0
	data.patrol_radius = 80.0
	data.orbit_radius = 46.0
	data.weave_amplitude = 12.0
	data.weave_frequency = 1.4
	data.orbit_lead = 0.8
	data.turn_time_min = 0.9
	data.turn_time_max = 2.2
	data.dive_trigger_range = 84.0
	data.dive_speed = 250.0
	data.dive_overshoot = 30.0
	data.climb_speed = 95.0
	data.group_gap = 0.55
	ResourceSaver.save(data, "res://data/enemies/murcielago.tres")
	print("murcielago written")
	quit()
