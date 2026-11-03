class_name AbyssHands
extends Enemy
## Manos del abismo: a hand of molten stone that lives under the edges of the platforms. Burrowed it
## is nothing: no art, no hurtbox. It comes out on the edge of its room nearest Nico (a warning circle
## and the special animation while it rises), its arm shoots out toward where he stood and, if the
## hand catches him, it hurts him and holds him in place for a moment (player.apply_pull; a dodge
## breaks free, and so does a hit on the hand). Then the arm winds back, the hand stays out at the
## edge for a while (it can be hit from when it reaches out until it sinks) and sinks again.
## Everything tunable lives in its AbyssHandsData.

enum Phase { UNDER, RISING, REACHING, HOLDING, RETRACTING, RESTING, SINKING }

## player.apply_pull lets go as soon as Nico is near its anchor: a hold whose hand is closer than this
## anchors this far away instead (the pull speed is meant to be about 0, so only the hold matters).
const HOLD_ANCHOR_MIN := 32.0
const GrabWarning := preload("res://scripts/enemies/manos_abismo_warning.gd")

var phase: Phase = Phase.UNDER

var _hands: AbyssHandsData
var _phase_left := 0.0
## Where the arm comes out of the ground, the way it reaches and how far out the hand is.
var _anchor := Vector2.ZERO
var _reach_dir := Vector2.RIGHT
var _reach_out := 0.0
var _victim: Node2D = null
var _shown_phase := -1
var _grab: Hitbox
var _arm: Line2D
var _arm_edge: Line2D
var _pool: Pool


func _ready() -> void:
	super()
	_hands = data as AbyssHandsData
	if _hands == null:
		push_error("AbyssHands '%s' needs an AbyssHandsData." % name)
		_hands = AbyssHandsData.new()
	_hurtbox.invulnerability_check = func() -> bool: return not is_out()
	_build_arm()
	_set_out(false)
	_anchor = global_position
	# It rests under the ground before coming out the first time too.
	_attack_cooldown_left = data.attack_cooldown
	if _sprite != null:
		_sprite.visible = false


func _physics_process(delta: float) -> void:
	super(delta)
	_update_arm()


## True while the hand is out of the ground and can be hit.
func is_out() -> bool:
	return phase in [Phase.REACHING, Phase.HOLDING, Phase.RETRACTING, Phase.RESTING]


## True while it holds Nico.
func is_holding() -> bool:
	return phase == Phase.HOLDING and _victim != null and is_instance_valid(_victim) \
			and _victim.has_method("is_pulled") and _victim.is_pulled()


## Where its arm comes out of the ground (world position).
func anchor() -> Vector2:
	return _anchor


## Under the ground nothing can push it.
func apply_knockback(push: Vector2) -> void:
	if is_out():
		super(push)


# --- Behaviour ---------------------------------------------------------------------------------

func _process_idle(delta: float) -> void:
	if not _settle():
		super(delta)


func _process_patrol(delta: float) -> void:
	if not _settle():
		super(delta)


## A hit lets Nico go.
func _process_hurt(delta: float) -> void:
	_release()
	super(delta)


## Burrowed, it waits under the ground for its rest to end and comes out again.
func _process_chase(_delta: float) -> void:
	if _settle() or not _target_is_valid():
		return
	velocity = Vector2.ZERO
	if _attack_cooldown_left == 0.0:
		_start_attack()


## The attack is the whole trip out: warning, reach, hold, wind back, rest and sink.
func _start_attack() -> void:
	state = State.ATTACK
	velocity = Vector2.ZERO
	phase = Phase.RISING
	_phase_left = data.attack_windup
	_anchor = _emerge_spot()
	global_position = _anchor
	_reach_out = 0.0
	if _target_is_valid():
		facing = (target.global_position - _anchor).normalized()
	var parent := get_parent() as Node2D
	if parent != null:
		var warning := GrabWarning.new()
		warning.shape = SkillZone.Shape.CIRCLE
		warning.position = parent.to_local(_anchor)
		warning.radius = _hands.warning_radius
		warning.color = _hands.warning_color
		warning.lifetime = data.attack_windup
		warning.art = _hands.warning_art
		warning.art_frames = maxi(_hands.warning_frames, 1)
		parent.add_child(warning)


