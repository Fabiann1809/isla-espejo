extends SceneTree
## Character art test: every SpriteFrames loads with the animations the game plays, the scenes
## that use them still build, and an NPC without art keeps its colored figure.
## Run: godot --headless --path . --script res://tests/test_character_art.gd

## SpriteFrames path -> animations it must have.
const PLAYED := {
	"res://data/player/nico_frames.tres": [&"idle", &"walk", &"attack"],
	"res://data/enemies/sombra_errante_frames.tres": [&"idle", &"walk", &"run", &"attack", &"hurt", &"death"],
	"res://data/enemies/murcielago_frames.tres": [&"idle", &"walk", &"run", &"attack", &"hurt", &"death"],
	"res://data/enemies/ancient_guardian_frames.tres": [&"idle", &"walk", &"run", &"attack", &"hurt", &"death"],
	"res://data/enemies/guardian_del_bosque_frames.tres": [&"idle", &"walk", &"run", &"attack", &"hurt", &"death"],
	"res://data/enemies/serpiente_frames.tres": [&"idle", &"attack", &"hurt", &"death"],
	"res://data/enemies/guardian_de_la_isla_frames.tres": [&"idle", &"attack", &"hurt", &"death"],
	"res://data/npcs/elder_frames.tres": [&"idle", &"face_south"],
	"res://data/npcs/traveler_frames.tres": [&"idle", &"face_south"],
	"res://data/npcs/merchant_frames.tres": [&"idle", &"face_south"],
}
## Cell size of every sheet: 32x32 for Nico and the Sombra errante, 64x64 for the rest.
const SMALL := ["nico_frames", "sombra_errante_frames"]

