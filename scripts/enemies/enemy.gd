class_name Enemy
extends CharacterBody2D
## Base enemy: idle/patrol, sight-based detection, chase, telegraphed melee attack, hurt and death.
## Stats come from an EnemyData resource. Specific enemies inherit `enemy.tscn`, assign their own
## data and override the `_process_*` / `_start_attack` hooks only where their behaviour differs.
##
## The adaptive AI "director" tunes an enemy before it enters the tree through the
## `*_multiplier` properties, never by editing this script.

signal player_detected(player: Node2D)
signal died

enum State { IDLE, PATROL, CHASE, ATTACK, HURT, DEAD }
enum AttackPhase { WINDUP, STRIKE, RECOVER }

const WORLD_LAYER := 1
const VISION_CHECK_INTERVAL := 0.1
const ARRIVE_DISTANCE := 4.0
## Animation hysteresis: an idle/walk/run animation shows at least this long, and chasing switches
## to run above RUN_ENTER_SPEED but only back to idle below RUN_EXIT_SPEED (px/s).
const ANIM_MIN_HOLD := 0.15
const RUN_ENTER_SPEED := 8.0
const RUN_EXIT_SPEED := 2.0
## Limits of the walk/run playback speed relative to the speed the cycle was drawn for.
const ANIM_SPEED_MIN := 0.5
const ANIM_SPEED_MAX := 2.0

@export var data: EnemyData
## Shows the current state above the enemy (debugging aid).
@export var debug_state := false

@export_group("Director modifiers")
@export var health_multiplier := 1.0
@export var speed_multiplier := 1.0
@export var damage_multiplier := 1.0
@export var vision_multiplier := 1.0
@export var patrol_multiplier := 1.0

var state: State = State.IDLE
var target: Node2D = null
var facing := Vector2.DOWN

var _home := Vector2.ZERO
var _patrol_point := Vector2.ZERO
var _wait_left := 0.0
var _vision_timer := 0.0
var _attack_phase := AttackPhase.WINDUP
var _attack_time_left := 0.0
var _attack_cooldown_left := 0.0
var _hurt_time_left := 0.0
var _root_left := 0.0
var _slow_left := 0.0
var _slow_factor := 1.0

@onready var health: HealthComponent = $HealthComponent
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _hitbox: Hitbox = $AttackPivot/Hitbox
@onready var _pivot: Node2D = $AttackPivot
@onready var _telegraph: ColorRect = $AttackPivot/Telegraph
@onready var _body: ColorRect = $Body
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _label: Label = $StateLabel

var _sprite: AnimatedSprite2D
## Seconds the current locomotion animation (idle, walk, run) has been showing.
var _anim_held := 0.0
var _status_tinted := false


func _ready() -> void:
	add_to_group("enemies")
	if data == null:
		push_error("Enemy '%s' has no EnemyData assigned." % name)
		data = EnemyData.new()
	_home = global_position
	_vision_timer = randf() * VISION_CHECK_INTERVAL
	_body.color = data.placeholder_color
	_build_sprite()
	health.set_max_health(ceili(data.max_health * health_multiplier))
	health.died.connect(_on_died)
	_hurtbox.hit.connect(_on_hurtbox_hit)
	_label.visible = debug_state
	_telegraph.hide()
	_enter_idle()


func _physics_process(delta: float) -> void:
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	_root_left = maxf(_root_left - delta, 0.0)
	_slow_left = maxf(_slow_left - delta, 0.0)
	_update_awareness(delta)

	match state:
		State.IDLE:
			_process_idle(delta)
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)
		State.HURT:
			_process_hurt(delta)
		State.DEAD:
			velocity = Vector2.ZERO

	# Rooted enemies cannot walk but can still attack and be pushed.
	if _root_left > 0.0 and state in [State.IDLE, State.PATROL, State.CHASE]:
		velocity = Vector2.ZERO
	move_and_slide()
	_update_status_tint_target()
	_update_animation()
	if debug_state:
		_label.text = State.keys()[state]


## True if the enemy currently sees `other`: in range, inside the field of view
## and not blocked by the world.
func can_see(other: Node2D) -> bool:
	var to_other := other.global_position - global_position
	if to_other.length() > data.detection_range * vision_multiplier * _visibility_of(other):
		return false
	if data.vision_angle < 360.0:
		if absf(facing.angle_to(to_other)) > deg_to_rad(data.vision_angle) / 2.0:
			return false
	var query := PhysicsRayQueryParameters2D.create(
			global_position, other.global_position, 1 << (WORLD_LAYER - 1))
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func is_dead() -> bool:
	return state == State.DEAD


## Status effects used by player skills.
func apply_root(duration: float) -> void:
	if state != State.DEAD:
		_root_left = maxf(_root_left, duration)


