extends SceneTree
## Builds the SpriteFrames of the skills' art (data/skills/<id>_frames.tres) from the strips in
## assets/sprites/skills/ drawn by tools/make_skill_art.py (square cells side by side). A zone's
## frames hold `start` (played once), an optional `loop` (held while the zone lasts) and an optional
## `end` (played once before it goes). The cast burst is one `start`.
## Run: godot --headless --path . --script res://tools/make_skill_frames.gd

const DIR := "res://assets/sprites/skills/"
## id -> {animation: [strip name, cell size, frames per second, loops]}
const SETS := {
	&"roots": {
		&"start": ["roots_start", 96, 12.0, false],
		&"loop": ["roots_loop", 96, 6.0, true],
		&"end": ["roots_end", 96, 10.0, false],
	},
	&"current": {&"start": ["current_wave", 64, 16.0, false]},
	&"shadow": {&"start": ["shadow_puff", 32, 14.0, false]},
	&"cast_burst": {&"start": ["cast_burst", 32, 14.0, false]},
}


func _initialize() -> void:
	for id: StringName in SETS:
		var frames := SpriteFrames.new()
		frames.remove_animation(&"default")
		for anim: StringName in SETS[id]:
			var spec: Array = SETS[id][anim]
			var strip: Texture2D = load(DIR + spec[0] + ".png")
			var cell: int = spec[1]
			frames.add_animation(anim)
			frames.set_animation_speed(anim, spec[2])
			frames.set_animation_loop(anim, spec[3])
			for i in strip.get_width() / cell:
				var atlas := AtlasTexture.new()
				atlas.atlas = strip
				atlas.region = Rect2(i * cell, 0, cell, cell)
				frames.add_frame(anim, atlas)
		var error := ResourceSaver.save(frames, "res://data/skills/%s_frames.tres" % id)
		print("%s frames written (error %d)" % [id, error])
	quit()
