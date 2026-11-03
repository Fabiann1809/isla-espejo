class_name BridgeWorm
extends Enemy
## Bridge worm (island 3): it lives under the lava and the ground. Burrowed it is only a ripple: no
## body, no hurtbox, it cannot be hit. It travels under to a spot beside Nico (or beside his path when
## he moves), warns with a circle, bursts out and surges in a straight line through where he stands,
## its body pieces (WormSegment) rising after the head along its path. Out, the pieces are solid for
## Nico and hurt on contact, so the body can cut a narrow path; it stays out a moment, then the head
## dives and the pieces follow it into the hole. It can be hit only while its head is out.
## Everything tunable lives in its BridgeWormData.

enum Phase { UNDER, RISING, SURGING, RESTING, SINKING }

## Below this speed (px/s) Nico counts as standing still when the worm picks where to surface.
const MOVING_SPEED := 10.0
## Rings of the ripple, and how fast they spread (cycles per second; faster while rising).
const RIPPLE_RINGS := 3
const RIPPLE_SPEED := 1.2
const RIPPLE_RISING_SPEED := 3.5

var phase: Phase = Phase.UNDER

var _worm: BridgeWormData
var _segments: Array[WormSegment] = []
## The head's path since it surfaced, and how far along it the body has flowed out of the hole.
var _trail := PackedVector2Array()
var _trail_length := 0.0
var _flow := 0.0
var _surge_dir := Vector2.RIGHT
var _phase_left := 0.0
var _burrow_clock := 0.0
var _last_position := Vector2.ZERO
var _ripple: Ripple
## Which part of its trip out the sprite is playing (rise, lunge, rest, dive), so each starts once.
var _shown: StringName = &""


func _ready() -> void:
	super()
	_worm = data as BridgeWormData
	if _worm == null:
		push_error("BridgeWorm '%s' needs a BridgeWormData." % name)
		_worm = BridgeWormData.new()
	_hurtbox.invulnerability_check = func() -> bool: return not is_out()
	_telegraph.hide()
	_ripple = Ripple.new()
	_ripple.name = "Ripple"
	_ripple.color = _worm.ripple_color
	_ripple.radius = _worm.ripple_radius
	_ripple.art = _worm.ripple_art
	add_child(_ripple)
	_set_head_out(false)


func _physics_process(delta: float) -> void:
	_last_position = global_position
	super(delta)
	_follow_head(delta)
	_place_segments()
	_ripple.visible = not is_out() and state != State.DEAD
	_ripple.speed = RIPPLE_RISING_SPEED if phase == Phase.RISING else RIPPLE_SPEED
	var shadow := get_node_or_null(^"Shadow") as CanvasItem
	if shadow != null:
		shadow.visible = is_out() or state == State.DEAD


## True while the head is above the ground (the only time the worm can be hit).
func is_out() -> bool:
	return phase in [Phase.SURGING, Phase.RESTING]


## The body pieces that are above the ground right now.
func segments_out() -> Array[WormSegment]:
	var out: Array[WormSegment] = []
	for segment in _segments:
		if segment.is_out:
			out.append(segment)
	return out


func _exit_tree() -> void:
	for segment in _segments:
		if is_instance_valid(segment):
			segment.queue_free()
	_segments.clear()


## Under the ground nothing can push it; out, its data's resistance applies.
func apply_knockback(push: Vector2) -> void:
	if is_out():
		super(push)


# --- Behaviour ---------------------------------------------------------------------------------

func _process_idle(delta: float) -> void:
	if not _settle_underground():
		super(delta)


func _process_patrol(delta: float) -> void:
	if not _settle_underground():
		super(delta)


## Burrowed, it heads for the spot where it will surface and waits there for its cooldown.
func _process_chase(delta: float) -> void:
	if _settle_underground() or not _target_is_valid():
		return
	var spot := _emerge_spot()
	var to_spot := spot - global_position
	_burrow_clock += delta
	var arrived := to_spot.length() <= _worm.emerge_arrive_distance
	var gave_up := _burrow_clock >= _worm.burrow_give_up_time \
			and global_position.distance_to(target.global_position) <= _worm.surge_distance
	if (arrived or gave_up) and _attack_cooldown_left == 0.0:
		_start_attack()
		return
	if arrived:
		velocity = Vector2.ZERO
		return
	facing = to_spot.normalized()
	velocity = facing * minf(_worm.burrow_speed * _speed_scale(), to_spot.length() / delta)


## The attack is the whole trip out: warning, surge, rest and dive.
func _start_attack() -> void:
	state = State.ATTACK
	velocity = Vector2.ZERO
	phase = Phase.RISING
	_phase_left = _worm.emerge_windup
	_burrow_clock = 0.0
	var room := get_parent()
	if room != null:
		var center := (room as Node2D).to_local(global_position) if room is Node2D else global_position
		room.add_child(SkillZone.circle(center, _worm.emerge_warning_radius,
				_worm.emerge_warning_color, _worm.emerge_windup))


