extends SceneTree
## Writes the Baldosa hambrienta's data (data/enemies/baldosa_hambrienta.tres). Its SpriteFrames come
## from tools/make_temple_enemy_frames.gd; the scene scenes/enemies/baldosa_hambrienta.tscn is
## hand-written.
## Run: godot --headless --path . --script res://tools/make_baldosa_hambrienta.gd


func _initialize() -> void:
	var data := HungryTileData.new()
	data.id = &"baldosa_hambrienta"
	data.display_name = "Baldosa hambrienta"
	data.placeholder_color = Color(0.45, 0.3, 0.22)
	data.sprite_frames = load("res://data/enemies/baldosa_hambrienta_frames.tres")
	# 64x64 cells, its art drawn by tools/make_baldosa_hambrienta_art.py with the front's last row on
	# row 50: the tile's base sits a few pixels below its center.
	data.sprite_offset = Vector2(0, -12)
	data.max_health = 4
	# It only crawls once revealed, and never more than a tile.
	data.move_speed = 14.0
	data.chase_speed = 14.0
	# It notices Nico only when he is nearly on it; it never chases.
	data.detection_range = 40.0
	data.lose_range = 120.0
	data.attack_range = 22.0
	data.attack_damage = 1
	data.attack_cooldown = 1.1
	data.hurt_time = 0.25
	data.knockback_speed = 60.0
	data.knockback_resistance = 0.85
	data.patrol_radius = 0.0
	data.patrol_wait = 1.0
	data.trigger_radius = 22.0
	data.tell_time = 0.25
	data.bite_time = 0.25
	data.hold_time = 0.6
	data.reveal_time = 2.5
	data.crawl_leash = 16.0
	data.close_timeout = 2.0
	data.rearm_time = 1.0
	ResourceSaver.save(data, "res://data/enemies/baldosa_hambrienta.tres")
	print("baldosa_hambrienta written")
	quit()
