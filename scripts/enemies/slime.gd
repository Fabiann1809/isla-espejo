class_name Slime
extends Enemy
## A slime: chases like any enemy but attacks by crouching (the telegraph) and then leaping at the
## spot where the player stood. The direction is locked at the start of the windup, so moving
## sideways dodges it. Everything tunable lives in its SlimeData.

var _slime: SlimeData
var _leap_velocity := Vector2.ZERO


func _ready() -> void:
	super()
	_slime = data as SlimeData
	if _slime == null:
		push_error("Slime '%s' needs a SlimeData." % name)
		_slime = SlimeData.new()


func _start_attack() -> void:
	super()
	_leap_velocity = facing * _slime.leap_speed * _speed_scale()


func _process_attack(delta: float) -> void:
	super(delta)
	# The base attack stands still; the strike phase is the jump.
	if _attack_phase == AttackPhase.STRIKE:
		velocity = _leap_velocity