func _process_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	_phase_left -= delta
	match phase:
		Phase.RISING:
			if _phase_left <= 0.0:
				_start_surge()
		Phase.SURGING:
			velocity = _surge_dir * _worm.surge_speed * _speed_scale()
		Phase.RESTING:
			if _phase_left <= 0.0:
				_start_sinking()
		Phase.UNDER:
			# Cut off before surfacing (lost Nico mid-warning): it simply stays under.
			_enter_chase_or_idle()


func _start_surge() -> void:
	phase = Phase.SURGING
	var aim := global_position + facing * _worm.surge_distance
	if _target_is_valid():
		var travel := global_position.distance_to(target.global_position) / maxf(_worm.surge_speed, 1.0)
		aim = target.global_position + _motion_of(target) * travel
	if aim.distance_to(global_position) > 0.5:
		_surge_dir = (aim - global_position).normalized()
	else:
		_surge_dir = facing
	facing = _surge_dir
	velocity = _surge_dir * _worm.surge_speed * _speed_scale()
	_trail = PackedVector2Array([global_position])
	_trail_length = 0.0
	_flow = 0.0
	_ensure_segments()
	_set_head_out(true)
	_pivot.rotation = _surge_dir.angle()
	_hitbox.damage = _damage()
	_hitbox.activate()
	Events.enemy_attacked.emit(self, &"melee")


func _start_resting() -> void:
	phase = Phase.RESTING
	_phase_left = _worm.surface_time
	_hitbox.deactivate()
	velocity = Vector2.ZERO


## The head goes under; the pieces keep flowing along the path into its hole.
func _start_sinking() -> void:
	state = State.ATTACK
	velocity = Vector2.ZERO
	if phase == Phase.SINKING:
		return
	phase = Phase.SINKING
	_hitbox.deactivate()
	_set_head_out(false)
	_flow = minf(_flow, _trail_length)


func _finish_sinking() -> void:
	phase = Phase.UNDER
	_attack_cooldown_left = maxf(_attack_cooldown_left, data.attack_cooldown)
	_burrow_clock = 0.0
	_enter_chase_or_idle()


## Called by the burrowed hooks: if the worm is still (partly) out, it dives first. True if it did.
func _settle_underground() -> bool:
	match phase:
		Phase.UNDER:
			return false
		Phase.RISING:
			phase = Phase.UNDER
			return false
	_start_sinking()
	return true


## Where to surface: `emerge_offset` from Nico on the worm's side, or beside the path he is walking
## (a little ahead of him), so the surge crosses it. Never out of its room.
func _emerge_spot() -> Vector2:
	var center := target.global_position
	var away := global_position - center
	var side := away.normalized() if away.length() > 0.01 else Vector2.RIGHT
	var motion := _motion_of(target)
	if motion.length() > MOVING_SPEED:
		side = motion.orthogonal().normalized()
		if side.dot(away) < 0.0:
			side = -side
		center += motion * _worm.emerge_lead
	var spot := center + side * _worm.emerge_offset
	var inside := home_area.grow(-Tuning.DASH_ROOM_MARGIN)
	if home_area.has_area() and inside.has_area():
		spot = spot.clamp(inside.position, inside.end)
	return spot


# --- Body --------------------------------------------------------------------------------------

## After the move: the surge grows the head's path, the dive keeps the body flowing into the hole.
func _follow_head(delta: float) -> void:
	if state == State.DEAD:
		return
	if state == State.ATTACK and phase == Phase.SURGING:
		var moved := global_position.distance_to(_last_position)
		if moved > 0.0:
			_trail.append(global_position)
			_trail_length += moved
		_flow = _trail_length
		var expected := _worm.surge_speed * _speed_scale() * delta
		if _trail_length >= _worm.surge_distance or moved < expected * _worm.surge_blocked_fraction:
			_start_resting()
	elif phase == Phase.SINKING:
		_flow += _worm.surge_speed * _speed_scale() * delta
		if _flow >= _trail_length + _worm.segment_count * _worm.segment_spacing:
			_place_segments()
			_finish_sinking()


## Piece i sits `(i + 1) * segment_spacing` behind the head's flow along its path; it is out only
## between the hole it came from and the hole the head went into.
func _place_segments() -> void:
	if _segments.is_empty():
		return
	var damage := _damage()
	for i in _segments.size():
		var segment := _segments[i]
		var along := _flow - (i + 1) * _worm.segment_spacing
		var out := state != State.DEAD and phase != Phase.UNDER and along > 0.0 and along < _trail_length
		if out:
			segment.global_position = _point_on_trail(along)
			segment.face(_surge_dir)
		segment.set_out(out, damage)


func _point_on_trail(distance: float) -> Vector2:
	var left := distance
	for i in range(1, _trail.size()):
		var step := _trail[i - 1].distance_to(_trail[i])
		if left <= step:
			return _trail[i - 1].lerp(_trail[i], left / maxf(step, 0.001))
		left -= step
	return _trail[_trail.size() - 1]


