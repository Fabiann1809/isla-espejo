extends SceneTree
## Front-only merchant. Run after make_merchant_art.py and Godot --import.


func _initialize() -> void:
	build_frames()
	quit()


static func build_frames() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim: String in ["idle", "interact", "face_south"]:
		var strip_name := "idle" if anim == "face_south" else anim
		var strip: Texture2D = load("res://assets/sprites/npcs/merchant/merchant_%s.png" % strip_name)
		assert(strip != null and strip.get_size() == Vector2(384, 64))
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 8.0 if anim == "interact" else 6.0)
		frames.set_animation_loop(anim, anim == "idle")
		for i in (1 if anim == "face_south" else 6):
			var atlas := AtlasTexture.new()
			atlas.atlas = strip
			atlas.region = Rect2(i * 64, 0, 64, 64)
			frames.add_frame(anim, atlas)
	var error := ResourceSaver.save(frames, "res://data/npcs/merchant_frames.tres")
	assert(error == OK)
	print("merchant frames written")
