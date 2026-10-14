extends SceneTree
## Generates data/ai/profile_config.tres (tuning and texts of the player profile).
## Run from the repo root: godot --headless --path . --script res://tools/make_ai_data.gd
## The .tres can be edited by hand afterwards (that is where the AI is tuned).


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/ai")
	var config := ProfileConfig.new()

	config.skill_styles = {
		&"roots": &"aggressive",
		&"current": &"aggressive",
		&"shadow": &"stealth",
	}

	config.texts = {
		"title": "La isla te recuerda",
		"style_label": "Estilo de juego",
		"style_aggressive": "Agresivo",
		"style_stealth": "Sigiloso",
		"style_balanced": "Equilibrado",
		"message_aggressive": "La isla te vio luchar de frente. La próxima vez estará lista para ti.",
		"message_stealth": "La isla te sintió moverte entre las sombras. Aprenderá a mirar mejor.",
		"message_balanced": "La isla aún no sabe cómo eres. Sigue observándote.",
		"aggression": "Agresión",
		"stealth": "Sigilo",
		"stat_time": "Tiempo: %s",
		"stat_attacks": "Ataques: %d",
		"stat_skills": "Habilidades usadas: %d",
		"stat_rooms": "Salas visitadas: %d",
		"stat_evaded": "Salas evadidas: %d",
		"stat_detections": "Veces detectado: %d",
		"continue": "Pulsa E para volver a intentarlo",
	}

	ResourceSaver.save(config, "res://data/ai/profile_config.tres")
	print("ai data written")
	quit()
