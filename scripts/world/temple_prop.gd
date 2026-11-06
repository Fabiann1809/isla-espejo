class_name TempleProp
extends Node2D
## Scenery of the Templo del Eclipse placed in a room scene, like RuinProp in the Ruinas: pillars,
## statues, braziers, urns, vines, banners, lava falls, geysers, the face gate... Each kind is an
## animated strip drawn by `tools/make_temple_props_art.py` into `assets/sprites/temple_props/`
## (`props.json` lists its cell, frames, fps, foot and footprint). Nothing is static: fires and lava
## burn, stone glints and moss sways, and neighbours start out of step.
##
## The node's origin is the prop's foot (the pixel that stands on the floor), so the parent's y-sort
## puts it among the actors. Solid kinds block only a low rectangle around the foot (`footprint`), on
## the layer of their height `level` (plus `world` on level 0), so Nico walks behind their tops. Flat
## or overhead kinds have no collision. Fire kinds carry a flickering RuinLight glow.
##
## A GEYSER cycles idle, rumble, erupt and settle (`Tuning.TEMPLE_GEYSER_*`); with `hazard` on, a
## Hitbox over its footprint hurts while it erupts.

enum Kind {
	PILLAR_CARVED, PILLAR_BLOCK, COLUMN_LOW, COLUMN_BROKEN, STATUE_GUARDIAN, BRAZIER, BRAZIER_PEDESTAL,
	TORCH_WALL, URN, VASE, BARREL, RUBBLE, ROCK_SMOKING, PLANT, VINES, BANNER, LAVA_FALL, GEYSER,
	FACE_GATE, ALTAR_RUNE, EMBER_VENT,
}
enum GeyserPhase { IDLE, RUMBLE, ERUPT, SETTLE }

@export var kind: Kind = Kind.PILLAR_CARVED
## Mirrors the picture (the foot stays where it is).
@export var flip := false
## Height level the prop stands on (see Heights): it blocks only the actors of that level.
@export var level := 0
## GEYSER only: true makes its eruption hurt Nico.
@export var hazard := false

const ART_DIR := "res://assets/sprites/temple_props/"
const META_PATH := ART_DIR + "props.json"
const WORLD_BITS := 1
const ENEMY_ATTACK_LAYER := 5
const PLAYER_LAYER := 2
## Kinds that block their footprint.
const SOLID_KINDS: Array[Kind] = [
	Kind.PILLAR_CARVED, Kind.PILLAR_BLOCK, Kind.COLUMN_LOW, Kind.COLUMN_BROKEN, Kind.STATUE_GUARDIAN,
	Kind.BRAZIER_PEDESTAL, Kind.URN, Kind.BARREL, Kind.ROCK_SMOKING, Kind.FACE_GATE, Kind.ALTAR_RUNE,
]
## Kinds lying on the floor: drawn over every floor and under every actor, never y-sorted.
const FLOOR_KINDS: Array[Kind] = [Kind.RUBBLE, Kind.EMBER_VENT]
## Fire kinds: where their glow sits (relative to the foot) and which light it is (see Tuning.TEMPLE_*):
## `fire` for flames, `lava` for molten rock and `gate` for the face gate's mouth (lava, wider).
const LIGHTS := {
	Kind.BRAZIER: [Vector2(0, -12), "fire"],
	Kind.BRAZIER_PEDESTAL: [Vector2(0, -32), "fire"],
	Kind.TORCH_WALL: [Vector2(0, -16), "fire"],
	Kind.LAVA_FALL: [Vector2(0, -20), "lava"],
	Kind.FACE_GATE: [Vector2(0, -24), "gate"],
	Kind.GEYSER: [Vector2(0, -14), "lava"],
}
## The strip of each kind.
const STRIPS := {
	Kind.PILLAR_CARVED: "pillar_carved", Kind.PILLAR_BLOCK: "pillar_block", Kind.COLUMN_LOW: "column_low",
	Kind.COLUMN_BROKEN: "column_broken", Kind.STATUE_GUARDIAN: "statue_guardian", Kind.BRAZIER: "brazier",
	Kind.BRAZIER_PEDESTAL: "brazier_pedestal", Kind.TORCH_WALL: "torch_wall", Kind.URN: "urn", Kind.VASE: "vase",
	Kind.BARREL: "barrel", Kind.RUBBLE: "rubble", Kind.ROCK_SMOKING: "rock_smoking", Kind.PLANT: "plant",
	Kind.VINES: "vines", Kind.BANNER: "banner", Kind.LAVA_FALL: "lava_fall", Kind.GEYSER: "geyser",
	Kind.FACE_GATE: "face_gate", Kind.ALTAR_RUNE: "altar_rune", Kind.EMBER_VENT: "ember_vent",
}
const GEYSER_PHASE_NAMES: Array[StringName] = [&"idle", &"rumble", &"erupt", &"settle"]

