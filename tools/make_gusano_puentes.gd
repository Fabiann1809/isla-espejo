extends SceneTree
## Writes the bridge worm's data (data/enemies/gusano_puentes.tres, a BridgeWormData). Its art is
## data/enemies/gusano_puentes_frames.tres (tools/make_temple_enemy_frames.gd); the pictures of its
## body pieces and of its ripple are strips drawn by tools/make_gusano_puentes_art.py.
## The scene scenes/enemies/gusano_puentes.tscn is hand-written.
## Run: godot --headless --path . --script res://tools/make_gusano_puentes.gd


func _initialize() -> void:
	var data := BridgeWormData.new()
	data.id = &"gusano_puentes"
	data.display_name = "Gusano de los puentes"
	data.placeholder_color = Color(0.85, 0.35, 0.15)
	data.sprite_frames = load("res://data/enemies/gusano_puentes_frames.tres")
	# 64x64 cells, its art drawn by tools/make_gusano_puentes_art.py with the pool's surface (its
	# feet) on row 54: they sit a few pixels below the body's center.
	data.sprite_offset = Vector2(0, -16)
	data.segment_texture = load("res://assets/sprites/gusano_puentes/gusano_puentes_segment.png")
	data.ripple_art = load("res://assets/sprites/gusano_puentes/gusano_puentes_ripple.png")
	data.max_health = 8
	data.move_speed = 40.0
	data.burrow_speed = 85.0
	data.detection_range = 170.0
	data.lose_range = 280.0
	data.attack_damage = 1
	# Time it stays under between two surges.
	data.attack_cooldown = 1.4
	data.hurt_time = 0.2
	data.knockback_speed = 100.0
	# Half buried: a hit barely moves it.
	data.knockback_resistance = 0.85
	data.patrol_radius = 70.0
	data.patrol_wait = 0.8
	data.emerge_offset = 44.0
	data.emerge_lead = 0.35
	data.emerge_windup = 0.6
	data.emerge_warning_radius = 18.0
	data.surge_speed = 210.0
	data.surge_distance = 120.0
	data.surface_time = 1.1
	data.segment_count = 4
	data.segment_spacing = 13.0
	data.segment_body_radius = 7.0
	data.segment_hit_radius = 10.0
	ResourceSaver.save(data, "res://data/enemies/gusano_puentes.tres")
	print("gusano_puentes written")
	quit()

