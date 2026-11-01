extends SceneTree
## Generates the Serpiente de piedra's data (data/enemies/stone_serpent.tres).
## Run from the repo root: godot --headless --path . --script res://tools/make_stone_serpent.gd
## (after tools/make_serpent_frames.gd, whose frames it uses). The numbers are the boss's balance:
## a little harder than the Guardián del bosque (90 health), since it is the second boss.


func _initialize() -> void:
	var boss := SerpentData.new()
	boss.id = &"stone_serpent"
	boss.display_name = "Serpiente de piedra"
	boss.placeholder_color = Color(0.45, 0.52, 0.42)
	boss.sprite_frames = load("res://data/enemies/stone_serpent_frames.tres")
	boss.sprite_scale = 1.0
	boss.sprite_offset = Vector2(0, -22)
	boss.max_health = 110
	boss.move_speed = 30.0
	boss.chase_speed = 78.0
	boss.detection_range = 230.0
	boss.lose_range = 420.0
	boss.attack_range = 40.0
	boss.attack_cooldown = 0.5
	boss.hurt_time = 0.0
	boss.knockback_speed = 0.0
	boss.knockback_resistance = 1.0
	boss.patrol_radius = 0.0

	boss.strike_time = 0.3
	boss.recover_time = 0.65
	boss.arena_radius = 190.0
	boss.phase_two_threshold = 0.5
	boss.phase_two_speed = 1.25
	boss.phase_two_windup = 0.75

	boss.charge_windup = 0.85
	boss.charge_speed = 300.0
	boss.charge_length = 230.0
	boss.charge_width = 30.0
	boss.charge_damage = 2
	boss.phase_two_charges = 2
	boss.charge_chain_windup = 0.55

	boss.spit_windup = 0.8
	boss.spit_count = 3
	boss.phase_two_extra_orbs = 2
	boss.spit_gap_degrees = 18.0
	boss.orb_speed = 85.0
	boss.orb_range = 240.0
	boss.orb_damage = 1
	boss.muzzle_distance = 18.0
	boss.projectile_scene = load("res://scenes/enemies/poison_orb.tscn")

	boss.zone_spread = 0.8
	boss.floor_margin = 40.0
	boss.zone_min_move = 64.0
	boss.zone_keep_distance = 80.0
	boss.zone_move_time = 1.6
	boss.phase_two_roar = 0.6

	boss.defeated_flag = &"ruins_boss_defeated"
	boss.pickup_scene = load("res://scenes/world/fragment_blue.tscn")
	var intro: Array[String] = [
		"Nico: Otra criatura guardando un fragmento…",
		"Serpiente: Las piedras recuerdan a todos los que cayeron aquí.",
	]
	boss.intro_lines = intro
	var defeat: Array[String] = ["Nico: Dos fragmentos. La brújula ya casi señala a casa."]
	boss.defeat_lines = defeat
	var error := ResourceSaver.save(boss, "res://data/enemies/stone_serpent.tres")
	print("stone serpent written (error %d)" % error)
	quit(0 if error == OK else 1)
