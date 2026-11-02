extends SceneTree
## Writes the bridge worm's data (data/enemies/gusano_puentes.tres, a BridgeWormData). Its art is
## data/enemies/gusano_puentes_frames.tres (tools/make_temple_enemy_frames.gd); the picture of one
## body piece is cut here from the first idle frame (a chunk of its back, rounded off) and stored in
## the data. The scene scenes/enemies/gusano_puentes.tscn is hand-written.
## Run: godot --headless --path . --script res://tools/make_gusano_puentes.gd

const IDLE_STRIP := "res://assets/sprites/gusano_puentes/gusano_puentes_idle.png"
## A piece of the coiled back in the first idle frame (64x64 cells), clear of the head.
const SEGMENT_REGION := Rect2i(13, 29, 24, 26)


func _initialize() -> void:
	var data := BridgeWormData.new()
	data.id = &"gusano_puentes"
	data.display_name = "Gusano de los puentes"
	data.placeholder_color = Color(0.85, 0.35, 0.15)
	data.sprite_frames = load("res://data/enemies/gusano_puentes_frames.tres")
	data.sprite_offset = Vector2(0, -16)
	data.segment_texture = _segment_texture()
	data.max_health = 8
	data.move_speed = 40.0
	data.burrow_speed = 85.0
	data.detection_range = 170.0
	data.lose_range = 280.0
	data.attack_damage = 1
	# Time it stays under between two surges.
	data.attack_cooldown = 1.4
	data.hurt_time = 0.2
	data.knockback_speed = 100.0
	# Half buried: a hit barely moves it.
	data.knockback_resistance = 0.85
	data.patrol_radius = 70.0
	data.patrol_wait = 0.8
	data.emerge_offset = 44.0
	data.emerge_lead = 0.35
	data.emerge_windup = 0.6
	data.emerge_warning_radius = 18.0
	data.surge_speed = 210.0
	data.surge_distance = 120.0
	data.surface_time = 1.1
	data.segment_count = 4
	data.segment_spacing = 13.0
	data.segment_body_radius = 7.0
	data.segment_hit_radius = 10.0
	ResourceSaver.save(data, "res://data/enemies/gusano_puentes.tres")
	print("gusano_puentes written")
	quit()


## The chunk of back with the corners outside an ellipse cleared, so a piece reads as a round
## body ring instead of a cut rectangle. Read straight from the PNG (headless runs have no GPU).
func _segment_texture() -> Texture2D:
	var strip := Image.load_from_file(ProjectSettings.globalize_path(IDLE_STRIP))
	var piece := strip.get_region(SEGMENT_REGION)
	piece.convert(Image.FORMAT_RGBA8)
	var half := Vector2(piece.get_size()) / 2.0
	for y in piece.get_height():
		for x in piece.get_width():
			var d := (Vector2(x, y) + Vector2(0.5, 0.5) - half) / half
			if d.length_squared() > 1.0:
				piece.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(piece)
