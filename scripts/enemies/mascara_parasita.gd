class_name ParasiteMask
extends Enemy
## Máscara parásita: a floating mask that flies to the nearest other living enemy of its room and
## rides its head, sending it into a frenzy (Enemy.apply_frenzy: faster, attacks come back sooner)
## for as long as it rides; it also tells the host it is masked (Enemy.set_masked), so some enemies
## boost their own mechanic too. While it rides it cannot be hit (its hurtbox is off, arrows fly on to the
## host): kill the host first. When the host dies the mask jumps off, flees from Nico for a moment
## (it can be hit now) and then looks for another host; with none left it bites Nico by itself
## (the base melee attack, weak). Its body flies: it only stops at walls and never blocks anyone.
## Everything tunable lives in its ParasiteMaskData.

## Meta set on the enemy it rides, so two masks never share a host.
const RIDER_META := &"parasite_rider"
## Its body sits this much below the host's, so the y-sort draws it over the host.
const RIDE_SORT_OFFSET := 1.0

var _mask: ParasiteMaskData
var _host: Enemy = null
var _riding := false
var _flee_left := 0.0
var _flee_dir := Vector2.ZERO
## After fleeing it waits this long before it looks for a host again.
var _seek_rest_left := 0.0
@onready var _hurt_shape: CollisionShape2D = $Hurtbox/CollisionShape2D


func _ready() -> void:
	super()
	_mask = data as ParasiteMaskData
	if _mask == null:
		push_error("ParasiteMask '%s' needs a ParasiteMaskData." % name)
		_mask = ParasiteMaskData.new()
	# Moves after the other enemies, so while riding it sits on where its host is this frame.
	process_physics_priority = 1


func _physics_process(delta: float) -> void:
	_flee_left = maxf(_flee_left - delta, 0.0)
	_seek_rest_left = maxf(_seek_rest_left - delta, 0.0)
	if state != State.DEAD and not _riding and not _host_is_valid(_host):
		_host = _find_host()
	super(delta)
	if _riding:
		_ride()


func is_riding() -> bool:
	return _riding


## The enemy it rides or flies to (null if none).
func host() -> Enemy:
	return _host if _host_is_valid(_host) else null


func is_fleeing() -> bool:
	return _flee_left > 0.0


# --- Behaviour ---------------------------------------------------------------------------------

func _process_idle(delta: float) -> void:
	if not _act_on_host():
		super(delta)


func _process_patrol(delta: float) -> void:
	if not _act_on_host():
		super(delta)


func _process_chase(delta: float) -> void:
	if not _act_on_host():
		super(delta)


## Riding, fleeing or flying to a host replace its normal behaviour; false when none applies.
func _act_on_host() -> bool:
	if _riding:
		velocity = Vector2.ZERO
		return true
	if _flee_left > 0.0:
		velocity = _flee_dir * _mask.flee_speed * _speed_scale()
		if not _dash_allowed(global_position + velocity * get_physics_process_delta_time()):
			velocity = Vector2.ZERO
		return true
	if not _host_is_valid(_host):
		return false
	var to_host := _host.global_position - global_position
	if to_host.length() <= _mask.attach_distance:
		_attach()
		return true
	facing = to_host.normalized()
	velocity = facing * minf(_mask.seek_speed * _speed_scale(), to_host.length() / get_physics_process_delta_time())
	return true


## The nearest living enemy in its room that can move and has no rider, or null.
func _find_host() -> Enemy:
	if _flee_left > 0.0 or _seek_rest_left > 0.0:
		return null
	var best: Enemy = null
	var best_distance := _mask.seek_range
	for node in get_tree().get_nodes_in_group("enemies"):
		var candidate := node as Enemy
		if not _host_is_valid(candidate) or candidate is ParasiteMask or candidate is Boss:
			continue
		if candidate.data.chase_speed <= 0.0 or not _in_territory(candidate.global_position):
			continue
		var rider: Variant = candidate.get_meta(RIDER_META) if candidate.has_meta(RIDER_META) else null
		if rider != null and is_instance_valid(rider) and rider != self:
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func _host_is_valid(candidate: Variant) -> bool:
	return candidate != null and is_instance_valid(candidate) and candidate != self \
			and not candidate.is_dead() and not candidate.is_queued_for_deletion()


func _attach() -> void:
	_riding = true
	velocity = Vector2.ZERO
	_hitbox.deactivate()
	_telegraph.hide()
	state = State.IDLE
	_host.set_meta(RIDER_META, self)
	_host.died.connect(_on_host_died, CONNECT_ONE_SHOT)
	# Some hosts get their own boost on top of the frenzy (Enemy.set_masked).
	_host.set_masked(true)
	_hurt_shape.set_deferred("disabled", true)
	_set_shadow_visible(false)
	Events.enemy_attacked.emit(self, &"summon")
	_ride()


## Sits on the host's head and keeps its frenzy going; a host that is gone throws it off.
func _ride() -> void:
	if not _host_is_valid(_host):
		_detach()
		return
	global_position = _host.global_position + Vector2(0, RIDE_SORT_OFFSET)
	facing = _host.facing
	_host.apply_frenzy(_mask.frenzy_speed, _mask.frenzy_cooldown_rate, _mask.frenzy_refresh)
	if _sprite != null:
		_sprite.position = data.sprite_offset - Vector2(0, _mask.ride_height + RIDE_SORT_OFFSET)


func _on_host_died() -> void:
	if _riding:
		_detach()


## Jumps off: the host's frenzy ends, and the mask flees from Nico before it looks for another.
func _detach() -> void:
	_riding = false
	if is_instance_valid(_host):
		if _host.has_meta(RIDER_META) and _host.get_meta(RIDER_META) == self:
			_host.remove_meta(RIDER_META)
		if _host.died.is_connected(_on_host_died):
			_host.died.disconnect(_on_host_died)
		_host.end_frenzy()
		_host.set_masked(false)
	_host = null
	if state == State.DEAD:
		return
	_hurt_shape.set_deferred("disabled", false)
	_set_shadow_visible(true)
	if _sprite != null:
		_sprite.position = data.sprite_offset
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var away := global_position - player.global_position if player != null else Vector2.ZERO
	_flee_dir = away.normalized() if away.length() > 0.01 else Vector2.from_angle(randf() * TAU)
	facing = _flee_dir
	_flee_left = _mask.flee_time
	_seek_rest_left = _mask.flee_time + _mask.reattach_delay
	_enter_chase_or_idle()


## Pushes and hits cannot reach it while it rides.
func apply_knockback(push: Vector2) -> void:
	if not _riding:
		super(push)


func _on_died() -> void:
	if _riding:
		_detach()
	super()


func _set_shadow_visible(shown: bool) -> void:
	var shadow := get_node_or_null(ActorShadow.NODE_NAME) as CanvasItem
	if shadow != null:
		shadow.visible = shown


# --- Animation ---------------------------------------------------------------------------------

## The leap to a host loops `special`, riding shakes in `idle` and fleeing is `run`; alone, the base's.
func _update_animation() -> void:
	if _sprite == null or state == State.DEAD:
		return
	var wanted := StringName()
	if _riding:
		wanted = &"idle"
	elif _flee_left > 0.0:
		wanted = &"run"
	elif _host_is_valid(_host) and state in [State.IDLE, State.PATROL, State.CHASE]:
		wanted = &"special"
	if wanted.is_empty():
		super()
		return
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	if _sprite.animation != wanted or not _sprite.is_playing():
		_sprite.play(wanted)
		_sprite.speed_scale = 1.0
		_anim_held = 0.0
