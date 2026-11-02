class_name BroodCore
extends Enemy
## Núcleo de cría: a volcanic structure that never moves. While it hunts Nico and has energy left it
## pulses (`special`) and breeds small creatures around it every few seconds, up to a cap alive at
## once; each creature spends one point of energy and its art dims as the energy runs out. When it is
## destroyed it does not just die: it burns for a moment over a warning circle and then explodes,
## hurting Nico if he is still inside. Its creatures outlive it. Everything tunable lives in its
## BroodCoreData.

var _core: BroodCoreData
var _energy := 0
var _brood: Array[Enemy] = []
var _spawn_left := 0.0
var _breeding := false
## Destroyed, burning before the blast; then the blast itself.
var _fusing := false
var _fuse_left := 0.0
var _blast_left := 0.0
var _blast_hitbox: Hitbox


func _ready() -> void:
	super()
	_core = data as BroodCoreData
	if _core == null:
		push_error("BroodCore '%s' needs a BroodCoreData." % name)
		_core = BroodCoreData.new()
	_energy = _core.energy
	_spawn_left = _core.first_spawn_delay
	_build_blast()
	_update_dim()


func _physics_process(delta: float) -> void:
	if _fusing:
		_process_fuse(delta)
	elif target != null:
		_spawn_left = maxf(_spawn_left - delta, 0.0)
	super(delta)
	# A hit or a lost target cuts the breeding short (it keeps the energy).
	if _breeding and state != State.ATTACK:
		_breeding = false


func energy() -> int:
	return _energy


func living_brood() -> int:
	var alive: Array[Enemy] = []
	for creature in _brood:
		if is_instance_valid(creature) and not creature.is_dead():
			alive.append(creature)
	_brood = alive
	return _brood.size()


func is_fusing() -> bool:
	return _fusing


# --- Behaviour ---------------------------------------------------------------------------------

func _process_idle(delta: float) -> void:
	if not _fusing:
		super(delta)


func _process_patrol(_delta: float) -> void:
	velocity = Vector2.ZERO
	if not _fusing:
		_enter_idle()


func _process_chase(_delta: float) -> void:
	velocity = Vector2.ZERO
	if _fusing or not _target_is_valid():
		return
	facing = (target.global_position - global_position).normalized()
	if _spawn_left == 0.0 and _energy > 0 and living_brood() < _core.max_brood:
		_start_breeding()


func _process_hurt(delta: float) -> void:
	if not _fusing:
		super(delta)


func _start_breeding() -> void:
	state = State.ATTACK
	velocity = Vector2.ZERO
	_breeding = true
	_attack_phase = AttackPhase.WINDUP
	_attack_time_left = _core.spawn_windup


func _process_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	if _fusing or not _breeding:
		return
	_attack_time_left -= delta
	if _attack_time_left > 0.0:
		return
	if _attack_phase == AttackPhase.WINDUP:
		_breed()
		_attack_phase = AttackPhase.RECOVER
		_attack_time_left = data.attack_time
	else:
		_breeding = false
		_spawn_left = _core.spawn_interval
		_enter_chase_or_idle()


func _breed() -> void:
	var parent := get_parent()
	if parent == null or _core.brood_scene == null:
		return
	Events.enemy_attacked.emit(self, &"summon")
	var count := mini(mini(_core.brood_per_spawn, _core.max_brood - living_brood()), _energy)
	var start_angle := randf() * TAU
	for i in count:
		var spot := _free_spot(start_angle + TAU * i / maxf(count, 1.0))
		var creature: Enemy = _core.brood_scene.instantiate()
		creature.position = (parent as Node2D).to_local(spot) if parent is Node2D else spot
		creature.modulate = _core.brood_tint
		creature.home_area = home_area
		parent.add_child(creature)
		Placement.reset(creature)
		if parent.has_method("register_enemy"):
			parent.register_enemy(creature)
		_brood.append(creature)
		_energy -= 1
	_update_dim()


## A spot at `spawn_radius` around it with no wall in between, turning from `angle` until one is free.
func _free_spot(angle: float) -> Vector2:
	var space := get_world_2d().direct_space_state
	for step in 8:
		var spot := global_position + Vector2.from_angle(angle + TAU * step / 8.0) * _core.spawn_radius
		var query := PhysicsRayQueryParameters2D.create(global_position, spot, 1 << (WORLD_LAYER - 1))
		query.exclude = [get_rid()]
		if space.intersect_ray(query).is_empty():
			return spot
	return global_position


func _update_dim() -> void:
	if _sprite != null:
		_sprite.self_modulate = _core.spent_tint.lerp(Color.WHITE, float(_energy) / maxf(_core.energy, 1.0))


# --- Destruction -------------------------------------------------------------------------------

## Destroyed: instead of dying at once it burns over a warning circle, then explodes (see
## `_process_fuse`); only after the blast does it really die (and count as killed for its room).
func _on_died() -> void:
	if _fusing:
		return
	_fusing = true
	_breeding = false
	_fuse_left = _core.fuse_time
	velocity = Vector2.ZERO
	_hitbox.deactivate()
	_telegraph.hide()
	_hurtbox.set_deferred("monitorable", false)
	_add_zone(_core.explosion_radius, _core.warning_color, _core.fuse_time)
	if _sprite != null:
		_sprite.play(&"hurt")


func _process_fuse(delta: float) -> void:
	if _fuse_left > 0.0:
		_fuse_left -= delta
		if _sprite != null:
			var lit := fmod(_fuse_left * _core.fuse_flicker, 1.0) < 0.5
			_sprite.self_modulate = Color(2.0, 1.6, 1.2) if lit else _core.spent_tint
		if _fuse_left <= 0.0:
			_blast()
		return
	_blast_left -= delta
	if _blast_left <= 0.0 and state != State.DEAD:
		_blast_hitbox.deactivate()
		super._on_died()


func _blast() -> void:
	_blast_hitbox.damage = ceili(_core.explosion_damage * damage_multiplier)
	_blast_hitbox.activate()
	_blast_left = _core.blast_time
	_add_zone(_core.explosion_radius, _core.blast_color, _core.blast_time * 3.0)
	Events.enemy_attacked.emit(self, &"melee")


func _add_zone(radius: float, color: Color, seconds: float) -> void:
	var room := get_parent()
	if room == null:
		return
	var center := (room as Node2D).to_local(global_position) if room is Node2D else global_position
	room.add_child(SkillZone.circle(center, radius, color, seconds))


func _build_blast() -> void:
	_blast_hitbox = Hitbox.new()
	_blast_hitbox.name = "BlastHitbox"
	_blast_hitbox.collision_layer = 1 << 4
	_blast_hitbox.collision_mask = 1 << 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _core.explosion_radius
	shape.shape = circle
	_blast_hitbox.add_child(shape)
	add_child(_blast_hitbox)
	# The blast throws Nico away from the core's center.
	_blast_hitbox.owner = self


# --- Animation ---------------------------------------------------------------------------------

## Breeding pulses with `special`; burning holds `hurt` (set in `_on_died`).
func _update_animation() -> void:
	if _sprite == null or state == State.DEAD or _fusing:
		return
	if state != State.ATTACK or not _breeding:
		super()
		return
	if _sprite.animation != &"special":
		_sprite.play(&"special")
		_anim_held = 0.0
		_sprite.speed_scale = _animation_length(&"special") / maxf(_core.spawn_windup + data.attack_time, 0.05)
