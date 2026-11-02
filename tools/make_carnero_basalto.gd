extends SceneTree
## Writes the Carnero de basalto's data (data/enemies/carnero_basalto.tres). Its SpriteFrames come
## from tools/make_temple_enemy_frames.gd; the scene scenes/enemies/carnero_basalto.tscn is
## hand-written.
## Run: godot --headless --path . --script res://tools/make_carnero_basalto.gd


func _initialize() -> void:
	var data := BasaltRamData.new()
	data.id = &"carnero_basalto"
	data.display_name = "Carnero de basalto"
	data.placeholder_color = Color(0.3, 0.27, 0.28)
	data.sprite_frames = load("res://data/enemies/carnero_basalto_frames.tres")
	data.sprite_offset = Vector2(0, -16)
	data.max_health = 7
	data.move_speed = 30.0
	data.chase_speed = 40.0
	data.detection_range = 170.0
	data.lose_range = 260.0
	# It charges from afar: this is the distance at which it starts marking its lane.
	data.attack_range = 140.0
	data.attack_damage = 1
	data.attack_cooldown = 1.2
	data.hurt_time = 0.25
	data.knockback_speed = 80.0
	data.knockback_resistance = 0.6
	# A charging (or stunned) ram is not stopped by arrows; stunned is the moment to hit it.
	data.attack_armor = true
	data.patrol_radius = 50.0
	data.patrol_wait = 1.2
	data.charge_windup = 0.7
	data.charge_speed = 230.0
	data.charge_distance = 260.0
	data.charge_recover = 0.5
	data.stun_time = 1.6
	data.lane_width = 18.0
	ResourceSaver.save(data, "res://data/enemies/carnero_basalto.tres")
	print("carnero_basalto written")
	quit()
