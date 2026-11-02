extends SceneTree
## Writes the Núcleo de cría's BroodCoreData (data/enemies/nucleo_cria.tres) and the EnemyData of the
## creature it breeds, the cría volcánica (data/enemies/cria_volcanica.tres: the salamander's art at
## half size; the core tints it). The core's SpriteFrames come from
## tools/make_temple_enemy_frames.gd; the scenes scenes/enemies/nucleo_cria.tscn and
## cria_volcanica.tscn are hand-written.
## Run: godot --headless --path . --script res://tools/make_nucleo_cria.gd


func _initialize() -> void:
	_write_brood()
	_write_core()
	quit()


func _write_core() -> void:
	var data := BroodCoreData.new()
	data.id = &"nucleo_cria"
	data.display_name = "Núcleo de cría"
	data.placeholder_color = Color(0.9, 0.4, 0.1)
	data.sprite_frames = load("res://data/enemies/nucleo_cria_frames.tres")
	# 96x96 cells: the base of the structure sits a few pixels below its center.
	data.sprite_offset = Vector2(0, -30)
	data.max_health = 12
	# A structure: it never moves and cannot be pushed.
	data.move_speed = 0.0
	data.chase_speed = 0.0
	data.patrol_radius = 0.0
	data.knockback_resistance = 1.0
	data.attack_armor = true
	data.detection_range = 200.0
	data.lose_range = 320.0
	# Only the pose after a breeding.
	data.attack_time = 0.3
	data.hurt_time = 0.15
	data.brood_scene = load("res://scenes/enemies/cria_volcanica.tscn")
	data.energy = 6
	data.brood_per_spawn = 2
	data.max_brood = 3
	data.spawn_interval = 4.5
	data.first_spawn_delay = 1.2
	data.spawn_windup = 0.7
	data.spawn_radius = 28.0
	data.brood_tint = Color(1.0, 0.55, 0.35)
	data.spent_tint = Color(0.5, 0.45, 0.45)
	data.fuse_time = 0.9
	data.explosion_radius = 44.0
	data.explosion_damage = 1
	data.blast_time = 0.12
	data.warning_color = Color(1.0, 0.35, 0.1)
	data.blast_color = Color(1.0, 0.8, 0.3)
	data.fuse_flicker = 12.0
	ResourceSaver.save(data, "res://data/enemies/nucleo_cria.tres")
	print("nucleo_cria written")


func _write_brood() -> void:
	var data := EnemyData.new()
	data.id = &"cria_volcanica"
	data.display_name = "Cría volcánica"
	data.placeholder_color = Color(1.0, 0.5, 0.25)
	data.sprite_frames = load("res://data/enemies/salamandra_cristal_frames.tres")
	data.sprite_scale = 0.5
	data.sprite_offset = Vector2(0, -5)
	data.max_health = 1
	data.move_speed = 50.0
	data.chase_speed = 100.0
	data.detection_range = 200.0
	data.lose_range = 300.0
	data.attack_range = 14.0
	data.attack_damage = 1
	data.attack_windup = 0.35
	data.attack_time = 0.12
	data.attack_cooldown = 1.0
	data.knockback_speed = 170.0
	data.patrol_radius = 30.0
	data.patrol_wait = 0.5
	data.hurt_time = 0.15
	# Bred without end by a core: they leave nothing behind.
	data.drop_multiplier = 0.0
	ResourceSaver.save(data, "res://data/enemies/cria_volcanica.tres")
	print("cria_volcanica written")
