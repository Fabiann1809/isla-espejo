extends SceneTree
## Dev aid (needs a window): casts the three skills in the test room and saves screenshots.
## Run: godot --path . --script res://tools/snapshot_skills.gd -- <folder>

var _dir := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else "user://"
	root.get_node("PlayerProfile").persistence_enabled = false
	var level: Node = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.seed_value = 7
	level.use_director = false
	root.add_child(level)
	await _frames(30)
	var player = level.player
	for id in ["roots", "current", "shadow"]:
		player.skills.unlock(load("res://data/skills/%s.tres" % id))
	player.facing = Vector2.RIGHT
	await _frames(5)
	await _shot("hud_icons")
	player.skills.try_use(0)
	await _frames(6)
	await _shot("roots_start")
	await _frames(40)
	await _shot("roots_loop")
	await _frames(120)
	player.skills.try_use(1)
	await _frames(5)
	await _shot("current_wave")
	await _frames(30)
	player.skills.try_use(2)
	await _frames(4)
	await _shot("shadow_puff")
	quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	image.save_png(_dir.path_join(name + ".png"))
	print("saved ", name)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