## The Sombra floats without feet, so walking reuses its hover cells on purpose.
const IDLE_MAY_SHARE_WITH_WALK := ["sombra_errante_frames"]
const ENEMY_FRAMES := ["sombra_errante_frames", "murcielago_frames", "ancient_guardian_frames", "guardian_del_bosque_frames"]

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	for path: String in PLAYED:
		var frames: SpriteFrames = load(path)
		_check(frames != null, "%s loads" % path.get_file())
		if frames == null:
			continue
		for anim: StringName in PLAYED[path]:
			_check(frames.has_animation(anim) and frames.get_frame_count(anim) > 0, "%s has %s" % [path.get_file(), anim])
		var expected := 32.0 if path.get_file().get_basename() in SMALL else 64.0
		var size: Vector2 = frames.get_frame_texture(&"idle", 0).get_size()
		_check(size == Vector2(expected, expected), "%s cells are %dx%d" % [path.get_file(), expected, expected])

	for name: String in ENEMY_FRAMES:
		var frames: SpriteFrames = load("res://data/enemies/%s.tres" % name)
		var idle := _cells(frames, &"idle")
		var others := {}
		for anim: StringName in [&"attack", &"hurt", &"death"] + ([] if name in IDLE_MAY_SHARE_WITH_WALK else [&"walk", &"run"]):
			for cell in _cells(frames, anim):
				others[cell] = true
		var clash := idle.filter(func(cell: String) -> bool: return others.has(cell))
		_check(clash.is_empty(), "%s: idle does not use cells of other animations %s" % [name, clash])
	# Speeds that read well: rest 4-6, walk and run 8-12, attack 10-12 (one swing is stretched over the
	# real windup + strike anyway, see Enemy._update_animation).
	var fps_ok := true
	for name: String in ENEMY_FRAMES + ["nico_frames"]:
		var frames: SpriteFrames = load(("res://data/player/%s.tres" if name == "nico_frames" else "res://data/enemies/%s.tres") % name)
		for anim: StringName in [&"idle", &"walk", &"run", &"attack"]:
			if not frames.has_animation(anim):
				continue
			var fps := frames.get_animation_speed(anim)
			var idle_range := Vector2(8, 8) if name == "murcielago_frames" else Vector2(4, 6)
			var range: Vector2 = {&"idle": idle_range, &"walk": Vector2(8, 12), &"run": Vector2(8, 12), &"attack": Vector2(10, 12)}[anim]
			if name == "nico_frames" and anim == &"attack":
				continue
			if fps < range.x or fps > range.y:
				fps_ok = false
				print("  out of range: %s %s %.1f fps" % [name, anim, fps])
	_check(fps_ok, "idle runs at 4-6 fps (bat 8), walk and run at 8-12, attack at 10-12")
	# New bat art: one 64x64 strip per animation.
	var bat: SpriteFrames = load("res://data/enemies/murcielago_frames.tres")
	var bat_spec := {&"idle": [4, 8.0, true], &"walk": [6, 12.0, true], &"run": [6, 12.0, true], &"attack": [4, 10.0, false], &"hurt": [2, 8.0, false], &"death": [4, 8.0, false]}
	for anim: StringName in bat_spec:
		var want: Array = bat_spec[anim]
		_check(bat.get_frame_count(anim) == want[0] and bat.get_animation_speed(anim) == want[1] and bat.get_animation_loop(anim) == want[2], "bat %s: %d frames, %.0f fps, loop %s" % [anim, want[0], want[1], want[2]])
	var boss_idle: SpriteFrames = load("res://data/enemies/guardian_del_bosque_frames.tres")
	_check(boss_idle.get_frame_count(&"idle") == 1, "the forest guardian rests on one still cell")

	var player = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	_check(player.get_node("Sprite").sprite_frames.has_animation(&"walk"), "the player uses the new Nico frames")
	player.queue_free()

	for scene: String in ["murcielago", "sombra_errante", "ancient_guardian", "forest_guardian"]:
		var enemy = load("res://scenes/enemies/%s.tscn" % scene).instantiate()
		root.add_child(enemy)
		await process_frame
		_check(enemy.get_node_or_null("Sprite") != null, "%s shows its sprite" % scene)
		enemy.queue_free()

	# The Sombra errante is as tall as Nico (27 px), feet on the same ground line.
	var shadow = load("res://scenes/enemies/sombra_errante.tscn").instantiate()
	root.add_child(shadow)
	await process_frame
	var shadow_sprite: AnimatedSprite2D = shadow.get_node("Sprite")
	var shadow_height := _visible_height(shadow_sprite)
	var atlas := shadow_sprite.sprite_frames.get_frame_texture(&"idle", 0) as AtlasTexture
	var used := atlas.atlas.get_image().get_region(Rect2i(atlas.region)).get_used_rect()
	var feet := shadow_sprite.position.y + (used.end.y - atlas.region.size.y / 2.0) * shadow_sprite.scale.y
	_check(shadow_height >= 25.0 and shadow_height <= 29.0 and absf(feet - 8.0) <= 1.0,
			"the Sombra errante is %.1f px tall with its feet at y %.1f" % [shadow_height, feet])
	shadow.queue_free()

	var elder = load("res://scenes/npcs/elder.tscn").instantiate()
	root.add_child(elder)
	await process_frame
	_check(elder.get_node("Sprite").visible and not elder.get_node("Body").visible, "the elder shows its sprite instead of the colored figure")
	_check(elder.sprite_scale == 0.5, "the elder is drawn at half size")
	var height := _visible_height(elder.get_node("Sprite"))
	_check(height >= 24.0 and height <= 34.0, "the elder is about as tall as Nico (%.1f px)" % height)
	# A new NPC with 64x64 art gets the same size without setting anything.
	for id: String in ["traveler", "merchant"]:
		var npc = load("res://scenes/npcs/npc.tscn").instantiate()
		npc.sprite_frames = load("res://data/npcs/%s_frames.tres" % id)
		root.add_child(npc)
		await process_frame
		var npc_height := _visible_height(npc.get_node("Sprite"))
		_check(npc_height >= 24.0 and npc_height <= 34.0, "%s is about as tall as Nico by default (%.1f px)" % [id, npc_height])
		npc.queue_free()
	var plain = load("res://scenes/npcs/npc.tscn").instantiate()
	root.add_child(plain)
	await process_frame
	_check(plain.get_node("Body").visible and not plain.get_node("Sprite").visible, "an NPC without art keeps the colored figure")

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


## The sheet position of every cell an animation shows.
func _cells(frames: SpriteFrames, anim: StringName) -> Array:
	var cells := []
	for i in frames.get_frame_count(anim):
		var atlas := frames.get_frame_texture(anim, i) as AtlasTexture
		cells.append("%s %s" % [atlas.atlas.resource_path, atlas.region.position])
	return cells


## The tallest the visible pixels of any idle cell get on screen (cell art times the node's scale).
func _visible_height(sprite: AnimatedSprite2D) -> float:
	var tallest := 0.0
	for i in sprite.sprite_frames.get_frame_count(&"idle"):
		var atlas := sprite.sprite_frames.get_frame_texture(&"idle", i) as AtlasTexture
		var cell := atlas.atlas.get_image().get_region(Rect2i(atlas.region))
		tallest = maxf(tallest, cell.get_used_rect().size.y * sprite.scale.y)
	return tallest
