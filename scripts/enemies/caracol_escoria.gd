class_name SlagSnail
extends Enemy
## Caracol de escoria: very slow and very sturdy, with a weak bite, it leaves a burning trail of
## patches (GroundHazard) that hurt and slow Nico for a few seconds, so where it has crawled limits
## where he can walk. Everything tunable lives in its SlagSnailData.

var _snail: SlagSnailData
## Where it dropped its last patch.
var _last_drop := Vector2.ZERO


func _ready() -> void:
	super()
	_snail = data as SlagSnailData
	if _snail == null:
		push_error("SlagSnail '%s' needs a SlagSnailData." % name)
		_snail = SlagSnailData.new()
	_last_drop = global_position


func _process_patrol(delta: float) -> void:
	super(delta)
	_leave_trail()


func _process_chase(delta: float) -> void:
	super(delta)
	_leave_trail()


func _leave_trail() -> void:
	if global_position.distance_to(_last_drop) < _snail.trail_spacing:
		return
	var parent := get_parent() as Node2D
	if parent == null:
		return
	_last_drop = global_position
	var patch := GroundHazard.create(parent.to_local(global_position), _snail.trail_radius,
			_snail.trail_lifetime, ceili(_snail.trail_damage * damage_multiplier), _snail.trail_color)
	patch.tick = _snail.trail_tick
	patch.slow_factor = _snail.trail_slow_factor
	patch.slow_time = _snail.trail_slow_time
	patch.art = _snail.trail_art
	# mirrored at random so a long trail does not repeat one patch
	patch.art_flip = randf() < 0.5
	parent.add_child(patch)