static var _meta: Dictionary = {}
static var _frames_cache: Dictionary = {}

var _sprite: AnimatedSprite2D
var _light: Sprite2D
var _hitbox: Hitbox
var _phase: GeyserPhase = GeyserPhase.IDLE
var _phase_left := 0.0


func _ready() -> void:
	_build()


func is_solid() -> bool:
	return kind in SOLID_KINDS


func is_erupting() -> bool:
	return kind == Kind.GEYSER and _phase == GeyserPhase.ERUPT


## The strip's description from props.json (cell, frames, fps, foot, footprint, extras).
func spec() -> Dictionary:
	return _meta_of(STRIPS[kind])


func footprint() -> Vector2:
	var size: Array = spec().get("footprint", [0, 0])
	return Vector2(size[0], size[1])


## The room cells (16 px) the footprint covers, in the parent's coordinates, so the room generator can
## keep the lanes free. Empty for anything that does not block (a hazard geyser counts: its eruption does).
func blocks_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not (is_solid() or (kind == Kind.GEYSER and hazard)):
		return cells
	var size := footprint()
	if size.x <= 0.0 or size.y <= 0.0:
		return cells
	var rect := Rect2(position - size / 2.0, size)
	var tile := float(TileArt.TILE)
	var first := Vector2i((rect.position / tile).floor())
	var last := Vector2i(((rect.end - Vector2.ONE * 0.01) / tile).floor())
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			cells.append(Vector2i(x, y))
	return cells


func _build() -> void:
	var info := spec()
	if info.is_empty():
		push_error("TempleProp: no strip for kind %s" % Kind.keys()[kind])
		return
	_foot_shadow()
	_sprite = _make_sprite(info)
	add_child(_sprite)
	if kind in FLOOR_KINDS:
		z_index = RoomTheme.GROUND_FX_Z
	if is_solid():
		_collide(footprint(), _layer_bits())
	set_physics_process(kind == Kind.GEYSER)
	if kind == Kind.GEYSER:
		_start_geyser(info)
	elif LIGHTS.has(kind):
		_light = _make_light(kind)


## The strip as an AnimatedSprite2D with its foot on the origin, starting on a frame seeded by its place.
func _make_sprite(info: Dictionary) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Art"
	sprite.sprite_frames = _frames_of(STRIPS[kind], info)
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.flip_h = flip
	var cell: Array = info["cell"]
	var foot: Array = info["foot"]
	var foot_x: float = (cell[0] - foot[0]) if flip else foot[0]
	sprite.offset = Vector2(-foot_x, -foot[1])
	var anim: StringName = &"idle" if kind == Kind.GEYSER else &"default"
	sprite.animation = anim
	sprite.frame = posmod(hash(Vector2i(global_position)), sprite.sprite_frames.get_frame_count(anim))
	sprite.play(anim)
	return sprite


## The SpriteFrames of a strip, cut into its cells (cached per strip). The geyser's strip holds one
## animation per phase (`phases` in props.json); erupt and settle play once, idle and rumble loop.
static func _frames_of(strip_name: String, info: Dictionary) -> SpriteFrames:
	if _frames_cache.has(strip_name):
		return _frames_cache[strip_name]
	var texture: Texture2D = load(ART_DIR + strip_name + ".png")
	var cell: Array = info["cell"]
	var frames := SpriteFrames.new()
	var animations := {"default": [0, info["frames"]]}
	if info.has("phases"):
		animations = info["phases"]
		frames.remove_animation(&"default")
	for anim_name in animations:
		var span: Array = animations[anim_name]
		var anim := StringName(anim_name)
		if not frames.has_animation(anim):
			frames.add_animation(anim)
		frames.set_animation_speed(anim, info["fps"])
		for i in range(int(span[0]), int(span[1])):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(i * cell[0], 0, cell[0], cell[1])
			frames.add_frame(anim, atlas)
	_frames_cache[strip_name] = frames
	return frames


