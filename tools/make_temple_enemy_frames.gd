extends SceneTree
## Builds the SpriteFrames of the temple enemies (island 3), `data/enemies/<id>_frames.tres`, from the
## strips made by tools/make_temple_enemy_art.py (`assets/sprites/<id>/<id>_<animation>.png`, square
## cells). Animations: idle, walk, run (the walk), attack, special, hurt and death, facing right.
## Each enemy's EnemyData is written by its own tool (tools/make_<id>.gd).
## Run: godot --headless --path . --script res://tools/make_temple_enemy_frames.gd

const STRIP := "res://assets/sprites/%s/%s_%s.png"
const ENEMIES := [
	&"centinela_obsidiana", &"carcelero_cadenas", &"acolito_brasero", &"verdugo_piedra",
	&"duelista_maldito", &"salamandra_cristal", &"gusano_puentes", &"caracol_escoria",
	&"carnero_basalto", &"manta_hollin",
]
## animation -> [strip, frames per second, loops]
const ANIMATIONS := {
	&"idle": [&"idle", 6.0, true],
	&"walk": [&"walk", 10.0, true],
	&"run": [&"walk", 12.0, true],
	&"attack": [&"attack", 12.0, false],
	&"special": [&"special", 10.0, false],
	&"hurt": [&"hurt", 9.0, false],
	&"death": [&"death", 8.0, false],
}


func _initialize() -> void:
	for id: StringName in ENEMIES:
		var frames := SpriteFrames.new()
		frames.remove_animation(&"default")
		for anim: StringName in ANIMATIONS:
			var spec: Array = ANIMATIONS[anim]
			var strip: Texture2D = load(STRIP % [id, id, spec[0]])
			var cell := strip.get_height()
			frames.add_animation(anim)
			frames.set_animation_speed(anim, spec[1])
			frames.set_animation_loop(anim, spec[2])
			for i in strip.get_width() / cell:
				var atlas := AtlasTexture.new()
				atlas.atlas = strip
				atlas.region = Rect2(i * cell, 0, cell, cell)
				frames.add_frame(anim, atlas)
		ResourceSaver.save(frames, "res://data/enemies/%s_frames.tres" % id)
	print("temple enemy frames written")
	quit()
