class_name BronzeBellRinger
extends Enemy
## Campanero de bronce: a slow automaton with a bell. When Nico comes close it raises its hammer (a
## warning circle at its feet), then strikes the bell again and again: every stroke sends a ring
## along the floor that grows to its max radius and hurts Nico once when its band passes over him.
## Walking away does not outrun a ring; dashing through it does (Nico is invulnerable while dashing).
## Everything tunable lives in its BronzeBellRingerData.

enum Toll { WINDUP, RINGING, RECOVER }

## A ring on its way out: where it started (world), its age, its radius and whether it landed.
class Ring:
	var canvas: Node2D
	var center := Vector2.ZERO
	var age := 0.0
	var radius := 0.0
	var landed := false

## The fading rim of a ring: how much of its alpha is gone when it reaches its max radius.
const RING_FADE := 0.7
const RING_SEGMENTS := 48
const RING_FILL_ALPHA := 0.35
const RING_EDGE_ALPHA := 0.9
const RING_EDGE_LIGHTEN := 0.3

var toll_step: Toll = Toll.WINDUP

var _ringer: BronzeBellRingerData
var _step_left := 0.0
var _strokes_left := 0
var _rings: Array[Ring] = []
var _warning: Node2D


func _ready() -> void:
	super()
	_ringer = data as BronzeBellRingerData
	if _ringer == null:
		push_error("BronzeBellRinger '%s' needs a BronzeBellRingerData." % name)
		_ringer = BronzeBellRingerData.new()


func _physics_process(delta: float) -> void:
	super(delta)
	# A push (a skill), a lost target or death ends the strikes; rings already out keep going.
	if state != State.ATTACK:
		_strokes_left = 0
		if is_instance_valid(_warning):
			_warning.queue_free()
	_update_rings(delta)


func _exit_tree() -> void:
	for ring in _rings:
		if is_instance_valid(ring.canvas):
			ring.canvas.queue_free()
	_rings.clear()
	if is_instance_valid(_warning):
		_warning.queue_free()


## Radii of the rings on their way out, oldest first (tests read them).
func ring_radii() -> Array[float]:
	var radii: Array[float] = []
	for ring in _rings:
		radii.append(ring.radius)
	return radii


# --- Behaviour ---------------------------------------------------------------------------------

func _start_attack() -> void:
	super()
	# The circle on the ground is the warning, not the generic lane in front of it.
	_telegraph.hide()
	toll_step = Toll.WINDUP
	_step_left = data.attack_windup
	_warning = SkillZone.circle(_to_parent_local(global_position), _ringer.warning_radius,
			_ringer.warning_color, data.attack_windup)
	get_parent().add_child(_warning)


func _process_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	_step_left -= delta
	if _step_left > 0.0:
		return
	match toll_step:
		Toll.WINDUP:
			toll_step = Toll.RINGING
			_strokes_left = maxi(_ringer.ring_count, 1)
			_strike()
		Toll.RINGING:
			if _strokes_left > 0:
				_strike()
			else:
				toll_step = Toll.RECOVER
				_step_left = _ringer.recover_time
		Toll.RECOVER:
			_attack_cooldown_left = data.attack_cooldown
			_enter_chase_or_idle()


## One stroke of the hammer: a ring leaves the bell.
func _strike() -> void:
	_strokes_left -= 1
	_step_left = _ringer.ring_interval if _strokes_left > 0 else 0.0
	Events.enemy_attacked.emit(self, &"melee")
	var ring := Ring.new()
	ring.center = global_position
	ring.canvas = Node2D.new()
	ring.canvas.name = "BellRing"
	ring.canvas.z_as_relative = false
	ring.canvas.z_index = RoomTheme.GROUND_FX_Z
	ring.canvas.position = _to_parent_local(ring.center)
	ring.canvas.draw.connect(_draw_ring.bind(ring))
	get_parent().add_child(ring.canvas)
	_rings.append(ring)
	if _sprite != null and _sprite.sprite_frames.has_animation(&"special"):
		# Each stroke swings the bell once.
		_sprite.play(&"special")
		_sprite.frame = 0
		_sprite.speed_scale = _animation_length(&"special") / maxf(_ringer.ring_interval, 0.05)


func _update_rings(delta: float) -> void:
	for ring: Ring in _rings.duplicate():
		ring.age += delta
		var previous := ring.radius
		ring.radius = _ringer.ring_max_radius * clampf(ring.age / maxf(_ringer.ring_time, 0.01), 0.0, 1.0)
		if not ring.landed:
			_hurt_player_in_band(ring, previous)
		if is_instance_valid(ring.canvas):
			ring.canvas.queue_redraw()
		if ring.age >= _ringer.ring_time:
			if is_instance_valid(ring.canvas):
				ring.canvas.queue_free()
			_rings.erase(ring)


## The band swept this tick covers from the trailing edge of the old ring to the new ring.
func _hurt_player_in_band(ring: Ring, from_radius: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var distance := player.global_position.distance_to(ring.center)
	if distance < from_radius - _ringer.ring_band or distance > ring.radius:
		return
	var hurtbox := player.get_node_or_null("Hurtbox") as Hurtbox
	# Refused while dashing (or still blinking from the last ring): the ring tries on while it is over him.
	if hurtbox != null and hurtbox.receive_hit(ceili(_ringer.ring_damage * damage_multiplier), ring.center):
		ring.landed = true


func _draw_ring(ring: Ring) -> void:
	var canvas := ring.canvas
	if not is_instance_valid(canvas):
		return
	var progress := clampf(ring.age / maxf(_ringer.ring_time, 0.01), 0.0, 1.0)
	var fade := 1.0 - progress * RING_FADE
	var band := _ringer.ring_band
	var middle := maxf(ring.radius - band / 2.0, 1.0)
	if Tuning.ZONE_OUTLINE_ALPHA > 0.0:
		canvas.draw_arc(Vector2.ZERO, ring.radius, 0.0, TAU, RING_SEGMENTS, Color(0, 0, 0, Tuning.ZONE_OUTLINE_ALPHA * fade), 2.0)
	canvas.draw_arc(Vector2.ZERO, middle, 0.0, TAU, RING_SEGMENTS, Color(_ringer.ring_color, RING_FILL_ALPHA * fade), band)
	canvas.draw_arc(Vector2.ZERO, ring.radius, 0.0, TAU, RING_SEGMENTS,
			Color(_ringer.ring_color.lightened(RING_EDGE_LIGHTEN), RING_EDGE_ALPHA * fade), 2.0)


## Rings and warnings are children of the room, which in a generated map is not at the origin.
func _to_parent_local(world_point: Vector2) -> Vector2:
	var parent := get_parent() as Node2D
	return parent.to_local(world_point) if parent != null else world_point


# --- Animation ---------------------------------------------------------------------------------

## The windup raises the hammer (`attack`); each stroke swings the bell (`special`, started by
## `_strike`); the recover rests in `idle`.
func _update_animation() -> void:
	if _sprite == null or state != State.ATTACK:
		super()
		return
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	match toll_step:
		Toll.WINDUP:
			if _sprite.animation != &"attack":
				_sprite.play(&"attack")
				_anim_held = 0.0
				_sprite.speed_scale = _animation_length(&"attack") / maxf(data.attack_windup, 0.05)
		Toll.RECOVER:
			if _sprite.animation != &"idle":
				_sprite.play(&"idle")
				_sprite.speed_scale = 1.0