## The pieces live in the worm's room (beside it, y-sorted with the actors); made the first time it
## surfaces because the room may still be adding its children during `_ready`.
func _ensure_segments() -> void:
	if not _segments.is_empty() or get_parent() == null:
		return
	for i in _worm.segment_count:
		var segment := WormSegment.create(_worm, i)
		segment.hurtbox.invulnerability_check = func() -> bool: return not is_out()
		segment.hurtbox.hit.connect(_on_hurtbox_hit)
		get_parent().add_child(segment)
		_segments.append(segment)


## Out: the head is a body Nico bumps into and a hurtbox; under: nothing at all.
func _set_head_out(out: bool) -> void:
	set_collision_layer_value(WormSegment.ENEMY_LAYER, out)
	_hurtbox.get_node("CollisionShape2D").set_deferred("disabled", not out)
	_tint_target().visible = out


func _on_died() -> void:
	super()
	# Dead pieces stop blocking at once and vanish with the head.
	_place_segments()


func _damage() -> int:
	return ceili(data.attack_damage * damage_multiplier)


func _motion_of(node: Node2D) -> Vector2:
	var motion = node.get("velocity")
	return motion if motion is Vector2 else Vector2.ZERO


# --- Animation ---------------------------------------------------------------------------------

## Burrowed there is nothing to animate. The trip out is drawn in three parts: `special` breaks the
## ground and raises it over its hole during the warning (it stays put there, still unhittable),
## `attack` is the lunge, stretched over the surge, and `idle` the rest; diving, `special` plays
## backwards over the time the body takes to flow into the hole. Out of an attack the base picks
## (`hurt` when hit).
func _update_animation() -> void:
	if _sprite == null or state == State.DEAD:
		return
	var emerging := state == State.ATTACK and phase in [Phase.RISING, Phase.SINKING]
	_sprite.visible = is_out() or emerging
	if not _sprite.visible:
		_shown = &""
		return
	if state != State.ATTACK:
		_shown = &""
		super()
		return
	var shown: StringName = &"rest"
	match phase:
		Phase.RISING:
			shown = &"rise"
		Phase.SURGING:
			shown = &"lunge"
		Phase.SINKING:
			shown = &"dive"
		Phase.RESTING:
			# A surge cut short by a wall still finishes its lunge before resting.
			if _shown == &"lunge" and _sprite.is_playing():
				shown = &"lunge"
	if phase == Phase.RISING and _target_is_valid():
		# It does not know its aim yet: it rises facing Nico, whom it will surge at.
		var to_target := target.global_position.x - global_position.x
		if absf(to_target) > 0.1:
			_sprite.flip_h = to_target < 0.0
	elif absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	if shown == _shown:
		return
	_shown = shown
	match shown:
		&"rise":
			_play_over(&"special", _worm.emerge_windup)
		&"lunge":
			_play_over(&"attack", _worm.surge_distance / maxf(_worm.surge_speed * _speed_scale(), 1.0))
		&"dive":
			var left := _trail_length + _worm.segment_count * _worm.segment_spacing - _flow
			_play_over(&"special", left / maxf(_worm.surge_speed * _speed_scale(), 1.0), true)
		_:
			_sprite.play(&"idle")
			_sprite.speed_scale = 1.0


## Plays `anim` once so that it lasts `span` seconds (backwards: from its last frame to its first).
func _play_over(anim: StringName, span: float, backwards := false) -> void:
	if backwards:
		_sprite.play_backwards(anim)
	else:
		_sprite.play(anim)
	_sprite.speed_scale = _animation_length(anim) / maxf(span, 0.05)


## The ground stirring over the worm: rings that spread and fade, drawn on the ground (its pixel art
## when it has one: one ripple cycle per pass over the strip).
class Ripple extends Node2D:
	var color := Color.ORANGE
	var radius := 9.0
	var speed := 1.0
	var art: Texture2D
	var _time := 0.0

	func _ready() -> void:
		z_index = RoomTheme.GROUND_FX_Z

	func _process(delta: float) -> void:
		_time += delta * speed
		queue_redraw()

	func _draw() -> void:
		if art != null:
			var cell := float(art.get_height())
			var count := maxi(int(art.get_width() / cell), 1)
			var frame := int(fmod(_time, 1.0) * count) % count
			draw_texture_rect_region(art, Rect2(-cell / 2.0, -cell / 2.0, cell, cell),
					Rect2(frame * cell, 0.0, cell, cell))
			return
		for i in RIPPLE_RINGS:
			var progress := fmod(_time + float(i) / RIPPLE_RINGS, 1.0)
			var ring := color
			ring.a = 0.7 * (1.0 - progress)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
			draw_arc(Vector2.ZERO, radius * (0.3 + progress), 0.0, TAU, 16, ring, 1.5)