func _process_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	_phase_left -= delta
	match phase:
		Phase.RISING:
			if _phase_left <= 0.0:
				_start_reach()
		Phase.REACHING:
			var next := _reach_out + _hands.reach_speed * _speed_scale() * delta
			var inside := home_area.grow(-_hands.edge_margin)
			var leaves_room := home_area.has_area() and not inside.grow(1.0).has_point(_anchor + _reach_dir * next)
			_reach_out = minf(next, _hands.reach_length)
			if not leaves_room:
				global_position = _anchor + _reach_dir * _reach_out
			if _reach_out >= _hands.reach_length or leaves_room:
				_start_retract()
		Phase.HOLDING:
			if _phase_left <= 0.0 or not is_holding():
				_start_retract()
		Phase.RETRACTING:
			_reach_out = maxf(_reach_out - _hands.retract_speed * _speed_scale() * delta, 0.0)
			global_position = _anchor + _reach_dir * _reach_out
			if _reach_out <= 0.0:
				phase = Phase.RESTING
				_phase_left = _hands.out_time
		Phase.RESTING:
			if _phase_left <= 0.0:
				phase = Phase.SINKING
				_phase_left = _hands.sink_time
				_set_out(false)
		Phase.SINKING:
			if _phase_left <= 0.0:
				_finish_sinking()
		Phase.UNDER:
			_enter_chase_or_idle()


func _start_reach() -> void:
	phase = Phase.REACHING
	if _target_is_valid() and target.global_position.distance_to(_anchor) > 0.5:
		_reach_dir = (target.global_position - _anchor).normalized()
	else:
		_reach_dir = facing
	facing = _reach_dir
	_set_out(true)
	_grab.damage = ceili(data.attack_damage * damage_multiplier)
	_grab.activate()
	Events.enemy_attacked.emit(self, &"melee")


func _on_grab(hurtbox: Hurtbox) -> void:
	if phase != Phase.REACHING:
		return
	_grab.deactivate()
	var victim := (hurtbox.owner if hurtbox.owner != null else hurtbox.get_parent()) as Node2D
	if victim == null or not victim.has_method("apply_pull"):
		_start_retract()
		return
	_victim = victim
	phase = Phase.HOLDING
	_phase_left = _hands.hold_time
	var hand := global_position + _hands.hand_offset
	var to_hand := hand - victim.global_position
	var hold_at := hand
	if to_hand.length() < HOLD_ANCHOR_MIN:
		var away := to_hand.normalized() if to_hand.length() > 0.01 else Vector2.DOWN
		hold_at = victim.global_position + away * HOLD_ANCHOR_MIN
	victim.apply_pull(hold_at, _hands.hold_pull_speed, _hands.hold_time)


func _start_retract() -> void:
	_release()
	if phase in [Phase.REACHING, Phase.HOLDING]:
		phase = Phase.RETRACTING


func _release() -> void:
	_grab.deactivate()
	if is_holding():
		# A pull of no time lets him go where he stands.
		_victim.apply_pull(_victim.global_position, 0.0, 0.0)
	_victim = null


func _finish_sinking() -> void:
	phase = Phase.UNDER
	_reach_out = 0.0
	_set_out(false)
	_attack_cooldown_left = maxf(_attack_cooldown_left, data.attack_cooldown)
	_enter_chase_or_idle()


## Called by the hooks outside its attack (a hit, a lost target): a hand still out winds back and
## sinks first. True if it is busy doing so.
func _settle() -> bool:
	match phase:
		Phase.UNDER:
			return false
		Phase.RISING:
			# Cut off during the warning: it simply stays under.
			phase = Phase.UNDER
			return false
	state = State.ATTACK
	_start_retract()
	return true


## The spot on the edge of its room nearest Nico, slid a little along it. Without a room, a spot
## `fallback_distance` from him on its own side.
func _emerge_spot() -> Vector2:
	var nico := target.global_position if _target_is_valid() else global_position
	var edge := home_area.grow(-_hands.edge_margin)
	if not home_area.has_area() or not edge.has_area():
		var side := global_position - nico
		return nico + (side.normalized() if side.length() > 0.01 else Vector2.RIGHT) * _hands.fallback_distance
	var spot := nico.clamp(edge.position, edge.end)
	var to_sides := [spot.x - edge.position.x, edge.end.x - spot.x, spot.y - edge.position.y, edge.end.y - spot.y]
	var nearest: int = to_sides.find(to_sides.min())
	var slide := randf_range(-_hands.edge_jitter, _hands.edge_jitter)
	if nearest < 2:
		spot.x = edge.position.x if nearest == 0 else edge.end.x
		spot.y = clampf(spot.y + slide, edge.position.y, edge.end.y)
	else:
		spot.y = edge.position.y if nearest == 2 else edge.end.y
		spot.x = clampf(spot.x + slide, edge.position.x, edge.end.x)
	return spot


## Out: the hand can be hit. Shapes change deferred because this runs in physics callbacks.
func _set_out(out: bool) -> void:
	_hurtbox.get_node("CollisionShape2D").set_deferred("disabled", not out)


func _on_died() -> void:
	_release()
	super()
	_arm.hide()
	_arm_edge.hide()


