extends SceneTree
## Writes the Reina volcánica's data (data/enemies/reina_volcanica.tres, a VolcanicQueenData). Its
## art is drawn at game size by python tools/make_reina_volcanica_art.py and its SpriteFrames,
## data/enemies/reina_volcanica_frames.tres, come from tools/make_temple_enemy_frames.gd (run that
## first). The scene scenes/enemies/reina_volcanica.tscn is hand-written.
## Run: godot --headless --path . --script res://tools/make_reina_volcanica.gd


func _initialize() -> void:
	var data := VolcanicQueenData.new()
	data.id = &"reina_volcanica"
	data.display_name = "Reina volcánica"
	data.placeholder_color = Color(0.95, 0.4, 0.12)
	data.sprite_frames = load("res://data/enemies/reina_volcanica_frames.tres")
	# 64x64 cells, its shadow (it flies) on row 57: a few pixels below its center.
	data.sprite_offset = Vector2(0, -19)
	# A mini boss: tougher than any temple enemy (the slag snail has 14), softer than the forest's
	# Ente (30); its sting hurts like the rest.
	data.max_health = 20
	data.move_speed = 40.0
	data.chase_speed = 62.0
	data.detection_range = 200.0
	data.lose_range = 320.0
	data.attack_range = 56.0
	data.attack_damage = 1
	# The lane shows long enough to step aside; the lunge reaches lunge_speed * attack_time = 42 px.
	data.attack_windup = 0.6
	data.attack_time = 0.2
	data.attack_cooldown = 1.4
	data.hurt_time = 0.15
	data.knockback_speed = 90.0
	data.knockback_resistance = 0.4
	data.attack_armor = true
	data.patrol_radius = 50.0
	data.patrol_wait = 1.0
	# A rare fight: it leaves resources far more often than a normal enemy (like the Ente).
	data.drop_multiplier = 3.0
	data.windup_backoff_speed = 14.0
	data.lunge_speed = 210.0
	data.lunge_recover = 0.45
	data.brood_scene = load("res://scenes/enemies/cria_volcanica.tscn")
	data.brood_per_summon = 2
	data.max_brood = 3
	data.summon_interval = 6.5
	data.first_summon_delay = 2.0
	data.summon_windup = 0.8
	data.summon_recover = 0.4
	data.spawn_radius = 26.0
	data.brood_tint = Color.WHITE
	data.brood_dies_with_queen = true
	ResourceSaver.save(data, "res://data/enemies/reina_volcanica.tres")
	print("reina_volcanica written")
	quit()
