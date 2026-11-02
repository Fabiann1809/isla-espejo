class_name CrystalSalamander
extends Enemy
## Salamandra de cristal: it keeps to the edges of its room (patrol and repositioning spots lie a
## margin inside its borders) and, when Nico is in range, spits a hot crystal in a lob at where he
## stands: a warning circle marks the landing spot during the flight and the crystal leaves a patch
## (GroundHazard) that hurts and slows for a few seconds. Without a room it roams around its spot.
## Everything tunable lives in its CrystalSalamanderData.

var _salamander: CrystalSalamanderData
## Where it is running to while hunting, and for how much longer it tries.
var _spot := Vector2.ZERO
var _running := false
var _run_left := 0.0
var _rest_left := 0.0


func _ready() -> void:
	super()
	_salamander = data as CrystalSalamanderData
	if _salamander == null:
		push_error("CrystalSalamander '%s' needs a CrystalSalamanderData." % name)
		_salamander = CrystalSalamanderData.new()


## The spot it is running to while hunting (tests read it), or its position when it is not running.
func current_spot() -> Vector2:
	return _spot if _running else global_position


## Patrol legs go to spots along its room's edges.
func _process_idle(delta: float) -> void:
	if not home_area.has_area() or data.patrol_radius * patrol_multiplier <= 0.0:
		super(delta)
		return
	velocity = Vector2.ZERO
	_wait_left -= delta
	if _wait_left <= 0.0:
		_patrol_point = _edge_point_near(global_position, data.patrol_radius * patrol_multiplier)
		_start_patrol_leg()
		state = State.PATROL


func _process_chase(delta: float) -> void:
	if not _target_is_valid():
		return
	var to_target := target.global_position - global_position
	if to_target.length() <= data.attack_range and _attack_cooldown_left == 0.0 and can_see(target):
		facing = to_target.normalized()
		_running = false
		_start_attack()
		return
	if _running:
		_run(delta)
		return
	velocity = Vector2.ZERO
	facing = to_target.normalized()
	_rest_left -= delta
	if _rest_left <= 0.0:
		_spot = _choose_spot()
		_running = true
		_run_left = _salamander.reposition_time


func _run(delta: float) -> void:
	var to_spot := _spot - global_position
	_run_left -= delta
	if to_spot.length() <= ARRIVE_DISTANCE or _run_left <= 0.0:
		_running = false
		_rest_left = _salamander.spot_wait
		velocity = Vector2.ZERO
		return
	facing = to_spot.normalized()
	velocity = facing * data.chase_speed * _speed_scale()


## The spit: the special animation warns, the crystal leaves at the end of the windup.
func _start_attack() -> void:
	state = State.ATTACK
	velocity = Vector2.ZERO
	_attack_phase = AttackPhase.WINDUP
	_attack_time_left = data.attack_windup


func _process_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	if _attack_phase == AttackPhase.WINDUP and _target_is_valid():
		facing = (target.global_position - global_position).normalized()
	_attack_time_left -= delta
	if _attack_time_left > 0.0:
		return
	match _attack_phase:
		AttackPhase.WINDUP:
			_spit()
			_attack_phase = AttackPhase.STRIKE
			_attack_time_left = data.attack_time
		AttackPhase.STRIKE:
			_attack_phase = AttackPhase.RECOVER
			_attack_time_left = data.attack_cooldown * 0.5
		AttackPhase.RECOVER:
			_attack_cooldown_left = data.attack_cooldown * 0.5
			# Straight off to another spot after spitting.
			_rest_left = 0.0
			_enter_chase_or_idle()


