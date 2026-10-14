extends CharacterBody2D
## Nico: 8-direction movement, dash with i-frames, sword attack, health and death.
## Behaviour is a small state machine (see State). Damage arrives through the Hurtbox;
## combat events are published on the Events bus for the adaptive AI.

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
## Invulnerability after taking a hit (includes the hurt state).
@export var hit_invulnerability_time := 0.8

var state: State = State.IDLE
var facing := Vector2.DOWN

var _state_time_left := 0.0
var _dash_cooldown_left := 0.0
var _attack_cooldown_left := 0.0
var _invulnerable_left := 0.0
var _move_dir := Vector2.ZERO
var _action_dir := Vector2.ZERO

@onready var health: HealthComponent = $HealthComponent
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _body: ColorRect = $Placeholder
@onready var _attack_pivot: Node2D = $AttackPivot
@onready var _hitbox: Hitbox = $AttackPivot/Hitbox
@onready var _slash: ColorRect = $AttackPivot/Slash
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	_hurtbox.invulnerability_check = is_invulnerable
	_hurtbox.hit.connect(_on_hurtbox_hit)
	_hitbox.hit_landed.connect(_on_hitbox_hit_landed)
	health.changed.connect(func(current: int, maximum: int) -> void:
		Events.player_health_changed.emit(current, maximum))
	health.died.connect(die)
	_set_attack_active(false)
	Events.player_health_changed.emit(health.current, health.max_health)


func _physics_process(delta: float) -> void:
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)

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


## True while the player cannot be damaged (dash i-frames, after a hit, or dead).
func is_invulnerable() -> bool:
	return state == State.DASH or state == State.DEAD or _invulnerable_left > 0.0


## Limits the camera to a rectangle in world coordinates (usually the level bounds).
func set_camera_limits(bounds: Rect2) -> void:
	_camera.limit_left = int(bounds.position.x)
	_camera.limit_top = int(bounds.position.y)
	_camera.limit_right = int(bounds.end.x)
	_camera.limit_bottom = int(bounds.end.y)


## Puts the player in the hurt state and pushes it away from `from_position`.
func hurt(from_position: Vector2) -> void:
	if is_invulnerable():
		return
	_set_attack_active(false)
	_action_dir = (global_position - from_position).normalized()
	_invulnerable_left = hit_invulnerability_time
	_enter_state(State.HURT, hurt_time)


func die() -> void:
	if state == State.DEAD:
		return
	_set_attack_active(false)
	_enter_state(State.DEAD, 0.0)
	Events.player_died.emit()


func _on_hurtbox_hit(damage: int, from_position: Vector2) -> void:
	health.take_damage(damage, from_position)
	Events.player_damaged.emit(damage, from_position)
	if not health.is_dead():
		hurt(from_position)


func _on_hitbox_hit_landed(hurtbox: Hurtbox) -> void:
	var target: Node = hurtbox.owner
	attack_hit.emit(target)
	Events.player_hit_enemy.emit(target, attack_damage)


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
	Events.player_dashed.emit(_action_dir)


func _process_dash(delta: float) -> void:
	velocity = _action_dir * dash_speed
	_state_time_left -= delta
	if _state_time_left <= 0.0:
		_enter_state(State.IDLE, 0.0)


func _start_attack() -> void:
	_action_dir = facing
	_attack_cooldown_left = attack_cooldown
	_attack_pivot.rotation = _action_dir.angle()
	_hitbox.damage = attack_damage
	_set_attack_active(true)
	_enter_state(State.ATTACK, attack_time)
	attacked.emit(_action_dir)
	Events.player_attacked.emit(_action_dir)


func _process_attack(delta: float) -> void:
	velocity = _move_dir * speed * attack_move_factor
	_state_time_left -= delta
	if _state_time_left <= 0.0:
		_set_attack_active(false)
		_enter_state(State.IDLE, 0.0)


func _process_hurt(delta: float) -> void:
	velocity = _action_dir * knockback_speed * (_state_time_left / hurt_time)
	_state_time_left -= delta
	if _state_time_left <= 0.0:
		_enter_state(State.IDLE, 0.0)


func _enter_state(new_state: State, duration: float) -> void:
	state = new_state
	_state_time_left = duration


func _set_attack_active(active: bool) -> void:
	if active:
		_hitbox.activate()
	else:
		_hitbox.deactivate()
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
			var blink := _invulnerable_left > 0.0 and int(_invulnerable_left * 20.0) % 2 == 0
			_body.modulate = Color(1, 1, 1, 0.4) if blink else Color.WHITE
