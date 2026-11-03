class_name DoomedForger
extends Enemy
## Forjador condenado: a spectral smith. When it sees Nico within its reach it raises its arms (the
## special animation) and calls glowing iron blocks down: warning circles mark where they fall, the
## first on Nico and the rest around him. A block hurts on impact and then stands as a solid obstacle
## until it cools down (IronBlock), so the room fills with walls for a while; it never drops one in a
## door lane of its room, and a block that would land on somebody shatters instead of shutting him
## in. Up close it swings its hammer (the normal melee attack). Everything tunable lives in its
## DoomedForgerData.

var _forger: DoomedForgerData
var _blocks: Array[IronBlock] = []
var _drop_cooldown_left := 0.0
## The current attack is a drop, not the hammer swing.
var _dropping := false


func _ready() -> void:
	super()
	_forger = data as DoomedForgerData
	if _forger == null:
		push_error("DoomedForger '%s' needs a DoomedForgerData." % name)
		_forger = DoomedForgerData.new()


func _physics_process(delta: float) -> void:
	_drop_cooldown_left = maxf(_drop_cooldown_left - delta, 0.0)
	super(delta)
	# A hit, a push or a lost target ends the drop before the blocks are called.
	if _dropping and state != State.ATTACK:
		_dropping = false


## Its blocks still falling or standing.
func blocks() -> Array[IronBlock]:
	var standing: Array[IronBlock] = []
	for i in _blocks.size():
		# Untyped: a block that went away is a freed instance, which a typed variable refuses.
		var block = _blocks[i]
		if is_instance_valid(block) and not block.is_queued_for_deletion():
			standing.append(block)
	_blocks = standing
	return standing.duplicate()


func is_dropping() -> bool:
	return _dropping


func _process_chase(delta: float) -> void:
	if _target_is_valid() and _can_drop():
		_start_drop()
		return
	super(delta)


func _can_drop() -> bool:
	return _drop_cooldown_left == 0.0 and _attack_cooldown_left == 0.0 \
			and global_position.distance_to(target.global_position) <= _forger.drop_range \
			and blocks().size() < _forger.max_blocks and can_see(target)


func _start_drop() -> void:
	state = State.ATTACK
	velocity = Vector2.ZERO
	_dropping = true
	_attack_phase = AttackPhase.WINDUP
	_attack_time_left = _forger.drop_windup
	facing = (target.global_position - global_position).normalized()


func _process_attack(delta: float) -> void:
	if not _dropping:
		super(delta)
		return
	velocity = Vector2.ZERO
	_attack_time_left -= delta
	if _attack_time_left > 0.0:
		return
	match _attack_phase:
		AttackPhase.WINDUP:
			_drop_blocks()
			_attack_phase = AttackPhase.STRIKE
			_attack_time_left = data.attack_time
		AttackPhase.STRIKE:
			_attack_phase = AttackPhase.RECOVER
			_attack_time_left = data.attack_cooldown * 0.5
		AttackPhase.RECOVER:
			_dropping = false
			_drop_cooldown_left = _forger.drop_cooldown
			_attack_cooldown_left = data.attack_cooldown * 0.5
			_enter_chase_or_idle()


func _drop_blocks() -> void:
	var parent := get_parent() as Node2D
	if parent == null or not _target_is_valid():
		return
	var room_left := _forger.max_blocks - blocks().size()
	var spots := _drop_spots(target.global_position, mini(_forger.blocks_per_drop, room_left))
	if spots.is_empty():
		return
	Events.enemy_attacked.emit(self, &"shot")
	var damage := ceili(_forger.impact_damage * damage_multiplier)
	var warning_radius := _forger.block_size.length() / 2.0 + _forger.impact_margin
	for spot in spots:
		var local := parent.to_local(spot)
		parent.add_child(SkillZone.circle(local, warning_radius, _forger.warning_color, _forger.fall_time))
		var block := IronBlock.create(local, _forger, damage)
		parent.add_child(block)
		_blocks.append(block)


## Up to `count` landing spots (world positions): the first on Nico, the rest around him, each moved
## out of the door lanes and kept inside its room, none touching another block.
func _drop_spots(center: Vector2, count: int) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	var tries := maxi(_forger.blocks_per_drop, count)
	var start_angle := randf() * TAU
	for i in tries:
		if spots.size() >= count:
			break
		var candidate := center
		if i > 0:
			candidate += Vector2.from_angle(start_angle + TAU * (i - 1) / maxf(tries - 1, 1)) * _forger.drop_spread
		var spot := _legal_spot(candidate)
		if spot.is_finite() and _clear_of_blocks(spot, spots):
			spots.append(spot)
	return spots


## `point` kept inside its room and out of its door lanes; Vector2.INF if the room has no such place.
func _legal_spot(point: Vector2) -> Vector2:
	if not home_area.has_area():
		return point
	var half := _forger.block_size / 2.0
	var inside := home_area.grow(-_forger.room_margin)
	inside = Rect2(inside.position + half, inside.size - half * 2.0)
	if not inside.has_area():
		return Vector2.INF
	point = point.clamp(inside.position, inside.end)
	var middle := home_area.get_center()
	point.x = _out_of_lane(point.x, middle.x, _forger.door_lane_half_width + half.x)
	point.y = _out_of_lane(point.y, middle.y, _forger.door_lane_half_width + half.y)
	return point if inside.grow(0.01).has_point(point) else Vector2.INF


## A coordinate moved to the nearer side of a lane that spans `reach` each side of `middle`.
static func _out_of_lane(value: float, middle: float, reach: float) -> float:
	if absf(value - middle) >= reach:
		return value
	return middle + (reach if value >= middle else -reach)


func _clear_of_blocks(spot: Vector2, chosen: Array[Vector2]) -> bool:
	var taken: Array[Vector2] = chosen.duplicate()
	for block in blocks():
		taken.append(block.global_position)
	for other in taken:
		if absf(other.x - spot.x) < _forger.block_size.x + 2.0 and absf(other.y - spot.y) < _forger.block_size.y + 2.0:
			return false
	return true


## The drop plays `special` over the windup and the release; the hammer keeps `attack`.
func _update_animation() -> void:
	if _sprite == null or state != State.ATTACK or not _dropping:
		super()
		return
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	if _sprite.animation != &"special":
		_sprite.play(&"special")
		_anim_held = 0.0
		_sprite.speed_scale = _animation_length(&"special") / maxf(_forger.drop_windup + data.attack_time, 0.05)
