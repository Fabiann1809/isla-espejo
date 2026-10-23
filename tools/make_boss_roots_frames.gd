extends SceneTree
## Builds the SpriteFrames of the forest boss roots (data/enemies/boss_roots_frames.tres) from the
## 64x64 strips in assets/sprites/guardian_del_bosque/raices/ (raices_<anim>_<A|B>.png).
## Run: godot --headless --path . --script res://tools/make_boss_roots_frames.gd
## Speeds are the drawn defaults: BossRoots stretches "brote" so it ends right when the hit lands.

const DIR := "res://assets/sprites/guardian_del_bosque/raices/raices_%s_%s.png"
const CELL := 64
## anim -> [frames, fps, loops]
const ANIMATIONS := {
	"aviso": [4, 8.0, true],
	"brote": [6, 12.0, false],
	"pico": [2, 10.0, true],
	"retirada": [4, 12.0, false],
}


func _initialize() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim: String in ANIMATIONS:
		var spec: Array = ANIMATIONS[anim]
		for variant in ["A", "B"]:
			var name := "%s_%s" % [anim, variant]
			var sheet: Texture2D = load(DIR % [anim, variant])
			frames.add_animation(name)
			frames.set_animation_speed(name, spec[1])
			frames.set_animation_loop(name, spec[2])
			for i: int in spec[0]:
				var atlas := AtlasTexture.new()
				atlas.atlas = sheet
				atlas.region = Rect2(i * CELL, 0, CELL, CELL)
				frames.add_frame(name, atlas)
	ResourceSaver.save(frames, "res://data/enemies/boss_roots_frames.tres")
	print("boss roots frames written")
	quit()
