extends SceneTree
## Writes the Carcelero de cadenas' ChainJailerData (data/enemies/carcelero_cadenas.tres). Its
## SpriteFrames come from tools/make_temple_enemy_frames.gd; the scene
## scenes/enemies/carcelero_cadenas.tscn is hand-written.
## Run: godot --headless --path . --script res://tools/make_carcelero_cadenas.gd


func _initialize() -> void:
	var data := ChainJailerData.new()
	data.id = &"carcelero_cadenas"
	data.display_name = "Carcelero de cadenas"
	data.placeholder_color = Color(0.62, 0.22, 0.16)
	data.sprite_frames = load("res://data/enemies/carcelero_cadenas_frames.tres")
	# 64x64 cells: the feet sit a few pixels below the body's center.
	data.sprite_offset = Vector2(0, -16)
	data.max_health = 6
	data.move_speed = 30.0
	data.chase_speed = 46.0
	data.detection_range = 170.0
	data.lose_range = 260.0
	# The melee swing that follows a catch.
	data.attack_range = 24.0
	data.attack_damage = 1
	data.attack_windup = 0.4
	data.attack_time = 0.2
	data.attack_cooldown = 1.2
	data.knockback_speed = 100.0
	data.knockback_resistance = 0.3
	data.patrol_radius = 50.0
	data.patrol_wait = 1.2
	data.hurt_time = 0.2
	data.chain_range = 120.0
	data.chain_min_range = 40.0
	data.chain_windup = 0.65
	data.aim_lock_time = 0.2
	data.chain_speed = 280.0
	data.retract_speed = 360.0
	data.tip_radius = 6.0
	data.chain_damage = 1
	data.chain_cooldown = 3.0
	data.chain_recover = 0.25
	data.pull_speed = 240.0
	data.pull_time = 1.1
	ResourceSaver.save(data, "res://data/enemies/carcelero_cadenas.tres")
	print("carcelero_cadenas written")
	quit()
