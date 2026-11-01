class_name Diver
extends Enemy
## A flying enemy (the Murciélago). It never flies straight at the player: it circles them, weaving
## in and out and changing direction now and then. When the player is close and in sight it rears
## back and blinks while a thin lane on the ground shows its path (the warning), then dives straight
## through where the player stood, past them, and climbs away before circling again. Divers of the
## same room take turns (`EnemyPack`), so a group dives one after another.
## Everything tunable lives in its DiverData.

var _diver: DiverData
var _orbit_dir := 1.0
var _turn_left := 0.0
var _weave_clock := 0.0
var _dive_end := Vector2.ZERO
var _dive_dir := Vector2.RIGHT
var _climb_dir := Vector2.UP
var _lane: AttackLane
var _flash: Tween


func _ready() -> void:
	super()
	_diver = data as DiverData
	if _diver == null:
		push_error("Diver '%s' needs a DiverData." % name)
		_diver = DiverData.new()
	_orbit_dir = 1.0 if randf() < 0.5 else -1.0
	_turn_left = randf_range(_diver.turn_time_min, _diver.turn_time_max)
	_weave_clock = randf() * 10.0


func _physics_process(delta: float) -> void:
	super(delta)
	# A hit, a push or Nico leaving the room ends the warning early.
	if _lane != null and not (state == State.ATTACK and _attack_phase == AttackPhase.WINDUP):
		_clear_warning()


## True while it warns or dives (for tests and the group).
func is_diving() -> bool:
	return state == State.ATTACK and _attack_phase in [AttackPhase.WINDUP, AttackPhase.STRIKE]


func _process_chase(delta: float) -> void:
	if not _target_is_valid():
		return
	var to_target := target.global_position - global_position
	var distance := to_target.length()
	if distance > 0.01:
		facing = to_target / distance
	if distance <= _diver.dive_trigger_range and _attack_cooldown_left == 0.0 and can_see(target) \
			and EnemyPack.my_turn(self, _diver.group_gap):
		_start_attack()
		return
	_turn_left -= delta
	if _turn_left <= 0.0 or _hit_world():
		_orbit_dir = -_orbit_dir
		_turn_left = randf_range(_diver.turn_time_min, _diver.turn_time_max)
	_weave_clock += delta
	var radius := _diver.orbit_radius + sin(_weave_clock * TAU * _diver.weave_frequency) * _diver.weave_amplitude
	var around := (-to_target).angle() + _orbit_dir * _diver.orbit_lead
	var goal := target.global_position + Vector2.from_angle(around) * radius
	velocity = (goal - global_position).normalized() * data.chase_speed * _speed_scale()


func _start_attack() -> void:
	super()
	_telegraph.hide()
	EnemyPack.mark_strike(self)
	var aim := target.global_position if _target_is_valid() else global_position + facing * 40.0
	_dive_dir = (aim - global_position).normalized() if aim != global_position else facing
	_dive_end = aim + _dive_dir * _diver.dive_overshoot
	if get_parent() is Node2D:
		_lane = AttackLane.create(get_parent(), global_position, _dive_end, _diver.lane_width,
				_diver.warn_color, data.attack_windup)
	_blink()


func _process_attack(delta: float) -> void:
	_attack_time_left -= delta
	match _attack_phase:
		AttackPhase.WINDUP:
			# It rears back a little before diving.
			velocity = -_dive_dir * _diver.climb_speed * 0.15 * _speed_scale()
			if _attack_time_left <= 0.0:
				_launch()
		AttackPhase.STRIKE:
			velocity = _dive_dir * _diver.dive_speed * _speed_scale()
			var blocked := _hit_world() or not _dash_allowed(global_position + velocity * get_physics_process_delta_time())
			if _attack_time_left <= 0.0 or blocked:
				_end_dive(blocked)
		AttackPhase.RECOVER:
			var span := maxf(data.attack_cooldown * 0.5, 0.01)
			velocity = _climb_dir * _diver.climb_speed * _speed_scale() * clampf(_attack_time_left / span, 0.0, 1.0)
			if _hit_world():
				_climb_dir = -_climb_dir
			if _attack_time_left <= 0.0:
				_attack_cooldown_left = data.attack_cooldown * 0.5
				_enter_chase_or_idle()


func _launch() -> void:
	_clear_warning()
	var reach := global_position.distance_to(_dive_end)
	if reach > 0.5:
		_dive_dir = (_dive_end - global_position) / reach
	facing = _dive_dir
	_pivot.rotation = facing.angle()
	_hitbox.damage = ceili(data.attack_damage * damage_multiplier)
	_hitbox.activate()
	Events.enemy_attacked.emit(self, &"dive")
	_attack_phase = AttackPhase.STRIKE
	_attack_time_left = minf(reach / maxf(_diver.dive_speed * _speed_scale(), 1.0), data.attack_time)


func _end_dive(blocked: bool) -> void:
	_hitbox.deactivate()
	velocity = Vector2.ZERO
	# Up and away: on along the dive, bending up the screen (or back, if it hit something).
	var forward := -_dive_dir if blocked else _dive_dir
	_climb_dir = (forward + Vector2(0.0, -0.7)).normalized()
	if _climb_dir == Vector2.ZERO:
		_climb_dir = Vector2.UP
	_attack_phase = AttackPhase.RECOVER
	_attack_time_left = data.attack_cooldown * 0.5


## The bat blinks twice during the warning.
func _blink() -> void:
	if _sprite == null:
		return
	if _flash != null:
		_flash.kill()
	var step := data.attack_windup / 4.0
	_flash = create_tween()
	for i in 2:
		_flash.tween_property(_sprite, "modulate", _diver.flash_color, step * 0.5)
		_flash.tween_property(_sprite, "modulate", Color.WHITE, step * 1.5)


func _clear_warning() -> void:
	if is_instance_valid(_lane):
		_lane.queue_free()
	_lane = null
	if _flash != null and _flash.is_valid():
		_flash.kill()
	_flash = null
