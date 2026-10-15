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
## How visible the player is to enemies (1 = normal). The Sombra skill lowers it for a while.
var visibility := 1.0

var _state_time_left := 0.0
var _dash_cooldown_left := 0.0
var _attack_cooldown_left := 0.0
var _invulnerable_left := 0.0
var _stealth_left := 0.0
## True while a dialogue is open: the player cannot move, attack or cast.
var _locked := false
var _interact_block_left := 0.0
var _nearby: Interactable = null
var _move_dir := Vector2.ZERO
var _action_dir := Vector2.ZERO

@onready var health: HealthComponent = $HealthComponent
@onready var skills: SkillManager = $SkillManager
@onready var _hurtbox: Hurtbox = $Hurtbox
## Nico's art (the old colored square `Placeholder` stays hidden as a fallback).
@onready var _body: AnimatedSprite2D = $Sprite
@onready var _attack_pivot: Node2D = $AttackPivot
@onready var _hitbox: Hitbox = $AttackPivot/Hitbox
@onready var _slash: ColorRect = $AttackPivot/Slash
@onready var _sword_pivot: Node2D = $SwordPivot
@onready var _camera: Camera2D = $Camera2D
@onready var _interact_area: Area2D = $InteractArea


func _ready() -> void:
	add_to_group("player")
	_hurtbox.invulnerability_check = is_invulnerable
	_hurtbox.hit.connect(_on_hurtbox_hit)
	_hitbox.hit_landed.connect(_on_hitbox_hit_landed)
	health.changed.connect(func(current: int, maximum: int) -> void:
		Events.player_health_changed.emit(current, maximum))
	health.died.connect(die)
	Events.dialogue_started.connect(_on_dialogue_started)
	Events.dialogue_finished.connect(_on_dialogue_finished)
	_set_attack_active(false)
	Events.player_health_changed.emit(health.current, health.max_health)


func _physics_process(delta: float) -> void:
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	if _stealth_left > 0.0:
		_stealth_left -= delta
		if _stealth_left <= 0.0:
			end_stealth()

	_interact_block_left = maxf(_interact_block_left - delta, 0.0)
	_move_dir = Vector2.ZERO if _locked else Input.get_vector("move_left", "move_right", "move_up", "move_down")
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
	_update_interaction()
	_update_visuals()


## True while the player cannot be damaged (dash i-frames, after a hit, or dead).
func is_invulnerable() -> bool:
	return state == State.DASH or state == State.DEAD or _invulnerable_left > 0.0


func is_dead() -> bool:
	return state == State.DEAD


## Skills can only be cast while moving freely, not while attacking, dashing, hurt or dead.
func can_cast() -> bool:
	return not _locked and (state == State.IDLE or state == State.MOVE)


## True when the player can use an object (not busy, not in a dialogue).
func can_interact() -> bool:
	return not _locked and _interact_block_left == 0.0 and (state == State.IDLE or state == State.MOVE)


func is_stealthed() -> bool:
	return _stealth_left > 0.0


## Makes enemies notice the player only from `new_visibility` of their normal range.
func start_stealth(duration: float, new_visibility: float) -> void:
	var was_stealthed := is_stealthed()
	_stealth_left = duration
	visibility = new_visibility
	if not was_stealthed:
		Events.player_stealth_changed.emit(true)


func end_stealth() -> void:
	if _stealth_left <= 0.0 and visibility == 1.0:
		return
	_stealth_left = 0.0
	visibility = 1.0
	Events.player_stealth_changed.emit(false)


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


## Finds the nearest usable object in reach, tells the HUD, and uses it when E is pressed.
func _update_interaction() -> void:
	var best: Interactable = null
	var best_distance := INF
	if can_interact():
		for area in _interact_area.get_overlapping_areas():
			var item := area as Interactable
			if item == null or not item.enabled:
				continue
			var distance := global_position.distance_to(item.global_position)
			if distance < best_distance:
				best = item
				best_distance = distance
	if best != _nearby:
		_nearby = best
		Events.interaction_prompt_changed.emit(best.prompt if best != null else "")
	if best != null and Input.is_action_just_pressed("interact"):
		best.interact(self)


func _on_dialogue_started(_dialogue_id: StringName) -> void:
	_locked = true
	velocity = Vector2.ZERO


func _on_dialogue_finished(_dialogue_id: StringName, _state: StringName) -> void:
	_locked = false
	# The key that closed the dialogue must not open the next interaction in the same instant.
	_interact_block_left = 0.3


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

	if _locked:
		return
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
	end_stealth()
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
	_sword_pivot.visible = active
	if active:
		_sword_pivot.position.x = 5.0 if _action_dir.x >= 0.0 else -5.0
		_update_sword()


## The sword sweeps an arc around the attack direction over the attack's duration.
func _update_sword() -> void:
	var progress := 1.0 - _state_time_left / attack_time
	var swing := lerpf(-1.3, 1.3, 1.0 - pow(1.0 - clampf(progress, 0.0, 1.0), 2.0))
	_sword_pivot.rotation = _action_dir.angle() + swing * (1.0 if _action_dir.x >= 0.0 else -1.0)


func _update_visuals() -> void:
	if state == State.ATTACK:
		_update_sword()
	# The art faces right: flip it when moving left. Walks while moving, rests otherwise.
	if absf(facing.x) > 0.1:
		_body.flip_h = facing.x < 0.0
	var wanted: StringName = &"walk" if velocity.length() > 5.0 and state != State.DEAD else &"idle"
	if state == State.ATTACK:
		wanted = &"attack"
	if _body.animation != wanted:
		_body.play(wanted)
	match state:
		State.DASH:
			_body.modulate = Color(1, 1, 1, 0.5)
		State.HURT:
			_body.modulate = Color(1, 0.4, 0.4, 1)
		State.DEAD:
			_body.modulate = Color(0.3, 0.3, 0.3, 1)
		_:
			var blink := _invulnerable_left > 0.0 and int(_invulnerable_left * 20.0) % 2 == 0
			if blink:
				_body.modulate = Color(1, 1, 1, 0.4)
			elif is_stealthed():
				_body.modulate = Color(0.7, 0.5, 1.0, 0.5)
			else:
				_body.modulate = Color.WHITE
