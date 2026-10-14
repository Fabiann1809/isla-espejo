extends SceneTree
## Generates data/ai/director_rules.tres: how the island reacts to each play style.
## Run from the repo root: godot --headless --path . --script res://tools/make_director_data.gd
## This is the AI's rule table. After generating it, tune the numbers by editing the .tres
## (or this script and regenerating). Texts are Spanish and shown to the player.
##
## Reaction design (see docs/JUEGO.md, section 6):
##   aggressive -> tougher enemies, more of them, more ambush rooms
##   stealth    -> sharper senses, wider patrols, more guarded ("watch") rooms
##   balanced   -> a mild mix of both


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/ai")

	var aggressive := DirectorRule.new()
	aggressive.health_multiplier = 1.4
	aggressive.speed_multiplier = 1.1
	aggressive.count_multiplier = 1.3
	aggressive.room_weights = {&"ambush": 3.0, &"standard": 0.8}
	aggressive.island_line = "La isla endurece a sus criaturas."
	aggressive.hints = ["Criaturas más resistentes y rápidas", "Más enemigos por sala", "Más emboscadas"]

	var stealth := DirectorRule.new()
	stealth.vision_multiplier = 1.6
	stealth.patrol_multiplier = 2.0
	stealth.count_multiplier = 1.0
	stealth.room_weights = {&"watch": 5.0, &"ambush": 0.4}
	stealth.island_line = "La isla afina sus sentidos."
	stealth.hints = ["Enemigos que ven desde más lejos", "Patrullas más amplias", "Más salas vigiladas"]

	var balanced := DirectorRule.new()
	balanced.health_multiplier = 1.15
	balanced.vision_multiplier = 1.2
	balanced.patrol_multiplier = 1.3
	balanced.count_multiplier = 1.1
	balanced.island_line = ""
	balanced.hints = ["La isla aún te estudia: un poco más dura en todo"]

	var config := DirectorConfig.new()
	config.rules = {&"aggressive": aggressive, &"stealth": stealth, &"balanced": balanced}
	config.full_intensity_difference = 0.6
	config.balanced_intensity = 1.0
	config.texts = {
		"prepare_title": "La isla se prepara:",
	}
	ResourceSaver.save(config, "res://data/ai/director_rules.tres")
	print("director data written")
	quit()
