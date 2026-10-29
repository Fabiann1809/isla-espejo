extends SceneTree
## Frame time of the forest level with a window and without vsync (so the number is not capped at
## 60), while Nico walks across the start room. Compare before and after a visual change.
##   godot --path . --script res://tools/measure_fps.gd -- <seed>

const SECONDS := 6.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var map_seed := int(args[0]) if args.size() > 0 else 4242
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await process_frame
	# Run with a window, saving would be on: never touch the player's save or profile.
	root.get_node("SaveGame").persistence_enabled = false
	root.get_node("PlayerProfile").persistence_enabled = false
	var level = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.seed_value = map_seed
	level.use_director = false
	root.add_child(level)
	for i in 90:
		await process_frame
	var player: Node2D = level.player
	var room: Node2D = level.rooms[level.layout.start_cell]
	var frames := 0
	var worst := 0.0
	var start := Time.get_ticks_usec()
	var last := start
	while Time.get_ticks_usec() - start < SECONDS * 1000000.0:
		# Back and forth across the room, so the camera scrolls.
		var t := (Time.get_ticks_usec() - start) / 1000000.0
		player.global_position = room.global_position + Vector2(240 + sin(t) * 180.0, 150)
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		frames += 1
	var average := (Time.get_ticks_usec() - start) / 1000.0 / frames
	print("FPS seed %d: %.0f fps (%.2f ms per frame, worst %.2f ms), %d draw calls, %d nodes" % [
			map_seed, 1000.0 / average, average, worst,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	quit(0)
