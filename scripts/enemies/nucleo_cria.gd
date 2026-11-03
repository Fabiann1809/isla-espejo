class_name BroodCore
extends Enemy
## Núcleo de cría: a volcanic structure that never moves. While it hunts Nico and has energy left it
## pulses (`special`) and breeds small creatures around it every few seconds, up to a cap alive at
## once; each creature spends one point of energy and its art dims as the energy runs out. When it is
## destroyed it does not just die: it burns for a moment over a warning circle and then explodes,
## hurting Nico if he is still inside. Its creatures outlive it.
## As it is hurt it breaks in stages (`BroodCoreData.stages`): each swaps its art for a more broken
## one (with a shake and the `crack` animation), gives it back some energy and breeds faster a
## fiercer brood (the director's multipliers it inherits times the stage's, tinted). Near the end it
## lets its queen out once: its comb splits open over a ring on the floor and she comes out of the
## ring; destroyed before that, she comes out at its blast. Everything tunable lives in its
## BroodCoreData.

var _core: BroodCoreData
var _energy := 0
var _brood: Array[Enemy] = []
var _spawn_left := 0.0
var _breeding := false
## The stage it was in when the breeding began: entering a new one meanwhile breeds again soon.
var _breed_stage := 0
## Destroyed, burning before the blast; then the blast itself.
var _fusing := false
var _fuse_left := 0.0
var _blast_left := 0.0
var _blast_hitbox: Hitbox
## 0 while whole; n once it entered `stages[n - 1]`.
var _stage := 0
## The brood's EnemyData with a stage's shorter cooldown, made once per stage.
var _fierce_data: Dictionary[int, EnemyData] = {}
var _cracking_left := 0.0
var _shake_tween: Tween
## Letting the queen out: the comb opens for `queen_windup`; she has come out once released.
var _hatching := false
var _hatch_left := 0.0
var _queen_released := false
## Destroyed before she came out: she comes out at the blast.
var _queen_pending := false
var _queen_spot := Vector2.ZERO
## Seconds the ring where she comes out must show; placed on the next physics tick, because the
## free spot needs a ray and a hit's callback cannot cast one.
var _ring_due := 0.0
var _queen_ring: Node
var _queen: Enemy


func _ready() -> void:
	super()
	_core = data as BroodCoreData
	if _core == null:
		push_error("BroodCore '%s' needs a BroodCoreData." % name)
		_core = BroodCoreData.new()
	_energy = _core.energy
	_spawn_left = _core.first_spawn_delay
	_queen_spot = global_position
	_build_blast()
	_update_dim()
	health.changed.connect(_on_health_changed)


func _physics_process(delta: float) -> void:
	if _fusing:
		_process_fuse(delta)
	elif target != null:
		_spawn_left = maxf(_spawn_left - delta, 0.0)
	_cracking_left = maxf(_cracking_left - delta, 0.0)
	if _ring_due > 0.0:
		_place_queen_ring(_ring_due)
		_ring_due = 0.0
	if _hatching:
		_process_hatch(delta)
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


## 1 while whole, 2 cracked, 3 broken (one more per entry of `stages`).
func stage() -> int:
	return _stage + 1


func is_hatching() -> bool:
	return _hatching


func has_released_queen() -> bool:
	return _queen_released


## The queen it let out (null before, or if it had none).
func queen() -> Enemy:
	return _queen


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
	if _fusing or _hatching or not _target_is_valid():
		return
	facing = (target.global_position - global_position).normalized()
	if _spawn_left == 0.0 and _energy > 0 and living_brood() < _max_brood():
		_start_breeding()


func _process_hurt(delta: float) -> void:
	if not _fusing:
		super(delta)


func _start_breeding() -> void:
	state = State.ATTACK
	velocity = Vector2.ZERO
	_breeding = true
	_breed_stage = _stage
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
		_spawn_left = _spawn_interval() if _breed_stage == _stage else _core.first_spawn_delay
		_enter_chase_or_idle()


func _breed() -> void:
	var parent := get_parent()
	if parent == null or _core.brood_scene == null:
		return
	Events.enemy_attacked.emit(self, &"summon")
	var count := mini(mini(_per_spawn(), _max_brood() - living_brood()), _energy)
	var start_angle := randf() * TAU
	var now := _current_stage()
	for i in count:
		var spot := _free_spot(start_angle + TAU * i / maxf(count, 1.0), _core.spawn_radius)
		var creature: Enemy = _core.brood_scene.instantiate()
		creature.position = (parent as Node2D).to_local(spot) if parent is Node2D else spot
		if now != null:
			creature.modulate = now.brood_tint
			_pass_director(creature, now.brood_speed, now.brood_damage)
			_make_fierce(creature, now)
		else:
			creature.modulate = _core.brood_tint
			_pass_director(creature)
		creature.home_area = home_area
		parent.add_child(creature)
		Placement.reset(creature)
		if parent.has_method("register_enemy"):
			parent.register_enemy(creature)
		_brood.append(creature)
		_energy -= 1
	_update_dim()


