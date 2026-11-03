extends SceneTree
## Writes the Ojo del sol's SunEyeData (data/enemies/ojo_sol.tres). Its SpriteFrames (64x64 cells)
## are data/enemies/ojo_sol_frames.tres; the scene scenes/enemies/ojo_sol.tscn is hand-written (it
## floats: its body collides with walls but not with ponds).
## Run: godot --headless --path . --script res://tools/make_ojo_sol.gd


func _initialize() -> void:
	var data := SunEyeData.new()
	data.id = &"ojo_sol"
	data.display_name = "Ojo del sol"
	data.placeholder_color = Color(0.95, 0.6, 0.15)
	data.sprite_frames = load("res://data/enemies/ojo_sol_frames.tres")
	# 64x64 cells, its art drawn by tools/make_ojo_sol_art.py with its shadow (its feet) on row 52:
	# they sit a few pixels below the body's center.
	data.sprite_offset = Vector2(0, -14)
	data.max_health = 6
	data.move_speed = 22.0
	data.chase_speed = 30.0
	data.detection_range = 300.0
	data.lose_range = 400.0
	# It starts aiming within this distance; the laser itself reaches `laser_range` (across a whole
	# room: a wall stops it first).
	data.attack_range = 300.0
	data.attack_damage = 1
	# The ray follows Nico this long, then holds for `lock_time`, then the laser burns `attack_time`.
	data.attack_windup = 1.1
	# A long burn: at `laser_turn_speed` the laser sweeps up to about 60 degrees after Nico.
	data.attack_time = 2.0
	data.attack_cooldown = 2.4
	data.hurt_time = 0.2
	data.knockback_speed = 90.0
	data.knockback_resistance = 0.3
	data.patrol_radius = 30.0
	data.patrol_wait = 1.8
	data.aim_turn_speed = 100.0
	# The laser follows Nico too, slower: running around the eye (about 35-55 degrees/s at its
	# distances) or a dash outruns it.
	data.laser_turn_speed = 30.0
	data.lock_time = 0.35
	data.approach_distance = 200.0
	data.recover_time = 0.6
	data.laser_range = 520.0
	data.laser_width = 8.0
	data.muzzle_distance = 6.0
	data.beam_art = load("res://assets/sprites/ojo_sol/ojo_sol_beam.png")
	data.aim_art = load("res://assets/sprites/ojo_sol/ojo_sol_aim.png")
	data.spin_art = load("res://assets/sprites/ojo_sol/ojo_sol_spin.png")
	data.art_directions = 16
	ResourceSaver.save(data, "res://data/enemies/ojo_sol.tres")
	print("ojo_sol written")
	quit()
