class_name DevouringWheel
extends Enemy
## Rueda devoradora (island 3): a stone wheel with carved faces. When it sees Nico its faces glow
## for a moment (the warning), then it rolls fast in a straight line, spinning, and hurts him on
## contact (it rolls through him). Walls, obstacles, ponds and the edge of its room make it bounce:
## its course is reflected on the surface it hit and leans a little toward Nico. After its burst
## time or a number of bounces it brakes to a stop and rests (the moment to hit it), then rolls
## again. Everything tunable lives in its DevouringWheelData.

enum Phase { WINDUP, ROLL, BRAKE, REST }

## How fast the carved face turns back upright when the wheel stops (per second).
const SETTLE_RATE := 10.0

var phase: Phase = Phase.REST
## How many times the current burst has bounced.
var bounces := 0

var _wheel: DevouringWheelData
var _phase_left := 0.0
var _launch_left := 0.0
var _roll_dir := Vector2.RIGHT
var _last_position := Vector2.ZERO


func _ready() -> void:
	super()
	_wheel = data as DevouringWheelData
	if _wheel == null:
		push_error("DevouringWheel '%s' needs a DevouringWheelData." % name)
		_wheel = DevouringWheelData.new()
	if _sprite != null:
		# The sprite turns around the hub of the wheel, not around the middle of its frame.
		_sprite.offset = Vector2(0, -_wheel.hub_offset) / data.sprite_scale
		_sprite.position = data.sprite_offset + Vector2(0, _wheel.hub_offset)
	_last_position = global_position


func _physics_process(delta: float) -> void:
	_last_position = global_position
	super(delta)
	_spin(delta)


## The direction of the current (or last) burst.
func roll_direction() -> Vector2:
	return _roll_dir


func is_rolling() -> bool:
	return state == State.ATTACK and phase in [Phase.ROLL, Phase.BRAKE]


# --- Behaviour ---------------------------------------------------------------------------------

func _process_chase(_delta: float) -> void:
	if not _target_is_valid():
		return
	var to_target := target.global_position - global_position
	facing = to_target.normalized()
	if to_target.length() <= data.attack_range and _attack_cooldown_left == 0.0 and can_see(target):
		_start_attack()
		return
	if to_target.length() > data.attack_range * 0.6:
		velocity = facing * data.chase_speed * _speed_scale()
	else:
		velocity = Vector2.ZERO


func _start_attack() -> void:
	state = State.ATTACK
	velocity = Vector2.ZERO
	phase = Phase.WINDUP
	_phase_left = _wheel.windup_time


func _process_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	_phase_left -= delta
	_launch_left = maxf(_launch_left - delta, 0.0)
	match phase:
		Phase.WINDUP:
			# It keeps its faces on Nico while it winds up.
			if _target_is_valid():
				facing = (target.global_position - global_position).normalized()
			if _phase_left <= 0.0:
				_start_roll()
		Phase.ROLL:
			if _phase_left <= 0.0:
				_start_brake()
			_roll(delta, 1.0)
		Phase.BRAKE:
			if _phase_left <= 0.0:
				_start_rest()
			else:
				_roll(delta, _phase_left / maxf(_wheel.brake_time, 0.01))
		Phase.REST:
			if _phase_left <= 0.0:
				_attack_cooldown_left = data.attack_cooldown
				_enter_chase_or_idle()


func _start_roll() -> void:
	phase = Phase.ROLL
	_phase_left = _wheel.roll_time
	_launch_left = _wheel.launch_time
	_roll_dir = facing if facing != Vector2.ZERO else Vector2.RIGHT
	bounces = 0
	_hitbox.damage = ceili(data.attack_damage * damage_multiplier)
	_hitbox.activate()
	Events.enemy_attacked.emit(self, &"melee")


func _start_brake() -> void:
	phase = Phase.BRAKE
	_phase_left = _wheel.brake_time


func _start_rest() -> void:
	phase = Phase.REST
	_phase_left = _wheel.rest_time
	velocity = Vector2.ZERO
	_hitbox.deactivate()


