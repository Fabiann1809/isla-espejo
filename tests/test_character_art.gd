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
