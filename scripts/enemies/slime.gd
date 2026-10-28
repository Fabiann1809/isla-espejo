class_name Slime
extends Enemy
## A slime: it always moves by hopping. It only advances while airborne (the stretched frames of
## its walk), so patrolling and chasing are the same squash-and-leap cycle, and it keeps hopping in
## place near the player. Its attack is a short lunge at close range, warned by a crouch.
## Everything tunable lives in its SlimeData.

var _slime: SlimeData
var _lunge_velocity := Vector2.ZERO


func _ready() -> void:
	super()
	_slime = data as SlimeData
	if _slime == null:
		push_error("Slime '%s' needs a SlimeData." % name)
		_slime = SlimeData.new()


func _process_patrol(delta: float) -> void:
	super(delta)
	_gate_by_hop()


func _process_chase(delta: float) -> void:
	super(delta)
	_gate_by_hop()


func _start_attack() -> void:
	super()
	_lunge_velocity = facing * _slime.leap_speed * _speed_scale()


func _process_attack(delta: float) -> void:
	super(delta)
	# The base attack stands still; the strike phase is the lunge.
	if _attack_phase == AttackPhase.STRIKE:
		velocity = _lunge_velocity


## Walking and chasing hop the whole time (never idle), at the pace the cycle was drawn for.
func _update_animation() -> void:
	if _sprite == null or state not in [State.PATROL, State.CHASE]:
		super()
		return
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	if _sprite.animation != &"walk":
		_sprite.play(&"walk")
	_sprite.speed_scale = 1.0


## Moves only in the airborne frames, faster so the average speed stays the data's speed.
func _gate_by_hop() -> void:
	if _sprite == null or _sprite.animation != &"walk":
		velocity = Vector2.ZERO
		return
	var last := mini(_slime.air_last_frame, _sprite.sprite_frames.get_frame_count(&"walk") - 1)
	var air_frames := last - _slime.air_first_frame + 1
	if _sprite.frame < _slime.air_first_frame or _sprite.frame > last:
		velocity = Vector2.ZERO
	else:
		velocity *= float(_sprite.sprite_frames.get_frame_count(&"walk")) / maxf(air_frames, 1.0)
