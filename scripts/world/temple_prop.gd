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
##
## The trap walk's traps always hurt, only through a Hitbox (`Tuning.TEMPLE_TRAP_*`), and never
## block: SPIKES (flat, one cell) sleep, warn with their tips out and the slots glowing, rise and
## sink on a timer; a SAW spins along a track of `track` cells from the prop's cell toward
## `direction` (its groove is drawn on the floor) and hurts whoever stays on it every so often; a
## ROLLING_ROCK rumbles up at the prop's cell, rolls `track` cells toward `direction`, breaks at
## the lane's end and rises again after a pause. Their cells (`blocks_cells`) are kept free of
## other props and spawns by the room generator, but a lane may cross them: the way opens between
## their beats.

enum Kind {
	PILLAR_CARVED, PILLAR_BLOCK, COLUMN_LOW, COLUMN_BROKEN, STATUE_GUARDIAN, BRAZIER, BRAZIER_PEDESTAL,
	TORCH_WALL, URN, VASE, BARREL, RUBBLE, ROCK_SMOKING, PLANT, VINES, BANNER, LAVA_FALL, GEYSER,
	FACE_GATE, ALTAR_RUNE, EMBER_VENT, SPIKES, SAW, ROLLING_ROCK,
}
enum GeyserPhase { IDLE, RUMBLE, ERUPT, SETTLE }
enum SpikesPhase { DOWN, WARN, UP, RETRACT }
enum RockPhase { SPAWN, ROLL, BREAK, WAIT }

@export var kind: Kind = Kind.PILLAR_CARVED
## Mirrors the picture (the foot stays where it is).
@export var flip := false
## Height level the prop stands on (see Heights): it blocks only the actors of that level.
@export var level := 0
## GEYSER only: true makes its eruption hurt Nico.
@export var hazard := false
## SAW and ROLLING_ROCK: cells of track or lane from the prop's cell (0 = the strip's default) and
## the way it runs.
@export var track := 0
@export var direction := Vector2i.RIGHT

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
const FLOOR_KINDS: Array[Kind] = [Kind.RUBBLE, Kind.EMBER_VENT, Kind.SPIKES]
## The traps: they hurt on their own rhythm (never a body).
const TRAP_KINDS: Array[Kind] = [Kind.SPIKES, Kind.SAW, Kind.ROLLING_ROCK]
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
	Kind.SPIKES: "spikes", Kind.SAW: "saw", Kind.ROLLING_ROCK: "rolling_rock",
}
const GEYSER_PHASE_NAMES: Array[StringName] = [&"idle", &"rumble", &"erupt", &"settle"]
const SPIKES_PHASE_NAMES: Array[StringName] = [&"down", &"warn", &"up", &"retract"]
const SAW_TRACK_STRIP := "saw_track"

static var _meta: Dictionary = {}
static var _frames_cache: Dictionary = {}

var _sprite: AnimatedSprite2D
var _light: Sprite2D
var _hitbox: Hitbox
var _phase: int = 0
var _phase_left := 0.0
## The moving part of a saw or a rock (sprite and hitbox), its travel in px and where it is on it.
var _mover: Node2D
var _travel := 0.0
var _along := 0.0
var _hit_clock := 0.0


func _ready() -> void:
	_build()


func is_solid() -> bool:
	return kind in SOLID_KINDS


func is_trap() -> bool:
	return kind in TRAP_KINDS


func is_erupting() -> bool:
	return kind == Kind.GEYSER and _phase == GeyserPhase.ERUPT


## True while the trap can hurt: the spikes up, the saw always (it is never still), the rock rolling.
func is_hazard_active() -> bool:
	match kind:
		Kind.SPIKES:
			return _phase == SpikesPhase.UP
		Kind.SAW:
			return Tuning.TEMPLE_TRAPS_ENABLED
		Kind.ROLLING_ROCK:
			return _phase == RockPhase.ROLL
	return is_erupting()


## The spikes' phase (SpikesPhase) or the rock's (RockPhase), for tests and the arena.
func phase() -> int:
	return _phase


## Where the moving part of a saw or a rock is, in the parent's coordinates (the prop's own for the rest).
func mover_position() -> Vector2:
	return position + _mover.position if _mover != null else position


