class_name AshOracle
extends Enemy
## Oráculo de ceniza: keeps its distance and reads where Nico is heading. It raises its staff, marks
## the spot where he will be if he keeps his course (a warning circle on the floor) and a fireball
## falls there; the impact hurts only inside the circle, so changing course dodges it. A hit during
## the staff raise cancels the cast; once marked, the fireball lands anyway.
## Everything tunable lives in its AshOracleData.

enum Cast { WINDUP, RECOVER }

## Turns (radians) tried, in order, when the straight way back would leave the room or hit a wall.
const RETREAT_TURNS: Array[float] = [0.0, PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0]
## The falling ball's look without art: a soft halo (px wider than the ball) and a bright core.
const BALL_GLOW := 1.0
const BALL_GLOW_ALPHA := 0.5
const BALL_CORE_SCALE := 0.5
## Layout of its art strips (see tools/make_oraculo_ceniza_art.py).
const BALL_CENTER := Vector2(12, 17)
const BALL_FPS := 12.0
const SEAL_OPEN_FRAMES := 3
const SEAL_FPS := 10.0
## Radius of the seal's ring in its art: it is scaled to the strike's radius (1:1 at 22 px).
const SEAL_ART_RADIUS := 22.0
## Where the landing is centered in a burst cell (its blast also has a 22 px radius).
const BURST_CENTER := Vector2(32, 40)

var cast_step: Cast = Cast.WINDUP

var _oracle: AshOracleData
var _step_left := 0.0
## The fireball on its way (null when none): where it lands (world), how long it has been falling,
## its mark on the ground and its picture in the air.
var _ball: Node2D
var _ball_center := Vector2.ZERO
var _ball_age := 0.0
var _mark: Node2D
var _seal: Node2D
var _burst: Node2D
var _burst_age := 0.0
var _impact: Hitbox
var _impact_left := 0.0


func _ready() -> void:
	super()
	_oracle = data as AshOracleData
	if _oracle == null:
		push_error("AshOracle '%s' needs an AshOracleData." % name)
		_oracle = AshOracleData.new()


func _physics_process(delta: float) -> void:
	super(delta)
	_update_fireball(delta)
	_update_impact(delta)
	_update_burst(delta)


func _exit_tree() -> void:
	_clear_fireball()
	_clear_impact()
	# Its zone frees itself, but nobody would animate the art left on it.
	if is_instance_valid(_burst):
		_burst.queue_free()
	_burst = null


## Where the current fireball will land (world), or null when none is falling.
func fireball_target() -> Variant:
	return _ball_center if _ball != null else null


# --- Behaviour ---------------------------------------------------------------------------------

func _process_chase(_delta: float) -> void:
	if not _target_is_valid():
		return
	var to_target := target.global_position - global_position
	var distance := to_target.length()
	facing = to_target.normalized()
	if distance <= data.attack_range and _attack_cooldown_left == 0.0 and can_see(target):
		_start_attack()
		return
	velocity = Vector2.ZERO
	if distance < _oracle.preferred_distance:
		velocity = _retreat_direction(-facing) * _oracle.retreat_speed * _speed_scale()
	elif distance > _oracle.approach_distance:
		velocity = facing * data.chase_speed * _speed_scale()


## The first way back that stays in the room and is not blocked, or zero when it is cornered.
func _retreat_direction(away: Vector2) -> Vector2:
	for turn in RETREAT_TURNS:
		var direction := away.rotated(turn)
		var step := direction * _oracle.retreat_lookahead
		if _dash_allowed(global_position + step) and not test_move(global_transform, step):
			return direction
	return Vector2.ZERO


func _start_attack() -> void:
	super()
	_telegraph.hide()
	cast_step = Cast.WINDUP
	_step_left = data.attack_windup


func _process_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	_step_left -= delta
	match cast_step:
		Cast.WINDUP:
			if _target_is_valid():
				facing = (target.global_position - global_position).normalized()
			if _step_left <= 0.0 and state == State.ATTACK:
				_launch(_predict())
				cast_step = Cast.RECOVER
				_step_left = _oracle.recover_time
		Cast.RECOVER:
			if _step_left <= 0.0:
				_attack_cooldown_left = data.attack_cooldown
				_enter_chase_or_idle()


## Where Nico will be after `lead_time` if he keeps his course, inside its room.
func _predict() -> Vector2:
	var lead := Vector2.ZERO
	var mover := target as CharacterBody2D
	if mover != null:
		lead = (mover.velocity * _oracle.lead_time).limit_length(_oracle.max_lead)
	var spot := target.global_position + lead
	if home_area.has_area():
		spot = spot.clamp(home_area.position, home_area.end)
	return spot


# --- Fireball ----------------------------------------------------------------------------------

func _launch(spot: Vector2) -> void:
	Events.enemy_attacked.emit(self, &"shot")
	_clear_fireball()
	_ball_center = spot
	_ball_age = 0.0
	_mark = SkillZone.circle(_to_parent_local(spot), _oracle.strike_radius, _oracle.mark_color, _oracle.fall_time)
	_seal = _art_on_zone(_mark, _oracle.seal_art, "SealArt", _draw_seal)
	get_parent().add_child(_mark)
	# The ball is y-sorted with the actors at the spot it falls on, and drawn up in the air.
	_ball = Node2D.new()
	_ball.name = "AshFireball"
	_ball.position = _to_parent_local(spot)
	_ball.draw.connect(_draw_ball.bind(_ball))
	get_parent().add_child(_ball)


func _update_fireball(delta: float) -> void:
	if _ball == null:
		return
	_ball_age += delta
	_ball.queue_redraw()
	if is_instance_valid(_seal):
		_seal.queue_redraw()
	if _ball_age >= _oracle.fall_time:
		var spot := _ball_center
		_clear_fireball()
		_land(spot)


