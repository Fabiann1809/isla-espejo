extends SceneTree
## Writes the Forjador condenado's DoomedForgerData (data/enemies/forjador_condenado.tres). Its
## SpriteFrames come from tools/make_temple_enemy_frames.gd; the scene
## scenes/enemies/forjador_condenado.tscn is hand-written.
## Run: godot --headless --path . --script res://tools/make_forjador_condenado.gd


func _initialize() -> void:
	var data := DoomedForgerData.new()
	data.id = &"forjador_condenado"
	data.display_name = "Forjador condenado"
	data.placeholder_color = Color(0.55, 0.3, 0.2)
	data.sprite_frames = load("res://data/enemies/forjador_condenado_frames.tres")
	# 96x96 cells: the feet sit a few pixels below the body's center.
	data.sprite_offset = Vector2(0, -30)
	data.max_health = 7
	# A slow, heavy smith: the blocks do the chasing.
	data.move_speed = 22.0
	data.chase_speed = 34.0
	data.detection_range = 170.0
	data.lose_range = 260.0
	# The hammer swing up close.
	data.attack_range = 26.0
	data.attack_damage = 1
	data.attack_windup = 0.55
	data.attack_time = 0.2
	data.attack_cooldown = 1.4
	data.hurt_time = 0.25
	data.knockback_speed = 80.0
	data.knockback_resistance = 0.4
	data.patrol_radius = 40.0
	data.patrol_wait = 1.2
	data.drop_range = 150.0
	data.drop_windup = 0.6
	data.drop_cooldown = 3.5
	data.blocks_per_drop = 3
	data.drop_spread = 36.0
	data.max_blocks = 5
	data.warning_color = Color(1.0, 0.45, 0.1)
	data.door_lane_half_width = 48.0
	data.room_margin = 12.0
	data.block_size = Vector2(22, 14)
	data.block_height = 14.0
	data.fall_time = 0.8
	data.fall_height = 70.0
	data.impact_damage = 1
	data.impact_time = 0.15
	data.impact_margin = 3.0
	data.block_lifetime = 7.0
	data.fade_time = 0.6
	data.cool_time = 3.0
	data.hot_color = Color(1.0, 0.5, 0.15)
	data.cold_color = Color(0.27, 0.25, 0.27)
	data.edge_color = Color(1.0, 0.85, 0.4)
	ResourceSaver.save(data, "res://data/enemies/forjador_condenado.tres")
	print("forjador_condenado written")
	quit()