## `factor` multiplies movement speed (0.4 = 60% slower) for `duration` seconds.
func apply_slow(factor: float, duration: float) -> void:
	if state == State.DEAD:
		return
	_slow_factor = factor if _slow_left <= 0.0 else minf(_slow_factor, factor)
	_slow_left = maxf(_slow_left, duration)


## Pushes the enemy and interrupts what it was doing (like a hit without damage).
func apply_knockback(push: Vector2) -> void:
	if state == State.DEAD:
		return
	_hitbox.deactivate()
	_telegraph.hide()
	state = State.HURT
	_hurt_time_left = data.hurt_time
	velocity = push * (1.0 - data.knockback_resistance)


func is_rooted() -> bool:
	return _root_left > 0.0


func is_slowed() -> bool:
	return _slow_left > 0.0


# --- Overridable behaviour ---------------------------------------------------

func _process_idle(delta: float) -> void:
	velocity = Vector2.ZERO
	if data.patrol_radius * patrol_multiplier <= 0.0:
		return
	_wait_left -= delta
	if _wait_left <= 0.0:
		_choose_patrol_point()
		state = State.PATROL


func _process_patrol(_delta: float) -> void:
	var to_point := _patrol_point - global_position
	if to_point.length() <= ARRIVE_DISTANCE:
		_enter_idle()
		return
	facing = to_point.normalized()
	velocity = facing * data.move_speed * _speed_scale()


func _process_chase(_delta: float) -> void:
	if not _target_is_valid():
		return
	var to_target := target.global_position - global_position
	facing = to_target.normalized()
	if to_target.length() <= data.attack_range and _attack_cooldown_left == 0.0:
		_start_attack()
		return
	# Keep a little distance once in range instead of pushing into the player.
	if to_target.length() > data.attack_range * 0.8:
		velocity = facing * data.chase_speed * _speed_scale()
	else:
		velocity = Vector2.ZERO


## Default melee attack: telegraph, strike with the hitbox, then recover.
## Override together with `_process_attack` for other attack patterns.
func _start_attack() -> void:
	state = State.ATTACK
	velocity = Vector2.ZERO
	_pivot.rotation = facing.angle()
	_attack_phase = AttackPhase.WINDUP
	_attack_time_left = data.attack_windup
	_telegraph.show()


func _process_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	_attack_time_left -= delta
	if _attack_time_left > 0.0:
		return
	match _attack_phase:
		AttackPhase.WINDUP:
			_telegraph.hide()
			_hitbox.damage = ceili(data.attack_damage * damage_multiplier)
			_hitbox.activate()
			_attack_phase = AttackPhase.STRIKE
			_attack_time_left = data.attack_time
		AttackPhase.STRIKE:
			_hitbox.deactivate()
			_attack_phase = AttackPhase.RECOVER
			_attack_time_left = data.attack_cooldown * 0.5
		AttackPhase.RECOVER:
			_attack_cooldown_left = data.attack_cooldown * 0.5
			_enter_chase_or_idle()


func _process_hurt(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, data.knockback_speed * 4.0 * delta)
	_hurt_time_left -= delta
	if _hurt_time_left <= 0.0:
		_enter_chase_or_idle()


# --- Internals -----------------------------------------------------------------

func _update_awareness(delta: float) -> void:
	if state == State.DEAD:
		return
	if target != null:
		if not _target_is_valid():
			return
		var lose := data.lose_range * vision_multiplier * _visibility_of(target)
		if global_position.distance_to(target.global_position) > lose:
			_lose_target()
		return
	_vision_timer -= delta
	if _vision_timer > 0.0:
		return
	_vision_timer = VISION_CHECK_INTERVAL
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and not _is_dead_node(player) and can_see(player):
		_acquire_target(player)


func _acquire_target(player: Node2D) -> void:
	target = player
	player_detected.emit(player)
	Events.enemy_detected_player.emit(self)
	if state in [State.IDLE, State.PATROL]:
		state = State.CHASE


func _lose_target() -> void:
	target = null
	if state in [State.CHASE, State.ATTACK]:
		_hitbox.deactivate()
		_telegraph.hide()
		_enter_idle()


func _target_is_valid() -> bool:
	if target == null or not is_instance_valid(target) or _is_dead_node(target):
		target = null
		if state in [State.CHASE, State.ATTACK]:
			_hitbox.deactivate()
			_telegraph.hide()
			_enter_idle()
		return false
	return true


func _speed_scale() -> float:
	return speed_multiplier * (_slow_factor if _slow_left > 0.0 else 1.0)


## How visible a node is (1 = normal). The player lowers it with the Sombra skill.
func _visibility_of(node: Node) -> float:
	var value = node.get("visibility")
	return float(value) if value != null else 1.0


