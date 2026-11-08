class_name ExitPortal
extends Node2D
## The way out of a scenario. It stays sealed until the scenario's boss has been defeated (its
## story flag is set); then E takes the player to the next chapter. Sealed, E only says so.
## Its art (Tuning.PORTAL_ART_ENABLED): a stone dais with a ring of runes, lying with the floor, and a
## stone arch standing on it, y-sorted with the actors by its foot so Nico can walk behind it; once
## open, a swirling violet veil fills the doorway. Without the art: a glowing violet doorway on
## flagstones. The base shows from the start (the player knows where the way out will be); light and
## sparks join the glow once it opens.

## The portal opens when this flag is set (the boss's `defeated_flag`).
@export var required_flag: StringName = &"forest_boss_defeated"
## How far down the base's sort point goes (past the bottom of any room).
const BASE_SORT_OFFSET := 320.0
const ART_DIR := "res://assets/art_forest/portal/"
const DAIS := ART_DIR + "portal_dais.png"
const ARCH := ART_DIR + "portal_arch.png"
const VEIL := ART_DIR + "portal_veil.png"
## Where the veil sits in the arch's picture (its doorway's top-left corner) and the dais's middle in
## its own picture.
const DOORWAY := Vector2(9, 10)
const DAIS_MIDDLE := Vector2(24, 12)
## Width of one frame of the veil's strip.
const VEIL_FRAME_WIDTH := 14.0

## Set by the Level that places the portal.
var scenario_id: StringName = &""
## The prompt of the open portal (from the scene); a sealed one shows the sealed prompt instead.
var _open_prompt := ""
var _time := 0.0
## 0 while the portal is waking up, 1 when it shines fully (an already open portal starts at 1).
var _open_amount := 1.0
var _light: Sprite2D
var _sparks: CPUParticles2D

@onready var _glow: Polygon2D = $Glow
@onready var _use: Interactable = $Use


func _ready() -> void:
	add_to_group("exit_portals")
	_build_base()
	_open_prompt = _use.prompt
	_use.interacted.connect(_on_used)
	Events.boss_defeated.connect(func(_id: StringName) -> void:
		var was_open := _glow.visible
		_refresh()
		if not was_open and is_open():
			_play_opening())
	_refresh()


func _process(delta: float) -> void:
	if _glow.visible:
		_time += delta
		_glow.modulate.a = (0.6 + 0.3 * sin(_time * 4.0)) * _open_amount
		if _light != null:
			_light.modulate.a = Tuning.PORTAL_LIGHT.a * (0.8 + 0.2 * sin(_time * 4.0)) * _open_amount


func is_open() -> bool:
	return required_flag == &"" or GameState.has_flag(required_flag)


## Seals the portal until `flag` is set (empty = open from the start); the Level sets the chapter's
## own flag here, so a flag earned on an earlier island never opens a later exit.
func seal_with(flag: StringName) -> void:
	required_flag = flag
	if is_inside_tree():
		_refresh()


func _refresh() -> void:
	var open := is_open()
	_glow.visible = open
	# Sealed, it can still be used: it says what opens it instead of staying silent.
	_use.prompt = _open_prompt if open else UiText.t("portal_sealed_prompt")
	if _light != null:
		_light.visible = open
	if _sparks != null:
		_sparks.emitting = open


## The boss has just fallen: the doorway unfolds upward, the light and the sparks swell, a ring of
## sparks bursts from the dais and the screen trembles a little (the sealed stone was waiting for this).
func _play_opening() -> void:
	_open_amount = 0.0
	_glow.scale = Vector2(1.0, 0.04)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "_open_amount", 1.0, Tuning.PORTAL_OPEN_SECONDS)
	tween.tween_property(_glow, "scale", Vector2.ONE, Tuning.PORTAL_OPEN_SECONDS) 			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var burst := CPUParticles2D.new()
	burst.texture = RoomDressing.pixel()
	burst.one_shot = true
	burst.amount = 32
	burst.lifetime = 1.0
	burst.explosiveness = 1.0
	burst.position = Vector2(0, 6)
	burst.direction = Vector2.UP
	burst.spread = 180.0
	burst.gravity = Vector2.ZERO
	burst.initial_velocity_min = 35.0
	burst.initial_velocity_max = 70.0
	burst.scale_amount_min = 1.0
	burst.scale_amount_max = 2.0
	burst.color = Color(0.88, 0.74, 1.0, 0.95)
	burst.emitting = true
	add_child(burst)
	get_tree().create_timer(2.0).timeout.connect(burst.queue_free)
	Events.portal_opened.emit(global_position)


