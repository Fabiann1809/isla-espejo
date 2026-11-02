extends SceneTree
## Writes the Custodio del sello's SealGuardianData (data/enemies/custodio_sello.tres). Its
## SpriteFrames come from tools/make_temple_enemy_frames.gd; the scene
## scenes/enemies/custodio_sello.tscn is hand-written.
## Run: godot --headless --path . --script res://tools/make_custodio_sello.gd


func _initialize() -> void:
	var data := SealGuardianData.new()
	data.id = &"custodio_sello"
	data.display_name = "Custodio del sello"
	data.placeholder_color = Color(0.85, 0.55, 0.25)
	data.sprite_frames = load("res://data/enemies/custodio_sello_frames.tres")
	# 96x96 cells: the feet sit a few pixels below the body's center.
	data.sprite_offset = Vector2(0, -30)
	data.max_health = 6
	# Slow: it keeps behind its allies instead of hunting Nico.
	data.move_speed = 22.0
	data.chase_speed = 34.0
	data.detection_range = 170.0
	data.lose_range = 260.0
	# A weak, slow swing for when Nico comes too close.
	data.attack_range = 22.0
	data.attack_damage = 1
	data.attack_windup = 0.6
	data.attack_time = 0.2
	data.attack_cooldown = 1.6
	data.knockback_speed = 130.0
	data.patrol_radius = 40.0
	data.patrol_wait = 1.4
	data.hurt_time = 0.25
	data.seal_radius = 90.0
	data.seal_windup = 0.8
	data.seal_recover = 0.4
	data.shield_time = 3.5
	data.seal_cooldown = 6.0
	data.link_range = 150.0
	data.shield_refresh = 0.25
	data.ally_keep_fraction = 0.55
	data.seal_color = Color(0.45, 0.9, 1.0)
	data.link_width = 1.0
	data.link_alpha = 0.6
	data.ally_ring_radius = 10.0
	ResourceSaver.save(data, "res://data/enemies/custodio_sello.tres")
	print("custodio_sello written")
	quit()
