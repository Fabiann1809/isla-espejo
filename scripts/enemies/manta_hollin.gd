class_name SootManta
extends Enemy
## Soot manta (island 3): it glides over the lava, so its body only stops at the world layer (walls),
## never at water or lava, and Nico does not bump into it. Its art flies above a small shadow on the
## ground. It circles Nico at a hover distance; when its dive is ready it marks his spot with a circle,
## rears back, swoops in a straight line through that spot with its hitbox on (dropping close to the
## ground) and climbs back to hover until it may dive again. A swoop stops at the edge of its room.
## Everything tunable lives in its SootMantaData.

## How high its art is above its shadow right now (px).
var height := 0.0

var _manta: SootMantaData
var _dive_target := Vector2.ZERO
var _dive_dir := Vector2.RIGHT
## Distance from where the swoop began to the marked spot, and what is left of the whole swoop.
var _dive_reach := 1.0
var _dive_left := 0.0
var _orbit_sign := 1.0
var _last_position := Vector2.ZERO


func _ready() -> void:
	super()
	_manta = data as SootMantaData
	if _manta == null:
		push_error("SootManta '%s' needs a SootMantaData." % name)
		_manta = SootMantaData.new()
	height = _manta.fly_height
	_telegraph.hide()
	_add_shadow()
	_apply_height()


func _physics_process(delta: float) -> void:
	_last_position = global_position
	super(delta)
	_track_swoop(delta)
	_update_height(delta)
	_apply_height()


func _acquire_target(player: Node2D) -> void:
	super(player)
	_orbit_sign = 1.0 if randf() < 0.5 else -1.0


# --- Behaviour ---------------------------------------------------------------------------------

## Circles Nico at the hover distance; dives when ready, at that distance and with a clear view.
func _process_chase(delta: float) -> void:
	if not _target_is_valid():
		return
	var to_target := target.global_position - global_position
	var distance := to_target.length()
	facing = to_target.normalized() if distance > 0.01 else facing
	if _attack_cooldown_left == 0.0 and absf(distance - _manta.hover_distance) <= _manta.hover_tolerance \
			and _dash_allowed(target.global_position) and can_see(target):
		_start_attack()
		return
	if _hit_world():
		_orbit_sign = -_orbit_sign
	var around := -facing.rotated(deg_to_rad(_manta.orbit_lead_degrees) * _orbit_sign)
	var spot := target.global_position + around * _manta.hover_distance
	var inside := home_area.grow(-Tuning.DASH_ROOM_MARGIN)
	if home_area.has_area() and inside.has_area():
		spot = spot.clamp(inside.position, inside.end)
	var to_spot := spot - global_position
	velocity = to_spot.normalized() * minf(data.chase_speed * _speed_scale(), to_spot.length() / delta)


## Marks the dive: a circle where Nico stands now, which the swoop will cross.
func _start_attack() -> void:
	state = State.ATTACK
	velocity = Vector2.ZERO
	_attack_phase = AttackPhase.WINDUP
	_attack_time_left = data.attack_windup
	_dive_target = target.global_position
	_dive_dir = (_dive_target - global_position).normalized()
	facing = _dive_dir
	var room := get_parent()
	if room != null:
		var center := (room as Node2D).to_local(_dive_target) if room is Node2D else _dive_target
		var reach_time := global_position.distance_to(_dive_target) / maxf(_manta.dive_speed, 1.0)
		room.add_child(SkillZone.circle(center, _manta.dive_warning_radius, _manta.dive_warning_color,
				data.attack_windup + reach_time))


func _process_attack(delta: float) -> void:
	_attack_time_left -= delta
	match _attack_phase:
		AttackPhase.WINDUP:
			velocity = -_dive_dir * _manta.windup_backoff_speed * _speed_scale()
			if _attack_time_left <= 0.0:
				_start_swoop()
		AttackPhase.STRIKE:
			velocity = _dive_dir * _manta.dive_speed * _speed_scale()
		AttackPhase.RECOVER:
			velocity = velocity.move_toward(Vector2.ZERO, _manta.climb_drag * delta)
			if _attack_time_left <= 0.0:
				_attack_cooldown_left = data.attack_cooldown
				_enter_chase_or_idle()


