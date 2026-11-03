class_name ObsidianSentinel
extends Enemy
## Centinela de obsidiana: a slow, sturdy warrior whose black shield stops every hit that comes from
## its front arc (no damage, a white flash). It turns toward the player at a limited rate, so Nico
## can circle around it and strike its back, and it lowers the shield for a moment after each swing.
## Ridden by a Máscara parásita its shield also covers its sides and it turns faster.
## Everything tunable lives in its ObsidianSentinelData.

var _sentinel: ObsidianSentinelData
## Time left of the block pose after stopping a hit.
var _block_left := 0.0


func _ready() -> void:
	super()
	_sentinel = data as ObsidianSentinelData
	if _sentinel == null:
		push_error("ObsidianSentinel '%s' needs an ObsidianSentinelData." % name)
		_sentinel = ObsidianSentinelData.new()


func _physics_process(delta: float) -> void:
	_block_left = maxf(_block_left - delta, 0.0)
	super(delta)


## The shield is up all the time except in the recover right after its own swing (and once dead).
func is_shield_up() -> bool:
	if state == State.DEAD:
		return false
	return not (state == State.ATTACK and _attack_phase == AttackPhase.RECOVER)


## True if a hit coming from `point` (world position) lands on the shield.
func shield_covers(point: Vector2) -> bool:
	var to_point := point - global_position
	if to_point.is_zero_approx():
		return false
	return absf(facing.angle_to(to_point)) <= deg_to_rad(shield_arc()) / 2.0


## Width (degrees) of the arc the shield covers now: wider while a mask rides it.
func shield_arc() -> float:
	return _sentinel.masked_shield_arc if is_masked() else _sentinel.shield_arc


## How fast (degrees per second) it turns now: faster while a mask rides it.
func turn_rate() -> float:
	return _sentinel.masked_turn_rate if is_masked() else _sentinel.turn_rate


# --- Behaviour ---------------------------------------------------------------------------------

func _process_chase(delta: float) -> void:
	if not _target_is_valid():
		return
	var to_target := target.global_position - global_position
	_turn_toward(to_target, delta)
	var off_angle := absf(facing.angle_to(to_target))
	if off_angle <= deg_to_rad(_sentinel.swing_aim_angle) and to_target.length() <= data.attack_range \
			and _attack_cooldown_left == 0.0:
		_start_attack()
		return
	# It walks where it faces: with Nico behind it, it stops and turns in place instead of backing off.
	if off_angle < PI / 2.0 and to_target.length() > data.attack_range * 0.8:
		velocity = facing * data.chase_speed * _speed_scale()
	else:
		velocity = Vector2.ZERO


func _process_attack(delta: float) -> void:
	var phase_before := _attack_phase
	super(delta)
	if phase_before == AttackPhase.STRIKE and _attack_phase == AttackPhase.RECOVER:
		_attack_time_left = _sentinel.shield_down_time


func _on_hurtbox_hit(damage: int, from_position: Vector2) -> void:
	if is_shield_up() and shield_covers(from_position):
		_block()
		return
	super(damage, from_position)


func _block() -> void:
	_block_left = _sentinel.block_pose_time
	_flash_hit_only()
	Events.arrow_blocked.emit(global_position)
	# A blocked shot still gives the shooter away.
	if target == null:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null:
			_acquire_target(player)


## Turns `facing` toward `direction` by at most the data's turn rate (slows turn it slower too).
func _turn_toward(direction: Vector2, delta: float) -> void:
	if direction.is_zero_approx():
		return
	var step := deg_to_rad(turn_rate()) * _speed_scale() * delta
	facing = facing.rotated(clampf(facing.angle_to(direction), -step, step)).normalized()


## The block pose (`special`, played over `block_pose_time`) shows over walking and idling.
func _update_animation() -> void:
	if _sprite == null or _block_left <= 0.0 or state in [State.ATTACK, State.DEAD]:
		super()
		return
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	if _sprite.animation != &"special" and _sprite.sprite_frames.has_animation(&"special"):
		_sprite.play(&"special")
		_sprite.speed_scale = _animation_length(&"special") / maxf(_sentinel.block_pose_time, 0.05)
		_anim_held = 0.0
