class_name Boss
extends Enemy
## A boss: an Enemy with attack patterns (slam and roots, each warned by a circle), a second phase,
## territorial behaviour and super armor (hits do not interrupt it; it cannot be pushed or rooted).
## Everything tunable lives in its BossData. Bosses are not touched by the AI director.

enum Pattern { SLAM, ROOTS }
enum Step { WINDUP, STRIKE, RECOVER }

const WARNING_COLOR := Color(1.0, 0.45, 0.2)
const ERUPTION_COLOR := Color(0.35, 0.8, 0.3)

var phase := 1
var pattern: Pattern = Pattern.SLAM
var step: Step = Step.WINDUP

var _boss: BossData
var _step_left := 0.0
var _roots_spots: Array[Vector2] = []
## The art of each eruption of the current roots attack (BossRoots), if the data has one.
var _roots_art: Array[Node2D] = []
var _roots_sprouted := false
var _engaged := false
var _last_pattern: Pattern = Pattern.ROOTS
var _visual: Node2D


func _ready() -> void:
	super()
	_boss = data as BossData
	if _boss == null:
		push_error("Boss '%s' needs a BossData." % name)
		_boss = BossData.new()
	_build_visual()


func _physics_process(delta: float) -> void:
	super(delta)
	_enforce_territory()


## A boss attack lasts its own windup + strike + recover (about 2 s), far longer than the generic
## enemy swing, so each step shows its own pose instead of one stretched animation:
## windup = first frame of `attack` (the warning pose), strike = `slam` for the slam (or the last
## frame of `attack`), recover = `idle`. Missing animations fall back to `idle`.
func _update_animation() -> void:
	if _sprite == null or state != State.ATTACK:
		super()
		return
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	_sprite.speed_scale = 1.0
	match step:
		Step.WINDUP:
			_hold_pose(&"attack", 0)
		Step.STRIKE:
			if pattern == Pattern.SLAM and _sprite.sprite_frames.has_animation(&"slam"):
				_hold_pose(&"slam", 0)
			else:
				_hold_pose(&"attack", -1)
		Step.RECOVER:
			if _sprite.animation != &"idle" or not _sprite.is_playing():
				_sprite.play(&"idle")


## Shows one frame of an animation and keeps it (-1 = its last frame).
func _hold_pose(anim: StringName, frame: int) -> void:
	if not _sprite.sprite_frames.has_animation(anim):
		anim = &"idle"
		frame = 0
	if frame < 0:
		frame = _sprite.sprite_frames.get_frame_count(anim) - 1
	if _sprite.animation == anim and _sprite.frame == frame and not _sprite.is_playing():
		return
	_sprite.play(anim)
	_sprite.pause()
	_sprite.frame = frame


## Removed in the middle of a roots attack (not only by dying): its roots must not stay behind.
func _exit_tree() -> void:
	_retract_roots_art()


## The boss ignores being pushed and rooted, and is slowed only half as much.
func apply_knockback(_push: Vector2) -> void:
	pass


func apply_root(_duration: float) -> void:
	pass


func apply_slow(factor: float, duration: float) -> void:
	super(lerpf(factor, 1.0, 0.5), duration)


# --- Behaviour ---------------------------------------------------------------------------------

func _process_chase(_delta: float) -> void:
	if not _target_is_valid():
		return
	var to_target := target.global_position - global_position
	facing = to_target.normalized()
	if _attack_cooldown_left == 0.0:
		_start_attack()
		return
	var stop_distance := _boss.slam_trigger_range * 0.8
	if to_target.length() > stop_distance:
		var speed_boost := _boss.phase_two_speed if phase == 2 else 1.0
		velocity = facing * data.chase_speed * _speed_scale() * speed_boost
	else:
		velocity = Vector2.ZERO


func _start_attack() -> void:
	var distance := global_position.distance_to(target.global_position)
	if distance <= _boss.slam_trigger_range:
		pattern = Pattern.SLAM
	elif _last_pattern == Pattern.SLAM or randf() < 0.7:
		pattern = Pattern.ROOTS
	else:
		pattern = Pattern.SLAM
	_last_pattern = pattern
	state = State.ATTACK
	velocity = Vector2.ZERO
	step = Step.WINDUP
	if pattern == Pattern.SLAM:
		_step_left = _scaled(_boss.slam_windup)
		_warn(global_position, _boss.slam_radius)
	else:
		_step_left = _scaled(_boss.roots_windup)
		_roots_spots = _choose_roots_spots()
		for spot in _roots_spots:
			_warn(spot, _boss.roots_radius)
		_spawn_roots_art()


func _process_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	_step_left -= delta
	if step == Step.WINDUP and _step_left > 0.0:
		_sprout_roots_art()
	if _step_left > 0.0:
		return
	match step:
		Step.WINDUP:
			_strike()
			step = Step.STRIKE
			_step_left = _boss.strike_time
		Step.STRIKE:
			step = Step.RECOVER
			_step_left = _boss.recover_time / (_boss.phase_two_speed if phase == 2 else 1.0)
			_retract_roots_art()
		Step.RECOVER:
			_attack_cooldown_left = data.attack_cooldown
			_enter_chase_or_idle()


## The hit of the current pattern lands: whoever is inside a warned circle is hurt.
func _strike() -> void:
	if pattern == Pattern.SLAM:
		_flash_zone(global_position, _boss.slam_radius)
		_hurt_player_within(global_position, _boss.slam_radius, _boss.slam_damage)
	else:
		for spot in _roots_spots:
			_flash_zone(spot, _boss.roots_radius)
			_hurt_player_within(spot, _boss.roots_radius, _boss.roots_damage)
		for art in _roots_art:
			if is_instance_valid(art):
				art.strike()
				# The hit flash was just added after it: keep the art on top of every circle.
				art.get_parent().move_child(art, -1)