## Cells of a saw's track or a rock's lane (0 = the strip's default length).
func track_length() -> int:
	return track if track > 0 else int(spec().get("track_cells", 1))


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
	if not (is_solid() or (kind == Kind.GEYSER and hazard) or is_trap()):
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
	if kind == Kind.SAW or kind == Kind.ROLLING_ROCK:
		# The whole track or lane, from the prop's cell on.
		var start := cells.duplicate()
		for i in range(1, track_length()):
			for cell in start:
				var next: Vector2i = cell + direction * i
				if not cells.has(next):
					cells.append(next)
	return cells


func _build() -> void:
	var info := spec()
	if info.is_empty():
		push_error("TempleProp: no strip for kind %s" % Kind.keys()[kind])
		return
	_foot_shadow()
	_sprite = _make_sprite(info)
	if kind == Kind.SAW or kind == Kind.ROLLING_ROCK:
		_mover = Node2D.new()
		_mover.name = "Mover"
		_mover.add_child(_sprite)
		add_child(_mover)
	else:
		add_child(_sprite)
	if kind in FLOOR_KINDS:
		z_index = RoomTheme.GROUND_FX_Z
	if is_solid():
		_collide(footprint(), _layer_bits())
	set_physics_process(kind == Kind.GEYSER or (is_trap() and Tuning.TEMPLE_TRAPS_ENABLED))
	match kind:
		Kind.GEYSER:
			_start_geyser(info)
		Kind.SPIKES:
			_start_spikes()
		Kind.SAW:
			_start_saw(info)
		Kind.ROLLING_ROCK:
			_start_rock()
		_:
			if LIGHTS.has(kind):
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
	var anim: StringName = &"default"
	match kind:
		Kind.GEYSER:
			anim = &"idle"
		Kind.SPIKES:
			anim = &"down"
		Kind.ROLLING_ROCK:
			anim = &"roll"
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
	var bits := 1 << (Heights.block_layer(level) - 1)
	if level == 0:
		bits |= WORLD_BITS
	return bits


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
## It leans east, away from the light, the taller the prop (`Tuning.TEMPLE_PROP_SHADOW_LEAN`), so a
## column reads as standing up.
func _foot_shadow() -> void:
	if not Tuning.RUIN_PROP_SHADOWS or not is_solid():
		return
	var size := footprint()
	var shadow := ActorShadow.new()
	shadow.name = ActorShadow.NODE_NAME
	var foot: Array = spec().get("foot", [0, 0])
	var lean := maxf(0.0, Tuning.TEMPLE_PROP_SHADOW_LEAN) * float(foot[1])
	shadow.size = Vector2(size.x + 4.0 + lean, maxf(4.0, size.y * 0.75))
	shadow.position = Vector2(lean / 2.0, 0.0).round()
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
	var seconds := flicker_seconds(global_position + Vector2(light[0]))
	tween.tween_property(glow, "modulate", dim, seconds)
	tween.tween_property(glow, "modulate", color, seconds)
	return glow


## The flicker half-cycle of a light at this spot: a fixed value per position, so a rebuilt light
## (a geyser's next eruption) keeps its rhythm and the global RNG is left alone.
static func flicker_seconds(at: Vector2) -> float:
	var t := float(posmod(hash(Vector2i(at)) / 7, 1000)) / 1000.0
	return Tuning.RUIN_LIGHT_FLICKER_SECONDS * lerpf(Tuning.TEMPLE_PROP_LIGHT_FLICKER_MIN, Tuning.TEMPLE_PROP_LIGHT_FLICKER_MAX, t)


