class_name CarvingSpider
extends Enemy
## Araña talladora: a stone construct that drills the floor. When Nico is within its reach it stops
## and drills (the special animation): the tiles under him and a few around him crack (the warning,
## a crack runs from its drill to each patch) and then sink for a few seconds into pits that hurt,
## holding Nico for a moment if he was on one when it sank (SinkingFloor). Between drills it scuttles
## fast to a new spot at its preferred distance from him. Everything tunable lives in its
## CarvingSpiderData.

var _spider: CarvingSpiderData
var _spot := Vector2.ZERO
var _running := false
var _run_left := 0.0
var _rest_left := 0.0


func _ready() -> void:
	super()
	_spider = data as CarvingSpiderData
	if _spider == null:
		push_error("CarvingSpider '%s' needs a CarvingSpiderData." % name)
		_spider = CarvingSpiderData.new()


## The spot it is scuttling to (tests read it), or its position when it is not running.
func current_spot() -> Vector2:
	return _spot if _running else global_position


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
		_run_left = _spider.reposition_time


func _run(delta: float) -> void:
	var to_spot := _spot - global_position
	_run_left -= delta
	if to_spot.length() <= ARRIVE_DISTANCE or _run_left <= 0.0:
		_running = false
		_rest_left = _spider.spot_wait
		velocity = Vector2.ZERO
		return
	facing = to_spot.normalized()
	velocity = facing * data.chase_speed * _speed_scale()


## The drill: the special animation over the windup, the floor cracks at its end.
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
			_drill()
			_attack_phase = AttackPhase.STRIKE
			_attack_time_left = data.attack_time
		AttackPhase.STRIKE:
			_attack_phase = AttackPhase.RECOVER
			_attack_time_left = data.attack_cooldown * 0.5
		AttackPhase.RECOVER:
			_attack_cooldown_left = data.attack_cooldown * 0.5
			# Straight off to another spot after drilling.
			_rest_left = 0.0
			_enter_chase_or_idle()


func _drill() -> void:
	var parent := get_parent() as Node2D
	if parent == null or not _target_is_valid():
		return
	Events.enemy_attacked.emit(self, &"melee")
	var damage := ceili(_spider.pit_damage * damage_multiplier)
	for spot in _pit_spots(target.global_position):
		parent.add_child(SinkingFloor.create(parent.to_local(spot), _spider, damage, parent.to_local(global_position)))


## Where the patches go (world positions): the first under Nico, the rest around him, none
## overlapping another, all inside its room.
func _pit_spots(center: Vector2) -> Array[Vector2]:
	var size: float = _spider.pit_tiles * TileArt.TILE
	var spots: Array[Vector2] = []
	var start_angle := randf() * TAU
	var count := maxi(_spider.pits_per_drill, 1)
	for i in count:
		var spot := center
		if i > 0:
			spot += Vector2.from_angle(start_angle + TAU * (i - 1) / maxf(count - 1, 1)) * _spider.pit_spread
		spot = _fit_pit(spot, size)
		var overlaps := false
		for other in spots:
			overlaps = overlaps or (absf(other.x - spot.x) < size and absf(other.y - spot.y) < size)
		if not overlaps:
			spots.append(spot)
	return spots


## On the floor's tile grid (when asked) and inside its room.
func _fit_pit(spot: Vector2, size: float) -> Vector2:
	if _spider.snap_to_tiles:
		# An even number of tiles is centered on a tile corner, an odd one on a tile's middle.
		var shift := 0.0 if _spider.pit_tiles % 2 == 0 else TileArt.TILE / 2.0
		spot = ((spot - Vector2.ONE * shift) / TileArt.TILE).round() * TileArt.TILE + Vector2.ONE * shift
	var inside := home_area.grow(-size / 2.0)
	if home_area.has_area() and inside.has_area():
		spot = spot.clamp(inside.position, inside.end)
	return spot


## The best of a few candidate spots: the one nearest its preferred distance from Nico.
func _choose_spot() -> Vector2:
	var best := global_position
	var best_score := INF
	var inside := home_area.grow(-_spider.room_margin)
	for i in maxi(_spider.reposition_samples, 1):
		var candidate := global_position + Vector2.from_angle(randf() * TAU) \
				* randf_range(0.4, 1.0) * _spider.reposition_distance
		if home_area.has_area() and inside.has_area():
			candidate = candidate.clamp(inside.position, inside.end)
		var score := absf(candidate.distance_to(target.global_position) - _spider.preferred_distance)
		if score < best_score:
			best_score = score
			best = candidate
	return best


## The drill plays `special` over the windup and the strike.
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
