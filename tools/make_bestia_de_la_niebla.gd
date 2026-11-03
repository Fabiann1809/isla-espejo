extends SceneTree
## Builds the Bestia de la niebla's ChargerData (data/enemies/bestia_de_la_niebla.tres): a pack
## hunter that flanks Nico and charges at him (scripts/enemies/charger.gd). Its SpriteFrames
## (data/enemies/bestia_de_la_niebla_frames.tres) are kept as they are; the scene
## scenes/enemies/bestia_de_la_niebla.tscn is hand-written.
## Run: godot --headless --path . --script res://tools/make_bestia_de_la_niebla.gd


func _initialize() -> void:
	var data := ChargerData.new()
	data.id = &"bestia_de_la_niebla"
	data.display_name = "Bestia de la niebla"
	data.placeholder_color = Color(0.28, 0.35, 0.42)
	data.sprite_frames = load("res://data/enemies/bestia_de_la_niebla_frames.tres")
	data.sprite_scale = 0.25
	data.sprite_offset = Vector2(0, -5)
	data.max_health = 5
	data.move_speed = 34.0
	data.chase_speed = 60.0
	data.detection_range = 145.0
	data.lose_range = 240.0
	data.vision_angle = 360.0
	data.attack_range = 24.0
	data.attack_damage = 1
	# Crouch with the lane on the ground, then a charge through Nico and charge_overshoot past him,
	# at most attack_time at charge_speed (132 px).
	data.attack_windup = 0.6
	data.attack_time = 0.6
	data.attack_cooldown = 1.6
	data.hurt_time = 0.25
	data.knockback_speed = 100.0
	data.knockback_resistance = 0.15
	# Arrows do not stop a charge once it is warned.
	data.attack_armor = true
	data.patrol_radius = 72.0
	data.patrol_wait = 0.8
	data.charge_trigger_range = 96.0
	data.charge_speed = 220.0
	data.charge_overshoot = 40.0
	data.aim_lock_time = 0.25
	data.wall_stun = 0.7
	data.pack_alert_range = 180.0
	data.pack_gap = 0.4
	data.flank_distance = 70.0
	data.flank_spread_degrees = 70.0
	data.flank_tolerance = 24.0
	data.flank_patience = 1.5
	data.lane_width = 12.0
	ResourceSaver.save(data, "res://data/enemies/bestia_de_la_niebla.tres")
	print("bestia de la niebla written")
	quit()