# --- geyser ---------------------------------------------------------------------------------------
func _start_geyser(info: Dictionary) -> void:
	# Erupt and settle play once, stretched over their phase; idle and rumble loop at the strip's pace.
	var frames := _sprite.sprite_frames
	frames.set_animation_loop(&"erupt", false)
	frames.set_animation_loop(&"settle", false)
	frames.set_animation_speed(&"erupt", frames.get_frame_count(&"erupt") / Tuning.TEMPLE_GEYSER_ERUPT)
	frames.set_animation_speed(&"settle", frames.get_frame_count(&"settle") / Tuning.TEMPLE_GEYSER_SETTLE)
	if hazard:
		_hitbox = _make_hitbox(footprint(), Vector2.ZERO, Tuning.TEMPLE_GEYSER_DAMAGE, self)
	_phase = GeyserPhase.IDLE
	_phase_left = Tuning.TEMPLE_GEYSER_IDLE
	if not hazard:
		# Ambient geysers are out of step with each other; a trap keeps its full idle, so its rhythm is fair.
		_phase_left *= 0.3 + 0.7 * (posmod(hash(Vector2i(global_position)), 1000) / 1000.0)
	_sprite.play(&"idle")


func _physics_process(delta: float) -> void:
	match kind:
		Kind.GEYSER:
			_phase_left -= delta
			if _phase_left <= 0.0:
				_enter_phase(((_phase + 1) % GeyserPhase.size()) as GeyserPhase)
		Kind.SPIKES:
			_phase_left -= delta
			if _phase_left <= 0.0:
				_enter_spikes_phase(((_phase + 1) % SpikesPhase.size()) as SpikesPhase)
		Kind.SAW:
			_run_saw(delta)
		Kind.ROLLING_ROCK:
			_run_rock(delta)


func _enter_phase(phase: GeyserPhase) -> void:
	_phase = phase
	var durations: Array[float] = [Tuning.TEMPLE_GEYSER_IDLE, Tuning.TEMPLE_GEYSER_RUMBLE,
			Tuning.TEMPLE_GEYSER_ERUPT, Tuning.TEMPLE_GEYSER_SETTLE]
	_phase_left = durations[phase]
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


# --- traps ------------------------------------------------------------------------------------------
## A Hitbox of `size` centred `offset` from `parent`'s origin, on the enemy_attack layer against the
## player, inactive until its trap arms it.
func _make_hitbox(size: Vector2, offset: Vector2, damage: int, parent: Node2D) -> Hitbox:
	var hitbox := Hitbox.new()
	hitbox.name = "Hitbox"
	hitbox.damage = damage
	hitbox.collision_layer = 1 << (ENEMY_ATTACK_LAYER - 1)
	hitbox.collision_mask = 1 << (PLAYER_LAYER - 1)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	shape.position = offset
	hitbox.add_child(shape)
	parent.add_child(hitbox)
	return hitbox


## The strip's `hitbox` ([w, h, x, y] about the foot) as a Hitbox under `parent`.
func _trap_hitbox(parent: Node2D) -> Hitbox:
	var box: Array = spec().get("hitbox", [footprint().x, footprint().y, 0, 0])
	return _make_hitbox(Vector2(box[0], box[1]), Vector2(box[2], box[3]), Tuning.TEMPLE_TRAP_DAMAGE, parent)


## Every trap of a room keeps the full first beat, so a band of spikes rises together and the way
## reads as one rhythm.
func _start_spikes() -> void:
	_hitbox = _trap_hitbox(self)
	_phase = SpikesPhase.DOWN
	_phase_left = Tuning.TEMPLE_SPIKES_DOWN
	var frames := _sprite.sprite_frames
	frames.set_animation_loop(&"retract", false)
	frames.set_animation_speed(&"retract", frames.get_frame_count(&"retract") / maxf(0.05, Tuning.TEMPLE_SPIKES_RETRACT))
	_sprite.play(&"down")


func _enter_spikes_phase(phase: SpikesPhase) -> void:
	_phase = phase
	var durations: Array[float] = [Tuning.TEMPLE_SPIKES_DOWN, Tuning.TEMPLE_SPIKES_WARN,
			Tuning.TEMPLE_SPIKES_UP, Tuning.TEMPLE_SPIKES_RETRACT]
	_phase_left = durations[phase]
	_sprite.play(SPIKES_PHASE_NAMES[phase])
	if phase == SpikesPhase.UP:
		_hitbox.activate()
	else:
		_hitbox.deactivate()


## The saw: its groove along the track (flat, under the actors), the blade and its hitbox on the
## mover, which runs from the prop's cell to the track's far end and back.
func _start_saw(info: Dictionary) -> void:
	var tile := float(TileArt.TILE)
	_travel = (track_length() - 1) * tile
	var groove := _meta_of(SAW_TRACK_STRIP)
	if not groove.is_empty():
		var vertical := direction.y != 0
		for i in track_length():
			var piece := AnimatedSprite2D.new()
			piece.name = "Track%d" % i
			piece.sprite_frames = _frames_of(SAW_TRACK_STRIP, groove)
			piece.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			piece.z_as_relative = false
			piece.z_index = RoomTheme.GROUND_FX_Z
			# The groove tile is centred on its cell: the blade's centre runs along the cell centres.
			var foot: Array = info["foot"]
			var blade_center := Vector2(0, float(info["cell"][1]) / 2.0 - foot[1])
			piece.position = blade_center + Vector2(direction) * i * tile
			piece.rotation = PI / 2.0 if vertical else 0.0
			piece.frame = posmod(i * 2, piece.sprite_frames.get_frame_count(&"default"))
			piece.play(&"default")
			add_child(piece)
	_hitbox = _trap_hitbox(_mover)
	if Tuning.TEMPLE_TRAPS_ENABLED:
		_hitbox.activate()
	_along = 0.0
	_hit_clock = 0.0


func _run_saw(delta: float) -> void:
	if _travel <= 0.0:
		return
	_along = fmod(_along + delta * Tuning.TEMPLE_SAW_SPEED, 2.0 * _travel)
	var t := _along / _travel
	if t > 1.0:
		t = 2.0 - t
	# Eased at the ends, so the blade slows where it turns (a beat to cross behind it).
	_mover.position = Vector2(direction) * _travel * smoothstep(0.0, 1.0, t)
	_hit_clock += delta
	if _hit_clock >= Tuning.TEMPLE_SAW_HIT_EVERY:
		_hit_clock = 0.0
		_hitbox.activate()


## The rock: it rises at the prop's cell (the rumble is the warning), rolls down the lane, breaks
## at its end and the lane rests before the next one.
func _start_rock() -> void:
	_travel = float((track_length() - 1) * TileArt.TILE)
	_hitbox = _trap_hitbox(_mover)
	var frames := _sprite.sprite_frames
	frames.set_animation_loop(&"break", false)
	frames.set_animation_loop(&"spawn", false)
	frames.set_animation_speed(&"break", frames.get_frame_count(&"break") / maxf(0.05, Tuning.TEMPLE_ROCK_BREAK))
	frames.set_animation_speed(&"spawn", frames.get_frame_count(&"spawn") / maxf(0.05, Tuning.TEMPLE_ROCK_SPAWN))
	if Tuning.TEMPLE_TRAPS_ENABLED:
		_enter_rock_phase(RockPhase.SPAWN)
	else:
		_phase = RockPhase.SPAWN
		_sprite.play(&"spawn")
		_sprite.pause()


func _enter_rock_phase(phase: RockPhase) -> void:
	_phase = phase
	_sprite.visible = phase != RockPhase.WAIT
	match phase:
		RockPhase.SPAWN:
			_mover.position = Vector2.ZERO
			_phase_left = Tuning.TEMPLE_ROCK_SPAWN
			_sprite.play(&"spawn")
		RockPhase.ROLL:
			_along = 0.0
			_sprite.play(&"roll")
			_hitbox.activate()
		RockPhase.BREAK:
			_phase_left = Tuning.TEMPLE_ROCK_BREAK
			_sprite.play(&"break")
			_hitbox.deactivate()
		RockPhase.WAIT:
			_phase_left = Tuning.TEMPLE_ROCK_RESPAWN


func _run_rock(delta: float) -> void:
	if _phase == RockPhase.ROLL:
		_along = minf(_along + delta * Tuning.TEMPLE_ROCK_SPEED, _travel)
		_mover.position = Vector2(direction) * _along
		if _along >= _travel:
			_enter_rock_phase(RockPhase.BREAK)
		return
	_phase_left -= delta
	if _phase_left <= 0.0:
		_enter_rock_phase(((_phase + 1) % RockPhase.size()) as RockPhase)