func _update_status_tint_target() -> void:
	if state == State.DEAD:
		return
	if _root_left > 0.0:
		_tint_target().modulate = Color(0.6, 1.0, 0.6)
		_status_tinted = true
	elif _slow_left > 0.0:
		_tint_target().modulate = Color(0.6, 0.75, 1.0)
		_status_tinted = true
	elif _status_tinted or _sprite == null:
		# A sprite is only reset after a status tint, so the hit flash is not cut short.
		_tint_target().modulate = Color.WHITE
		_status_tinted = false


func _is_dead_node(node: Node) -> bool:
	return node.has_method("is_dead") and node.is_dead()


func _enter_idle() -> void:
	state = State.IDLE
	velocity = Vector2.ZERO
	_wait_left = data.patrol_wait


func _enter_chase_or_idle() -> void:
	if _target_is_valid():
		state = State.CHASE
	else:
		_enter_idle()


func _choose_patrol_point() -> void:
	var angle := randf() * TAU
	_patrol_point = _home + Vector2.from_angle(angle) * randf_range(0.3, 1.0) * data.patrol_radius * patrol_multiplier


func _on_hurtbox_hit(damage: int, from_position: Vector2) -> void:
	if state == State.DEAD:
		return
	Events.enemy_damaged.emit(self, damage)
	health.take_damage(damage, from_position)
	if health.is_dead():
		return
	# Being hit makes the enemy aware of the player even without seeing them.
	if target == null:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null:
			_acquire_target(player)
	_hitbox.deactivate()
	_telegraph.hide()
	state = State.HURT
	_hurt_time_left = data.hurt_time
	velocity = (global_position - from_position).normalized() \
			* data.knockback_speed * (1.0 - data.knockback_resistance)
	if _sprite != null:
		_sprite.modulate = Color(2.5, 2.5, 2.5)
		create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.12)
	else:
		_body.color = Color.WHITE
		create_tween().tween_property(_body, "color", data.placeholder_color, 0.12)


func _on_died() -> void:
	state = State.DEAD
	_hitbox.deactivate()
	_telegraph.hide()
	_hurtbox.set_deferred("monitorable", false)
	_collision.set_deferred("disabled", true)
	Events.enemy_killed.emit(self)
	died.emit()
	var fade_delay := 0.0
	if _sprite != null and _sprite.sprite_frames.has_animation(&"death"):
		_sprite.play(&"death")
		fade_delay = _animation_length(&"death")
	var tween := create_tween()
	tween.tween_interval(fade_delay)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)


# --- Sprite (optional art from EnemyData.sprite_frames) ----------------------------------------

func _build_sprite() -> void:
	if data.sprite_frames == null:
		return
	_body.visible = false
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = data.sprite_frames
	_sprite.scale = Vector2.ONE * data.sprite_scale
	_sprite.position = data.sprite_offset
	add_child(_sprite)
	move_child(_sprite, 1)
	_sprite.play(&"idle")


## What is tinted by statuses: the sprite if there is one, else the colored square.
func _tint_target() -> CanvasItem:
	return _sprite if _sprite != null else _body


func _animation_length(anim: StringName) -> float:
	var frames := _sprite.sprite_frames
	return frames.get_frame_count(anim) / frames.get_animation_speed(anim)


func _update_animation() -> void:
	if _sprite == null or state == State.DEAD:
		return
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	_anim_held += get_physics_process_delta_time()
	var wanted: StringName = &"idle"
	match state:
		State.PATROL:
			wanted = &"walk"
		State.CHASE:
			# Two thresholds: once running it takes a real stop to go back to idle.
			var running := _sprite.animation == &"run"
			var speed := velocity.length()
			wanted = &"run" if speed > (RUN_EXIT_SPEED if running else RUN_ENTER_SPEED) else &"idle"
		State.ATTACK:
			wanted = &"attack"
		State.HURT:
			wanted = &"hurt"
	if not _sprite.sprite_frames.has_animation(wanted):
		wanted = &"idle"
	# Idle/walk/run hold a moment before changing (each play() restarts the cycle); attack and hurt
	# show at once because they warn the player.
	var locomotion := [&"idle", &"walk", &"run"]
	if wanted in locomotion and _sprite.animation in locomotion and _anim_held < ANIM_MIN_HOLD:
		wanted = _sprite.animation
	if _sprite.animation != wanted:
		_sprite.play(wanted)
		_anim_held = 0.0
		if wanted == &"attack":
			# One swing spans the whole windup + strike.
			var span := data.attack_windup + data.attack_time
			_sprite.speed_scale = _animation_length(wanted) / maxf(span, 0.05)
	if wanted in [&"walk", &"run"]:
		# The cycle follows the real speed (director multipliers, slows, boss boosts) so the feet
		# slide less; walk is drawn for move_speed and run for chase_speed.
		var reference := data.move_speed if wanted == &"walk" else data.chase_speed
		_sprite.speed_scale = clampf(velocity.length() / maxf(reference, 1.0), ANIM_SPEED_MIN, ANIM_SPEED_MAX)
	elif wanted != &"attack":
		_sprite.speed_scale = 1.0
