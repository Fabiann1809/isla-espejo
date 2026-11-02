extends SceneTree
## Writes the Centinela de obsidiana's data (data/enemies/centinela_obsidiana.tres). Its SpriteFrames
## come from tools/make_temple_enemy_frames.gd; the scene scenes/enemies/centinela_obsidiana.tscn is
## hand-written.
## Run: godot --headless --path . --script res://tools/make_centinela_obsidiana.gd


func _initialize() -> void:
	var data := ObsidianSentinelData.new()
	data.id = &"centinela_obsidiana"
	data.display_name = "Centinela de obsidiana"
	data.placeholder_color = Color(0.16, 0.13, 0.2)
	data.sprite_frames = load("res://data/enemies/centinela_obsidiana_frames.tres")
	data.sprite_offset = Vector2(0, -16)
	data.max_health = 6
	data.move_speed = 22.0
	data.chase_speed = 34.0
	data.detection_range = 150.0
	data.lose_range = 240.0
	data.attack_range = 24.0
	data.attack_damage = 1
	data.attack_windup = 0.6
	data.attack_time = 0.2
	data.attack_cooldown = 1.4
	data.hurt_time = 0.25
	data.knockback_speed = 90.0
	data.knockback_resistance = 0.5
	data.attack_armor = true
	data.patrol_radius = 40.0
	data.patrol_wait = 1.5
	data.shield_arc = 140.0
	data.shield_down_time = 0.9
	data.block_pose_time = 0.3
	data.turn_rate = 110.0
	data.swing_aim_angle = 35.0
	ResourceSaver.save(data, "res://data/enemies/centinela_obsidiana.tres")
	print("centinela_obsidiana written")
	quit()
