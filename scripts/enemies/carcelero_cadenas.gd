class_name ChainJailer
extends Enemy
## Carcelero de cadenas: when Nico keeps his distance it aims (a line shows where), throws a chain
## that flies out up to its range and, if its tip catches him, drags him close and follows up with
## its normal melee swing. A wall stops the chain; a dodge (i-frames) lets it pass through and also
## breaks the drag. Everything tunable lives in its ChainJailerData.

enum ChainStep { NONE, AIM, OUT, BACK, RECOVER }

var _jailer: ChainJailerData
var _chain_step := ChainStep.NONE
var _step_left := 0.0
var _chain_cooldown_left := 0.0
## Direction of the throw and how far the tip is from the hand along it.
var _aim := Vector2.RIGHT
var _tip := 0.0
## Where the chain stops this throw: its range, or a wall in the way.
var _reach := 0.0
var _victim: Node2D = null
var _chain_hitbox: Hitbox
var _chain_line: Line2D
var _aim_line: Line2D


func _ready() -> void:
	super()
	_jailer = data as ChainJailerData
	if _jailer == null:
		push_error("ChainJailer '%s' needs a ChainJailerData." % name)
		_jailer = ChainJailerData.new()
	_build_chain()


func _physics_process(delta: float) -> void:
	_chain_cooldown_left = maxf(_chain_cooldown_left - delta, 0.0)
	super(delta)
	# A hit, a push, a lost target or death ends the attack: the chain goes with it.
	if _chain_step != ChainStep.NONE and state != State.ATTACK:
		_drop_chain()


## True while the chain is out or being aimed (tests and the animation read it).
func is_throwing() -> bool:
	return _chain_step != ChainStep.NONE


func _process_chase(delta: float) -> void:
	if _target_is_valid() and _can_throw():
		_start_throw()
		return
	super(delta)


func _process_attack(delta: float) -> void:
	if _chain_step == ChainStep.NONE:
		super(delta)
		return
	velocity = Vector2.ZERO
	_step_left -= delta
	match _chain_step:
		ChainStep.AIM:
			_process_aim()
		ChainStep.OUT:
			_process_out(delta)
		ChainStep.BACK:
			_process_back(delta)
		ChainStep.RECOVER:
			if _step_left <= 0.0:
				_end_throw()
	_update_lines()


func _can_throw() -> bool:
	var distance := global_position.distance_to(target.global_position)
	return _chain_cooldown_left == 0.0 and _attack_cooldown_left == 0.0 \
			and distance > _jailer.chain_min_range and distance <= _jailer.chain_range and can_see(target)


func _start_throw() -> void:
	state = State.ATTACK
	velocity = Vector2.ZERO
	_chain_step = ChainStep.AIM
	_step_left = _jailer.chain_windup
	_victim = null
	_aim = (target.global_position - global_position).normalized()
	facing = _aim
	_aim_line.show()
	_update_lines()


func _process_aim() -> void:
	if _step_left > _jailer.aim_lock_time:
		if not _target_is_valid():
			return
		_aim = (target.global_position - global_position).normalized()
		facing = _aim
	if _step_left <= 0.0:
		_throw()


func _throw() -> void:
	_chain_step = ChainStep.OUT
	_aim_line.hide()
	_chain_line.show()
	_tip = 0.0
	_reach = _clear_reach()
	_chain_hitbox.damage = ceili(_jailer.chain_damage * damage_multiplier)
	_chain_hitbox.activate()
	Events.enemy_attacked.emit(self, &"shot")


func _process_out(delta: float) -> void:
	_tip = minf(_tip + _jailer.chain_speed * delta, _reach)
	if _tip >= _reach:
		_start_retract()


func _on_chain_hit(hurtbox: Hurtbox) -> void:
	if _chain_step != ChainStep.OUT:
		return
	var victim := (hurtbox.owner if hurtbox.owner != null else hurtbox.get_parent()) as Node2D
	if victim != null and victim.has_method("apply_pull"):
		_victim = victim
		victim.apply_pull(global_position, _jailer.pull_speed, _jailer.pull_time)
	_start_retract()