# --- Arm and looks -----------------------------------------------------------------------------

func _build_arm() -> void:
	_arm_edge = Line2D.new()
	_arm_edge.name = "ArmEdge"
	_arm_edge.width = _hands.arm_width + 2.0
	_arm_edge.default_color = _hands.arm_edge_color
	_arm_edge.begin_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_arm_edge)
	move_child(_arm_edge, 0)
	_arm = Line2D.new()
	_arm.name = "Arm"
	_arm.width = _hands.arm_width
	_arm.default_color = _hands.arm_color
	_arm.begin_cap_mode = Line2D.LINE_CAP_ROUND
	if _hands.arm_art != null:
		# The tile spans the arm and its glowing edge, so the edge line is not needed.
		_arm.width = _hands.arm_width + 2.0
		_arm.texture = _hands.arm_art
		_arm.texture_mode = Line2D.LINE_TEXTURE_TILE
		_arm.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_arm.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_arm.default_color = Color.WHITE
		_arm.begin_cap_mode = Line2D.LINE_CAP_NONE
	add_child(_arm)
	move_child(_arm, 1)
	_pool = Pool.new()
	_pool.name = "Pool"
	_pool.radius = _hands.pool_radius
	_pool.color = _hands.pool_color
	_pool.art = _hands.pool_art
	_pool.art_frames = maxi(_hands.pool_frames, 1)
	_pool.art_fps = _hands.pool_fps
	add_child(_pool)
	_grab = Hitbox.new()
	_grab.name = "GrabHitbox"
	_grab.collision_layer = 1 << 4
	_grab.collision_mask = 1 << 1
	_grab.position = _hands.hand_offset
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _hands.grab_radius
	shape.shape = circle
	_grab.add_child(shape)
	add_child(_grab)
	# The grab pushes Nico away from the hand itself.
	_grab.owner = self
	_grab.hit_landed.connect(_on_grab)


func _update_arm() -> void:
	var stretched := state != State.DEAD and _reach_out > 1.0 and phase != Phase.UNDER
	_arm.visible = stretched
	_arm_edge.visible = stretched and _hands.arm_art == null
	if stretched:
		var points := PackedVector2Array([to_local(_anchor), _hands.hand_offset])
		_arm.points = points
		_arm_edge.points = points
	_pool.visible = phase != Phase.UNDER and state != State.DEAD
	_pool.global_position = _anchor
	var shadow := get_node_or_null(^"Shadow") as CanvasItem
	if shadow != null:
		shadow.visible = phase != Phase.UNDER


## Burrowed there is nothing to show. It rises with `special`, reaches and holds with `attack`, waits
## with `idle` and sinks with `special` played backwards; the base picks `hurt`.
func _update_animation() -> void:
	if _sprite == null or state == State.DEAD:
		return
	_sprite.visible = phase != Phase.UNDER
	if phase == Phase.UNDER:
		_shown_phase = -1
		return
	if state == State.HURT:
		_shown_phase = -1
		super()
		return
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	if _shown_phase == phase:
		return
	_shown_phase = phase
	_sprite.speed_scale = 1.0
	match phase:
		Phase.RISING:
			_sprite.play(&"special")
			_sprite.speed_scale = _animation_length(&"special") / maxf(data.attack_windup, 0.05)
		Phase.REACHING, Phase.HOLDING:
			if _sprite.animation != &"attack":
				_sprite.play(&"attack")
		Phase.SINKING:
			_sprite.play_backwards(&"special")
			_sprite.speed_scale = _animation_length(&"special") / maxf(_hands.sink_time, 0.05)
		_:
			_sprite.play(&"idle")


## The molten pool the arm comes out of, lying on the ground: its looping strip, or shapes without
## one.
class Pool extends Node2D:
	## Radius (px) its strip is drawn at; other radii scale it.
	const ART_RADIUS := 11.0

	var radius := 10.0
	var color := Color.ORANGE
	var art: Texture2D
	var art_frames := 1
	var art_fps := 5.0
	var _time := 0.0

	func _ready() -> void:
		top_level = true
		z_as_relative = false
		z_index = RoomTheme.GROUND_FX_Z

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		if art != null:
			var cell := float(art.get_height())
			var frame := int(_time * art_fps) % art_frames
			var size := cell * radius / ART_RADIUS
			draw_texture_rect_region(art, Rect2(-size / 2.0, -size / 2.0, size, size),
					Rect2(frame * cell, 0, cell, cell))
			return
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, radius, Color(0.08, 0.03, 0.02, 0.85))
		var glow := 0.75 + 0.25 * sin(_time * 5.0)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(color, color.a * glow), 2.0)
		draw_circle(Vector2.ZERO, radius * 0.5, Color(color, color.a * 0.5 * glow))
