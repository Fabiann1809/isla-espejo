extends SceneTree
## Generates the three skill resources in data/skills/.
## Run from the repo root: godot --headless --path . --script res://tools/make_skill_data.gd
## The .tres files can be edited by hand afterwards (balance lives there); this only creates them
## in the right format. Fragments: green = Raíces, blue = Corriente, violet = Sombra.


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/skills")

	var roots := SkillData.new()
	roots.id = &"roots"
	roots.display_name = "Raíces"
	roots.description = "Hace brotar raíces que traban a los enemigos en una zona."
	roots.slot = 0
	roots.cooldown = 6.0
	roots.range = 56.0
	roots.color = Color(0.3, 0.75, 0.3)
	var roots_effect := RootsEffect.new()
	roots_effect.radius = 40.0
	roots_effect.duration = 3.0
	roots_effect.root_time = 0.35
	roots.effect = roots_effect
	ResourceSaver.save(roots, "res://data/skills/roots.tres")

	var current := SkillData.new()
	current.id = &"current"
	current.display_name = "Corriente"
	current.description = "Una ola empuja a los enemigos de frente y los ralentiza."
	current.slot = 1
	current.cooldown = 5.0
	current.range = 90.0
	current.color = Color(0.3, 0.55, 0.95)
	var current_effect := CurrentEffect.new()
	current_effect.arc_degrees = 100.0
	current_effect.push_speed = 260.0
	current_effect.slow_factor = 0.4
	current_effect.slow_time = 2.5
	current.effect = current_effect
	ResourceSaver.save(current, "res://data/skills/current.tres")

	var shadow := SkillData.new()
	shadow.id = &"shadow"
	shadow.display_name = "Sombra"
	shadow.description = "Un salto corto entre sombras: te vuelve difícil de detectar. Atacar rompe el efecto."
	shadow.slot = 2
	shadow.cooldown = 7.0
	shadow.range = 110.0
	shadow.color = Color(0.65, 0.4, 0.9)
	var shadow_effect := ShadowEffect.new()
	shadow_effect.stealth_time = 3.0
	shadow_effect.visibility = 0.3
	shadow.effect = shadow_effect
	ResourceSaver.save(shadow, "res://data/skills/shadow.tres")

	print("skill data written")
	quit()
