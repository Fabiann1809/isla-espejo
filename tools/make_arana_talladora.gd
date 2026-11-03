extends SceneTree
## Writes the Araña talladora's CarvingSpiderData (data/enemies/arana_talladora.tres). Its
## SpriteFrames come from tools/make_temple_enemy_frames.gd; the scene
## scenes/enemies/arana_talladora.tscn is hand-written.
## Run: godot --headless --path . --script res://tools/make_arana_talladora.gd


func _initialize() -> void:
	var data := CarvingSpiderData.new()
	data.id = &"arana_talladora"
	data.display_name = "Araña talladora"
	data.placeholder_color = Color(0.7, 0.32, 0.15)
	data.sprite_frames = load("res://data/enemies/arana_talladora_frames.tres")
	# 64x64 cells, its art drawn by tools/make_arana_talladora_art.py with the feet on row 44:
	# they sit a few pixels below the body's center.
	data.sprite_offset = Vector2(0, -6)
	data.max_health = 5
	# It scuttles fast between drills.
	data.move_speed = 50.0
	data.chase_speed = 100.0
	data.detection_range = 170.0
	data.lose_range = 260.0
	# How far from itself it can drill; the drilling's warning is the special animation, then the cracks.
	data.attack_range = 120.0
	data.attack_damage = 1
	data.attack_windup = 0.5
	data.attack_time = 0.2
	data.attack_cooldown = 2.4
	data.hurt_time = 0.2
	data.knockback_speed = 140.0
	data.patrol_radius = 80.0
	data.patrol_wait = 0.5
	data.reposition_distance = 90.0
	data.reposition_samples = 6
	data.preferred_distance = 80.0
	data.reposition_time = 1.0
	data.spot_wait = 0.25
	data.room_margin = 24.0
	data.pits_per_drill = 2
	data.pit_spread = 40.0
	data.pit_tiles = 2
	data.snap_to_tiles = true
	data.crack_time = 0.9
	data.sunk_time = 2.5
	data.close_time = 0.4
	data.pit_damage = 1
	data.pit_tick = 0.7
	data.hold_time = 0.5
	data.crack_color = Color(1.0, 0.55, 0.15, 0.9)
	data.pit_color = Color(0.06, 0.03, 0.03, 0.95)
	data.rim_color = Color(0.85, 0.3, 0.08, 0.9)
	data.crack_trail_width = 1.0
	data.pit_art = load("res://assets/sprites/arana_talladora/arana_talladora_pit.png")
	data.crack_art = load("res://assets/sprites/arana_talladora/arana_talladora_crack.png")
	ResourceSaver.save(data, "res://data/enemies/arana_talladora.tres")
	print("arana_talladora written")
	quit()