static func _meta_of(strip_name: String) -> Dictionary:
	if _meta.is_empty():
		var file := FileAccess.open(META_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_meta = parsed
	return _meta.get(strip_name, {})


## Collision bits of the prop's height level: the layer that blocks the actors standing on `level`,
## plus `world` on the ground so arrows and everyone else stop at it too.
func _layer_bits() -> int:
	var bits := 1 << (_block_layer(level) - 1)
	if level == 0:
		bits |= WORLD_BITS
	return bits


# TODO(heights): use Heights.block_layer(level) once it lands (8, 9 or 10 for levels 0, 1 and 2).
static func _block_layer(height_level: int) -> int:
	return 8 + height_level


## A body over the footprint, centered on the foot, so only the base blocks.
func _collide(size: Vector2, layer_bits: int) -> void:
	var body := StaticBody2D.new()
	body.name = "Body"
	body.collision_layer = layer_bits
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	body.add_child(shape)
	add_child(body)


## A soft shadow on the floor under a solid prop, drawn with the floor so it never darkens an actor.
func _foot_shadow() -> void:
	if not Tuning.RUIN_PROP_SHADOWS or not is_solid():
		return
	var size := footprint()
	var shadow := ActorShadow.new()
	shadow.name = ActorShadow.NODE_NAME
	shadow.size = Vector2(size.x + 4.0, maxf(4.0, size.y * 0.75))
	shadow.alpha = Tuning.RUIN_PROP_SHADOW_ALPHA
	shadow.z_as_relative = false
	shadow.z_index = RoomTheme.FLOOR_Z
	add_child(shadow)


## A flickering additive glow (see RuinProp._light) in the temple's fire or lava colour.
func _make_light(of_kind: Kind) -> Sprite2D:
	var light: Array = LIGHTS[of_kind]
	var color: Color = Tuning.TEMPLE_FIRE_LIGHT if light[1] == "fire" else Tuning.TEMPLE_LAVA_LIGHT
	var radius: float = Tuning.TEMPLE_FIRE_LIGHT_RADIUS
	match light[1]:
		"lava":
			radius = Tuning.TEMPLE_LAVA_LIGHT_RADIUS
		"gate":
			radius = Tuning.TEMPLE_GATE_LIGHT_RADIUS
	if not Tuning.RUIN_LIGHTS_ENABLED or color.a <= 0.0:
		return null
	var glow := RuinLight.glow(color, Vector2.ONE * radius * 2.0)
	glow.name = "Light"
	glow.position = light[0]
	glow.z_as_relative = false
	glow.z_index = Tuning.RUIN_LIGHT_Z
	add_child(glow)
	var dim := Color(color.r, color.g, color.b, color.a * (1.0 - Tuning.RUIN_LIGHT_FLICKER))
	var tween := glow.create_tween().set_loops()
	var seconds := Tuning.RUIN_LIGHT_FLICKER_SECONDS * randf_range(0.8, 1.4)
	tween.tween_property(glow, "modulate", dim, seconds)
	tween.tween_property(glow, "modulate", color, seconds)
	return glow


# --- geyser ---------------------------------------------------------------------------------------
func _start_geyser(info: Dictionary) -> void:
	# Erupt and settle play once, stretched over their phase; idle and rumble loop at the strip's pace.
	var frames := _sprite.sprite_frames
	frames.set_animation_loop(&"erupt", false)
	frames.set_animation_loop(&"settle", false)
	frames.set_animation_speed(&"erupt", frames.get_frame_count(&"erupt") / Tuning.TEMPLE_GEYSER_ERUPT)
	frames.set_animation_speed(&"settle", frames.get_frame_count(&"settle") / Tuning.TEMPLE_GEYSER_SETTLE)
	if hazard:
		_hitbox = Hitbox.new()
		_hitbox.name = "Hitbox"
		_hitbox.damage = Tuning.TEMPLE_GEYSER_DAMAGE
		_hitbox.collision_layer = 1 << (ENEMY_ATTACK_LAYER - 1)
		_hitbox.collision_mask = 1 << (PLAYER_LAYER - 1)
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = footprint()
		shape.shape = rectangle
		_hitbox.add_child(shape)
		add_child(_hitbox)
	_phase = GeyserPhase.IDLE
	_phase_left = Tuning.TEMPLE_GEYSER_IDLE
	if not hazard:
		# Ambient geysers are out of step with each other; a trap keeps its full idle, so its rhythm is fair.
		_phase_left *= 0.3 + 0.7 * (posmod(hash(Vector2i(global_position)), 1000) / 1000.0)
	_sprite.play(&"idle")


func _physics_process(delta: float) -> void:
	_phase_left -= delta
	if _phase_left <= 0.0:
		_enter_phase(((_phase + 1) % GeyserPhase.size()) as GeyserPhase)


func _enter_phase(phase: GeyserPhase) -> void:
	_phase = phase
	_phase_left = [Tuning.TEMPLE_GEYSER_IDLE, Tuning.TEMPLE_GEYSER_RUMBLE, Tuning.TEMPLE_GEYSER_ERUPT,
			Tuning.TEMPLE_GEYSER_SETTLE][phase]
	_sprite.play(GEYSER_PHASE_NAMES[phase])
	if phase == GeyserPhase.ERUPT:
		if _hitbox != null:
			_hitbox.activate()
		_light = _make_light(Kind.GEYSER)
	else:
		if _hitbox != null:
			_hitbox.deactivate()
		if _light != null:
			_light.queue_free()
			_light = null
