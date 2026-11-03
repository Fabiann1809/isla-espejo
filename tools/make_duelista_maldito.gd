extends SceneTree
## Writes the Duelista maldito's data (data/enemies/duelista_maldito.tres). Its SpriteFrames come
## from tools/make_temple_enemy_frames.gd; the scene scenes/enemies/duelista_maldito.tscn is
## hand-written.
## Run: godot --headless --path . --script res://tools/make_duelista_maldito.gd


func _initialize() -> void:
	var data := CursedDuelistData.new()
	data.id = &"duelista_maldito"
	data.display_name = "Duelista maldito"
	data.placeholder_color = Color(0.85, 0.8, 0.7)
	data.sprite_frames = load("res://data/enemies/duelista_maldito_frames.tres")
	data.sprite_offset = Vector2(0, -11)
	data.max_health = 5
	data.move_speed = 36.0
	data.chase_speed = 62.0
	data.detection_range = 170.0
	data.lose_range = 260.0
	data.attack_range = 24.0
	data.attack_damage = 1
	data.attack_windup = 0.35
	data.attack_time = 0.15
	data.attack_cooldown = 1.0
	data.hurt_time = 0.2
	data.knockback_speed = 140.0
	data.patrol_radius = 70.0
	data.patrol_wait = 0.8
	data.dodge_chance = 0.5
	data.dodge_cooldown = 2.5
	data.dodge_speed = 300.0
	data.dodge_time = 0.14
	data.arrow_sense_radius = 70.0
	data.arrow_lane_width = 14.0
	data.lunge_windup = 0.2
	data.lunge_speed = 250.0
	data.lunge_time = 0.24
	data.lunge_recover = 0.5
	data.masked_lunge_time = 0.36
	data.masked_dodge_chance = 0.85
	data.masked_dodge_cooldown = 1.4
	ResourceSaver.save(data, "res://data/enemies/duelista_maldito.tres")
	print("duelista_maldito written")
	quit()
