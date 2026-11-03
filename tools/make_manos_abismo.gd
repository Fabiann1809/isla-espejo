extends SceneTree
## Writes the Manos del abismo's AbyssHandsData (data/enemies/manos_abismo.tres). Its SpriteFrames
## come from tools/make_temple_enemy_frames.gd; the scene scenes/enemies/manos_abismo.tscn is
## hand-written (no body: the hand comes out of the ground and its arm reaches, it never walks into
## anybody).
## Run: godot --headless --path . --script res://tools/make_manos_abismo.gd


func _initialize() -> void:
	var data := AbyssHandsData.new()
	data.id = &"manos_abismo"
	data.display_name = "Manos del abismo"
	data.placeholder_color = Color(0.75, 0.25, 0.08)
	data.sprite_frames = load("res://data/enemies/manos_abismo_frames.tres")
	# 64x64 cells, its art drawn by tools/make_manos_abismo_art.py with the splash's last row on
	# row 52: the hand's base sits a few pixels below its center.
	data.sprite_offset = Vector2(0, -14)
	data.max_health = 5
	# It moves only under the ground, back to its spot when Nico leaves.
	data.move_speed = 60.0
	data.chase_speed = 60.0
	# It feels Nico anywhere in its room.
	data.detection_range = 320.0
	data.lose_range = 420.0
	# The warning before it comes out, the grab's damage and its rest under the ground.
	data.attack_windup = 0.8
	data.attack_damage = 1
	data.attack_cooldown = 1.6
	data.attack_range = 0.0
	data.attack_time = 0.0
	data.hurt_time = 0.25
	data.knockback_speed = 0.0
	data.knockback_resistance = 1.0
	# Burrowed it waits; it does not patrol.
	data.patrol_radius = 0.0
	data.patrol_wait = 1.0
	data.edge_margin = 10.0
	data.edge_jitter = 20.0
	data.fallback_distance = 90.0
	data.warning_radius = 14.0
	data.warning_color = Color(1.0, 0.35, 0.1)
	data.reach_length = 130.0
	data.reach_speed = 300.0
	data.grab_radius = 9.0
	data.hand_offset = Vector2(0, -10)
	data.hold_time = 0.9
	data.hold_pull_speed = 0.0
	data.retract_speed = 180.0
	data.out_time = 1.2
	data.sink_time = 0.4
	data.arm_width = 7.0
	data.arm_color = Color(0.62, 0.2, 0.08)
	data.arm_edge_color = Color(1.0, 0.5, 0.12)
	data.pool_radius = 11.0
	data.pool_color = Color(1.0, 0.45, 0.1, 0.75)
	data.warning_art = load("res://assets/sprites/manos_abismo/manos_abismo_warning.png")
	data.warning_frames = 8
	data.pool_art = load("res://assets/sprites/manos_abismo/manos_abismo_pool.png")
	data.pool_frames = 6
	data.pool_fps = 5.0
	data.arm_art = load("res://assets/sprites/manos_abismo/manos_abismo_arm.png")
	ResourceSaver.save(data, "res://data/enemies/manos_abismo.tres")
	print("manos_abismo written")
	quit()