func _hurt_player_within(center: Vector2, radius: float, damage: int) -> void:
	if not _target_is_valid():
		return
	# Measured to the player's center: standing on the edge of the circle is still safe.
	if target.global_position.distance_to(center) <= radius:
		var hurtbox := target.get_node_or_null("Hurtbox") as Hurtbox
		if hurtbox != null:
			hurtbox.receive_hit(ceili(damage * damage_multiplier), global_position)


## Super armor: damage never interrupts the boss.
func _on_hurtbox_hit(damage: int, from_position: Vector2) -> void:
	if state == State.DEAD:
		return
	Events.enemy_damaged.emit(self, damage)
	health.take_damage(damage, from_position)
	if health.is_dead():
		return
	if target == null:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null:
			_acquire_target(player)
	_flash_hit()
	Events.boss_health_changed.emit(_boss.id, health.current, health.max_health, _boss.display_name)
	if phase == 1 and health.current <= health.max_health * _boss.phase_two_threshold:
		_enter_phase_two()


func _acquire_target(player: Node2D) -> void:
	super(player)
	if not _engaged:
		_engaged = true
		for line in _boss.intro_lines:
			Events.message_requested.emit(line)
		Events.boss_health_changed.emit(_boss.id, health.current, health.max_health, _boss.display_name)


func _on_died() -> void:
	super()
	# Dying in the middle of a roots attack: the roots go back into the ground instead of staying.
	_retract_roots_art()
	GameState.set_flag(_boss.defeated_flag)
	Events.boss_defeated.emit(_boss.id)
	if _boss.pickup_scene != null:
		var pickup: Node2D = _boss.pickup_scene.instantiate()
		pickup.position = _local_to_room(global_position)
		get_parent().add_child.call_deferred(pickup)


# --- Helpers -----------------------------------------------------------------------------------

func _enter_phase_two() -> void:
	phase = 2
	if _visual != null:
		_visual.modulate = Color(1.0, 0.8, 0.8)


## Warning time, shorter in phase two.
func _scaled(windup: float) -> float:
	return windup * (_boss.phase_two_windup if phase == 2 else 1.0)


## The first eruption is where the player stands; the others are scattered around.
func _choose_roots_spots() -> Array[Vector2]:
	var spots: Array[Vector2] = [target.global_position]
	var total := _boss.roots_count + (_boss.phase_two_extra_roots if phase == 2 else 0)
	for i in range(1, total):
		var offset := Vector2.from_angle(randf() * TAU) * randf_range(_boss.roots_radius, _boss.roots_spread)
		spots.append(target.global_position + offset)
	return spots


## One piece of art per eruption, over its warning circle (added after it, so drawn on top).
func _spawn_roots_art() -> void:
	_retract_roots_art()
	_roots_sprouted = false
	if _boss.roots_effect == null:
		return
	for spot in _roots_spots:
		var art: Node2D = _boss.roots_effect.instantiate()
		art.position = _local_to_room(spot)
		get_parent().add_child(art)
		Placement.reset(art)
		_roots_art.append(art)
	_sprout_roots_art()


## In the last moments of the windup (or all of it if shorter) the roots sprout, timed so the
## sprout ends exactly when the hit lands.
func _sprout_roots_art() -> void:
	if _roots_sprouted or _roots_art.is_empty() or _step_left > BossRoots.SPROUT_TIME:
		return
	_roots_sprouted = true
	for art in _roots_art:
		if is_instance_valid(art):
			art.sprout(_step_left)


func _retract_roots_art() -> void:
	for art in _roots_art:
		if is_instance_valid(art):
			art.retract()
	_roots_art.clear()


## Attacks are aimed in world coordinates, but circles, roots art and the fragment are children of
## the boss's room: in a generated map the room is not at the origin, so the point must be converted.
func _local_to_room(world_point: Vector2) -> Vector2:
	var parent := get_parent() as Node2D
	return parent.to_local(world_point) if parent != null else world_point


func _warn(center: Vector2, radius: float) -> void:
	get_parent().add_child(SkillZone.circle(_local_to_room(center), radius, WARNING_COLOR, _step_left))


func _flash_zone(center: Vector2, radius: float) -> void:
	get_parent().add_child(SkillZone.circle(_local_to_room(center), radius, ERUPTION_COLOR, 0.3))


func _flash_hit() -> void:
	if _visual == null:
		return
	_visual.modulate = Color(2.5, 2.5, 2.5)
	var resting := Color(1.0, 0.8, 0.8) if phase == 2 else Color.WHITE
	create_tween().tween_property(_visual, "modulate", resting, 0.12)


## Keeps the boss inside its arena: it will not follow the player out of it.
func _enforce_territory() -> void:
	if state == State.DEAD:
		return
	var offset := global_position - _home
	if offset.length() > _boss.arena_radius:
		global_position = _home + offset.normalized() * _boss.arena_radius


## Without art: a giant tree made of two scaled tiles (placeholder).
func _build_visual() -> void:
	if _sprite != null:
		# Real art (EnemyData.sprite_frames) replaces the placeholder tiles.
		_visual = _sprite
		return
	_body.color = Color(0, 0, 0, 0)
	_visual = Node2D.new()
	_visual.name = "Visual"
	_visual.scale = Vector2(2.4, 2.4)
	_visual.add_child(TileArt.sprite(TileArt.ROUND_TREE_TALL_TOP, Vector2(-8, -30)))
	_visual.add_child(TileArt.sprite(TileArt.ROUND_TREE_TALL_BASE, Vector2(-8, -14)))
	add_child(_visual)
	move_child(_visual, 1)
