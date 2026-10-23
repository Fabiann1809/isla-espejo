class_name FacingView
extends RefCounted
## Which of Nico's three drawn views to show (side, down = front, up = back) for a movement
## direction. Pure logic, no nodes, so it can be tested on its own.
## Diagonals prefer the side view. While moving, switching needs one axis to beat the other by
## SWITCH_RATIO and a view is held at least MIN_HOLD seconds, so walking near 45 degrees does not
## flicker; a movement that starts from standing still picks its view fresh.

enum View { SIDE, DOWN, UP }

const SWITCH_RATIO := 1.3
const MIN_HOLD := 0.1

var view: View = View.DOWN
var _held := MIN_HOLD
var _was_moving := false


## Feeds the current movement direction (zero when standing still) and returns the view to show.
## Standing still keeps the view of the last movement.
func update(direction: Vector2, delta: float) -> View:
	_held += delta
	var starting := not _was_moving
	_was_moving = direction != Vector2.ZERO
	if direction == Vector2.ZERO or (_held < MIN_HOLD and not starting):
		return view
	var wanted := view
	var ax := absf(direction.x)
	var ay := absf(direction.y)
	if starting:
		# A fresh start has no view to hold on to: diagonals go to the side.
		wanted = View.SIDE
		if ay > ax * SWITCH_RATIO:
			wanted = View.DOWN if direction.y > 0.0 else View.UP
	elif view == View.SIDE:
		if ay > ax * SWITCH_RATIO:
			wanted = View.DOWN if direction.y > 0.0 else View.UP
	elif ax > ay * SWITCH_RATIO:
		wanted = View.SIDE
	elif ay > 0.0:
		# Already vertical: follow up/down turns right away.
		wanted = View.DOWN if direction.y > 0.0 else View.UP
	if wanted != view:
		view = wanted
		_held = 0.0
	return view


## Animation name for a base animation (`idle`, `walk`, `attack`) in a view: `walk_side`,
## `walk_down`, `walk_up`. A view without art falls back to `<base>_side`, then to the bare `<base>`.
static func animation_for(base: StringName, current_view: View, frames: SpriteFrames) -> StringName:
	var suffix := "_side"
	match current_view:
		View.DOWN:
			suffix = "_down"
		View.UP:
			suffix = "_up"
	for name: StringName in [StringName(String(base) + suffix), StringName(String(base) + "_side")]:
		if frames != null and frames.has_animation(name):
			return name
	return base