## What the director set on the core, passed on to what it breeds (times a stage's boost).
func _pass_director(enemy: Enemy, speed := 1.0, damage := 1.0) -> void:
	enemy.health_multiplier = health_multiplier
	enemy.speed_multiplier = speed_multiplier * speed
	enemy.damage_multiplier = damage_multiplier * damage
	enemy.vision_multiplier = vision_multiplier
	enemy.patrol_multiplier = patrol_multiplier


## A stage's shorter bite cooldown: a copy of the creature's data, shared by that stage's brood.
func _make_fierce(creature: Enemy, now: BroodStage) -> void:
	if is_equal_approx(now.brood_cooldown, 1.0) or creature.data == null:
		return
	if not _fierce_data.has(_stage):
		var fierce: EnemyData = creature.data.duplicate()
		fierce.attack_cooldown *= now.brood_cooldown
		_fierce_data[_stage] = fierce
	creature.data = _fierce_data[_stage]


## A spot at `radius` around it with no wall in between, turning from `angle` until one is free.
func _free_spot(angle: float, radius: float) -> Vector2:
	var space := get_world_2d().direct_space_state
	for step in 8:
		var spot := global_position + Vector2.from_angle(angle + TAU * step / 8.0) * radius
		var query := PhysicsRayQueryParameters2D.create(global_position, spot, 1 << (WORLD_LAYER - 1))
		query.exclude = [get_rid()]
		if space.intersect_ray(query).is_empty():
			return spot
	return global_position


func _update_dim() -> void:
	if _sprite != null:
		_sprite.self_modulate = _core.spent_tint.lerp(Color.WHITE, clampf(float(_energy) / maxf(_core.energy, 1.0), 0.0, 1.0))


# --- Damage stages -----------------------------------------------------------------------------

func _current_stage() -> BroodStage:
	return _core.stages[_stage - 1] if _stage > 0 else null


func _spawn_interval() -> float:
	return _current_stage().spawn_interval if _stage > 0 else _core.spawn_interval


func _per_spawn() -> int:
	return _current_stage().brood_per_spawn if _stage > 0 else _core.brood_per_spawn


func _max_brood() -> int:
	return _current_stage().max_brood if _stage > 0 else _core.max_brood


## Health only falls, so stages only go forward (a big hit may cross several at once). Dying also
## lands here first, so it always dies in its last stage's art.
func _on_health_changed(current: int, maximum: int) -> void:
	if _fusing or state == State.DEAD:
		return
	var fraction := float(current) / maxf(maximum, 1.0)
	while _stage < _core.stages.size() and fraction <= _core.stages[_stage].health_below:
		_stage += 1
		_enter_stage(_core.stages[_stage - 1])
	if current > 0 and not _queen_released and not _hatching and _core.queen_scene != null \
			and fraction <= _core.queen_health_below:
		_start_hatching()


func _enter_stage(now: BroodStage) -> void:
	_energy += now.energy_bonus
	# The broken hive spills its brood out soon.
	_spawn_left = minf(_spawn_left, _core.first_spawn_delay)
	_update_dim()
	if _sprite == null:
		return
	if now.sprite_frames != null:
		_sprite.sprite_frames = now.sprite_frames
	_shake()
	if _sprite.sprite_frames.has_animation(&"crack"):
		_sprite.play(&"crack")
		_sprite.speed_scale = 1.0
		_cracking_left = _animation_length(&"crack")


func _shake() -> void:
	if _shake_tween != null:
		_shake_tween.kill()
	_shake_tween = create_tween()
	var steps := 6
	var step_time := _core.crack_shake_time / (steps + 1)
	for i in steps:
		var side := 1.0 if i % 2 == 0 else -1.0
		var push := Vector2(side * _core.crack_shake * (1.0 - float(i) / steps), 0.0)
		_shake_tween.tween_property(_sprite, "position", data.sprite_offset + push, step_time)
	_shake_tween.tween_property(_sprite, "position", data.sprite_offset, step_time)


# --- Queen -------------------------------------------------------------------------------------

## Armored while it opens (an ATTACK state): hits still hurt it but do not cut the hatching short.
func _start_hatching() -> void:
	_hatching = true
	_hatch_left = _core.queen_windup
	_breeding = false
	state = State.ATTACK
	velocity = Vector2.ZERO
	_hitbox.deactivate()
	_telegraph.hide()
	_ring_due = _core.queen_windup


