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


## tan(67.5) and tan(22.5): the 8 aim directions are 45 degree sectors around each axis/diagonal.
const AIM_VERTICAL_RATIO := 2.414
const AIM_HORIZONTAL_RATIO := 0.414


## The attack animation for a shot aimed in `direction` (8 directions). The art faces right and is
## mirrored for left (see attack_flips): `attack_side` for east/west, `attack_down` for south,
## `attack_down_side` for the south diagonals, `attack_up_side` for the north diagonals and
## `attack_up` for north. A missing animation falls back to `attack_side`.
static func attack_animation(direction: Vector2, frames: SpriteFrames) -> StringName:
	var ax := absf(direction.x)
	var ay := absf(direction.y)
	var name := &"attack_side"
	if ay > ax * AIM_VERTICAL_RATIO:
		name = &"attack_down" if direction.y > 0.0 else &"attack_up"
	elif ay > ax * AIM_HORIZONTAL_RATIO:
		name = &"attack_down_side" if direction.y > 0.0 else &"attack_up_side"
	return name if frames != null and frames.has_animation(name) else &"attack_side"


## Where the arrow leaves, from Nico's origin, for a pose facing right (the bow's position in that
## art; mirrored with the art). The poses hold the bow at different places: beside him in the front
## and three-quarter poses, on his left (the viewer's) in the back pose.
const MUZZLES := {
	&"attack_side": Vector2(9, 0),
	&"attack_down": Vector2(9, -2),
	&"attack_down_side": Vector2(9, -2),
	&"attack_up_side": Vector2(7, -3),
	&"attack_up": Vector2(-9, -3),
}


static func attack_muzzle(animation: StringName, flipped: bool) -> Vector2:
	var offset: Vector2 = MUZZLES.get(animation, MUZZLES[&"attack_side"])
	return Vector2(-offset.x if flipped else offset.x, offset.y)


## Whether the attack art is mirrored: it faces right, so any shot with a leftward part flips it.
static func attack_flips(direction: Vector2) -> bool:
	return direction.x < -0.1


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
