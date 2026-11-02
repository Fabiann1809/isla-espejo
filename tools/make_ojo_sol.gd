extends SceneTree
## Writes the Ojo del sol's SunEyeData (data/enemies/ojo_sol.tres). Its SpriteFrames (96x96 cells)
## are data/enemies/ojo_sol_frames.tres; the scene scenes/enemies/ojo_sol.tscn is hand-written (it
## floats: its body collides with walls but not with ponds).
## Run: godot --headless --path . --script res://tools/make_ojo_sol.gd


func _initialize() -> void:
	var data := SunEyeData.new()
	data.id = &"ojo_sol"
	data.display_name = "Ojo del sol"
	data.placeholder_color = Color(0.95, 0.6, 0.15)
	data.sprite_frames = load("res://data/enemies/ojo_sol_frames.tres")
	# 96x96 cells: the feet sit a few pixels below the body's center.
	data.sprite_offset = Vector2(0, -30)
	data.max_health = 6
	data.move_speed = 22.0
	data.chase_speed = 30.0
	data.detection_range = 200.0
	data.lose_range = 290.0
	# It starts aiming within this distance; the laser itself reaches `laser_range`.
	data.attack_range = 190.0
	data.attack_damage = 1
	# The ray follows Nico this long, then holds for `lock_time`, then the laser burns `attack_time`.
	data.attack_windup = 1.1
	data.attack_time = 0.3
	data.attack_cooldown = 2.4
	data.hurt_time = 0.2
	data.knockback_speed = 90.0
	data.knockback_resistance = 0.3
	data.patrol_radius = 30.0
	data.patrol_wait = 1.8
	data.aim_turn_speed = 100.0
	data.lock_time = 0.35
	data.approach_distance = 140.0
	data.recover_time = 0.6
	data.laser_range = 260.0
	data.laser_width = 8.0
	data.muzzle_distance = 6.0
	ResourceSaver.save(data, "res://data/enemies/ojo_sol.tres")
	print("ojo_sol written")
	quit()
