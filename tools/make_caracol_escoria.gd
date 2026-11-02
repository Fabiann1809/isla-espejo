extends SceneTree
## Writes the Caracol de escoria's SlagSnailData (data/enemies/caracol_escoria.tres). Its
## SpriteFrames come from tools/make_temple_enemy_frames.gd; the scene
## scenes/enemies/caracol_escoria.tscn is hand-written.
## Run: godot --headless --path . --script res://tools/make_caracol_escoria.gd


func _initialize() -> void:
	var data := SlagSnailData.new()
	data.id = &"caracol_escoria"
	data.display_name = "Caracol de escoria"
	data.placeholder_color = Color(0.45, 0.3, 0.25)
	data.sprite_frames = load("res://data/enemies/caracol_escoria_frames.tres")
	# 64x64 cells: the feet sit a few pixels below the body's center.
	data.sprite_offset = Vector2(0, -5)
	# Very sturdy: lots of health, barely pushed, and a hit never cuts its bite short.
	data.max_health = 14
	data.knockback_resistance = 0.85
	data.attack_armor = true
	data.move_speed = 12.0
	data.chase_speed = 20.0
	data.detection_range = 140.0
	data.lose_range = 220.0
	data.attack_range = 20.0
	data.attack_damage = 1
	data.attack_windup = 0.6
	data.attack_time = 0.2
	data.attack_cooldown = 1.6
	data.knockback_speed = 80.0
	data.patrol_radius = 50.0
	data.patrol_wait = 1.5
	data.hurt_time = 0.12
	data.trail_spacing = 14.0
	data.trail_radius = 9.0
	data.trail_lifetime = 4.0
	data.trail_damage = 1
	data.trail_tick = 0.5
	data.trail_slow_factor = 0.55
	data.trail_slow_time = 0.6
	data.trail_color = Color(0.95, 0.38, 0.08, 0.6)
	ResourceSaver.save(data, "res://data/enemies/caracol_escoria.tres")
	print("caracol_escoria written")
	quit()
