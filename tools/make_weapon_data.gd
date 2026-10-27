extends SceneTree
## Generates the weapon resources in data/weapons/.
## Run from the repo root: godot --headless --path . --script res://tools/make_weapon_data.gd
## The .tres files can be edited by hand afterwards (balance lives there); this only creates them
## in the right format.


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/weapons")

	var bow := WeaponData.new()
	bow.id = &"bow"
	bow.display_name = "Arco corto"
	bow.damage = 1
	bow.attack_time = 0.25
	bow.attack_cooldown = 0.4
	bow.move_factor = 0.5
	bow.projectile_scene = load("res://scenes/player/arrow.tscn")
	bow.projectile_speed = 260.0
	bow.projectile_range = 200.0
	bow.release_at = 0.5
	ResourceSaver.save(bow, "res://data/weapons/bow.tres")

	print("weapon data written")
	quit()
