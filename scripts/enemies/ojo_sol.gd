class_name SunEye
extends Enemy
## Ojo del sol: a mechanical sphere hovering over the floor (it floats over ponds). It aims a thin
## ray of light that follows Nico at a limited turn rate, holds it still for a moment (the ray
## blinks), then fires a straight laser along it up to the first wall: Nico is hurt once if the beam
## touches him while it burns. Ray and laser lie on the floor.
## Everything tunable lives in its SunEyeData.

enum Beam { AIM, LOCK, FIRE, RECOVER }

## The laser's bright core, as a fraction of its width.
const CORE_SCALE := 0.4
## The held ray grows this much (px) on its bright blinks.
const LOCK_WIDTH_BONUS := 1.0

var beam_step: Beam = Beam.AIM

var _eye: SunEyeData
var _step_left := 0.0
var _aim := Vector2.RIGHT
var _beam_length := 0.0
## The ray / laser drawn on the room's floor (null when none), and the laser's Hitbox.
var _beam: Node2D
var _laser: Hitbox
var _laser_shape: RectangleShape2D
var _beam_clock := 0.0


func _ready() -> void:
	super()
	_eye = data as SunEyeData
	if _eye == null:
		push_error("SunEye '%s' needs a SunEyeData." % name)
		_eye = SunEyeData.new()
	_build_laser()


func _physics_process(delta: float) -> void:
	super(delta)
	# A hit, a push, a lost target or death ends the attack: no ray or laser left behind.
	if state != State.ATTACK or beam_step == Beam.RECOVER:
		_clear_beam()
	_beam_clock += delta
	if is_instance_valid(_beam):
		_beam.queue_redraw()


func _exit_tree() -> void:
	_clear_beam()


## Where the ray / laser points (tests read it).
func aim_direction() -> Vector2:
	return _aim


## Length of the ray / laser from the eye's center to where it stops (a wall or its range).
func beam_length() -> float:
	return _beam_length


# --- Behaviour ---------------------------------------------------------------------------------

func _process_chase(_delta: float) -> void:
	if not _target_is_valid():
		return
	var to_target := target.global_position - global_position
	facing = to_target.normalized()
	if to_target.length() <= data.attack_range and _attack_cooldown_left == 0.0 and can_see(target):
		_start_attack()
		return
	if to_target.length() > _eye.approach_distance:
		velocity = facing * data.chase_speed * _speed_scale()
	else:
		velocity = Vector2.ZERO


func _start_attack() -> void:
	super()
	_telegraph.hide()
	beam_step = Beam.AIM
	_step_left = data.attack_windup
	_aim = facing
	_show_beam()


func _process_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	_step_left -= delta
	match beam_step:
		Beam.AIM:
			_track(delta)
			if _step_left <= 0.0:
				beam_step = Beam.LOCK
				_step_left = _eye.lock_time
		Beam.LOCK:
			if _step_left <= 0.0:
				_fire()
		Beam.FIRE:
			if _step_left <= 0.0:
				_laser.deactivate()
				beam_step = Beam.RECOVER
				_step_left = _eye.recover_time
		Beam.RECOVER:
			if _step_left <= 0.0:
				_attack_cooldown_left = data.attack_cooldown
				_enter_chase_or_idle()
	if is_instance_valid(_beam):
		_beam_length = _clear_length()
		_beam.rotation = _aim.angle()


## The ray turns toward Nico, but no faster than its turn speed.
func _track(delta: float) -> void:
	if not _target_is_valid():
		return
	var wanted := (target.global_position - global_position).angle()
	var angle := rotate_toward(_aim.angle(), wanted, deg_to_rad(_eye.aim_turn_speed) * delta)
	_aim = Vector2.from_angle(angle)
	facing = _aim


