extends SceneTree
## Writes the Relojero de trampas' TrapClockmakerData (data/enemies/relojero_trampas.tres). Its
## SpriteFrames come from tools/make_temple_enemy_frames.gd; the scene
## scenes/enemies/relojero_trampas.tscn is hand-written.
## Run: godot --headless --path . --script res://tools/make_relojero_trampas.gd


func _initialize() -> void:
	var data := TrapClockmakerData.new()
	data.id = &"relojero_trampas"
	data.display_name = "Relojero de trampas"
	data.placeholder_color = Color(0.6, 0.42, 0.25)
	data.sprite_frames = load("res://data/enemies/relojero_trampas_frames.tres")
	# 64x64 cells, its art drawn by tools/make_relojero_trampas_art.py with the feet on row 52:
	# they sit a few pixels below the body's center.
	data.sprite_offset = Vector2(0, -14)
	data.max_health = 4
	# Quick little legs: it keeps away while its traps do the work.
	data.move_speed = 40.0
	data.chase_speed = 85.0
	data.detection_range = 200.0
	data.lose_range = 300.0
	# A weak jab when cornered.
	data.attack_range = 20.0
	data.attack_damage = 1
	data.attack_windup = 0.45
	data.attack_time = 0.15
	data.attack_cooldown = 1.2
	data.hurt_time = 0.25
	data.knockback_speed = 150.0
	data.patrol_radius = 30.0
	data.patrol_wait = 1.0
	data.trap_kinds = [&"spikes", &"saw", &"fire", &"spikes"] as Array[StringName]
	data.trap_ring_radius = 60.0
	data.trap_margin = 28.0
	data.trap_damage = 1
	data.set_time = 0.8
	data.tick_interval = 0.8
	data.wind_time = 0.4
	data.flee_distance = 110.0
	data.flee_lookahead = 40.0
	data.flee_directions = 12
	data.flee_margin = 20.0
	data.spikes_size = 16.0
	data.spikes_warn_time = 0.45
	data.spikes_time = 0.4
	data.saw_track_length = 56.0
	data.saw_radius = 7.0
	data.saw_warn_time = 0.35
	data.saw_travel_time = 0.7
	data.fire_length = 56.0
	data.fire_width = 12.0
	data.fire_warn_time = 0.5
	data.fire_time = 0.5
	data.trap_base_color = Color(0.22, 0.2, 0.2)
	data.trap_metal_color = Color(0.82, 0.8, 0.78)
	data.trap_warn_color = Color(1.0, 0.75, 0.25)
	data.fire_color = Color(1.0, 0.45, 0.1, 0.85)
	data.dormant_color = Color(0.4, 0.38, 0.38)
	var art := "res://assets/sprites/relojero_trampas/relojero_trampas_%s.png"
	data.spikes_art = load(art % "spikes")
	data.saw_art = load(art % "saw")
	data.track_art = load(art % "track")
	data.fire_art = load(art % "fire")
	data.nozzle_art = load(art % "nozzle")
	ResourceSaver.save(data, "res://data/enemies/relojero_trampas.tres")
	print("relojero_trampas written")
	quit()
