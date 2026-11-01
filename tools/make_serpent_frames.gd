extends SceneTree
## Builds the Serpiente de piedra's SpriteFrames (data/enemies/stone_serpent_frames.tres) from the
## source sheet (assets/sprites/serpiente/serpiente.png, cells of 64 px, 8 per row) and the frames
## derived from it by tools/make_serpent_art.py (serpiente_extra.png, one row).
## Run: godot --headless --path . --script res://tools/make_serpent_frames.gd
## Every pose faces right (the enemy flips it). data/enemies/serpiente_frames.tres (the art
## gallery's) is made by tools/make_character_frames.gd and is not touched here.

const SHEET := "res://assets/sprites/serpiente/serpiente.png"
const EXTRA := "res://assets/sprites/serpiente/serpiente_extra.png"
const CELL := 64
const COLS := 8

## Source cells: 1 coiled (side), 7 crawl, 8 reared up, 9 lunge, 10 venom in the mouth, 11 spitting,
## 12 hurt, 13 dying, 14 stone corpse, 15 hood open (rage).
## Extra cells: 0 idle breath, 1-4 crawl wave, 5 petrifying.
## name -> [fps, loops, [[sheet ("s" source, "x" extra), cell], ...]]
const ANIMS := {
	"idle": [3.0, true, [["s", 1], ["x", 0]]],
	"walk": [8.0, true, [["x", 1], ["x", 2], ["x", 3], ["x", 4]]],
	"run": [10.0, true, [["x", 1], ["x", 2], ["x", 3], ["x", 4]]],
	# Generic attack (windup pose, then the lunge), kept for anything that plays "attack".
	"attack": [8.0, false, [["s", 8], ["s", 9]]],
	"charge_windup": [1.0, false, [["s", 8]]],
	"charge": [1.0, false, [["s", 9]]],
	"spit_windup": [1.0, false, [["s", 10]]],
	"spit": [1.0, false, [["s", 11]]],
	"phase_two": [1.0, false, [["s", 15]]],
	"hurt": [8.0, false, [["s", 12]]],
	# It turns to stone: dying pose, half stone, then the stone corpse held a moment.
	"death": [4.0, false, [["s", 13], ["x", 5], ["s", 14], ["s", 14], ["s", 14]]],
}


func _initialize() -> void:
	var sheets := {"s": load(SHEET), "x": load(EXTRA)}
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim: String in ANIMS:
		var spec: Array = ANIMS[anim]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, spec[0])
		frames.set_animation_loop(anim, spec[1])
		for ref: Array in spec[2]:
			var index: int = ref[1]
			var atlas := AtlasTexture.new()
			atlas.atlas = sheets[ref[0]]
			atlas.region = Rect2((index % COLS) * CELL, (index / COLS) * CELL, CELL, CELL)
			frames.add_frame(anim, atlas)
	var error := ResourceSaver.save(frames, "res://data/enemies/stone_serpent_frames.tres")
	print("stone serpent frames written (error %d)" % error)
	quit(0 if error == OK else 1)
