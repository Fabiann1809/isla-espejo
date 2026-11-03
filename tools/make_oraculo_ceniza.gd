extends SceneTree
## Writes the Oráculo de ceniza's AshOracleData (data/enemies/oraculo_ceniza.tres). Its SpriteFrames
## (64x64 cells, drawn by tools/make_oraculo_ceniza_art.py) are data/enemies/oraculo_ceniza_frames.tres;
## the scene scenes/enemies/oraculo_ceniza.tscn is hand-written.
## Run: godot --headless --path . --script res://tools/make_oraculo_ceniza.gd


func _initialize() -> void:
	var data := AshOracleData.new()
	data.id = &"oraculo_ceniza"
	data.display_name = "Oráculo de ceniza"
	data.placeholder_color = Color(0.7, 0.22, 0.12)
	data.sprite_frames = load("res://data/enemies/oraculo_ceniza_frames.tres")
	# 64x64 cells, its art drawn by tools/make_oraculo_ceniza_art.py with the feet on row 50:
	# they sit a few pixels below the body's center.
	data.sprite_offset = Vector2(0, -12)
	data.max_health = 5
	data.move_speed = 24.0
	data.chase_speed = 34.0
	data.detection_range = 190.0
	data.lose_range = 280.0
	data.attack_range = 180.0
	data.attack_damage = 1
	data.attack_windup = 0.5
	data.attack_time = 0.2
	data.attack_cooldown = 2.4
	data.hurt_time = 0.2
	data.knockback_speed = 110.0
	data.patrol_radius = 40.0
	data.patrol_wait = 1.6
	data.lead_time = 0.8
	data.max_lead = 110.0
	data.fall_time = 0.9
	data.fall_height = 120.0
	data.ball_radius = 5.0
	data.strike_radius = 22.0
	data.strike_damage = 1
	data.impact_time = 0.12
	data.burst_time = 0.3
	data.recover_time = 0.6
	# The falling ball, the seal that marks its spot and the burst, by the same art tool.
	data.ball_art = load("res://assets/sprites/oraculo_ceniza/oraculo_ceniza_ball.png")
	data.seal_art = load("res://assets/sprites/oraculo_ceniza/oraculo_ceniza_seal.png")
	data.burst_art = load("res://assets/sprites/oraculo_ceniza/oraculo_ceniza_burst.png")
	data.preferred_distance = 100.0
	data.approach_distance = 150.0
	data.retreat_speed = 42.0
	data.retreat_lookahead = 24.0
	ResourceSaver.save(data, "res://data/enemies/oraculo_ceniza.tres")
	print("oraculo_ceniza written")
	quit()
