extends SceneTree
## Generates the Guardián del bosque's data (data/enemies/forest_guardian.tres).
## Run from the repo root: godot --headless --path . --script res://tools/make_forest_boss.gd
## The numbers (health, patterns, phase two) are the boss's balance: tune them in the .tres.


func _initialize() -> void:
	var boss := BossData.new()
	boss.id = &"forest_guardian"
	boss.display_name = "Guardián del bosque"
	boss.max_health = 30
	boss.move_speed = 20.0
	boss.chase_speed = 42.0
	boss.detection_range = 230.0
	boss.lose_range = 420.0
	boss.attack_range = 40.0
	boss.attack_cooldown = 1.2
	boss.hurt_time = 0.0
	boss.knockback_speed = 0.0
	boss.knockback_resistance = 1.0
	boss.patrol_radius = 0.0

	boss.slam_radius = 46.0
	boss.slam_damage = 2
	boss.slam_windup = 0.9
	boss.slam_trigger_range = 58.0
	boss.roots_count = 3
	boss.roots_radius = 22.0
	boss.roots_damage = 1
	boss.roots_windup = 1.1
	boss.roots_spread = 64.0
	boss.strike_time = 0.25
	boss.recover_time = 0.8
	boss.arena_radius = 150.0
	boss.phase_two_threshold = 0.5
	boss.phase_two_speed = 1.3
	boss.phase_two_windup = 0.75
	boss.phase_two_extra_roots = 2

	boss.defeated_flag = &"forest_boss_defeated"
	boss.pickup_scene = load("res://scenes/world/fragment_green.tscn")
	var intro: Array[String] = [
		"Nico: Así que tú eres quien guarda el fragmento…",
		"Guardián: Nadie abandona la isla.",
	]
	boss.intro_lines = intro
	ResourceSaver.save(boss, "res://data/enemies/forest_guardian.tres")
	print("forest guardian written")
	quit()
