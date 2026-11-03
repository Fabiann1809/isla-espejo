extends SceneTree
## Writes the Salamandra de cristal's CrystalSalamanderData (data/enemies/salamandra_cristal.tres).
## Its SpriteFrames come from tools/make_temple_enemy_frames.gd, the art of its crystal and patch from
## tools/make_salamandra_cristal_art.py; the scene
## scenes/enemies/salamandra_cristal.tscn is hand-written.
## Run: godot --headless --path . --script res://tools/make_salamandra_cristal.gd


func _initialize() -> void:
	var data := CrystalSalamanderData.new()
	data.id = &"salamandra_cristal"
	data.display_name = "Salamandra de cristal"
	data.placeholder_color = Color(0.85, 0.3, 0.12)
	data.sprite_frames = load("res://data/enemies/salamandra_cristal_frames.tres")
	# 64x64 cells: the feet sit a few pixels below the body's center.
	data.sprite_offset = Vector2(0, -11)
	data.max_health = 4
	# Quick on its feet: it scurries from edge to edge.
	data.move_speed = 45.0
	data.chase_speed = 80.0
	data.detection_range = 170.0
	data.lose_range = 260.0
	# How far it spits; the spit's warning is the special animation, then the circle on the ground.
	data.attack_range = 150.0
	data.attack_damage = 1
	data.attack_windup = 0.5
	data.attack_time = 0.2
	data.attack_cooldown = 2.2
	data.knockback_speed = 130.0
	data.patrol_radius = 90.0
	data.patrol_wait = 0.6
	data.hurt_time = 0.2
	data.edge_margin = 28.0
	data.reposition_distance = 110.0
	data.reposition_samples = 6
	data.preferred_distance = 100.0
	data.reposition_time = 1.4
	data.spot_wait = 0.35
	data.flight_time = 0.75
	data.lob_height = 28.0
	data.crystal_size = 3.0
	data.muzzle_distance = 8.0
	data.crystal_color = Color(1.0, 0.8, 0.35)
	data.crystal_art = load("res://assets/sprites/salamandra_cristal/salamandra_cristal_crystal.png")
	data.crystal_art_fps = 12.0
	data.warning_color = Color(1.0, 0.55, 0.2)
	data.hazard_radius = 12.0
	data.hazard_max = 6
	data.hazard_spacing = 30.0
	data.hazard_cool_time = 0.8
	data.hazard_damage = 1
	data.hazard_tick = 0.5
	data.hazard_slow_factor = 0.8
	data.hazard_slow_time = 0.6
	data.hazard_color = Color(1.0, 0.72, 0.3, 0.6)
	data.hazard_art = load("res://assets/sprites/salamandra_cristal/salamandra_cristal_patch.png")
	ResourceSaver.save(data, "res://data/enemies/salamandra_cristal.tres")
	print("salamandra_cristal written")
	quit()
