extends SceneTree
## Writes the Verdugo de piedra's data (data/enemies/verdugo_piedra.tres). Its SpriteFrames (80x80
## cells) come from tools/make_temple_enemy_frames.gd; the scene scenes/enemies/verdugo_piedra.tscn
## is hand-written (it widens the body and the hurtbox for its size).
## Run: godot --headless --path . --script res://tools/make_verdugo_piedra.gd


func _initialize() -> void:
	var data := StoneExecutionerData.new()
	data.id = &"verdugo_piedra"
	data.display_name = "Verdugo de piedra"
	data.placeholder_color = Color(0.42, 0.36, 0.33)
	data.sprite_frames = load("res://data/enemies/verdugo_piedra_frames.tres")
	data.sprite_offset = Vector2(0, -22)
	data.max_health = 20
	data.move_speed = 16.0
	data.chase_speed = 26.0
	data.detection_range = 150.0
	data.lose_range = 250.0
	# Close enough to slam: the wave then reaches far beyond it.
	data.attack_range = 44.0
	data.attack_damage = 2
	data.attack_windup = 0.9
	data.attack_time = 0.3
	data.attack_cooldown = 1.6
	data.hurt_time = 0.2
	data.knockback_speed = 60.0
	data.knockback_resistance = 0.85
	data.attack_armor = true
	data.patrol_radius = 30.0
	data.patrol_wait = 2.0
	data.warning_radius = 30.0
	data.recover_time = 1.0
	data.wave_max_radius = 110.0
	data.wave_time = 0.75
	data.wave_band = 12.0
	data.wave_damage = 2
	ResourceSaver.save(data, "res://data/enemies/verdugo_piedra.tres")
	print("verdugo_piedra written")
	quit()
