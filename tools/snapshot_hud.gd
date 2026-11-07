extends SceneTree
## Saves a screenshot of the HUD (gold, an upgrade, a fragment, one unlocked skill on cooldown).
## Needs a window: godot --path . --script res://tools/snapshot_hud.gd  -> user://hud.png


func _initialize() -> void:
	await process_frame
	var level: Node = load("res://scenes/levels/forest_level.tscn").instantiate()
	root.add_child(level)
	for i in 30:
		await process_frame
	# The island's camera intro hides the HUD while it plays: wait for it to end.
	var intro := level.find_child("ChapterIntro", true, false)
	if intro != null and intro.has_signal("finished"):
		await intro.finished
		for i in 10:
			await process_frame
	var state = root.get_node("GameState")
	state.collect_fragment(&"green")
	root.get_node("Events").fragment_collected.emit(&"green")
	state.add_upgrade(&"crit_chance")
	state.add_upgrade(&"crit_chance")
	state.add_upgrade(&"bow_damage")
	var player := get_first_node_in_group("player")
	player.add_gold(37)
	player.skills.unlock(load("res://data/skills/roots.tres"))
	player.skills.try_use(0)
	for i in 20:
		await process_frame
	var image := root.get_viewport().get_texture().get_image()
	image.save_png("user://hud.png")
	print("saved ", ProjectSettings.globalize_path("user://hud.png"))
	quit()