## Rolls on along its course at `speed_factor` of its speed, bouncing off what the last move ran
## into and off the edge of its room (it treats that edge as a wall).
func _roll(delta: float, speed_factor: float) -> void:
	if not _dash_allowed(global_position):
		# Pushed out of its room's inner area: no course can be checked from here, so it stops.
		_start_rest()
		return
	if _hit_world():
		_bounce(_wall_normal())
	var speed := _wheel.roll_speed * _speed_scale() * speed_factor
	if not _dash_allowed(global_position + _roll_dir * speed * delta):
		_bounce(_edge_normal(global_position + _roll_dir * speed * delta))
	velocity = _roll_dir * speed
	facing = _roll_dir


func _bounce(normal: Vector2) -> void:
	if normal == Vector2.ZERO or _roll_dir.dot(normal) >= 0.0:
		return
	var reflected := _roll_dir.bounce(normal).normalized()
	_roll_dir = reflected
	if _target_is_valid() and _wheel.aim_bias > 0.0:
		var to_target := (target.global_position - global_position).normalized()
		var leaned := (reflected + to_target * _wheel.aim_bias).normalized()
		if leaned.dot(normal) >= _wheel.min_leave:
			_roll_dir = leaned
	bounces += 1
	# A new stretch of the burst may hit Nico again (a Hitbox hits each hurtbox once per activation).
	_hitbox.activate()
	if phase == Phase.ROLL and bounces >= _wheel.max_bounces:
		_start_brake()


## The surface the last move ran into (world or ponds), as one normal.
func _wall_normal() -> Vector2:
	var normal := Vector2.ZERO
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var other := collision.get_collider() as CollisionObject2D
		if other != null and (other.get_collision_layer_value(WORLD_LAYER)
				or other.get_collision_layer_value(WATER_LAYER)):
			normal += collision.get_normal()
	return normal.normalized()


## The edge(s) of its room's inner area that `point` lies beyond, as an inward normal.
func _edge_normal(point: Vector2) -> Vector2:
	var inner := home_area.grow(-Tuning.DASH_ROOM_MARGIN)
	var normal := Vector2.ZERO
	if point.x < inner.position.x:
		normal.x = 1.0
	elif point.x > inner.end.x:
		normal.x = -1.0
	if point.y < inner.position.y:
		normal.y = 1.0
	elif point.y > inner.end.y:
		normal.y = -1.0
	return normal.normalized()


func _on_died() -> void:
	super()
	if _sprite != null:
		_sprite.rotation = 0.0


# --- Animation ---------------------------------------------------------------------------------

## Rolling turns the sprite by the distance covered; still (or winding up, or launching) its carved
## face settles back upright.
func _spin(delta: float) -> void:
	if _sprite == null or state == State.DEAD:
		return
	var moved := global_position - _last_position
	var launching := state == State.ATTACK and (phase in [Phase.WINDUP, Phase.REST] or _launch_left > 0.0)
	if moved.length() > 0.01 and not launching:
		var turn := 1.0 if moved.x >= 0.0 else -1.0
		_sprite.rotation = wrapf(_sprite.rotation + turn * moved.length() / maxf(_wheel.wheel_radius, 1.0), -PI, PI)
	else:
		_sprite.rotation = lerp_angle(_sprite.rotation, 0.0, minf(SETTLE_RATE * delta, 1.0))


## Windup: the faces glowing (attack, spanning the windup); launch: the blur of `special`; rolling:
## `run` (the sprite also spins); resting: `idle`.
func _update_animation() -> void:
	if _sprite == null or state != State.ATTACK:
		super()
		return
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	var wanted: StringName = &"idle"
	var span := 0.0
	match phase:
		Phase.WINDUP:
			wanted = &"attack"
			span = _wheel.windup_time
		Phase.ROLL, Phase.BRAKE:
			wanted = &"special" if _launch_left > 0.0 else &"run"
			if wanted == &"special":
				span = _wheel.launch_time
	if _sprite.animation != wanted:
		_sprite.play(wanted)
		_sprite.speed_scale = _animation_length(wanted) / span if span > 0.0 else 1.0
