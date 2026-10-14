extends CharacterBody2D
## Nico: 8-direction movement, dash with i-frames and a sword attack.
## Behaviour is a small state machine (see State). Health and damage arrive in the next task;
## `hurt()` and `die()` already exist so other systems can drive those states.

signal dashed(direction: Vector2)
signal attacked(direction: Vector2)
signal attack_hit(target: Node)

enum State { IDLE, MOVE, DASH, ATTACK, HURT, DEAD }

@export_group("Movement")
@export var speed := 110.0

@export_group("Dash")
@export var dash_speed := 300.0
@export var dash_time := 0.15
@export var dash_cooldown := 0.6

@export_group("Attack")
@export var attack_damage := 1
@export var attack_time := 0.2
@export var attack_cooldown := 0.35
@export_range(0.0, 1.0) var attack_move_factor := 0.3

@export_group("Hurt")
@export var hurt_time := 0.25
@export var knockback_speed := 140.0

var state: State = State.IDLE
var facing := Vector2.DOWN

var _state_time_left := 0.0
var _dash_cooldown_left := 0.0
var _attack_cooldown_left := 0.0
var _move_dir := Vector2.ZERO
var _action_dir := Vector2.ZERO
var _hit_this_swing: Array[Node] = []

@onready var _body: ColorRect = $Placeholder
@onready var _attack_pivot: Node2D = $AttackPivot
@onready var _hitbox: Area2D = $AttackPivot/Hitbox
@onready var _slash: ColorRect = $AttackPivot/Slash
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	_set_attack_active(false)


func _physics_process(delta: float) -> void:
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)

	_move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _move_dir != Vector2.ZERO and state in [State.IDLE, State.MOVE]:
		facing = _move_dir.normalized()

	match state:
		State.IDLE, State.MOVE:
			_process_free(delta)
		State.DASH:
			_process_dash(delta)
		State.ATTACK:
			_process_attack(delta)
		State.HURT:
			_process_hurt(delta)
		State.DEAD:
			velocity = Vector2.ZERO

	move_and_slide()
	_update_visuals()


## True while the player cannot be damaged (dash i-frames).
func is_invulnerable() -> bool:
	return state == State.DASH or state == State.DEAD


## Limits the camera to a rectangle in world coordinates (usually the level bounds).
func set_camera_limits(bounds: Rect2) -> void:
	_camera.limit_left = int(bounds.position.x)
	_camera.limit_top = int(bounds.position.y)
	_camera.limit_right = int(bounds.end.x)
	_camera.limit_bottom = int(bounds.end.y)


## Puts the player in the hurt state and pushes it away from `from_position`.
func hurt(from_position: Vector2) -> void:
	if is_invulnerable() or state == State.HURT:
		return
	_set_attack_active(false)
	_action_dir = (global_position - from_position).normalized()
	_enter_state(State.HURT, hurt_time)


func die() -> void:
	_set_attack_active(false)
	_enter_state(State.DEAD, 0.0)


func _process_free(_delta: float) -> void:
	velocity = _move_dir * speed
	state = State.MOVE if _move_dir != Vector2.ZERO else State.IDLE

	if Input.is_action_just_pressed("attack") and _attack_cooldown_left == 0.0:
		_start_attack()
	elif Input.is_action_just_pressed("dash") and _dash_cooldown_left == 0.0:
		_start_dash()


func _start_dash() -> void:
	_action_dir = facing
	_dash_cooldown_left = dash_cooldown
	_enter_state(State.DASH, dash_time)
	dashed.emit(_action_dir)


func _process_dash(delta: float) -> void:
	velocity = _action_dir * dash_speed
	_state_time_left -= delta
	if _state_time_left <= 0.0:
		_enter_state(State.IDLE, 0.0)


func _start_attack() -> void:
	_action_dir = facing
	_attack_cooldown_left = attack_cooldown
	_hit_this_swing.clear()
	_attack_pivot.rotation = _action_dir.angle()
	_set_attack_active(true)
	_enter_state(State.ATTACK, attack_time)
	attacked.emit(_action_dir)


func _process_attack(delta: float) -> void:
	velocity = _move_dir * speed * attack_move_factor
	_check_attack_hits()
	_state_time_left -= delta
	if _state_time_left <= 0.0:
		_set_attack_active(false)
		_enter_state(State.IDLE, 0.0)


func _check_attack_hits() -> void:
	for target in _hitbox.get_overlapping_bodies():
		if target in _hit_this_swing:
			continue
		_hit_this_swing.append(target)
		if target.has_method("take_hit"):
			target.take_hit(attack_damage, global_position)
		attack_hit.emit(target)


func _process_hurt(delta: float) -> void:
	velocity = _action_dir * knockback_speed * (_state_time_left / hurt_time)
	_state_time_left -= delta
	if _state_time_left <= 0.0:
		_enter_state(State.IDLE, 0.0)


func _enter_state(new_state: State, duration: float) -> void:
	state = new_state
	_state_time_left = duration


func _set_attack_active(active: bool) -> void:
	_hitbox.monitoring = active
	_slash.visible = active


func _update_visuals() -> void:
	match state:
		State.DASH:
			_body.modulate = Color(1, 1, 1, 0.5)
		State.HURT:
			_body.modulate = Color(1, 0.4, 0.4, 1)
		State.DEAD:
			_body.modulate = Color(0.3, 0.3, 0.3, 1)
		_:
			_body.modulate = Color.WHITE
