class_name CrystalSalamander
extends Enemy
## Salamandra de cristal: it keeps to the edges of its room (patrol and repositioning spots lie a
## margin inside its borders) and, when Nico is in range, spits a hot crystal in a lob at where he
## stands: a warning circle marks the landing spot during the flight and the crystal leaves a patch
## (GroundHazard) that hurts and slows. The patches burn for as long as it lives: with `hazard_max`
## of them it stops spitting, and a crystal aimed too close to a patch lands just outside it. When it
## dies or leaves (its room goes away) its patches cool down and go out. Without a room it roams
## around its spot. Everything tunable lives in its CrystalSalamanderData.

var _salamander: CrystalSalamanderData
## Where it is running to while hunting, and for how much longer it tries.
var _spot := Vector2.ZERO
var _running := false
var _run_left := 0.0
var _rest_left := 0.0
## Its patches, burning or still in the air (a crystal's patch is made when it is thrown).
var _patches: Array[GroundHazard] = []


func _ready() -> void:
	super()
	_salamander = data as CrystalSalamanderData
	if _salamander == null:
		push_error("CrystalSalamander '%s' needs a CrystalSalamanderData." % name)
		_salamander = CrystalSalamanderData.new()
	died.connect(_put_out_patches)


func _exit_tree() -> void:
	_put_out_patches()


## Its patches still burning, landed or in the air (tests read them).
func patches() -> Array[GroundHazard]:
	var burning: Array[GroundHazard] = []
	for i in _patches.size():
		# Untyped: a patch that went away is a freed instance, which a typed variable refuses.
		var patch = _patches[i]
		if is_instance_valid(patch) and not patch.is_queued_for_deletion() and not patch.is_expiring():
			burning.append(patch)
	_patches = burning
	return burning


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
	if to_target.length() <= data.attack_range and _attack_cooldown_left == 0.0 and can_see(target) 			and _patch_spot(target.global_position).is_finite():
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
	var mouth := global_position + facing * _salamander.muzzle_distance
	var landing := target.global_position
	if mouth.distance_to(landing) > data.attack_range:
		landing = mouth + (landing - mouth).normalized() * data.attack_range
	landing = _patch_spot(landing)
	# Nico moved during the windup to where no patch fits: nothing is thrown.
	if not landing.is_finite():
		return
	Events.enemy_attacked.emit(self, &"shot")
	landing = parent.to_local(landing)
	parent.add_child(SkillZone.circle(landing, _salamander.hazard_radius, _salamander.warning_color,
			_salamander.flight_time))
	var hazard := _make_hazard(landing)
	_patches.append(hazard)
	_lob(parent, parent.to_local(mouth), landing, _salamander.flight_time, _salamander.lob_height,
			_make_crystal(), hazard, _salamander.crystal_art_fps)


## Where a crystal aimed at `aim` (world coordinates) leaves its patch: `aim`, or just outside the
## nearest patch that is too close, kept in its room. INF when the patches are at their maximum or
## the spot is still too close to another one.
func _patch_spot(aim: Vector2) -> Vector2:
	var centers := _patch_centers()
	if centers.size() >= _salamander.hazard_max:
		return Vector2.INF
	var spacing := _salamander.hazard_spacing
	var spot := aim
	var nearest := Vector2.INF
	for center: Vector2 in centers:
		if spot.distance_to(center) < spacing and spot.distance_to(center) < spot.distance_to(nearest):
			nearest = center
	if nearest.is_finite():
		var away := (spot - nearest).normalized()
		if away == Vector2.ZERO:
			away = Vector2.from_angle(randf() * TAU)
		spot = nearest + away * spacing
	if home_area.has_area():
		spot = spot.clamp(home_area.position, home_area.end)
	for center: Vector2 in centers:
		# a hair of slack: the slid spot lies exactly `spacing` away
		if spot.distance_to(center) < spacing - 0.5:
			return Vector2.INF
	return spot


## World centers of its burning patches; those in the air are not in the tree yet but already sit
## (in local coordinates) where they will land, in its parent.
func _patch_centers() -> Array[Vector2]:
	var centers: Array[Vector2] = []
	var parent := get_parent() as Node2D
	for patch: GroundHazard in patches():
		if patch.is_inside_tree():
			centers.append(patch.global_position)
		elif parent != null:
			centers.append(parent.to_global(patch.position))
	return centers


## The fight is over (it died or left): every patch it made cools down and goes out, also one whose
## crystal is still in the air (it lands already cooling).
func _put_out_patches() -> void:
	for i in _patches.size():
		var patch = _patches[i]
		if is_instance_valid(patch):
			patch.expire()
	# A new array, not clear(): patches() handed this one out.
	_patches = []


## A Polygon2D either way: with art it is a square showing one cell of the strip (its uv covers the
## first cell; `texture_offset` slides it to the others while it flies).
func _make_crystal() -> Polygon2D:
	var crystal := Polygon2D.new()
	crystal.name = "Crystal"
	var art := _salamander.crystal_art
	if art == null:
		var size := _salamander.crystal_size
		crystal.polygon = PackedVector2Array([Vector2(0, -size), Vector2(size, 0), Vector2(0, size), Vector2(-size, 0)])
		crystal.color = _salamander.crystal_color
		return crystal
	var cell := float(art.get_height())
	var half := cell / 2.0
	crystal.polygon = PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	crystal.uv = PackedVector2Array([Vector2.ZERO, Vector2(cell, 0.0), Vector2(cell, cell), Vector2(0.0, cell)])
	crystal.texture = art
	return crystal


func _make_hazard(at: Vector2) -> GroundHazard:
	# No lifetime: it burns until the salamander dies or leaves.
	var hazard := GroundHazard.create(at, _salamander.hazard_radius, 0.0,
			ceili(_salamander.hazard_damage * damage_multiplier), _salamander.hazard_color)
	hazard.expire_time = _salamander.hazard_cool_time
	hazard.tick = _salamander.hazard_tick
	hazard.slow_factor = _salamander.hazard_slow_factor
	hazard.slow_time = _salamander.hazard_slow_time
	hazard.art = _salamander.hazard_art
	# mirrored at random so patches side by side do not repeat
	hazard.art_flip = randf() < 0.5
	return hazard


## The flight lives in the room, not in the salamander: a crystal in the air still lands if the
## salamander dies meanwhile (its patch then only cools down and goes out). Static, so its callbacks
## do not hold the salamander.
static func _lob(parent: Node2D, from: Vector2, to: Vector2, flight: float, height: float,
		crystal: Polygon2D, hazard: GroundHazard, spin_fps: float) -> void:
	crystal.position = from
	parent.add_child(crystal)
	var tween := crystal.create_tween()
	tween.tween_property(crystal, "position", to, flight)
	tween.parallel().tween_property(crystal, "offset:y", -height, flight / 2.0) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(crystal, "offset:y", 0.0, flight / 2.0).set_delay(flight / 2.0) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if crystal.texture != null:
		var cell := float(crystal.texture.get_height())
		var count := maxi(floori(crystal.texture.get_width() / cell), 1)
		var spin := func(time: float) -> void:
			crystal.texture_offset.x = float(floori(time * spin_fps) % count) * cell
		tween.parallel().tween_method(spin, 0.0, flight, flight)
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
