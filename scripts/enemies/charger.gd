class_name Charger
extends Enemy
## A pack hunter that charges (the Bestia de la niebla). When one notices the player its mates of the
## same room nearby join the hunt; they spread around the player (one straight in, the others to the
## sides) instead of queueing behind each other. In range and in sight it stops and crouches while a
## wide lane on the ground shows its path (the lane follows the player and locks just before the
## charge), then rushes along it at high speed, past the player. Crashing into a wall stuns it for a
## moment. Mates take turns (`EnemyPack`), so a pack charges from several sides one after another.
## Everything tunable lives in its ChargerData.

var _charger: ChargerData
var _charge_dir := Vector2.RIGHT
var _charge_length := 0.0
var _lane: AttackLane
var _in_range_time := 0.0


func _ready() -> void:
	super()
	_charger = data as ChargerData
	if _charger == null:
		push_error("Charger '%s' needs a ChargerData." % name)
		_charger = ChargerData.new()
	player_detected.connect(_on_player_detected)


func _physics_process(delta: float) -> void:
	super(delta)
	if _lane != null and not (state == State.ATTACK and _attack_phase == AttackPhase.WINDUP):
		_clear_warning()


## A mate noticed the player: hunt too, if the player is in this beast's room.
func join_hunt(player: Node2D) -> void:
	if state == State.DEAD or target != null or not _in_territory(player.global_position):
		return
	_acquire_target(player)


## True while it warns or charges (for tests and the pack).
func is_charging() -> bool:
	return state == State.ATTACK and _attack_phase in [AttackPhase.WINDUP, AttackPhase.STRIKE]


## Its place around the player: the first hunter goes straight in, the others to alternating sides.
func flank_point() -> Vector2:
	var hunters: Array[Enemy] = [self]
	for mate in EnemyPack.mates(self):
		if mate.target == target:
			hunters.append(mate)
	hunters.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.get_instance_id() < b.get_instance_id())
	var slot := hunters.find(self)
	if slot == 0:
		return target.global_position
	var lead := (hunters[0].global_position - target.global_position).angle()
	var step := floorf((slot + 1) / 2.0)
	var side := 1.0 if slot % 2 == 1 else -1.0
	var angle := lead + side * step * deg_to_rad(_charger.flank_spread_degrees)
	return target.global_position + Vector2.from_angle(angle) * _charger.flank_distance


func _process_chase(delta: float) -> void:
	if not _target_is_valid():
		return
	var to_target := target.global_position - global_position
	var distance := to_target.length()
	if distance > 0.01:
		facing = to_target / distance
	var goal := flank_point()
	var flanking := goal != target.global_position
	_in_range_time = _in_range_time + delta if distance <= _charger.charge_trigger_range else 0.0
	var placed := not flanking or global_position.distance_to(goal) <= _charger.flank_tolerance \
			or _in_range_time >= _charger.flank_patience
	if distance <= _charger.charge_trigger_range and placed and _attack_cooldown_left == 0.0 \
			and can_see(target) and EnemyPack.my_turn(self, _charger.pack_gap):
		_start_attack()
		return
	var to_goal := goal - global_position
	if not flanking and distance <= data.attack_range:
		velocity = Vector2.ZERO
	elif to_goal.length() > ARRIVE_DISTANCE:
		velocity = to_goal.normalized() * data.chase_speed * _speed_scale()
	else:
		velocity = Vector2.ZERO


func _start_attack() -> void:
	super()
	_telegraph.hide()
	_in_range_time = 0.0
	EnemyPack.mark_strike(self)
	_aim()
	if get_parent() is Node2D:
		_lane = AttackLane.create(get_parent(), global_position, _lane_end(), _charger.lane_width,
				_charger.warn_color, data.attack_windup)


func _process_attack(delta: float) -> void:
	_attack_time_left -= delta
	match _attack_phase:
		AttackPhase.WINDUP:
			velocity = Vector2.ZERO
			if _attack_time_left > _charger.aim_lock_time:
				_aim()
				if _lane != null:
					_lane.aim(global_position, _lane_end())
			if _attack_time_left <= 0.0:
				_launch()
		AttackPhase.STRIKE:
			velocity = _charge_dir * _charger.charge_speed * _speed_scale()
			var crashed := _hit_world()
			var at_edge := not _dash_allowed(global_position + velocity * get_physics_process_delta_time())
			if _attack_time_left <= 0.0 or crashed or at_edge:
				_end_charge(crashed)
		AttackPhase.RECOVER:
			# It skids to a stop.
			velocity = velocity.move_toward(Vector2.ZERO, _charger.charge_speed * 3.0 * delta)
			if _attack_time_left <= 0.0:
				_attack_cooldown_left = data.attack_cooldown * 0.5
				_enter_chase_or_idle()


func _launch() -> void:
	_clear_warning()
	facing = _charge_dir
	_pivot.rotation = facing.angle()
	_hitbox.damage = ceili(data.attack_damage * damage_multiplier)
	_hitbox.activate()
	Events.enemy_attacked.emit(self, &"charge")
	_attack_phase = AttackPhase.STRIKE
	# Same distance whatever the director's speed: a faster beast only gets there sooner.
	_attack_time_left = _charge_length / maxf(_charger.charge_speed * _speed_scale(), 1.0)


func _end_charge(crashed: bool) -> void:
	_hitbox.deactivate()
	_attack_phase = AttackPhase.RECOVER
	_attack_time_left = data.attack_cooldown * 0.5 + (_charger.wall_stun if crashed else 0.0)
	velocity = Vector2.ZERO if crashed else _charge_dir * _charger.charge_speed * _speed_scale() * 0.4


## Aims at the player: through them and `charge_overshoot` past, at most `attack_time` of charge.
func _aim() -> void:
	if not _target_is_valid() or target.global_position == global_position:
		_charge_length = _charger.charge_speed * data.attack_time
		return
	var to_target := target.global_position - global_position
	_charge_dir = to_target.normalized()
	facing = _charge_dir
	_charge_length = minf(to_target.length() + _charger.charge_overshoot, _charger.charge_speed * data.attack_time)


func _lane_end() -> Vector2:
	return global_position + _charge_dir * _charge_length


func _clear_warning() -> void:
	if is_instance_valid(_lane):
		_lane.queue_free()
	_lane = null


func _on_player_detected(player: Node2D) -> void:
	for mate in EnemyPack.mates(self):
		if mate.global_position.distance_to(global_position) <= _charger.pack_alert_range and mate.has_method("join_hunt"):
			mate.join_hunt(player)
