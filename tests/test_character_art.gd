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
			var range: Vector2 = {&"idle": Vector2(4, 6), &"walk": Vector2(8, 12), &"run": Vector2(8, 12), &"attack": Vector2(10, 12)}[anim]
			if name == "nico_frames" and anim == &"attack":
				continue
			if fps < range.x or fps > range.y:
				fps_ok = false
				print("  out of range: %s %s %.1f fps" % [name, anim, fps])
	_check(fps_ok, "idle runs at 4-6 fps, walk and run at 8-12, attack at 10-12")
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

	var elder = load("res://scenes/npcs/elder.tscn").instantiate()
	root.add_child(elder)
	await process_frame
	_check(elder.get_node("Sprite").visible and not elder.get_node("Body").visible, "the elder shows its sprite instead of the colored figure")
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
		cells.append(str((frames.get_frame_texture(anim, i) as AtlasTexture).region.position))
	return cells
