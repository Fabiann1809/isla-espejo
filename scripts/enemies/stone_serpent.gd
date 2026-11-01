class_name StoneSerpent
extends Boss
## Serpiente de piedra (boss of chapter 2). Between attacks it slithers to another spot of its arena
## instead of walking at Nico, then:
## - CHARGE: warns a straight lane toward Nico on the ground, then dashes along it; whoever is in the
##   lane when it passes is hurt. Walls and the arena's edge cut the lane (and stop the dash).
## - SPIT: rears up with venom in its mouth (the warning) and spits a fan of slow poison orbs.
## Phase two (below half health): shorter warnings, more orbs and charges in a row.
## Super armor, territory and the rewards come from Boss; the numbers live in its SerpentData.

enum Attack { CHARGE, SPIT }

## Nico is caught by the dash this far ahead of the serpent's center along the lane (its head plus
## Nico's body: his body is shoved ahead by the serpent's, so he is never passed through) or behind it.
const CHARGE_REACH_AHEAD := 28.0
const CHARGE_REACH_BEHIND := 16.0
## Half the body's length: a dash toward a rock stops this far from it.
const BODY_HALF := 14.0
const ARRIVE_DISTANCE_ZONE := 6.0
## A chained charge (phase two) is only warned if its lane is at least this long.
const MIN_CHAIN_LANE := 48.0
## Extra seconds a dash may take over its lane's length at full speed.
const DASH_GRACE := 0.25

var attack: Attack = Attack.CHARGE

var _serpent: SerpentData
var _last_attack: Attack = Attack.SPIT
## Current lane of a charge (world coordinates) and its art.
var _lane_start := Vector2.ZERO
var _lane_dir := Vector2.RIGHT
var _lane_length := 0.0
var _lane: AttackLane
var _dashing := false
var _charge_hit := false
var _charges_done := 0
## Moving between zones: where it is going and how long it may still try.
var _zone := Vector2.ZERO
var _zone_left := 0.0
var _needs_zone := true
var _roar_left := 0.0


func _ready() -> void:
	super()
	_serpent = data as SerpentData
	if _serpent == null:
		push_error("StoneSerpent '%s' needs a SerpentData." % name)
		_serpent = SerpentData.new()


func _physics_process(delta: float) -> void:
	_roar_left = maxf(_roar_left - delta, 0.0)
	super(delta)
	if state != State.ATTACK:
		_dashing = false
		_clear_lane()


func _exit_tree() -> void:
	super()
	_clear_lane()


# --- Moving between zones ----------------------------------------------------------------------

func _process_chase(delta: float) -> void:
	if not _target_is_valid():
		return
	velocity = Vector2.ZERO
	if _roar_left > 0.0:
		return
	if _needs_zone:
		_needs_zone = false
		_zone = _choose_zone()
		_zone_left = _serpent.zone_move_time
	if _zone_left > 0.0:
		_zone_left -= delta
		var to_zone := _zone - global_position
		if to_zone.length() > ARRIVE_DISTANCE_ZONE:
			facing = to_zone.normalized()
			var boost := _boss.phase_two_speed if phase == 2 else 1.0
			velocity = facing * data.chase_speed * _speed_scale() * boost
			return
		_zone_left = 0.0
	facing = (target.global_position - global_position).normalized()
	if _attack_cooldown_left == 0.0:
		_start_attack()


## A spot of the arena away from where it is and not on top of Nico (best of a few random tries).
func _choose_zone() -> Vector2:
	var best := global_position
	var best_score := -INF
	for i in 10:
		var spot := _random_spot()
		var moved := spot.distance_to(global_position)
		var from_nico := spot.distance_to(target.global_position)
		var score := minf(moved, _serpent.zone_min_move * 2.0) + minf(from_nico, _serpent.zone_keep_distance * 1.5)
		if moved < _serpent.zone_min_move:
			score -= 100.0
		if from_nico < _serpent.zone_keep_distance:
			score -= 100.0
		if _world_hit(global_position, spot) < moved:
			score -= 50.0
		if score > best_score:
			best_score = score
			best = spot
	return best


## A random point of the arena: its room's floor (inside zone_spread of it), or the circle of
## arena_radius around home when it is not in a room.
func _random_spot() -> Vector2:
	var floor_rect := _arena_floor()
	if floor_rect.has_area():
		var inner := floor_rect.grow_individual(
				-floor_rect.size.x * (1.0 - _serpent.zone_spread) / 2.0, -floor_rect.size.y * (1.0 - _serpent.zone_spread) / 2.0,
				-floor_rect.size.x * (1.0 - _serpent.zone_spread) / 2.0, -floor_rect.size.y * (1.0 - _serpent.zone_spread) / 2.0)
		return Vector2(randf_range(inner.position.x, inner.end.x), randf_range(inner.position.y, inner.end.y))
	var offset := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * _boss.arena_radius * _serpent.zone_spread
	return _home + offset


# --- Attacks -----------------------------------------------------------------------------------

func _start_attack() -> void:
	var next := Attack.CHARGE if _last_attack == Attack.SPIT else Attack.SPIT
	# Now and then the same attack twice, so the rhythm cannot be counted.
	if randf() < 0.25:
		next = _last_attack
	_begin_attack(next)


func _begin_attack(which: Attack) -> void:
	attack = which
	_last_attack = which
	state = State.ATTACK
	velocity = Vector2.ZERO
	step = Step.WINDUP
	_dashing = false
	_charges_done = 0
	if attack == Attack.CHARGE:
		_warn_charge(_scaled(_serpent.charge_windup))
	else:
		_step_left = _scaled(_serpent.spit_windup)
		Events.boss_attack_warned.emit(_boss.id, _pattern_name())


func _process_attack(delta: float) -> void:
	if attack == Attack.CHARGE and step == Step.STRIKE:
		_process_dash(delta)
		return
	velocity = Vector2.ZERO
	if step == Step.WINDUP and attack == Attack.SPIT and _target_is_valid():
		facing = (target.global_position - global_position).normalized()
	_step_left -= delta
	if _step_left > 0.0:
		return
	match step:
		Step.WINDUP:
			_strike()
		Step.STRIKE:
			_recover()
		Step.RECOVER:
			_attack_cooldown_left = data.attack_cooldown
			_needs_zone = true
			_enter_chase_or_idle()


func _strike() -> void:
	step = Step.STRIKE
	Events.boss_attack_struck.emit(_boss.id, _pattern_name(), global_position)
	if attack == Attack.CHARGE:
		_dashing = true
		_charge_hit = false
		# Time limit of the dash: something the ray did not see (a body) can never hold it forever.
		_step_left = _lane_length / maxf(_serpent.charge_speed * _speed_scale(), 1.0) + DASH_GRACE
		if _lane != null:
			_lane.fade(_lane_length / maxf(_serpent.charge_speed, 1.0) + 0.15)
			_lane = null
	else:
		_spit()
		_step_left = _boss.strike_time


func _recover() -> void:
	step = Step.RECOVER
	_step_left = _boss.recover_time / (_boss.phase_two_speed if phase == 2 else 1.0)


## The warned lane: from the serpent toward Nico, cut by walls and the arena's edge.
func _warn_charge(windup: float) -> void:
	step = Step.WINDUP
	_step_left = windup
	if _target_is_valid():
		var to_target := target.global_position - global_position
		if to_target.length() > 1.0:
			facing = to_target.normalized()
	_lane_start = global_position
	_lane_dir = facing.normalized()
	_lane_length = _lane_reach(_lane_start, _lane_dir)
	_clear_lane()
	# The lane lives as long as the windup; the strike (or any cut-short attack) fades it.
	_lane = AttackLane.create(get_parent(), _lane_start, _lane_start + _lane_dir * _lane_length,
			_serpent.charge_width, WARNING_COLOR, windup + 0.5)
	Events.boss_attack_warned.emit(_boss.id, _pattern_name())


func _process_dash(delta: float) -> void:
	var travelled := (global_position - _lane_start).dot(_lane_dir)
	var remaining := _lane_length - travelled
	_step_left -= delta
	# Ran into a rock or a wall (the last move slid on it), the lane is done, or it is held back.
	if remaining <= 1.0 or (travelled > 2.0 and _hit_world()) or _step_left <= 0.0:
		velocity = Vector2.ZERO
		_end_dash()
		return
	_hurt_in_lane(travelled)
	var speed := _serpent.charge_speed * _speed_scale()
	velocity = _lane_dir * minf(speed, remaining / maxf(delta, 0.001))


## Nico is hurt if he is in the lane where the serpent's head passes.
func _hurt_in_lane(travelled: float) -> void:
	if _charge_hit or not _target_is_valid():
		return
	var to_player := target.global_position - _lane_start
	var along := to_player.dot(_lane_dir)
	var side := absf(to_player.cross(_lane_dir))
	var reached := along - travelled <= CHARGE_REACH_AHEAD and travelled - along <= CHARGE_REACH_BEHIND
	if side <= _serpent.charge_width / 2.0 and reached:
		_charge_hit = true
		var hurtbox := target.get_node_or_null("Hurtbox") as Hurtbox
		if hurtbox != null:
			hurtbox.receive_hit(ceili(_serpent.charge_damage * damage_multiplier), global_position)


func _end_dash() -> void:
	_dashing = false
	_charges_done += 1
	# In phase two it charges again at once, unless it is cornered (no room left for a real dash).
	if phase == 2 and _charges_done < _serpent.phase_two_charges and _target_is_valid():
		var to_target := target.global_position - global_position
		if to_target.length() > 1.0 and _lane_reach(global_position, to_target.normalized()) >= MIN_CHAIN_LANE:
			_warn_charge(_serpent.charge_chain_windup)
			return
	_recover()


## A fan of orbs aimed at Nico: spit_count of them (more in phase two), spit_gap_degrees apart.
func _spit() -> void:
	if _serpent.projectile_scene == null or get_parent() == null:
		return
	var aim := facing
	if _target_is_valid():
		aim = (target.global_position - global_position).normalized()
	var count := _orb_count()
	for i in count:
		var angle := deg_to_rad(_serpent.spit_gap_degrees) * (i - (count - 1) / 2.0)
		var direction := aim.rotated(angle)
		var orb: EnemyOrb = _serpent.projectile_scene.instantiate()
		orb.height_level = Heights.level_of(self)
		orb.setup(direction, _serpent.orb_speed, _serpent.orb_range, ceili(_serpent.orb_damage * damage_multiplier))
		orb.position = _local_to_room(global_position + direction * _serpent.muzzle_distance)
		get_parent().add_child(orb)


func _orb_count() -> int:
	return _serpent.spit_count + (_serpent.phase_two_extra_orbs if phase == 2 else 0)


func _pattern_name() -> StringName:
	return &"charge" if attack == Attack.CHARGE else &"spit"


func _enter_phase_two() -> void:
	super()
	if state != State.ATTACK:
		_roar_left = _serpent.phase_two_roar


# --- Geometry ----------------------------------------------------------------------------------

## How far a dash from `start` along `direction` can go: its length, cut by the arena circle, the
## arena's floor (when it is in a room) and the first wall or rock.
func _lane_reach(start: Vector2, direction: Vector2) -> float:
	var reach := _serpent.charge_length
	var floor_rect := _arena_floor()
	if floor_rect.has_area():
		reach = minf(reach, _rect_exit(floor_rect, start, direction))
	else:
		# Arena circle: where the line leaves the circle of arena_radius around home.
		var rel := start - _home
		var b := rel.dot(direction)
		var c := rel.length_squared() - _boss.arena_radius * _boss.arena_radius
		reach = minf(reach, maxf(-b + sqrt(maxf(b * b - c, 0.0)), 0.0))
	reach = minf(reach, _world_hit(start, start + direction * reach) - BODY_HALF)
	return maxf(reach, 0.0)


## Distance from `start` along `direction` to the edge of `rect`.
func _rect_exit(rect: Rect2, start: Vector2, direction: Vector2) -> float:
	var t := INF
	if direction.x > 0.001:
		t = minf(t, (rect.end.x - start.x) / direction.x)
	elif direction.x < -0.001:
		t = minf(t, (rect.position.x - start.x) / direction.x)
	if direction.y > 0.001:
		t = minf(t, (rect.end.y - start.y) / direction.y)
	elif direction.y < -0.001:
		t = minf(t, (rect.position.y - start.y) / direction.y)
	return maxf(t, 0.0)


## Distance from `from` to the first wall or rock on the way to `to` (INF if the way is clear).
func _world_hit(from: Vector2, to: Vector2) -> float:
	if from.distance_to(to) < 0.5:
		return INF
	var query := PhysicsRayQueryParameters2D.create(from, to, (1 << (WORLD_LAYER - 1)) | (1 << (WATER_LAYER - 1)))
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return INF if hit.is_empty() else from.distance_to(hit.position)


## The floor of its room (minus its margin, so it stays off the border trees and rocks) in world
## coordinates; empty when not in a room.
func _arena_floor() -> Rect2:
	var room := get_parent() as Node2D
	if room == null or not room.has_method("pixel_size"):
		return Rect2()
	return Rect2(room.global_position, room.pixel_size()).grow(-maxf(Tuning.ARENA_MARGIN, _serpent.floor_margin))


## In a room its arena is the whole floor (it slithers and charges from wall to wall); elsewhere
## the circle of arena_radius around home, like every boss.
func _enforce_territory() -> void:
	var floor_rect := _arena_floor()
	if not floor_rect.has_area():
		super()
	elif state != State.DEAD:
		global_position = global_position.clamp(floor_rect.position, floor_rect.end)


func _clear_lane() -> void:
	if _lane != null and is_instance_valid(_lane):
		_lane.fade(0.15)
	_lane = null


# --- Animation ---------------------------------------------------------------------------------

## Each step of an attack holds its own pose: charge = reared up, then the lunge while dashing;
## spit = venom in the mouth, then spitting; recovery = idle. Entering phase two it opens its hood.
func _update_animation() -> void:
	if _sprite == null or state == State.DEAD:
		return
	if state != State.ATTACK:
		if _roar_left > 0.0:
			_hold_pose(&"phase_two", 0)
			return
		super()
		return
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	_sprite.speed_scale = 1.0
	match step:
		Step.WINDUP:
			_hold_pose(&"charge_windup" if attack == Attack.CHARGE else &"spit_windup", 0)
		Step.STRIKE:
			_hold_pose(&"charge" if attack == Attack.CHARGE else &"spit", 0)
		Step.RECOVER:
			if _sprite.animation != &"idle" or not _sprite.is_playing():
				_sprite.play(&"idle")