func _on_used(_player: Node) -> void:
	if is_open():
		Events.scenario_completed.emit(scenario_id)
	else:
		Events.message_requested.emit(UiText.t("portal_sealed"))


## Flagstones under the doorway (on the floor), and the light and sparks it shows once open.
func _build_base() -> void:
	if not Tuning.PORTAL_BASE:
		return
	var base := Node2D.new()
	base.name = "Base"
	base.z_index = RoomTheme.FLOOR_Z
	base.z_as_relative = false
	# With the floors, but sorted after the room's ground decoration (the arena's shade and roots,
	# whose origin is the room's bottom), so they never cover the flagstones.
	base.position = Vector2(0, BASE_SORT_OFFSET)
	add_child(base)
	move_child(base, 0)
	if _has_art():
		_build_art(base)
	else:
		var size := Vector2i(3, 2)
		for y in size.y:
			for x in size.x:
				var tile := TileArt.nine_slice_tile(TileArt.STONE_FLOOR, x, y, size)
				base.add_child(TileArt.sprite_of(tile, Vector2(x * TileArt.TILE - 24, y * TileArt.TILE - 8 - BASE_SORT_OFFSET)))
	if Tuning.PORTAL_LIGHT.a > 0.0:
		_light = RoomDressing.make_glow(Tuning.PORTAL_LIGHT, Vector2.ONE * Tuning.PORTAL_LIGHT_RADIUS * 2.0, true)
		_light.name = "Light"
		_light.position = Vector2(0, 4)
		_light.z_index = RoomTheme.GROUND_FX_Z
		_light.z_as_relative = false
		add_child(_light)
	if Tuning.PORTAL_SPARKS > 0:
		_sparks = CPUParticles2D.new()
		_sparks.name = "Sparks"
		_sparks.amount = Tuning.PORTAL_SPARKS
		_sparks.lifetime = 1.2
		_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_sparks.emission_rect_extents = Vector2(9, 3)
		_sparks.position = Vector2(0, 6)
		_sparks.direction = Vector2.UP
		_sparks.spread = 12.0
		_sparks.gravity = Vector2.ZERO
		_sparks.initial_velocity_min = 10.0
		_sparks.initial_velocity_max = 18.0
		_sparks.color = Color(0.85, 0.7, 1.0, 0.9)
		_sparks.texture = RoomDressing.pixel()
		_sparks.scale_amount_min = 1.0
		_sparks.scale_amount_max = 2.0
		_sparks.emitting = false
		add_child(_sparks)


func _has_art() -> bool:
	return Tuning.PORTAL_ART_ENABLED and ResourceLoader.exists(DAIS) and ResourceLoader.exists(ARCH) 			and ResourceLoader.exists(VEIL)


## The dais (on the floor, in `base`), the arch (with the actors) and the veil (in the glow, so it
## shows and pulses only while the portal is open).
func _build_art(base: Node2D) -> void:
	var foot := Tuning.PORTAL_ARCH_FOOT
	var dais := _sprite(load(DAIS))
	dais.position = Vector2(0, foot) - DAIS_MIDDLE - base.position
	base.add_child(dais)
	var arch_texture: Texture2D = load(ARCH)
	var arch := Node2D.new()
	arch.name = "Arch"
	arch.position = Vector2(0, foot)
	var arch_sprite := _sprite(arch_texture)
	arch_sprite.position = -Vector2(floorf(arch_texture.get_width() / 2.0), arch_texture.get_height() - 2.0)
	arch.add_child(arch_sprite)
	add_child(arch)
	# The children (the arch by its foot) join the room's sort with the actors.
	y_sort_enabled = true
	var sheet: Texture2D = load(VEIL)
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", Tuning.PORTAL_VEIL_FPS)
	var cell := Vector2(VEIL_FRAME_WIDTH, sheet.get_height())
	for i in int(sheet.get_width() / cell.x):
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(Vector2(i * cell.x, 0), cell)
		frames.add_frame(&"default", frame)
	var veil := AnimatedSprite2D.new()
	veil.name = "Veil"
	veil.sprite_frames = frames
	veil.centered = false
	veil.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	veil.position = arch.position + arch_sprite.position + DOORWAY
	veil.play(&"default")
	_glow.color.a = 0.0
	_glow.add_child(veil)


func _sprite(texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite

