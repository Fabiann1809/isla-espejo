class_name ClockTrap
extends Node2D
## A floor trap set by a trap clockmaker (TrapClockmaker): spikes that stab out of a plate, a saw
## that runs along a short track, or a nozzle that shoots a jet of fire in one direction. It does
## nothing by itself: the clockmaker `trigger()`s it, it warns for a moment and then its own Hitbox
## hurts Nico for its active time. When the clockmaker dies it goes dormant. Like the spike trap of
## the test room, but driven from outside. Drawn on the ground, under every actor.

enum Kind { SPIKES, SAW, FIRE }
enum Phase { READY, WARNING, ACTIVE, DORMANT }

const PLAYER_LAYER := 2
const ENEMY_ATTACK_LAYER := 5
const KIND_NAMES := {&"spikes": Kind.SPIKES, &"saw": Kind.SAW, &"fire": Kind.FIRE}
## Looks: how fast the saw spins (radians per second) and the warning blinks (per second).
const SAW_SPIN := 18.0
const BLINK_RATE := 10.0
const SAW_TEETH := 8

## Layouts of the drawn art (tools/make_relojero_trampas_art.py), each a strip of equal cells.
## Spikes: 24 px cells around a 16 px plate.
const SPIKES_ART_PLATE := 16.0
const SPIKES_READY := 0
const SPIKES_WARN := 1  # and 2, blinking
const SPIKES_RISE := 3
const SPIKES_UP := 4  # and 5, flickering
const SPIKES_DORMANT := 6
const SPIKES_FRAMES := 7
## How long the spikes show half out before they stand.
const SPIKES_RISE_TIME := 0.06
## Saw: 16 px cells of a blade of radius 7: four of its spin, the warning, dormant.
const SAW_ART_RADIUS := 7.0
const SAW_SPIN_FRAMES := 4
const SAW_WARN := 4
const SAW_DORMANT := 5
const SAW_FRAMES := 6
const SAW_ART_FPS := 20.0
## Track: two cells (normal, dormant) of a 56 px track lying along x.
const TRACK_ART_LENGTH := 56.0
const TRACK_FRAMES := 2
## Fire: cells pointing along x with the nozzle at FIRE_ART_ORIGIN_X: the spout (normal, warning,
## dormant), the warning line (bright, dim) and the jet (56 x 12) flickering in four.
const FIRE_ART_ORIGIN_X := 4.0
const FIRE_ART_LENGTH := 56.0
const FIRE_ART_WIDTH := 12.0
const FIRE_SPOUT := 0
const FIRE_SPOUT_WARN := 1
const FIRE_SPOUT_DORMANT := 2
const FIRE_WARN := 3  # and 4, blinking
const FIRE_JET := 5
const FIRE_JET_FRAMES := 4
const FIRE_FRAMES := 9
## Nozzle base: normal, warning, dormant.
const NOZZLE_FRAMES := 3
## Flicker of the spikes and the jet.
const ART_FPS := 12.0

var kind: Kind = Kind.SPIKES
var phase: Phase = Phase.READY
## The saw's track and the jet's aim.
var direction := Vector2.RIGHT
var damage := 1
var warn_time := 0.4
var active_time := 0.4
var spikes_size := 16.0
var track_length := 56.0
var saw_radius := 7.0
var fire_length := 56.0
var fire_width := 12.0
var base_color := Color.DIM_GRAY
var metal_color := Color.LIGHT_GRAY
var warn_color := Color.YELLOW
var fire_color := Color.ORANGE
var dormant_color := Color.DARK_GRAY
## Drawn art; without it the trap is drawn with plain shapes.
var spikes_art: Texture2D
var saw_art: Texture2D
var track_art: Texture2D
var fire_art: Texture2D
var nozzle_art: Texture2D

var _phase_left := 0.0
var _time := 0.0
## Where the saw is along its track (0 one end, 1 the other) and where this run goes.
var _saw_at := 0.0
var _saw_from := 0.0
var _saw_to := 1.0
var _hitbox: Hitbox
var _hit_shape: CollisionShape2D


## The trap kind for a name of the clockmaker's data (`spikes`, `saw`, `fire`), or -1.
static func kind_named(kind_name: StringName) -> int:
	return KIND_NAMES.get(kind_name, -1)


## A ready trap of `trap_kind` on `spot` (in its parent's coordinates), set up from the data.
static func create(trap_kind: Kind, spot: Vector2, aim: Vector2, data: TrapClockmakerData,
		hit_damage: int) -> ClockTrap:
	var trap := ClockTrap.new()
	trap.name = "ClockTrap"
	trap.kind = trap_kind
	trap.position = spot
	trap.direction = aim.normalized() if aim.length() > 0.01 else Vector2.RIGHT
	trap.damage = hit_damage
	match trap_kind:
		Kind.SPIKES:
			trap.warn_time = data.spikes_warn_time
			trap.active_time = data.spikes_time
		Kind.SAW:
			trap.warn_time = data.saw_warn_time
			trap.active_time = data.saw_travel_time
		Kind.FIRE:
			trap.warn_time = data.fire_warn_time
			trap.active_time = data.fire_time
	trap.spikes_size = data.spikes_size
	trap.track_length = data.saw_track_length
	trap.saw_radius = data.saw_radius
	trap.fire_length = data.fire_length
	trap.fire_width = data.fire_width
	trap.base_color = data.trap_base_color
	trap.metal_color = data.trap_metal_color
	trap.warn_color = data.trap_warn_color
	trap.fire_color = data.fire_color
	trap.dormant_color = data.dormant_color
	trap.spikes_art = data.spikes_art
	trap.saw_art = data.saw_art
	trap.track_art = data.track_art
	trap.fire_art = data.fire_art
	trap.nozzle_art = data.nozzle_art
	return trap


func _ready() -> void:
	# The arena's reset clears ground hazards; a trap is one more.
	add_to_group(&"ground_hazards")
	z_as_relative = false
	z_index = RoomTheme.GROUND_FX_Z
	_hitbox = Hitbox.new()
	_hitbox.collision_layer = 1 << (ENEMY_ATTACK_LAYER - 1)
	_hitbox.collision_mask = 1 << (PLAYER_LAYER - 1)
	_hitbox.damage = damage
	_hit_shape = CollisionShape2D.new()
	match kind:
		Kind.SPIKES:
			var square := RectangleShape2D.new()
			square.size = Vector2.ONE * spikes_size
			_hit_shape.shape = square
		Kind.SAW:
			var disc := CircleShape2D.new()
			disc.radius = saw_radius
			_hit_shape.shape = disc
			_hit_shape.position = _saw_point(_saw_at)
		Kind.FIRE:
			var jet := RectangleShape2D.new()
			jet.size = Vector2(fire_length, fire_width)
			_hit_shape.shape = jet
			_hit_shape.position = direction * fire_length / 2.0
			_hit_shape.rotation = direction.angle()
	_hitbox.add_child(_hit_shape)
	add_child(_hitbox)


## Starts a warning and then a strike. False if it is busy or dormant.
func trigger() -> bool:
	if phase != Phase.READY:
		return false
	phase = Phase.WARNING
	_phase_left = warn_time
	return true


## Stops for good: whatever it was doing, it no longer hurts.
func set_dormant() -> void:
	phase = Phase.DORMANT
	_hitbox.deactivate()
	queue_redraw()


func is_active() -> bool:
	return phase == Phase.ACTIVE


## Where the saw is now (world position); tests read it.
func saw_position() -> Vector2:
	return to_global(_saw_point(_saw_at))


func _physics_process(delta: float) -> void:
	_time += delta
	_phase_left -= delta
	match phase:
		Phase.WARNING:
			if _phase_left <= 0.0:
				_strike()
		Phase.ACTIVE:
			if kind == Kind.SAW:
				var progress := 1.0 - clampf(_phase_left / maxf(active_time, 0.001), 0.0, 1.0)
				_saw_at = lerpf(_saw_from, _saw_to, progress)
				_hit_shape.position = _saw_point(_saw_at)
			if _phase_left <= 0.0:
				phase = Phase.READY
				_hitbox.deactivate()
	queue_redraw()


func _strike() -> void:
	phase = Phase.ACTIVE
	_phase_left = active_time
	if kind == Kind.SAW:
		# Each run goes to the other end of the track.
		_saw_from = _saw_at
		_saw_to = 1.0 - _saw_at
	_hitbox.activate()


func _saw_point(along: float) -> Vector2:
	return direction * track_length * (along - 0.5)


func _draw() -> void:
	var blink := phase == Phase.WARNING and fmod(_time * BLINK_RATE, 1.0) < 0.5
	match kind:
		Kind.SPIKES:
			if spikes_art != null:
				_draw_spikes_art(blink)
			else:
				_draw_spikes(blink)
		Kind.SAW:
			if saw_art != null and track_art != null:
				_draw_saw_art(blink)
			else:
				_draw_saw(blink)
		Kind.FIRE:
			if fire_art != null and nozzle_art != null:
				_draw_fire_art(blink)
			else:
				_draw_fire(blink)


## Draws `frame` of a strip of `frames` equal cells into `rect`.
func _draw_cell(art: Texture2D, frames: int, frame: int, rect: Rect2) -> void:
	var cell := Vector2(art.get_width() / float(frames), art.get_height())
	draw_texture_rect_region(art, rect, Rect2(Vector2(cell.x * frame, 0.0), cell))


## The plate's art is drawn for a 16 px plate; another size scales it.
func _draw_spikes_art(blink: bool) -> void:
	var frame := SPIKES_READY
	match phase:
		Phase.WARNING:
			frame = SPIKES_WARN if blink else SPIKES_WARN + 1
		Phase.ACTIVE:
			if active_time - _phase_left < SPIKES_RISE_TIME:
				frame = SPIKES_RISE
			else:
				frame = SPIKES_UP + int(_time * ART_FPS) % 2
		Phase.DORMANT:
			frame = SPIKES_DORMANT
	var size := spikes_art.get_height() * spikes_size / SPIKES_ART_PLATE
	_draw_cell(spikes_art, SPIKES_FRAMES, frame, Rect2(-Vector2.ONE * size / 2.0, Vector2.ONE * size))


## The track lies along `direction` (the art is drawn along x); the blade is round, so it is drawn
## upright and spins through its frames.
func _draw_saw_art(blink: bool) -> void:
	var track_cell := Vector2(track_art.get_width() / float(TRACK_FRAMES), track_art.get_height())
	track_cell.x *= track_length / TRACK_ART_LENGTH
	draw_set_transform(Vector2.ZERO, direction.angle())
	_draw_cell(track_art, TRACK_FRAMES, 1 if phase == Phase.DORMANT else 0, Rect2(-track_cell / 2.0, track_cell))
	draw_set_transform(Vector2.ZERO)
	var frame := 0
	match phase:
		Phase.ACTIVE:
			frame = int(_time * SAW_ART_FPS) % SAW_SPIN_FRAMES
		Phase.WARNING:
			frame = SAW_WARN if blink else 0
		Phase.DORMANT:
			frame = SAW_DORMANT
	var size := saw_art.get_height() * saw_radius / SAW_ART_RADIUS
	_draw_cell(saw_art, SAW_FRAMES, frame, Rect2(_saw_point(_saw_at) - Vector2.ONE * size / 2.0, Vector2.ONE * size))