func _spit() -> void:
	var parent := get_parent() as Node2D
	if parent == null or not _target_is_valid():
		return
	Events.enemy_attacked.emit(self, &"shot")
	var mouth := global_position + facing * _salamander.muzzle_distance
	var landing := target.global_position
	if mouth.distance_to(landing) > data.attack_range:
		landing = mouth + (landing - mouth).normalized() * data.attack_range
	landing = parent.to_local(landing)
	parent.add_child(SkillZone.circle(landing, _salamander.hazard_radius, _salamander.warning_color,
			_salamander.flight_time))
	_lob(parent, parent.to_local(mouth), landing, _salamander.flight_time, _salamander.lob_height,
			_make_crystal(), _make_hazard(landing))


func _make_crystal() -> Polygon2D:
	var size := _salamander.crystal_size
	var crystal := Polygon2D.new()
	crystal.name = "Crystal"
	crystal.polygon = PackedVector2Array([Vector2(0, -size), Vector2(size, 0), Vector2(0, size), Vector2(-size, 0)])
	crystal.color = _salamander.crystal_color
	return crystal


func _make_hazard(at: Vector2) -> GroundHazard:
	var hazard := GroundHazard.create(at, _salamander.hazard_radius, _salamander.hazard_lifetime,
			ceili(_salamander.hazard_damage * damage_multiplier), _salamander.hazard_color)
	hazard.tick = _salamander.hazard_tick
	hazard.slow_factor = _salamander.hazard_slow_factor
	hazard.slow_time = _salamander.hazard_slow_time
	return hazard


## The flight lives in the room, not in the salamander: a crystal in the air still lands (and leaves
## its patch) if the salamander dies meanwhile. Static, so its callbacks do not hold the salamander.
static func _lob(parent: Node2D, from: Vector2, to: Vector2, flight: float, height: float,
		crystal: Polygon2D, hazard: GroundHazard) -> void:
	crystal.position = from
	parent.add_child(crystal)
	var tween := crystal.create_tween()
	tween.tween_property(crystal, "position", to, flight)
	tween.parallel().tween_property(crystal, "offset:y", -height, flight / 2.0) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(crystal, "offset:y", 0.0, flight / 2.0).set_delay(flight / 2.0) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		parent.add_child(hazard)
		crystal.queue_free())
	# The room went away with the crystal still in the air: the patch is never placed.
	crystal.tree_exiting.connect(func() -> void:
		if not hazard.is_inside_tree():
			hazard.free())


## The best of a few candidate spots: the one nearest its preferred distance from Nico.
func _choose_spot() -> Vector2:
	var best := global_position
	var best_score := INF
	for i in maxi(_salamander.reposition_samples, 1):
		var candidate := _edge_point_near(global_position, _salamander.reposition_distance)
		var score := absf(candidate.distance_to(target.global_position) - _salamander.preferred_distance)
		if score < best_score:
			best_score = score
			best = candidate
	return best


## A random point up to `reach` from `origin`, moved onto the nearest side of the line that runs
## `edge_margin` inside its room. Without a room, just the random point.
func _edge_point_near(origin: Vector2, reach: float) -> Vector2:
	var point := origin + Vector2.from_angle(randf() * TAU) * randf_range(0.3, 1.0) * reach
	var inside := home_area.grow(-_salamander.edge_margin)
	if not inside.has_area():
		return point
	point = point.clamp(inside.position, inside.end)
	var to_left := point.x - inside.position.x
	var to_right := inside.end.x - point.x
	var to_top := point.y - inside.position.y
	var to_bottom := inside.end.y - point.y
	var nearest := minf(minf(to_left, to_right), minf(to_top, to_bottom))
	if nearest == to_left:
		point.x = inside.position.x
	elif nearest == to_right:
		point.x = inside.end.x
	elif nearest == to_top:
		point.y = inside.position.y
	else:
		point.y = inside.end.y
	return point


## The spit plays `special` over the windup and the release.
func _update_animation() -> void:
	if _sprite == null or state != State.ATTACK:
		super()
		return
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	if _sprite.animation != &"special":
		_sprite.play(&"special")
		_anim_held = 0.0
		_sprite.speed_scale = _animation_length(&"special") / maxf(data.attack_windup + data.attack_time, 0.05)
