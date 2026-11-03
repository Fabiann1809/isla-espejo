class_name VolcanicQueen
extends Enemy
## Reina volcánica: the big queen of the volcanic brood, a temple mini boss (not a `Boss`: the
## director tunes it and it keeps to its room). It flies (its body only stops at walls, never at
## water) and chases Nico. Close enough, it marks a lane in front of it, backs off while it curls its
## stinger forward and then lunges along that lane with the stinger out. Every few seconds while it
## hunts it calls (`special`) and a pair of cría volcánicas appear around it in its room, never more
## than a cap alive at once; they burn out when it dies. Everything tunable lives in its
## VolcanicQueenData.

var _queen: VolcanicQueenData
var _brood: Array[Enemy] = []
var _summon_left := 0.0
## The current attack is a summon, not a sting.
var _summoning := false
var _lunge_dir := Vector2.RIGHT


func _ready() -> void:
	super()
	_queen = data as VolcanicQueenData
	if _queen == null:
		push_error("VolcanicQueen '%s' needs a VolcanicQueenData." % name)
		_queen = VolcanicQueenData.new()
	_summon_left = _queen.first_summon_delay


func _physics_process(delta: float) -> void:
	if target != null and not _summoning:
		_summon_left = maxf(_summon_left - delta, 0.0)
	super(delta)
	# A push or a lost target cuts the summon short (it is tried again later).
	if _summoning and state != State.ATTACK:
		_summoning = false


func living_brood() -> int:
	var alive: Array[Enemy] = []
	for creature in _brood:
		if is_instance_valid(creature) and not creature.is_dead():
			alive.append(creature)
	_brood = alive
	return _brood.size()


func is_summoning() -> bool:
	return _summoning


# --- Behaviour ---------------------------------------------------------------------------------

func _process_chase(delta: float) -> void:
	if not _target_is_valid():
		return
	if _can_summon():
		facing = (target.global_position - global_position).normalized()
		_start_summon()
		return
	super(delta)


func _can_summon() -> bool:
	return _summon_left == 0.0 and _attack_cooldown_left == 0.0 and _queen.brood_scene != null \
			and living_brood() < _queen.max_brood


## The sting: the generic warning, stretched over the whole lane the lunge will sweep.
func _start_attack() -> void:
	super()
	_summoning = false
	_lunge_dir = facing
	var reach := _queen.lunge_speed * _speed_scale() * data.attack_time
	_telegraph.offset_right = _sting_tip() + reach


func _process_attack(delta: float) -> void:
	if _summoning:
		_process_summon(delta)
		return
	_attack_time_left -= delta
	match _attack_phase:
		AttackPhase.WINDUP:
			velocity = -_lunge_dir * _queen.windup_backoff_speed * _speed_scale()
			if _attack_time_left <= 0.0:
				_start_lunge()
		AttackPhase.STRIKE:
			velocity = _lunge_dir * _queen.lunge_speed * _speed_scale()
			if _attack_time_left <= 0.0:
				velocity = Vector2.ZERO
				_hitbox.deactivate()
				_attack_phase = AttackPhase.RECOVER
				_attack_time_left = _queen.lunge_recover
		AttackPhase.RECOVER:
			velocity = Vector2.ZERO
			if _attack_time_left <= 0.0:
				_attack_cooldown_left = data.attack_cooldown
				_enter_chase_or_idle()


func _start_lunge() -> void:
	_telegraph.hide()
	_pivot.rotation = _lunge_dir.angle()
	_hitbox.damage = ceili(data.attack_damage * damage_multiplier)
	_hitbox.activate()
	Events.enemy_attacked.emit(self, &"melee")
	_attack_phase = AttackPhase.STRIKE
	_attack_time_left = data.attack_time


## How far in front of it the stinger's hitbox reaches (from the scene's shape).
func _sting_tip() -> float:
	var shape := _hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null or not (shape.shape is RectangleShape2D):
		return _telegraph.offset_right
	return shape.position.x + (shape.shape as RectangleShape2D).size.x / 2.0


# --- Brood -------------------------------------------------------------------------------------

func _start_summon() -> void:
	state = State.ATTACK
	velocity = Vector2.ZERO
	_summoning = true
	_attack_phase = AttackPhase.WINDUP
	_attack_time_left = _queen.summon_windup


func _process_summon(delta: float) -> void:
	velocity = Vector2.ZERO
	_attack_time_left -= delta
	if _attack_time_left > 0.0:
		return
	if _attack_phase == AttackPhase.WINDUP:
		_summon_brood()
		_attack_phase = AttackPhase.RECOVER
		_attack_time_left = _queen.summon_recover
	else:
		_summoning = false
		_summon_left = _queen.summon_interval
		_enter_chase_or_idle()


func _summon_brood() -> void:
	var parent := get_parent()
	if parent == null or _queen.brood_scene == null:
		return
	Events.enemy_attacked.emit(self, &"summon")
	var count := mini(_queen.brood_per_summon, _queen.max_brood - living_brood())
	var start_angle := randf() * TAU
	for i in count:
		var spot := _free_spot(start_angle + TAU * i / maxf(count, 1.0))
		var creature: Enemy = _queen.brood_scene.instantiate()
		creature.position = (parent as Node2D).to_local(spot) if parent is Node2D else spot
		creature.modulate = _queen.brood_tint
		creature.home_area = home_area
		parent.add_child(creature)
		Placement.reset(creature)
		if parent.has_method("register_enemy"):
			parent.register_enemy(creature)
		_brood.append(creature)


## A spot at `spawn_radius` around it with no wall in between, turning from `angle` until one is free.
func _free_spot(angle: float) -> Vector2:
	var space := get_world_2d().direct_space_state
	for step in 8:
		var spot := global_position + Vector2.from_angle(angle + TAU * step / 8.0) * _queen.spawn_radius
		var query := PhysicsRayQueryParameters2D.create(global_position, spot, 1 << (WORLD_LAYER - 1))
		query.exclude = [get_rid()]
		if space.intersect_ray(query).is_empty():
			return spot
	return global_position


func _on_died() -> void:
	_summoning = false
	if _queen != null and _queen.brood_dies_with_queen:
		for creature in _brood:
			if is_instance_valid(creature) and not creature.is_dead():
				creature.health.take_damage(creature.health.max_health, global_position)
	super()


# --- Animation ---------------------------------------------------------------------------------

## A summon plays `special` over its call and its pose; everything else is the base's (the sting
## is `attack`, stretched over the warning and the lunge).
func _update_animation() -> void:
	if _sprite == null or state != State.ATTACK or not _summoning:
		super()
		return
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	if _sprite.animation != &"special":
		_sprite.play(&"special")
		_anim_held = 0.0
		_sprite.speed_scale = _animation_length(&"special") / maxf(_queen.summon_windup + _queen.summon_recover, 0.05)