func _start_swoop() -> void:
	_dive_dir = (_dive_target - global_position).normalized()
	_dive_reach = maxf(global_position.distance_to(_dive_target), 1.0)
	_dive_left = _dive_reach + _manta.dive_overshoot
	facing = _dive_dir
	_pivot.rotation = _dive_dir.angle()
	velocity = _dive_dir * _manta.dive_speed * _speed_scale()
	_hitbox.damage = ceili(data.attack_damage * damage_multiplier)
	_hitbox.activate()
	Events.enemy_attacked.emit(self, &"melee")
	_attack_phase = AttackPhase.STRIKE


func _start_climb() -> void:
	_hitbox.deactivate()
	_attack_phase = AttackPhase.RECOVER
	_attack_time_left = _manta.climb_time


## After the move: the swoop ends past the marked spot, or early against a wall or its room's edge.
func _track_swoop(delta: float) -> void:
	if state != State.ATTACK or _attack_phase != AttackPhase.STRIKE:
		return
	var moved := global_position.distance_to(_last_position)
	_dive_left -= moved
	var expected := _manta.dive_speed * _speed_scale() * delta
	if _dive_left <= 0.0 or moved < expected * _manta.dive_blocked_fraction:
		_start_climb()


# --- Flight ------------------------------------------------------------------------------------

## The swoop drops it to `dive_height` right at the marked spot, the climb lifts it back over its
## length; otherwise it settles at its flying height (or falls when it dies).
func _update_height(delta: float) -> void:
	var low := _manta.dive_height
	if state == State.DEAD:
		height = move_toward(height, 0.0, _manta.height_speed * delta)
	elif state == State.ATTACK and _attack_phase == AttackPhase.STRIKE:
		var travelled := _dive_reach + _manta.dive_overshoot - _dive_left
		height = lerpf(_manta.fly_height, low, clampf(travelled / _dive_reach, 0.0, 1.0))
	elif state == State.ATTACK and _attack_phase == AttackPhase.RECOVER:
		var climbed := 1.0 - clampf(_attack_time_left / maxf(_manta.climb_time, 0.01), 0.0, 1.0)
		height = lerpf(low, _manta.fly_height, climbed)
	else:
		height = move_toward(height, _manta.fly_height, _manta.height_speed * delta)


func _apply_height() -> void:
	if _sprite != null:
		_sprite.position = data.sprite_offset - Vector2(0, height)


## Its own small shadow on the ground (the level's generic one would sit under the flying art).
func _add_shadow() -> void:
	if not Tuning.SHADOWS_ENABLED or has_node(ActorShadow.NODE_NAME):
		return
	var shadow := ActorShadow.new()
	shadow.name = ActorShadow.NODE_NAME
	shadow.position = _manta.shadow_offset
	shadow.size = _manta.shadow_size
	add_child(shadow)
	move_child(shadow, 0)


# --- Animation ---------------------------------------------------------------------------------

## The dive has its own poses: `special` while it marks and rears back, `attack` over the swoop and
## `walk` (hard flapping) while it climbs. Everything else is the base's.
func _update_animation() -> void:
	if _sprite == null or state != State.ATTACK:
		super()
		return
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	var wanted: StringName = &"walk"
	var span := 0.0
	match _attack_phase:
		AttackPhase.WINDUP:
			wanted = &"special"
			span = data.attack_windup
		AttackPhase.STRIKE:
			wanted = &"attack"
			span = (_dive_reach + _manta.dive_overshoot) / maxf(_manta.dive_speed * _speed_scale(), 1.0)
	if _sprite.animation == wanted:
		return
	_sprite.play(wanted)
	_anim_held = 0.0
	_sprite.speed_scale = _animation_length(wanted) / span if span > 0.0 else 1.0
