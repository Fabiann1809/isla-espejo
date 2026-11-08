class_name FragmentPickup
extends Node2D
## A compass fragment left by a boss. Taking it (E) records it in GameState, teaches the player the
## skill that goes with it and tells the player. It is a broken sector of Nico's brass compass with a
## glowing crystal needle (assets/sprites/fragments/, drawn by tools/make_fragment_art.py): it floats,
## breathes light and gives off sparks until it is taken.

const ART := "res://assets/sprites/fragments/fragment_%s_idle.png"
const GLOW := "res://assets/sprites/fragments/glow.png"
const CELL := 24
const FRAMES := 8
const FRAME_SPEED := 7.0
const FLOAT_HEIGHT := 11.0
const SPRITE_SCALE := 1.0
const BOB := 2.2

@export var fragment_id: StringName = &"green"
@export var skill_id: StringName = &"roots"
## Tint of the halo and the sparks (the crystal's own color).
@export var color := Color(0.35, 0.85, 0.4)
## Spanish texts. `%s` in the second one is the skill name.
@export var fragment_message := "Fragmento de brújula obtenido."
@export var skill_message := "Habilidad aprendida: %s"

var _time := 0.0
var _sprite: AnimatedSprite2D
var _halo: Sprite2D

@onready var _take: Interactable = $Take


func _ready() -> void:
	add_to_group("fragments")
	_build_art()
	_take.interacted.connect(_on_taken)


func _process(delta: float) -> void:
	_time += delta
	_sprite.position.y = -FLOAT_HEIGHT + sin(_time * 2.4) * BOB
	_halo.position.y = _sprite.position.y
	_halo.modulate.a = 0.65 + 0.18 * sin(_time * 3.1) + 0.07 * sin(_time * 7.3)
	_halo.scale = Vector2.ONE * (0.95 + 0.08 * sin(_time * 3.1))


func _build_art() -> void:
	var shadow := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 14:
		points.append(Vector2.from_angle(TAU * i / 14.0) * Vector2(9.0, 3.0))
	shadow.polygon = points
	shadow.color = Color(0, 0, 0, 0.3)
	shadow.position = Vector2(0, 2)
	add_child(shadow)
	_halo = Sprite2D.new()
	_halo.texture = load(GLOW)
	_halo.modulate = Color(color, 0.65)
	_halo.material = _additive()
	add_child(_halo)
	var sheet: Texture2D = load(ART % fragment_id)
	var frames := SpriteFrames.new()
	frames.add_animation(&"idle")
	frames.set_animation_speed(&"idle", FRAME_SPEED)
	frames.set_animation_loop(&"idle", true)
	for i in FRAMES:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * CELL, 0, CELL, CELL)
		frames.add_frame(&"idle", atlas)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.scale = Vector2.ONE * SPRITE_SCALE
	add_child(_sprite)
	_sprite.play(&"idle")
	add_child(_sparks())


func _additive() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


## Tiny lights that rise from the piece and fade.
func _sparks() -> CPUParticles2D:
	var sparks := CPUParticles2D.new()
	sparks.texture = RoomDressing.pixel()
	sparks.amount = 9
	sparks.lifetime = 1.7
	sparks.preprocess = 1.7
	sparks.position = Vector2(0, -FLOAT_HEIGHT)
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = Vector2(9, 8)
	sparks.direction = Vector2.UP
	sparks.spread = 25.0
	sparks.gravity = Vector2.ZERO
	sparks.initial_velocity_min = 6.0
	sparks.initial_velocity_max = 14.0
	sparks.color = color.lightened(0.5)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.25, Color.WHITE)
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	sparks.color_ramp = fade
	sparks.material = _additive()
	return sparks


func _on_taken(player: Node) -> void:
	_take.enabled = false
	GameState.collect_fragment(fragment_id)
	var skill: SkillData = null
	if skill_id != &"":
		skill = load(GameState.SKILL_PATH % skill_id)
		GameState.learn_skill(skill_id)
		player.skills.unlock(skill)
	Events.message_requested.emit(fragment_message)
	if skill != null:
		Events.message_requested.emit(skill_message % skill.display_name)
	queue_free()
