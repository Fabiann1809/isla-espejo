class_name Teleporter
extends Enemy
## An enemy that appears and disappears (the Sombra errante). When it sees the player at mid range it
## fades out (it cannot be hit once half faded: arrows go through it), a circle on the ground warns
## where it will come back, and it reappears behind or beside the player, then strikes like a melee
## enemy (its own telegraph). The arrival spot is always free ground (no wall, tree or pond) inside
## its room and in the open from the player; with no such spot it stays and walks instead. Up close
## it just strikes. Everything tunable lives in its TeleporterData.

enum Blink { NONE, FADE, HIDDEN, APPEAR }

## What blocks an arrival spot: whatever blocks its body (the world, the ponds and the ledges of
## its height level), so it never lands inside a terrace or a bridge.
## Angles tried around the spot behind the player (radians): behind first, then the sides.
const ARRIVAL_ANGLES := [0.0, PI / 2.0, PI / 4.0, 3.0 * PI / 4.0, PI]

var blink := Blink.NONE
var _tele: TeleporterData
var _blink_left := 0.0
var _teleport_cooldown_left := 0.0
var _teleport_requested := false
var _faded := false
var _arrival := Vector2.ZERO
var _warning: Node2D


func _ready() -> void:
	super()
	_tele = data as TeleporterData
	if _tele == null:
		push_error("Teleporter '%s' needs a TeleporterData." % name)
		_tele = TeleporterData.new()
	_hurtbox.invulnerability_check = func() -> bool: return _faded


func _physics_process(delta: float) -> void:
	_teleport_cooldown_left = maxf(_teleport_cooldown_left - delta, 0.0)
	super(delta)
	# A push or Nico leaving its room cut the teleport short: it shows up where it is.
	if blink != Blink.NONE and state != State.ATTACK:
		_end_blink()


## True while it cannot be hit (half faded, hidden or coming back).
func is_faded() -> bool:
	return _faded


## Where the current (or last) teleport lands, in world coordinates.
func arrival_point() -> Vector2:
	return _arrival


func _process_chase(delta: float) -> void:
	if _target_is_valid() and _can_teleport():
		_teleport_requested = true
		_start_attack()
		return
	super(delta)


func _can_teleport() -> bool:
	if _teleport_cooldown_left > 0.0 or _attack_cooldown_left > 0.0:
		return false
	var distance := global_position.distance_to(target.global_position)
	return distance <= _tele.teleport_range and distance > _tele.teleport_min_range and can_see(target)


func _start_attack() -> void:
	super()
	if not _teleport_requested:
		return
	_teleport_requested = false
	_telegraph.hide()
	blink = Blink.FADE
	_blink_left = _tele.fade_time
	_play_teleport(false, _tele.fade_time)


func _process_attack(delta: float) -> void:
	if blink == Blink.NONE:
		super(delta)
		return
	velocity = Vector2.ZERO
	_blink_left -= delta
	match blink:
		Blink.FADE:
			var progress := 1.0 - clampf(_blink_left / maxf(_tele.fade_time, 0.01), 0.0, 1.0)
			modulate.a = 1.0 - progress
			_faded = progress >= 0.5
			if _blink_left <= 0.0:
				_vanish()
		Blink.HIDDEN:
			if _blink_left <= 0.0:
				Placement.teleport(self, _arrival)
				_collision.set_deferred("disabled", false)
				_face_target()
				blink = Blink.APPEAR
				_blink_left = _tele.appear_time
				_play_teleport(true, _tele.appear_time)
		Blink.APPEAR:
			modulate.a = 1.0 - clampf(_blink_left / maxf(_tele.appear_time, 0.01), 0.0, 1.0)
			if _blink_left <= 0.0:
				_strike_after_teleport()


## Fully faded: pick the arrival spot and warn it, or give up and show up again where it is.
func _vanish() -> void:
	if not _target_is_valid():
		return
	if not _find_arrival():
		_end_blink()
		_teleport_cooldown_left = _tele.teleport_cooldown * 0.5
		_enter_chase_or_idle()
		return
	modulate.a = 0.0
	blink = Blink.HIDDEN
	_blink_left = _tele.hidden_time
	# Gone from the floor too: Nico walking through the spot bumps into nothing.
	_collision.set_deferred("disabled", true)
	var parent := get_parent() as Node2D
	if parent != null:
		_warning = SkillZone.circle(parent.to_local(_arrival), _tele.warn_radius, _tele.warn_color,
				_tele.hidden_time + _tele.appear_time)
		parent.add_child(_warning)


## Back in full view next to the player: the normal melee windup and strike follow.
func _strike_after_teleport() -> void:
	_end_blink()
	_teleport_cooldown_left = _tele.teleport_cooldown
	_face_target()
	_pivot.rotation = facing.angle()
	_attack_phase = AttackPhase.WINDUP
	_attack_time_left = data.attack_windup
	_telegraph.show()


## Behind the player (opposite to where they look), else beside, else in front: the first spot that
## is inside its room, free of walls and ponds and in the open from the player.
func _find_arrival() -> bool:
	var center := target.global_position
	var look = target.get("facing")
	var behind: Vector2 = -(look as Vector2) if look is Vector2 and look != Vector2.ZERO \
			else (center - global_position).normalized()
	var side := 1.0 if randf() < 0.5 else -1.0
	for angle: float in ARRIVAL_ANGLES:
		for turn in ([angle] if angle == 0.0 or angle == PI else [angle * side, -angle * side]):
			var spot: Vector2 = center + behind.rotated(turn) * _tele.appear_distance
			if _dash_allowed(spot) and _spot_free(spot) and _in_the_open(center, spot):
				_arrival = spot
				return true
	return false


func _spot_free(spot: Vector2) -> bool:
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = _collision.shape
	params.transform = Transform2D(0.0, spot)
	params.collision_mask = collision_mask
	params.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(params, 1).is_empty()


func _in_the_open(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1 << (WORLD_LAYER - 1))
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _face_target() -> void:
	if _target_is_valid() and target.global_position != global_position:
		facing = (target.global_position - global_position).normalized()


func _end_blink() -> void:
	blink = Blink.NONE
	_faded = false
	modulate.a = 1.0
	if is_instance_valid(_warning):
		_warning.queue_free()
	_warning = null


## The fade uses its `teleport` animation (backwards to come back), fit to the phase's time.
func _play_teleport(backwards: bool, seconds: float) -> void:
	if _sprite == null or not _sprite.sprite_frames.has_animation(&"teleport"):
		return
	_sprite.speed_scale = _animation_length(&"teleport") / maxf(seconds, 0.05)
	if backwards:
		_sprite.play_backwards(&"teleport")
	else:
		_sprite.play(&"teleport")


func _update_animation() -> void:
	if blink == Blink.NONE or _sprite == null or state == State.DEAD:
		super()
		return
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