func _land(spot: Vector2) -> void:
	_clear_impact()
	var parent := get_parent()
	if parent == null:
		return
	var burst := SkillZone.circle(_to_parent_local(spot), _oracle.strike_radius, _oracle.ball_color, _oracle.burst_time)
	if is_instance_valid(_burst):
		_burst.queue_free()
	_burst = _art_on_zone(burst, _oracle.burst_art, "BurstArt", _draw_burst)
	_burst_age = 0.0
	parent.add_child(burst)
	_impact = Hitbox.new()
	_impact.name = "AshImpact"
	_impact.collision_layer = 1 << 4
	_impact.collision_mask = 1 << 1
	_impact.damage = ceili(_oracle.strike_damage * damage_multiplier)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _oracle.strike_radius
	shape.shape = circle
	_impact.add_child(shape)
	_impact.position = _to_parent_local(spot)
	parent.add_child(_impact)
	_impact.activate()
	_impact_left = _oracle.impact_time


func _update_impact(delta: float) -> void:
	if _impact == null:
		return
	_impact_left -= delta
	if _impact_left <= 0.0:
		_clear_impact()


func _update_burst(delta: float) -> void:
	if not is_instance_valid(_burst):
		_burst = null
		return
	_burst_age += delta
	_burst.queue_redraw()


func _clear_fireball() -> void:
	if is_instance_valid(_ball):
		_ball.queue_free()
	if is_instance_valid(_mark):
		_mark.queue_free()
	_ball = null
	_mark = null
	_seal = null


func _clear_impact() -> void:
	if is_instance_valid(_impact):
		_impact.queue_free()
	_impact = null


## Puts `art` on a warning zone: the zone keeps its timing, size and ground layer (and frees itself)
## but its own circle is hidden, since the art is the warning now. Null when there is no art.
func _art_on_zone(zone: Node2D, art: Texture2D, art_name: String, drawer: Callable) -> Node2D:
	if art == null:
		return null
	zone.self_modulate = Color(1, 1, 1, 0)
	var canvas := Node2D.new()
	canvas.name = art_name
	canvas.draw.connect(drawer.bind(canvas))
	zone.add_child(canvas)
	return canvas


## Frame `index` of a strip of square cells, drawn into `rect`.
func _draw_cell(canvas: Node2D, art: Texture2D, index: int, rect: Rect2) -> void:
	var cell := float(art.get_height())
	canvas.draw_texture_rect_region(art, rect, Rect2(index * cell, 0.0, cell, cell))


func _cell_count(art: Texture2D) -> int:
	return maxi(int(float(art.get_width()) / maxf(art.get_height(), 1.0)), 1)


## The seal opens, then burns in a loop until the ball lands.
func _draw_seal(canvas: Node2D) -> void:
	var art := _oracle.seal_art
	var count := _cell_count(art)
	var index := int(_ball_age * SEAL_FPS)
	if index >= SEAL_OPEN_FRAMES:
		index = SEAL_OPEN_FRAMES + (index - SEAL_OPEN_FRAMES) % maxi(count - SEAL_OPEN_FRAMES, 1)
	var size := art.get_height() * _oracle.strike_radius / SEAL_ART_RADIUS
	_draw_cell(canvas, art, mini(index, count - 1), Rect2(-Vector2(size, size) / 2.0, Vector2(size, size)))


## The burst plays once over `burst_time`.
func _draw_burst(canvas: Node2D) -> void:
	var art := _oracle.burst_art
	var count := _cell_count(art)
	var index := mini(int(_burst_age / maxf(_oracle.burst_time, 0.01) * count), count - 1)
	var scale_by := _oracle.strike_radius / SEAL_ART_RADIUS
	var cell := float(art.get_height()) * scale_by
	_draw_cell(canvas, art, index, Rect2(-BURST_CENTER * scale_by, Vector2(cell, cell)))


func _draw_ball(canvas: Node2D) -> void:
	var progress := clampf(_ball_age / maxf(_oracle.fall_time, 0.01), 0.0, 1.0)
	# Falls faster and faster, like something dropped.
	var height := _oracle.fall_height * (1.0 - progress * progress)
	var at := Vector2(0.0, -height)
	if _oracle.ball_art != null:
		var art := _oracle.ball_art
		var cell := float(art.get_height())
		var index := int(_ball_age * BALL_FPS) % _cell_count(art)
		_draw_cell(canvas, art, index, Rect2((at - BALL_CENTER).round(), Vector2(cell, cell)))
		return
	canvas.draw_circle(at, _oracle.ball_radius + BALL_GLOW, Color(_oracle.ball_color, BALL_GLOW_ALPHA))
	canvas.draw_circle(at, _oracle.ball_radius, _oracle.ball_color)
	canvas.draw_circle(at, _oracle.ball_radius * BALL_CORE_SCALE, _oracle.ball_core_color)


## Marks, balls and impacts are children of the room, which in a generated map is not at the origin.
func _to_parent_local(world_point: Vector2) -> Vector2:
	var parent := get_parent() as Node2D
	return parent.to_local(world_point) if parent != null else world_point


# --- Animation ---------------------------------------------------------------------------------

## The staff raise plays `special` over the windup; the release plays `attack` once.
func _update_animation() -> void:
	if _sprite == null or state != State.ATTACK:
		super()
		return
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	var wanted: StringName = &"special" if cast_step == Cast.WINDUP else &"attack"
	if _sprite.animation != wanted:
		_sprite.play(wanted)
		_anim_held = 0.0
		var span := data.attack_windup if cast_step == Cast.WINDUP else _oracle.recover_time
		_sprite.speed_scale = _animation_length(wanted) / maxf(span, 0.05)