func _process_hatch(delta: float) -> void:
	_hatch_left -= delta
	if _hatch_left > 0.0:
		return
	_hatching = false
	_release_queen()
	if state == State.ATTACK:
		_enter_chase_or_idle()


func _place_queen_ring(seconds: float) -> void:
	if is_instance_valid(_queen_ring):
		_queen_ring.queue_free()
	# In front of it (toward the bottom of the screen), or the first side with no wall.
	_queen_spot = _free_spot(PI / 2.0, _core.queen_spawn_distance)
	_queen_ring = _add_zone(_core.queen_ring_radius, _core.queen_ring_color, seconds,
			_core.queen_ring_art, _queen_spot)


func _release_queen() -> void:
	_queen_released = true
	_queen_pending = false
	var parent := get_parent()
	if parent == null or _core.queen_scene == null:
		return
	Events.enemy_attacked.emit(self, &"summon")
	var queen_node: Enemy = _core.queen_scene.instantiate()
	queen_node.position = (parent as Node2D).to_local(_queen_spot) if parent is Node2D else _queen_spot
	_pass_director(queen_node)
	queen_node.home_area = home_area
	parent.add_child(queen_node)
	Placement.reset(queen_node)
	if parent.has_method("register_enemy"):
		parent.register_enemy(queen_node)
	_queen = queen_node


# --- Destruction -------------------------------------------------------------------------------

## Destroyed: instead of dying at once it burns over a warning circle, then explodes (see
## `_process_fuse`); only after the blast does it really die (and count as killed for its room).
func _on_died() -> void:
	if _fusing:
		return
	_fusing = true
	_breeding = false
	if not _queen_released and _core.queen_scene != null:
		# She comes out at the blast; her ring shows while it burns.
		_queen_pending = true
		_hatching = false
		_ring_due = _core.fuse_time
	_fuse_left = _core.fuse_time
	velocity = Vector2.ZERO
	_hitbox.deactivate()
	_telegraph.hide()
	_hurtbox.set_deferred("monitorable", false)
	_add_zone(_core.explosion_radius, _core.warning_color, _core.fuse_time, _core.warning_art)
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
	_add_zone(_core.explosion_radius, _core.blast_color, _core.blast_time * 3.0, _core.blast_art)
	Events.enemy_attacked.emit(self, &"melee")
	if _queen_pending:
		_release_queen()


## A ground circle (or its pixel art) of `radius` at `where` (its own center by default).
func _add_zone(radius: float, color: Color, seconds: float, art: Texture2D,
		where := Vector2.INF) -> SkillZone:
	var room := get_parent()
	if room == null:
		return null
	var at := global_position if where == Vector2.INF else where
	var center := (room as Node2D).to_local(at) if room is Node2D else at
	var zone: SkillZone
	if art != null:
		var art_zone := ArtZone.new()
		art_zone.art = art
		zone = art_zone
	else:
		zone = SkillZone.new()
	zone.radius = radius
	zone.color = color
	zone.lifetime = seconds
	zone.position = center
	room.add_child(zone)
	return zone


## The warning and the blast drawn with pixel art: one square frame of the strip per moment of its
## life (not per second), so the warning's inner ring closes just as the fuse runs out whatever the
## fuse time.
class ArtZone extends SkillZone:
	var art: Texture2D

	func _draw() -> void:
		var cell := float(art.get_height())
		var frames := maxi(int(art.get_width() / cell), 1)
		var progress := clampf(_age / maxf(lifetime, 0.001), 0.0, 0.999)
		var frame := int(progress * frames)
		draw_texture_rect_region(art, Rect2(-cell / 2.0, -cell / 2.0, cell, cell),
				Rect2(frame * cell, 0.0, cell, cell))


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

## Breeding pulses with `special`; burning holds `hurt` (set in `_on_died`); a new stage plays its
## `crack` through (set in `_enter_stage`) and letting the queen out plays `open` over its windup.
func _update_animation() -> void:
	if _sprite == null or state == State.DEAD or _fusing:
		return
	if _hatching:
		if _sprite.animation != &"open" and _sprite.sprite_frames.has_animation(&"open"):
			_sprite.play(&"open")
			_sprite.speed_scale = _animation_length(&"open") / maxf(_core.queen_windup, 0.05)
		return
	if _cracking_left > 0.0:
		return
	if state != State.ATTACK or not _breeding:
		super()
		return
	if _sprite.animation != &"special":
		_sprite.play(&"special")
		_anim_held = 0.0
		_sprite.speed_scale = _animation_length(&"special") / maxf(_core.spawn_windup + data.attack_time, 0.05)