func _fire() -> void:
	beam_step = Beam.FIRE
	_step_left = data.attack_time
	_beam_length = _clear_length()
	var reach := maxf(_beam_length - _eye.muzzle_distance, 0.0)
	_laser_shape.size = Vector2(reach, _eye.laser_width)
	_laser.position = _aim * (_eye.muzzle_distance + reach / 2.0)
	_laser.rotation = _aim.angle()
	_laser.damage = ceili(data.attack_damage * damage_multiplier)
	_laser.activate()
	Events.enemy_attacked.emit(self, &"shot")


## How far the beam goes before a wall stops it (ponds do not: it shines over them).
func _clear_length() -> float:
	var query := PhysicsRayQueryParameters2D.create(
			global_position, global_position + _aim * _eye.laser_range, 1 << (WORLD_LAYER - 1))
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return global_position.distance_to(hit.position) if not hit.is_empty() else _eye.laser_range


func _build_laser() -> void:
	_laser = Hitbox.new()
	_laser.name = "Laser"
	_laser.collision_layer = 1 << 4
	_laser.collision_mask = 1 << 1
	_laser_shape = RectangleShape2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = _laser_shape
	_laser.add_child(shape)
	add_child(_laser)
	# The hit pushes Nico away from the eye, not from the middle of the beam.
	_laser.owner = self


# --- Ray and laser on the floor ----------------------------------------------------------------

func _show_beam() -> void:
	_clear_beam()
	_beam = Node2D.new()
	_beam.name = "SunRay"
	_beam.z_as_relative = false
	_beam.z_index = RoomTheme.GROUND_FX_Z
	var parent := get_parent() as Node2D
	_beam.position = parent.to_local(global_position) if parent != null else global_position
	_beam.rotation = _aim.angle()
	_beam.draw.connect(_draw_beam.bind(_beam))
	get_parent().add_child(_beam)
	_beam_length = _clear_length()


func _clear_beam() -> void:
	if is_instance_valid(_beam):
		_beam.queue_free()
	_beam = null
	if _laser != null:
		_laser.deactivate()


func _draw_beam(canvas: Node2D) -> void:
	var from := Vector2(_eye.muzzle_distance, 0.0)
	var to := Vector2(maxf(_beam_length, _eye.muzzle_distance), 0.0)
	match beam_step:
		Beam.AIM:
			canvas.draw_line(from, to, _eye.ray_color, _eye.ray_width)
		Beam.LOCK:
			var on := fmod(_beam_clock * _eye.lock_blink_rate, 1.0) < 0.5
			var color := _eye.laser_core_color if on else _eye.ray_color
			canvas.draw_line(from, to, color, _eye.ray_width + (LOCK_WIDTH_BONUS if on else 0.0))
		Beam.FIRE:
			var fade := clampf(_step_left / maxf(data.attack_time, 0.01), 0.0, 1.0)
			canvas.draw_line(from, to, Color(_eye.laser_color, 0.5 + 0.4 * fade), _eye.laser_width)
			canvas.draw_line(from, to, _eye.laser_core_color, _eye.laser_width * CORE_SCALE)


# --- Animation ---------------------------------------------------------------------------------

## Aiming and holding play `attack` (the eye charging); the laser plays `special`.
func _update_animation() -> void:
	if _sprite == null or state != State.ATTACK:
		super()
		return
	if absf(_aim.x) > 0.1:
		_sprite.flip_h = _aim.x < 0.0
	var wanted: StringName = &"special" if beam_step == Beam.FIRE else &"attack"
	if beam_step == Beam.RECOVER:
		wanted = &"idle"
	if _sprite.animation != wanted:
		_sprite.play(wanted)
		_anim_held = 0.0
		match wanted:
			&"attack":
				_sprite.speed_scale = _animation_length(wanted) / maxf(data.attack_windup + _eye.lock_time, 0.05)
			&"special":
				_sprite.speed_scale = _animation_length(wanted) / maxf(data.attack_time, 0.05)
			_:
				_sprite.speed_scale = 1.0
