extends SceneTree
## Writes the Vasija poseída's data (data/enemies/vasija_poseida.tres) and the creature it releases:
## the Espíritu de la vasija (data/enemies/espiritu_vasija.tres, a plain EnemyData) with its
## SpriteFrames (data/enemies/espiritu_vasija_frames.tres), cut here from the fire spirit that leaps
## out of the vase (its own strip, made by tools/make_temple_enemy_art.py from the pack's attack). The vase's own SpriteFrames come from
## tools/make_temple_enemy_frames.gd; the scenes are hand-written.
## Run: godot --headless --path . --script res://tools/make_vasija_poseida.gd

const SPIRIT_STRIP := "res://assets/sprites/vasija_poseida/vasija_poseida_spirit.png"
## The vase's art cells are 96 px; the spirit's strip has its two flame frames.
const CELL := 96
const SPIRIT_CELLS := [0, 1]
## The part of a cell around the spirit (it is centered in it).
const SPIRIT_REGION := Rect2(16, 56, 64, 40)
const SPIRIT_FRAMES_PATH := "res://data/enemies/espiritu_vasija_frames.tres"
const SPIRIT_DATA_PATH := "res://data/enemies/espiritu_vasija.tres"


func _initialize() -> void:
	ResourceSaver.save(_spirit_frames(), SPIRIT_FRAMES_PATH)
	ResourceSaver.save(_spirit_data(), SPIRIT_DATA_PATH)
	ResourceSaver.save(_vase_data(), "res://data/enemies/vasija_poseida.tres")
	print("vasija_poseida and espiritu_vasija written")
	quit()


func _vase_data() -> PossessedVaseData:
	var data := PossessedVaseData.new()
	data.id = &"vasija_poseida"
	data.display_name = "Vasija poseída"
	data.placeholder_color = Color(0.75, 0.4, 0.15)
	data.sprite_frames = load("res://data/enemies/vasija_poseida_frames.tres")
	data.sprite_offset = Vector2(0, -30)
	# A hit breaks it whatever its health; the creature inside is the fight.
	data.max_health = 3
	data.move_speed = 0.0
	data.chase_speed = 0.0
	data.detection_range = 40.0
	data.lose_range = 120.0
	data.attack_range = 34.0
	data.attack_damage = 1
	data.patrol_radius = 0.0
	data.patrol_wait = 1.0
	# It never drops anything itself: its creature does.
	data.drop_multiplier = 0.0
	data.trigger_radius = 34.0
	data.shake_time = 0.55
	data.shake_amplitude = 1.0
	data.decoy_scene = load("res://scenes/enemies/vase_decoy.tscn")
	data.decoy_count_min = 2
	data.decoy_count_max = 3
	data.decoy_min_distance = 36.0
	data.decoy_max_distance = 64.0
	data.decoy_spacing = 24.0
	data.decoy_clearance = 10.0
	data.door_lane_half_width = 40.0
	data.creature_scene = load("res://scenes/enemies/espiritu_vasija.tscn")
	data.release_delay = 0.35
	data.creature_offset = 8.0
	return data


func _spirit_data() -> EnemyData:
	var data := EnemyData.new()
	data.id = &"espiritu_vasija"
	data.display_name = "Espíritu de la vasija"
	data.placeholder_color = Color(1.0, 0.55, 0.15)
	data.sprite_frames = load(SPIRIT_FRAMES_PATH)
	data.sprite_offset = Vector2(0, -8)
	data.max_health = 2
	data.move_speed = 45.0
	data.chase_speed = 85.0
	# Freed in the middle of the fight: it sees Nico at once.
	data.detection_range = 200.0
	data.lose_range = 280.0
	data.attack_range = 18.0
	data.attack_damage = 1
	data.attack_windup = 0.35
	data.attack_time = 0.15
	data.attack_cooldown = 0.9
	data.hurt_time = 0.25
	data.knockback_speed = 140.0
	data.patrol_radius = 30.0
	data.patrol_wait = 0.6
	return data


## The spirit is the same two flame frames in every animation, at different speeds.
func _spirit_frames() -> SpriteFrames:
	var strip: Texture2D = load(SPIRIT_STRIP)
	var cells: Array[AtlasTexture] = []
	for cell: int in SPIRIT_CELLS:
		var texture := AtlasTexture.new()
		texture.atlas = strip
		texture.region = Rect2(SPIRIT_REGION.position + Vector2(cell * CELL, 0), SPIRIT_REGION.size)
		cells.append(texture)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	# name: [speed, loop, frame order]
	var animations := {
		&"idle": [6.0, true, [0, 1]],
		&"walk": [8.0, true, [0, 1]],
		&"run": [12.0, true, [0, 1]],
		&"attack": [12.0, false, [0, 1, 0, 1]],
		&"hurt": [9.0, false, [1, 0]],
		&"death": [8.0, false, [0, 1, 0]],
	}
	for anim: StringName in animations:
		var spec: Array = animations[anim]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, spec[0])
		frames.set_animation_loop(anim, spec[1])
		for index: int in spec[2]:
			frames.add_frame(anim, cells[index])
	return frames
