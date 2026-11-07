extends SceneTree
## Builds the SpriteFrames of every enemy, boss and NPC from the sheets made by
## tools/make_character_sheets.py. It only builds art: stats live in the EnemyData/BossData .tres.
## Run: godot --headless --path . --script res://tools/make_character_frames.gd
## Cells are numbered in GIF order (row by row, 8 per row). Movement art must face right: the
## enemy flips it when it faces left. Animations the game does not play yet are kept for later.

const COLS := 8

## id -> { sheet, cell, anims: name -> [fps, loops, [cells...]] }
const ENEMIES := {
	# The Sombra floats (no feet), so walking and running reuse the hover cells (0-9) at other speeds.
	# Cells 48-57 are a full turn-around, not a walk cycle. 33-47 are side views facing left.
	"sombra_errante": {
		"sheet": "res://assets/sprites/sombra_errante/sombra_errante.png", "cell": 32,
		"anims": {
			"idle": [5.0, true, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]],
			"walk": [8.0, true, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]],
			"run": [10.0, true, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]],
			"attack": [10.0, false, [14, 15, 16, 17, 18, 19]],
			"hurt": [10.0, false, [21, 22, 23]],
			"death": [8.0, false, [58, 59, 60, 61, 62, 63]],
			"teleport": [10.0, false, [24, 25, 26, 27, 28]],
		},
	},
	# The bat uses one 64x64 strip per animation (new art), so "strips" replaces "sheet"/"cell".
	# strips: name -> [fps, loops, strip path, frame count]. The old murcielago.png sheet is kept unused.
	"murcielago": {
		"strips": {
			"idle": [8.0, true, "res://assets/sprites/murcielago/murcielago_idle.png", 4],
			"walk": [12.0, true, "res://assets/sprites/murcielago/murcielago_walk.png", 6],
			"run": [12.0, true, "res://assets/sprites/murcielago/murcielago_run.png", 6],
			"attack": [10.0, false, "res://assets/sprites/murcielago/murcielago_attack.png", 4],
			"hurt": [8.0, false, "res://assets/sprites/murcielago/murcielago_hurt.png", 2],
			"death": [8.0, false, "res://assets/sprites/murcielago/murcielago_death.png", 4],
		},
	},
	"ancient_guardian": {
		"sheet": "res://assets/sprites/guardian_antiguo/guardian_antiguo.png", "cell": 64,
		"anims": {
			"idle": [4.0, true, [0, 1]],
			"walk": [8.0, true, [2, 3]],
			"run": [8.0, true, [2, 3]],
			"attack": [10.0, false, [4, 5]],
			"cast": [10.0, false, [6, 7]],
			"punch": [10.0, false, [8, 9]],
			"hurt": [10.0, false, [12, 13]],
			"death": [8.0, false, [14, 15]],
		},
	},
	# The source has no real idle (cells 0-2 and 4 are poses of a turn-around), so it rests on one still cell.
	"guardian_del_bosque": {
		"sheet": "res://assets/sprites/guardian_del_bosque/guardian_del_bosque.png", "cell": 64,
		"anims": {
			"idle": [4.0, true, [0]],
			"walk": [8.0, true, [4, 5, 6, 5]],
			"run": [8.0, true, [4, 5, 6, 5]],
			"attack": [10.0, false, [8, 9]],
			"slam": [10.0, false, [10]],
			"phase_two": [6.0, true, [11]],
			"hurt": [10.0, false, [12]],
			"death": [8.0, false, [14, 15]],
		},
	},
	# Art only: no scene or behaviour uses these two yet.
	"serpiente": {
		"sheet": "res://assets/sprites/serpiente/serpiente.png", "cell": 64,
		"anims": {
			"idle": [4.0, true, [0, 1]],
			"walk": [6.0, true, [4, 5]],
			"run": [8.0, true, [7, 9]],
			"attack": [8.0, false, [8, 9, 10]],
			"spit": [8.0, false, [10, 11]],
			"hurt": [8.0, false, [12]],
			"death": [5.0, false, [13, 14]],
		},
	},
	"guardian_de_la_isla": {
		"sheet": "res://assets/sprites/guardian_de_la_isla/guardian_de_la_isla.png", "cell": 64,
		"anims": {
			"idle": [4.0, true, [0, 1, 2]],
			"walk": [5.0, true, [4, 5, 6]],
			"run": [5.0, true, [4, 5, 6]],
			"attack": [8.0, false, [8, 9, 10]],
			"charge": [6.0, true, [3, 7]],
			"hurt": [8.0, false, [12]],
			"death": [5.0, false, [13, 14, 15]],
		},
	},
}

const NPC_ROTATIONS := ["east", "north-east", "north-west", "north", "south-east", "south-west", "south", "west"]
const NPCS := {
	"elder": 8, "traveler": 9, "merchant": 9,  # id -> animation frames after the 8 rotations
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/npcs")
	for id: String in ENEMIES:
		var spec: Dictionary = ENEMIES[id]
		var frames := _new_frames()
		if spec.has("strips"):
			for anim: String in spec.strips:
				var s: Array = spec.strips[anim]
				var strip: Texture2D = load(s[2])
				_add(frames, strip, 64, anim, s[0], s[1], range(s[3]))
		else:
			var sheet: Texture2D = load(spec.sheet)
			for anim: String in spec.anims:
				var a: Array = spec.anims[anim]
				_add(frames, sheet, spec.cell, anim, a[0], a[1], a[2])
		ResourceSaver.save(frames, "res://data/enemies/%s_frames.tres" % id)
	for id: String in NPCS:
		var frames := _new_frames()
		var sheet: Texture2D = load("res://assets/sprites/npcs/%s/%s.png" % [id, id])
		var cells: Array = []
		for i in NPCS[id]:
			cells.append(NPC_ROTATIONS.size() + i)
		_add(frames, sheet, 64, "idle", 6.0, true, cells)
		for i in NPC_ROTATIONS.size():
			_add(frames, sheet, 64, "face_" + NPC_ROTATIONS[i], 1.0, false, [i])
		ResourceSaver.save(frames, "res://data/npcs/%s_frames.tres" % id)
	print("character frames written")
	quit()


func _new_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	return frames


func _add(frames: SpriteFrames, sheet: Texture2D, cell: int, anim: String, fps: float, loops: bool, cells: Array) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loops)
	for index: int in cells:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2((index % COLS) * cell, (index / COLS) * cell, cell, cell)
		frames.add_frame(anim, atlas)