## The base sits upright; the spout, the warning line and the jet point along `direction` (the art
## points along x), the jet stretched to `fire_length` x `fire_width`.
func _draw_fire_art(blink: bool) -> void:
	var dormant := phase == Phase.DORMANT
	var base := float(nozzle_art.get_height())
	var base_frame := 2 if dormant else (1 if blink else 0)
	_draw_cell(nozzle_art, NOZZLE_FRAMES, base_frame, Rect2(-Vector2.ONE * base / 2.0, Vector2.ONE * base))
	var cell := Vector2(fire_art.get_width() / float(FIRE_FRAMES), fire_art.get_height())
	var plain := Rect2(Vector2(-FIRE_ART_ORIGIN_X, -cell.y / 2.0), cell)
	draw_set_transform(Vector2.ZERO, direction.angle())
	if phase == Phase.WARNING:
		_draw_cell(fire_art, FIRE_FRAMES, FIRE_WARN if blink else FIRE_WARN + 1, plain)
	elif phase == Phase.ACTIVE:
		var stretch := Vector2(fire_length / FIRE_ART_LENGTH, fire_width / FIRE_ART_WIDTH)
		var frame := FIRE_JET + int(_time * ART_FPS) % FIRE_JET_FRAMES
		_draw_cell(fire_art, FIRE_FRAMES, frame, Rect2(plain.position * stretch, cell * stretch))
	var spout := FIRE_SPOUT_DORMANT if dormant else (FIRE_SPOUT_WARN if blink else FIRE_SPOUT)
	_draw_cell(fire_art, FIRE_FRAMES, spout, plain)
	draw_set_transform(Vector2.ZERO)


func _draw_spikes(blink: bool) -> void:
	var half := spikes_size / 2.0
	var plate := Rect2(-half, -half, spikes_size, spikes_size)
	draw_rect(plate, dormant_color.darkened(0.3) if phase == Phase.DORMANT else base_color)
	draw_rect(plate, warn_color if blink else base_color.lightened(0.2), false, 1.0)
	for x in 3:
		for y in 3:
			var hole := Vector2(-half + spikes_size * (x + 0.5) / 3.0, -half + spikes_size * (y + 0.5) / 3.0)
			match phase:
				Phase.ACTIVE:
					draw_colored_polygon(PackedVector2Array([hole + Vector2(-2, 1), hole + Vector2(2, 1),
							hole + Vector2(0, -4)]), metal_color)
				Phase.WARNING:
					draw_circle(hole, 1.0, metal_color)
				_:
					draw_circle(hole, 1.0, Color(0, 0, 0, 0.6))


func _draw_saw(blink: bool) -> void:
	var dormant := phase == Phase.DORMANT
	var track_end := direction * track_length / 2.0
	draw_line(-track_end, track_end, dormant_color.darkened(0.3) if dormant else base_color, 3.0)
	draw_line(-track_end, track_end, Color(0, 0, 0, 0.5), 1.0)
	var center := _saw_point(_saw_at)
	var spin := _time * SAW_SPIN if phase == Phase.ACTIVE else 0.0
	var teeth := PackedVector2Array()
	for i in SAW_TEETH * 2:
		var reach := saw_radius if i % 2 == 0 else saw_radius * 0.7
		teeth.append(center + Vector2.from_angle(spin + PI * i / SAW_TEETH) * reach)
	draw_colored_polygon(teeth, dormant_color if dormant else metal_color)
	draw_circle(center, saw_radius * 0.3, warn_color if blink else base_color)


func _draw_fire(blink: bool) -> void:
	var dormant := phase == Phase.DORMANT
	var across := direction.orthogonal() * fire_width / 2.0
	var tip := direction * fire_length
	if phase == Phase.WARNING:
		draw_line(Vector2.ZERO, tip, Color(warn_color, 0.6 if blink else 0.3), 1.0)
	elif phase == Phase.ACTIVE:
		var flicker := 0.8 + 0.2 * sin(_time * 40.0)
		draw_colored_polygon(PackedVector2Array([across * 0.4, tip + across * flicker,
				tip - across * flicker, -across * 0.4]), fire_color)
		draw_colored_polygon(PackedVector2Array([across * 0.2, tip * 0.8 + across * 0.4,
				tip * 0.8 - across * 0.4, -across * 0.2]), fire_color.lightened(0.5))
	var nozzle := Rect2(-4, -4, 8, 8)
	draw_rect(nozzle, dormant_color.darkened(0.3) if dormant else base_color)
	draw_line(Vector2.ZERO, direction * 5.0, warn_color if blink else metal_color, 3.0)
