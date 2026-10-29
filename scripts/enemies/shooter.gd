class_name Shooter
extends Enemy
## An enemy that stands its ground and spits a projectile at the player: it faces the player, and
## when it has a clear shot within `attack_range` it charges (the animation is the warning) and
## fires at the end of the windup. Stealth breaks the shot like it breaks sight (`can_see`).
## Everything tunable lives in its ShooterData.

var _shooter: ShooterData


func _ready() -> void:
	super()
	_shooter = data as ShooterData
	if _shooter == null:
		push_error("Shooter '%s' needs a ShooterData." % name)
		_shooter = ShooterData.new()


func _process_chase(_delta: float) -> void:
	if not _target_is_valid():
		return
	var to_target := target.global_position - global_position
	facing = to_target.normalized()
	velocity = facing * data.chase_speed * _speed_scale()
	if to_target.length() <= data.attack_range and _attack_cooldown_left == 0.0 and can_see(target):
		_start_attack()


func _start_attack() -> void:
	super()
	_telegraph.hide()


func _process_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	if _attack_phase == AttackPhase.WINDUP and _target_is_valid():
		facing = (target.global_position - global_position).normalized()
	_attack_time_left -= delta
	if _attack_time_left > 0.0:
		return
	match _attack_phase:
		AttackPhase.WINDUP:
			_fire()
			_attack_phase = AttackPhase.STRIKE
			_attack_time_left = data.attack_time
		AttackPhase.STRIKE:
			_attack_phase = AttackPhase.RECOVER
			_attack_time_left = data.attack_cooldown * 0.5
		AttackPhase.RECOVER:
			_attack_cooldown_left = data.attack_cooldown * 0.5
			_enter_chase_or_idle()


func _fire() -> void:
	if _shooter.projectile_scene == null or get_parent() == null:
		return
	var orb: EnemyOrb = _shooter.projectile_scene.instantiate()
	orb.setup(facing, _shooter.projectile_speed, _shooter.projectile_range,
			ceili(data.attack_damage * damage_multiplier))
	orb.position = position + facing * _shooter.muzzle_distance
	get_parent().add_child(orb)
