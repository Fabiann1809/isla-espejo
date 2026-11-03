class_name BrazierAcolyte
extends Shooter
## Acólito del brasero: a masked priest that plants itself and fires a fan of flames at Nico, and
## keeps its distance: when he comes closer than its preferred distance it backs away (never out of
## its room), until it is cornered or has been backing away for too long, and then it fires anyway.
## Ridden by a Máscara parásita its fan has more flames and is wider.
## Everything tunable lives in its BrazierAcolyteData.

## Turns (radians) tried, in order, when the straight way back would leave the room or hit a wall.
const RETREAT_TURNS: Array[float] = [0.0, PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0]

var _acolyte: BrazierAcolyteData
var _retreat_time := 0.0


func _ready() -> void:
	super()
	_acolyte = data as BrazierAcolyteData
	if _acolyte == null:
		push_error("BrazierAcolyte '%s' needs a BrazierAcolyteData." % name)
		_acolyte = BrazierAcolyteData.new()


## True while it is backing away from Nico (tests read it).
func is_retreating() -> bool:
	return state == State.CHASE and _retreat_time > 0.0


## Flames per shot and the fan's width (degrees) now: more and wider while a mask rides it.
func fan_count() -> int:
	return _acolyte.masked_fan_count if is_masked() else _acolyte.fan_count


func fan_angle() -> float:
	return _acolyte.masked_fan_angle if is_masked() else _acolyte.fan_angle


func _process_chase(delta: float) -> void:
	if not _target_is_valid():
		return
	var to_target := target.global_position - global_position
	if to_target.length() < _acolyte.preferred_distance and _retreat_time < _acolyte.retreat_max_time:
		var away := _retreat_direction(-to_target.normalized())
		if away != Vector2.ZERO:
			facing = to_target.normalized()
			velocity = away * _acolyte.retreat_speed * _speed_scale()
			_retreat_time += delta
			return
	elif to_target.length() >= _acolyte.preferred_distance:
		_retreat_time = 0.0
	super(delta)


## The first way back that stays in the room and is not blocked, or zero when it is cornered.
func _retreat_direction(away: Vector2) -> Vector2:
	for turn in RETREAT_TURNS:
		var direction := away.rotated(turn)
		var step := direction * _acolyte.retreat_lookahead
		if _dash_allowed(global_position + step) and not test_move(global_transform, step):
			return direction
	return Vector2.ZERO


func _fire() -> void:
	_retreat_time = 0.0
	if _shooter.projectile_scene == null or get_parent() == null:
		return
	Events.enemy_attacked.emit(self, &"shot")
	var count := maxi(fan_count(), 1)
	var spread := deg_to_rad(fan_angle())
	for i in count:
		var along := 0.5 if count == 1 else float(i) / float(count - 1)
		var direction := facing.rotated(lerpf(-spread / 2.0, spread / 2.0, along))
		var flame: EnemyOrb = _shooter.projectile_scene.instantiate()
		flame.setup(direction, _shooter.projectile_speed, _shooter.projectile_range,
				ceili(data.attack_damage * damage_multiplier))
		flame.position = position + direction * _shooter.muzzle_distance
		flame.modulate = _acolyte.fire_tint
		get_parent().add_child(flame)


## The fan plays `special` over the windup and the release.
func _update_animation() -> void:
	if _sprite == null or state != State.ATTACK:
		super()
		return
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	if _sprite.animation != &"special":
		_sprite.play(&"special")
		_anim_held = 0.0
		_sprite.speed_scale = _animation_length(&"special") / maxf(data.attack_windup + data.attack_time, 0.05)
