extends SceneTree
## Writes the Núcleo de cría's BroodCoreData (data/enemies/nucleo_cria.tres) and the EnemyData of the
## creature it breeds, the cría volcánica (data/enemies/cria_volcanica.tres). Both are drawn at game
## size by python tools/make_nucleo_cria_art.py and tools/make_cria_volcanica_art.py, and their
## SpriteFrames come from tools/make_temple_enemy_frames.gd; the scenes
## scenes/enemies/nucleo_cria.tscn and cria_volcanica.tscn are hand-written. It also builds the
## SpriteFrames of the core's two broken stages (data/enemies/nucleo_cria_s2_frames.tres and _s3_),
## from the strips `nucleo_cria_<animation>_s<n>.png` plus their `crack` (and `open` for the last),
## and links the queen it lets out, scenes/enemies/reina_volcanica.tscn.
## Run: godot --headless --path . --script res://tools/make_nucleo_cria.gd

const STAGE_STRIP := "res://assets/sprites/nucleo_cria/nucleo_cria_%s%s.png"
const STAGE_FRAMES := "res://data/enemies/nucleo_cria_s%d_frames.tres"
const QUEEN_SCENE := "res://scenes/enemies/reina_volcanica.tscn"
## Animations only the broken stages have: [frames per second, loops, last stage only].
const STAGE_EXTRAS := {
	&"crack": [10.0, false, false],
	&"open": [10.0, false, true],
}


func _initialize() -> void:
	_write_brood()
	_write_stage_frames(2)
	_write_stage_frames(3)
	_write_core()
	quit()


func _write_core() -> void:
	var data := BroodCoreData.new()
	data.id = &"nucleo_cria"
	data.display_name = "Núcleo de cría"
	data.placeholder_color = Color(0.9, 0.4, 0.1)
	data.sprite_frames = load("res://data/enemies/nucleo_cria_frames.tres")
	# 64x64 cells, the lava pool its comb drips into on row 58: it sits a few pixels below the
	# structure's center.
	data.sprite_offset = Vector2(0, -20)
	# Tougher than the first version (12): it now lasts through three stages.
	data.max_health = 22
	# A structure: it never moves and cannot be pushed.
	data.move_speed = 0.0
	data.chase_speed = 0.0
	data.patrol_radius = 0.0
	data.knockback_resistance = 1.0
	data.attack_armor = true
	data.detection_range = 200.0
	data.lose_range = 320.0
	# Only the pose after a breeding.
	data.attack_time = 0.3
	data.hurt_time = 0.15
	data.brood_scene = load("res://scenes/enemies/cria_volcanica.tscn")
	data.energy = 6
	data.brood_per_spawn = 2
	data.max_brood = 3
	data.spawn_interval = 4.5
	data.first_spawn_delay = 1.2
	data.spawn_windup = 0.7
	data.spawn_radius = 28.0
	data.brood_tint = Color.WHITE
	data.spent_tint = Color(0.5, 0.45, 0.45)
	data.fuse_time = 0.9
	data.explosion_radius = 44.0
	data.explosion_damage = 1
	data.blast_time = 0.12
	data.warning_color = Color(1.0, 0.35, 0.1)
	data.blast_color = Color(1.0, 0.8, 0.3)
	data.fuse_flicker = 12.0
	data.warning_art = load("res://assets/sprites/nucleo_cria/nucleo_cria_warning.png")
	data.blast_art = load("res://assets/sprites/nucleo_cria/nucleo_cria_blast.png")
	# Cracked under 66% and broken under 33%: each gives back energy and breeds faster a brood that
	# flies faster, bites more often (and, broken, harder), tinted redder.
	var stages: Array[BroodStage] = [
		_stage(2, 0.66, 4, 3.6, 2, 4, 1.2, 1.0, 0.7, Color(1.3, 0.8, 0.7)),
		_stage(3, 0.33, 5, 2.8, 2, 4, 1.4, 2.0, 0.5, Color(1.6, 0.6, 0.5)),
	]
	data.stages = stages
	data.crack_shake = 2.0
	data.crack_shake_time = 0.3
	if ResourceLoader.exists(QUEEN_SCENE):
		data.queen_scene = load(QUEEN_SCENE)
	else:
		push_warning("nucleo_cria: %s does not exist yet; the core will have no queen." % QUEEN_SCENE)
	data.queen_health_below = 0.2
	data.queen_windup = 1.4
	data.queen_spawn_distance = 34.0
	data.queen_ring_radius = 24.0
	data.queen_ring_color = Color(1.0, 0.75, 0.25)
	data.queen_ring_art = load("res://assets/sprites/nucleo_cria/nucleo_cria_queen_ring.png")
	ResourceSaver.save(data, "res://data/enemies/nucleo_cria.tres")
	print("nucleo_cria written")


