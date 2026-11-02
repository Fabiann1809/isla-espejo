class_name CursedDuelist
extends Enemy
## Duelista maldito: an agile skeleton. A sensor on the player-attack layer watches Nico's arrows;
## when one is coming straight at it, with some chance (and not again until its cooldown is over)
## it sidesteps across the arrow's line and answers with a lunge: a fast dash at Nico with its blade
## out. Otherwise it fights with the plain melee slash.
## Everything tunable lives in its CursedDuelistData.

enum Maneuver { NONE, DODGE, LUNGE_WINDUP, LUNGE, RECOVER }

const PLAYER_ATTACK_LAYER := 4
## An attack that moved less than this (px) since last tick is not flying (a melee swing).
const MIN_TRAVEL := 0.5

var maneuver: Maneuver = Maneuver.NONE

var _duelist: CursedDuelistData
var _sensor: Area2D
## Player attacks inside the sensor that are not judged yet -> where they were last tick.
var _watched := {}
var _dodge_cooldown_left := 0.0
var _maneuver_left := 0.0
var _dodge_dir := Vector2.ZERO


func _ready() -> void:
	super()
	_duelist = data as CursedDuelistData
	if _duelist == null:
		push_error("CursedDuelist '%s' needs a CursedDuelistData." % name)
		_duelist = CursedDuelistData.new()
	_build_sensor()


func _physics_process(delta: float) -> void:
	_dodge_cooldown_left = maxf(_dodge_cooldown_left - delta, 0.0)
	_judge_incoming()
	super(delta)
	# A hit, a push or a lost target ended the attack state: the maneuver ends with it.
	if state != State.ATTACK:
		maneuver = Maneuver.NONE


func _build_sensor() -> void:
	_sensor = Area2D.new()
	_sensor.name = "ArrowSensor"
	_sensor.collision_layer = 0
	_sensor.collision_mask = 1 << (PLAYER_ATTACK_LAYER - 1)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _duelist.arrow_sense_radius
	shape.shape = circle
	_sensor.add_child(shape)
	add_child(_sensor)
	_sensor.area_entered.connect(func(area: Area2D) -> void: _watched[area] = area.global_position)
	_sensor.area_exited.connect(func(area: Area2D) -> void: _watched.erase(area))


# --- Dodging -----------------------------------------------------------------------------------

## Its flight is read from how it moved since last tick; each arrow is judged once.
func _judge_incoming() -> void:
	for area: Variant in _watched.keys():
		if not is_instance_valid(area) or not area.is_inside_tree():
			_watched.erase(area)
			continue
		var now: Vector2 = area.global_position
		var travel: Vector2 = now - _watched[area]
		_watched[area] = now
		if travel.length() < MIN_TRAVEL:
			continue
		_watched.erase(area)
		_consider_dodge(now, travel.normalized())


func _consider_dodge(at: Vector2, flight: Vector2) -> void:
	var to_me := global_position - at
	if to_me.dot(flight) <= 0.0 or absf(flight.cross(to_me)) > _duelist.arrow_lane_width:
		return
	if not _can_dodge() or randf() >= _duelist.dodge_chance:
		return
	# Away from the arrow's line; if right on it, either side (the one that stays in its room).
	var off_line := to_me - flight * to_me.dot(flight)
	var side := off_line.normalized() if off_line.length() > 1.0 else flight.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
	var reach := _duelist.dodge_speed * _duelist.dodge_time
	if not _dash_allowed(global_position + side * reach):
		side = -side
	_start_dodge(side, -flight)


func _can_dodge() -> bool:
	return _dodge_cooldown_left == 0.0 and _root_left == 0.0 and state in [State.IDLE, State.PATROL, State.CHASE]


func _start_dodge(side: Vector2, toward_shooter: Vector2) -> void:
	_dodge_cooldown_left = _duelist.dodge_cooldown
	_hitbox.deactivate()
	_telegraph.hide()
	facing = toward_shooter
	state = State.ATTACK
	maneuver = Maneuver.DODGE
	_dodge_dir = side
	_maneuver_left = _duelist.dodge_time
	if target == null:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null:
			_acquire_target(player)


# --- Attacks -----------------------------------------------------------------------------------

func _start_attack() -> void:
	maneuver = Maneuver.NONE
	super()


func _process_attack(delta: float) -> void:
	if maneuver == Maneuver.NONE:
		super(delta)
		return
	_maneuver_left -= delta
	match maneuver:
		Maneuver.DODGE:
			velocity = _dodge_dir * _duelist.dodge_speed * _speed_scale()
			if _maneuver_left <= 0.0:
				_start_lunge_windup()
		Maneuver.LUNGE_WINDUP:
			velocity = Vector2.ZERO
			if not _target_is_valid():
				return
			facing = (target.global_position - global_position).normalized()
			_pivot.rotation = facing.angle()
			if _maneuver_left <= 0.0:
				_start_lunge()
		Maneuver.LUNGE:
			velocity = facing * _duelist.lunge_speed * _speed_scale()
			if _maneuver_left <= 0.0 or _hit_world() or not _dash_allowed(global_position + velocity * delta):
				velocity = Vector2.ZERO
				_hitbox.deactivate()
				maneuver = Maneuver.RECOVER
				_maneuver_left = _duelist.lunge_recover
		Maneuver.RECOVER:
			velocity = Vector2.ZERO
			if _maneuver_left <= 0.0:
				maneuver = Maneuver.NONE
				_attack_cooldown_left = data.attack_cooldown * 0.5
				_enter_chase_or_idle()


func _start_lunge_windup() -> void:
	velocity = Vector2.ZERO
	if not _target_is_valid():
		return
	maneuver = Maneuver.LUNGE_WINDUP
	_maneuver_left = _duelist.lunge_windup
	facing = (target.global_position - global_position).normalized()
	_pivot.rotation = facing.angle()
	_telegraph.show()


func _start_lunge() -> void:
	_telegraph.hide()
	_hitbox.damage = ceili(data.attack_damage * damage_multiplier)
	_hitbox.activate()
	Events.enemy_attacked.emit(self, &"melee")
	maneuver = Maneuver.LUNGE
	_maneuver_left = _duelist.lunge_time


## The sidestep is a quick run; the lunge (windup and dash) is the `special` slash-dash, which holds
## its last frame through the rest.
func _update_animation() -> void:
	if _sprite == null or state != State.ATTACK or maneuver == Maneuver.NONE:
		super()
		return
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	var wanted: StringName = &"run" if maneuver == Maneuver.DODGE else &"special"
	if not _sprite.sprite_frames.has_animation(wanted) or _sprite.animation == wanted:
		return
	_sprite.play(wanted)
	_anim_held = 0.0
	if wanted == &"special":
		_sprite.speed_scale = _animation_length(wanted) / maxf(_duelist.lunge_windup + _duelist.lunge_time, 0.05)
	else:
		_sprite.speed_scale = ANIM_SPEED_MAX