func _start_retract() -> void:
	_chain_step = ChainStep.BACK
	_chain_hitbox.deactivate()


## While Nico is being dragged the chain stays taut on him; once he is close (or broke free) it
## winds back in.
func _process_back(delta: float) -> void:
	if _dragging():
		var to_victim := _victim.global_position - _hand()
		_aim = to_victim.normalized()
		_tip = to_victim.length()
		facing = _aim
	else:
		_tip -= _jailer.retract_speed * delta
	if _tip <= 0.0 and not _dragging():
		_chain_step = ChainStep.RECOVER
		_step_left = _jailer.chain_recover
		_chain_line.hide()


func _end_throw() -> void:
	var caught := _victim != null
	_chain_step = ChainStep.NONE
	_chain_cooldown_left = _jailer.chain_cooldown
	# A catch is followed at once by the melee swing; a miss rests like after a swing.
	_attack_cooldown_left = 0.0 if caught else data.attack_cooldown * 0.5
	_victim = null
	_enter_chase_or_idle()


func _drop_chain() -> void:
	if _dragging():
		# Releases him where he stands: a pull of no time ends the drag.
		_victim.apply_pull(_victim.global_position, 0.0, 0.0)
	_chain_step = ChainStep.NONE
	_chain_cooldown_left = _jailer.chain_cooldown
	_victim = null
	_chain_hitbox.deactivate()
	_chain_line.hide()
	_aim_line.hide()


func _dragging() -> bool:
	return _victim != null and is_instance_valid(_victim) and _victim.has_method("is_pulled") \
			and _victim.is_pulled()


## How far the chain can fly along the aim before a wall stops it.
func _clear_reach() -> float:
	var from := _hand()
	var query := PhysicsRayQueryParameters2D.create(
			from, from + _aim * _jailer.chain_range, 1 << (WORLD_LAYER - 1))
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return from.distance_to(hit.position) if not hit.is_empty() else _jailer.chain_range


## Where the chain leaves the body, in world coordinates.
func _hand() -> Vector2:
	return global_position + _hand_local()


func _hand_local() -> Vector2:
	var offset := _jailer.hand_offset
	if facing.x < 0.0:
		offset.x = -offset.x
	return offset


func _build_chain() -> void:
	_aim_line = Line2D.new()
	_aim_line.name = "ChainAim"
	_aim_line.width = _jailer.aim_width
	_aim_line.default_color = _jailer.aim_color
	_aim_line.hide()
	add_child(_aim_line)
	_chain_line = Line2D.new()
	_chain_line.name = "Chain"
	_chain_line.width = _jailer.chain_width
	_chain_line.default_color = _jailer.chain_color
	_chain_line.hide()
	add_child(_chain_line)
	_chain_hitbox = Hitbox.new()
	_chain_hitbox.name = "ChainHitbox"
	_chain_hitbox.collision_layer = 1 << 4
	_chain_hitbox.collision_mask = 1 << 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _jailer.tip_radius
	shape.shape = circle
	_chain_hitbox.add_child(shape)
	add_child(_chain_hitbox)
	# The hit pushes Nico away from the jailer itself, not from the tip.
	_chain_hitbox.owner = self
	_chain_hitbox.hit_landed.connect(_on_chain_hit)


func _update_lines() -> void:
	var hand := _hand_local()
	if _aim_line.visible:
		_aim_line.points = PackedVector2Array([hand, hand + _aim * _clear_reach()])
	var tip := hand + _aim * maxf(_tip, 0.0)
	_chain_line.points = PackedVector2Array([hand, tip])
	_chain_hitbox.position = tip


## The throw plays `special` (aim and toss over the windup and the flight); the swing keeps `attack`.
func _update_animation() -> void:
	if _sprite == null or state != State.ATTACK or _chain_step == ChainStep.NONE:
		super()
		return
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	if _sprite.animation != &"special":
		_sprite.play(&"special")
		_anim_held = 0.0
		var span := _jailer.chain_windup + _jailer.chain_range / maxf(_jailer.chain_speed, 1.0)
		_sprite.speed_scale = _animation_length(&"special") / maxf(span, 0.05)
