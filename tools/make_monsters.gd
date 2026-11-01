extends SceneTree
## Builds the BossData of the Guardián antiguo (the Murciélago is built by tools/make_murcielago.gd). Its art
## (SpriteFrames) comes from tools/make_character_sheets.py and make_character_frames.gd. Run:
##   godot --headless --path . --script res://tools/make_monsters.gd
## The scene scenes/enemies/ancient_guardian.tscn is hand-written and inherits
## enemy.tscn; only the numbers (here) and the art live in the .tres files.


func _initialize() -> void:
	_guardian()
	print("monsters written")
	quit()


func _guardian() -> void:
	var boss := BossData.new()
	boss.id = &"ancient_guardian"
	boss.display_name = "Guardián antiguo"
	boss.sprite_frames = load("res://data/enemies/ancient_guardian_frames.tres")
	boss.sprite_scale = 1.0
	boss.sprite_offset = Vector2(0, -18)
	# Stats start from the forest boss and are meant to be harder (chapter 3); tune them here.
	boss.max_health = 45
	boss.move_speed = 20.0
	boss.chase_speed = 46.0
	boss.detection_range = 230.0
	boss.lose_range = 420.0
	boss.attack_range = 40.0
	boss.attack_cooldown = 1.0
	boss.hurt_time = 0.0
	boss.knockback_speed = 0.0
	boss.knockback_resistance = 1.0
	boss.patrol_radius = 0.0
	boss.slam_radius = 50.0
	boss.slam_damage = 2
	boss.slam_windup = 0.8
	boss.slam_trigger_range = 62.0
	boss.roots_count = 4
	boss.roots_radius = 22.0
	boss.roots_damage = 1
	boss.roots_windup = 1.0
	boss.roots_spread = 70.0
	boss.strike_time = 0.25
	boss.recover_time = 0.7
	boss.arena_radius = 160.0
	boss.phase_two_extra_roots = 2
	boss.defeated_flag = &"temple_boss_defeated"
	var intro: Array[String] = [
		"Guardián: Los fragmentos no se llevan. Se quedan.",
	]
	boss.intro_lines = intro
	ResourceSaver.save(boss, "res://data/enemies/ancient_guardian.tres")
