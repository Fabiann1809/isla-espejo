extends SceneTree
## Generates the weapon resources in data/weapons/.
## Run from the repo root: godot --headless --path . --script res://tools/make_weapon_data.gd
## The .tres files can be edited by hand afterwards (balance lives there); this only creates them
## in the right format.


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/weapons")

	var sword := WeaponData.new()
	sword.id = &"sword"
	sword.display_name = "Espada corta"
	sword.damage = 1
	sword.attack_time = 0.2
	sword.attack_cooldown = 0.35
	sword.move_factor = 0.3
	ResourceSaver.save(sword, "res://data/weapons/sword.tres")

	print("weapon data written")
	quit()
