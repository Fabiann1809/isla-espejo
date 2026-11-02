class_name TrapClockmaker
extends Enemy
## Relojero de trampas: a small automaton that, when it appears, sets a few traps around itself in
## its room (spikes, a saw on a track, a fire jet: ClockTrap) and, while Nico is in its room, fires
## them one after another on a steady rhythm; each trap warns before it strikes. It runs from Nico,
## toward the part of its room farthest from him, and only jabs when he corners it. When it dies its
## traps go dormant. Everything tunable lives in its TrapClockmakerData.

var _clock: TrapClockmakerData
var _traps: Array[ClockTrap] = []
var _tick_left := 0.0
var _next_trap := 0
## Time left of the special animation (setting the traps) and of a tick's signal.
var _setting_left := 0.0
var _wind_left := 0.0


func _ready() -> void:
	super()
	_clock = data as TrapClockmakerData
	if _clock == null:
		push_error("TrapClockmaker '%s' needs a TrapClockmakerData." % name)
		_clock = TrapClockmakerData.new()
	_tick_left = _clock.tick_interval
	_setting_left = _clock.set_time
	# Its room may still be adding its children during `_ready`.
	_set_traps.call_deferred()


func _physics_process(delta: float) -> void:
	super(delta)
	if state == State.DEAD:
		return
	_setting_left = maxf(_setting_left - delta, 0.0)
	_wind_left = maxf(_wind_left - delta, 0.0)
	# The clock only runs while Nico is in its room.
	if not _nico_in_room():
		return
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left = _clock.tick_interval
		_fire_next_trap()


## Its traps that are still there.
func traps() -> Array[ClockTrap]:
	var standing: Array[ClockTrap] = []
	for i in _traps.size():
		# Untyped: a trap that went away is a freed instance, which a typed variable refuses.
		var trap = _traps[i]
		if is_instance_valid(trap) and not trap.is_queued_for_deletion():
			standing.append(trap)
	return standing


func _exit_tree() -> void:
	# Taken away alive (the arena's reset): its traps go with it. Dead, they stay dormant in the room.
	if state != State.DEAD:
		for trap in traps():
			trap.queue_free()


func _on_died() -> void:
	super()
	for trap in traps():
		trap.set_dormant()


# --- Traps ------------------------------------------------------------------------------------

## One trap per kind of its data, on a ring around it, inside its room.
func _set_traps() -> void:
	var parent := get_parent() as Node2D
	if parent == null or not is_inside_tree() or state == State.DEAD:
		return
	var kinds := _clock.trap_kinds
	var start := randf() * TAU
	var inside := home_area.grow(-_clock.trap_margin)
	var damage := ceili(_clock.trap_damage * damage_multiplier)
	for i in kinds.size():
		var kind_id := ClockTrap.kind_named(kinds[i])
		if kind_id < 0:
			push_warning("TrapClockmaker: unknown trap kind '%s'." % kinds[i])
			continue
		var kind := kind_id as ClockTrap.Kind
		var outward := Vector2.from_angle(start + TAU * i / kinds.size())
		var spot := global_position + outward * _clock.trap_ring_radius
		if home_area.has_area() and inside.has_area():
			spot = spot.clamp(inside.position, inside.end)
		var trap := ClockTrap.create(kind, parent.to_local(spot), _trap_aim(kind, spot, outward), _clock, damage)
		parent.add_child(trap)
		_traps.append(trap)


## The saw runs across the ring; the jet fires toward the middle of its room (outward without one).
func _trap_aim(kind: ClockTrap.Kind, spot: Vector2, outward: Vector2) -> Vector2:
	match kind:
		ClockTrap.Kind.SAW:
			return outward.orthogonal()
		ClockTrap.Kind.FIRE:
			var to_middle := home_area.get_center() - spot
			if home_area.has_area() and to_middle.length() > 1.0:
				return to_middle.normalized()
	return outward


func _fire_next_trap() -> void:
	var list := traps()
	for attempt in list.size():
		var trap := list[_next_trap % list.size()]
		_next_trap += 1
		if trap.trigger():
			_wind_left = _clock.wind_time
			Events.enemy_attacked.emit(self, &"trap")
			return


func _nico_in_room() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	return player != null and not _is_dead_node(player) and _in_territory(player.global_position)


# --- Movement ---------------------------------------------------------------------------------

func _process_idle(delta: float) -> void:
	if _setting_left > 0.0:
		velocity = Vector2.ZERO
		return
	super(delta)


func _process_patrol(delta: float) -> void:
	if _setting_left > 0.0:
		velocity = Vector2.ZERO
		return
	super(delta)


## It keeps away from Nico; cornered (he is within reach) it jabs.
func _process_chase(_delta: float) -> void:
	if not _target_is_valid():
		return
	velocity = Vector2.ZERO
	if _setting_left > 0.0:
		return
	var to_target := target.global_position - global_position
	if to_target.length() <= data.attack_range and _attack_cooldown_left == 0.0:
		facing = to_target.normalized()
		_start_attack()
		return
	if to_target.length() >= _clock.flee_distance:
		facing = to_target.normalized()
		return
	facing = _flee_direction()
	velocity = facing * data.chase_speed * _speed_scale()


## Of a few directions, the one whose point `flee_lookahead` ahead is farthest from Nico and still
## inside its room; a little bias toward the way it already runs keeps it from dithering.
func _flee_direction() -> Vector2:
	var away := global_position - target.global_position
	var best := away.normalized() if away.length() > 0.01 else Vector2.RIGHT
	var best_score := -INF
	var inside := home_area.grow(-_clock.flee_margin)
	var running := velocity.normalized()
	for i in maxi(_clock.flee_directions, 1):
		var direction := Vector2.from_angle(TAU * i / maxi(_clock.flee_directions, 1))
		var ahead := global_position + direction * _clock.flee_lookahead
		if home_area.has_area() and inside.has_area() and not inside.has_point(ahead):
			continue
		var score := ahead.distance_to(target.global_position) + direction.dot(running) * 8.0
		if score > best_score:
			best_score = score
			best = direction
	return best


# --- Animation --------------------------------------------------------------------------------

## Setting the traps plays `special`; each tick of the clock flashes its `attack` signal.
func _update_animation() -> void:
	if _sprite == null or state in [State.DEAD, State.HURT, State.ATTACK] \
			or (_setting_left <= 0.0 and _wind_left <= 0.0):
		super()
		return
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	var wanted: StringName = &"special" if _setting_left > 0.0 else &"attack"
	if _sprite.animation != wanted:
		_sprite.play(wanted)
		_anim_held = 0.0
		var span := _clock.set_time if wanted == &"special" else _clock.wind_time
		_sprite.speed_scale = _animation_length(wanted) / maxf(span, 0.05)