func _stage(number: int, health_below: float, energy_bonus: int, spawn_interval: float,
		brood_per_spawn: int, max_brood: int, brood_speed: float, brood_damage: float,
		brood_cooldown: float, brood_tint: Color) -> BroodStage:
	var stage := BroodStage.new()
	stage.health_below = health_below
	stage.sprite_frames = load(STAGE_FRAMES % number)
	stage.energy_bonus = energy_bonus
	stage.spawn_interval = spawn_interval
	stage.brood_per_spawn = brood_per_spawn
	stage.max_brood = max_brood
	stage.brood_speed = brood_speed
	stage.brood_damage = brood_damage
	stage.brood_cooldown = brood_cooldown
	stage.brood_tint = brood_tint
	return stage


## The same animations and speeds as make_temple_enemy_frames.gd gives every temple enemy, from the
## stage's strips (death has none of its own: the common one already starts from the broken hive),
## plus the stage's own `crack` and, in the last, `open`.
func _write_stage_frames(number: int) -> void:
	var animations: Dictionary = load("res://tools/make_temple_enemy_frames.gd").get_script_constant_map()["ANIMATIONS"]
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var suffix := "_s%d" % number
	for anim: StringName in animations:
		var spec: Array = animations[anim]
		var path := STAGE_STRIP % [spec[0], suffix]
		if not ResourceLoader.exists(path):
			path = STAGE_STRIP % [spec[0], ""]
		_add_strip(frames, anim, path, spec[1], spec[2])
	for anim: StringName in STAGE_EXTRAS:
		var extra: Array = STAGE_EXTRAS[anim]
		if extra[2] and number != 3:
			continue
		_add_strip(frames, anim, STAGE_STRIP % [anim, suffix], extra[0], extra[1])
	ResourceSaver.save(frames, STAGE_FRAMES % number)
	print("nucleo_cria stage %d frames written" % number)


func _add_strip(frames: SpriteFrames, anim: StringName, path: String, fps: float, loops: bool) -> void:
	var strip: Texture2D = load(path)
	var cell := strip.get_height()
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loops)
	for i in strip.get_width() / cell:
		var atlas := AtlasTexture.new()
		atlas.atlas = strip
		atlas.region = Rect2(i * cell, 0, cell, cell)
		frames.add_frame(anim, atlas)


func _write_brood() -> void:
	var data := EnemyData.new()
	data.id = &"cria_volcanica"
	data.display_name = "Cría volcánica"
	data.placeholder_color = Color(1.0, 0.5, 0.25)
	data.sprite_frames = load("res://data/enemies/cria_volcanica_frames.tres")
	# 32x32 cells, its shadow (it flies) on row 26: a few pixels below its center.
	data.sprite_offset = Vector2(0, -4)
	data.max_health = 1
	data.move_speed = 50.0
	data.chase_speed = 100.0
	data.detection_range = 200.0
	data.lose_range = 300.0
	data.attack_range = 14.0
	data.attack_damage = 1
	data.attack_windup = 0.35
	data.attack_time = 0.12
	data.attack_cooldown = 1.0
	data.knockback_speed = 170.0
	data.patrol_radius = 30.0
	data.patrol_wait = 0.5
	data.hurt_time = 0.15
	# Bred without end by a core: they leave nothing behind.
	data.drop_multiplier = 0.0
	ResourceSaver.save(data, "res://data/enemies/cria_volcanica.tres")
	print("cria_volcanica written")
