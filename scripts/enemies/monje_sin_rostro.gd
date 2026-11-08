class_name FacelessMonk
extends Enemy
## Monje sin rostro: when it appears it draws glowing symbols on the floor of its room. To attack it
## fades away (it cannot be hit while gone), the symbol where it will come back flares, it reappears
## there and fires a spread of projectiles: one at Nico and the others angled away from him.
## Everything tunable lives in its FacelessMonkData.

enum Step { VANISH, HIDDEN, APPEAR, CAST, RECOVER }

## A symbol must keep clear of these: world and ponds.
const BLOCKING_MASK := (1 << (WORLD_LAYER - 1)) | (1 << (WATER_LAYER - 1))
## The glyph inside each symbol is a triangle (its corners, as fractions of the radius).
const GLYPH_CORNERS := 3
const GLYPH_SCALE := 0.75
const INNER_RING_SCALE := 0.5
## Frames of each loop in the drawn symbol's strip: resting, then warned.
const SYMBOL_ART_FRAMES := 4

var step: Step = Step.VANISH

var _monk: FacelessMonkData
var _step_left := 0.0
## Symbols in world coordinates; the one it stands on and the one warned as its destination.
var _symbols: Array[Vector2] = []
var _current_symbol := -1
var _warned_symbol := -1
var _symbol_art: Node2D
var _glow_clock := 0.0
var _hidden := false
## The attack step the sprite was last set for (-1: none yet this attack).
var _anim_step := -1


func _ready() -> void:
	super()
	_monk = data as FacelessMonkData
	if _monk == null:
		push_error("FacelessMonk '%s' needs a FacelessMonkData." % name)
		_monk = FacelessMonkData.new()
	# Gone, arrows and blows pass through it instead of being blocked.
	_hurtbox.invulnerability_check = func() -> bool: return _hidden
	died.connect(_fade_symbols)


func _physics_process(delta: float) -> void:
	# On the first tick, not in _ready: the room's walls must be in the physics space to avoid them.
	if _symbol_art == null and state != State.DEAD and get_parent() != null:
		_place_symbols()
	super(delta)
	if state != State.ATTACK:
		_show_again()
	_glow_clock += delta
	if is_instance_valid(_symbol_art):
		_symbol_art.queue_redraw()


func _exit_tree() -> void:
	if is_instance_valid(_symbol_art):
		_symbol_art.queue_free()


func is_hidden() -> bool:
	return _hidden


## The floor symbols, in world coordinates (tests read them).
func symbols() -> Array[Vector2]:
	return _symbols


## A push cannot reach what is not there.
func apply_knockback(push: Vector2) -> void:
	if not _hidden:
		super(push)


# --- Behaviour ---------------------------------------------------------------------------------

func _process_chase(_delta: float) -> void:
	if not _target_is_valid():
		return
	var to_target := target.global_position - global_position
	facing = to_target.normalized()
	if to_target.length() <= data.attack_range and _attack_cooldown_left == 0.0 and can_see(target):
		_start_attack()
		return
	if to_target.length() > _monk.preferred_distance:
		velocity = facing * data.chase_speed * _speed_scale()
	else:
		velocity = Vector2.ZERO


func _start_attack() -> void:
	super()
	_telegraph.hide()
	step = Step.VANISH
	_step_left = _monk.vanish_time
	_anim_step = -1


func _process_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	_step_left -= delta
	match step:
		Step.VANISH:
			modulate.a = clampf(_step_left / maxf(_monk.vanish_time, 0.01), 0.0, 1.0)
			if _step_left <= 0.0:
				_vanish()
		Step.HIDDEN:
			if _step_left <= 0.0:
				_appear()
		Step.APPEAR:
			modulate.a = 1.0 - clampf(_step_left / maxf(_monk.appear_time, 0.01), 0.0, 1.0)
			if _step_left <= 0.0:
				modulate.a = 1.0
				step = Step.CAST
				_step_left = data.attack_windup
		Step.CAST:
			if _target_is_valid():
				facing = (target.global_position - global_position).normalized()
			if _step_left <= 0.0 and state == State.ATTACK:
				_fire()
				step = Step.RECOVER
				_step_left = _monk.recover_time
		Step.RECOVER:
			if _step_left <= 0.0:
				_attack_cooldown_left = data.attack_cooldown
				_enter_chase_or_idle()


## Gone: it moves to its destination at once, and that symbol flares while it is away.
func _vanish() -> void:
	_hidden = true
	modulate.a = 0.0
	_collision.set_deferred("disabled", true)
	var destination := _pick_destination()
	if destination >= 0:
		_current_symbol = destination
		_warned_symbol = destination
		global_position = _symbols[destination]
	step = Step.HIDDEN
	_step_left = _monk.hidden_time


func _appear() -> void:
	_hidden = false
	_warned_symbol = -1
	_collision.set_deferred("disabled", false)
	step = Step.APPEAR
	_step_left = _monk.appear_time


## A hit before it is gone, a lost target or a push ends the attack: it must not stay invisible.
func _show_again() -> void:
	if state == State.DEAD or (not _hidden and modulate.a >= 1.0):
		return
	if _hidden:
		_hidden = false
		_collision.set_deferred("disabled", false)
	_warned_symbol = -1
	modulate.a = 1.0


## Another symbol: the best are neither too close to Nico nor out of shot, with a clear shot at him.
func _pick_destination() -> int:
	var others: Array[int] = []
	for i in _symbols.size():
		if i != _current_symbol:
			others.append(i)
	if others.is_empty():
		return -1
	var nico := target.global_position if _target_is_valid() else global_position
	var in_band := others.filter(func(i: int) -> bool:
		var distance := _symbols[i].distance_to(nico)
		return distance >= _monk.min_player_distance and distance <= _monk.max_player_distance)
	var clear := in_band.filter(func(i: int) -> bool: return _clear_shot(_symbols[i], nico))
	if not clear.is_empty():
		return clear.pick_random()
	return in_band.pick_random() if not in_band.is_empty() else others.pick_random()


func _clear_shot(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1 << (WORLD_LAYER - 1))
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _fire() -> void:
	if _monk.projectile_scene == null or get_parent() == null:
		return
	Events.enemy_attacked.emit(self, &"shot")
	var count := maxi(_monk.shot_count, 1)
	for i in count:
		var direction := facing.rotated(deg_to_rad(_monk.shot_spread) * (i - (count - 1) / 2.0))
		var orb: EnemyOrb = _monk.projectile_scene.instantiate()
		orb.height_level = Heights.level_of(self)
		orb.setup(direction, _monk.projectile_speed, _monk.projectile_range,
				ceili(data.attack_damage * damage_multiplier))
		orb.position = position + direction * _monk.muzzle_distance
		# Its comet tail streams behind it; the round hitbox does not care.
		orb.rotation = direction.angle()
		orb.modulate = _monk.shot_tint
		get_parent().add_child(orb)


# --- Floor symbols -----------------------------------------------------------------------------

func _place_symbols() -> void:
	_symbols = [global_position]
	_current_symbol = 0
	var area := home_area.grow(-_monk.symbol_margin)
	if not home_area.has_area() or not area.has_area():
		area = Rect2(_home - Vector2.ONE * _monk.symbol_spread, Vector2.ONE * _monk.symbol_spread * 2.0)
	for i in _monk.symbol_tries:
		if _symbols.size() >= _monk.symbol_count:
			break
		var spot := Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
		if _spot_is_free(spot):
			_symbols.append(spot)
	_symbol_art = Node2D.new()
	_symbol_art.name = "MonkSymbols"
	_symbol_art.z_as_relative = false
	_symbol_art.z_index = RoomTheme.GROUND_FX_Z
	_symbol_art.draw.connect(_draw_symbols)
	get_parent().add_child(_symbol_art)


func _spot_is_free(spot: Vector2) -> bool:
	for other in _symbols:
		if other.distance_to(spot) < _monk.symbol_gap:
			return false
	var circle := CircleShape2D.new()
	circle.radius = _monk.symbol_clearance
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, spot)
	query.collision_mask = BLOCKING_MASK
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _fade_symbols() -> void:
	if is_instance_valid(_symbol_art):
		var tween := _symbol_art.create_tween()
		tween.tween_property(_symbol_art, "modulate:a", 0.0, _monk.appear_time)
		tween.tween_callback(_symbol_art.queue_free)


func _draw_symbols() -> void:
	if _monk.symbol_art != null:
		_draw_symbol_art()
		return
	var pulse := 0.5 + 0.5 * sin(_glow_clock * TAU * _monk.symbol_pulse_rate)
	var radius := _monk.symbol_radius
	for i in _symbols.size():
		var at := _symbol_art.to_local(_symbols[i])
		var warned := i == _warned_symbol
		var color := _monk.symbol_warning_color if warned else _monk.symbol_color
		var glow := (0.35 + 0.3 * pulse) if warned else (0.1 + 0.1 * pulse)
		var size := radius * (1.0 + 0.25 * pulse) if warned else radius
		_symbol_art.draw_circle(at, size, Color(color, glow))
		if Tuning.ZONE_OUTLINE_ALPHA > 0.0:
			_symbol_art.draw_arc(at, size, 0.0, TAU, 24, Color(0, 0, 0, Tuning.ZONE_OUTLINE_ALPHA * 0.6), 3.0)
		_symbol_art.draw_arc(at, size, 0.0, TAU, 24, Color(color, 0.6 + 0.4 * pulse), 1.0)
		_symbol_art.draw_arc(at, size * INNER_RING_SCALE, 0.0, TAU, 16, Color(color, 0.5), 1.0)
		var glyph := PackedVector2Array()
		for corner in GLYPH_CORNERS + 1:
			glyph.append(at + Vector2.UP.rotated(TAU * corner / GLYPH_CORNERS) * size * GLYPH_SCALE)
		_symbol_art.draw_polyline(glyph, Color(color, 0.7), 1.0)


## The drawn symbols: the resting loop spans one glow pulse, the warned one flickers faster.
func _draw_symbol_art() -> void:
	var art := _monk.symbol_art
	var cell := float(art.get_height())
	var rest := int(_glow_clock * _monk.symbol_pulse_rate * SYMBOL_ART_FRAMES) % SYMBOL_ART_FRAMES
	var warned_frame := SYMBOL_ART_FRAMES + int(_glow_clock * _monk.symbol_warning_fps) % SYMBOL_ART_FRAMES
	for i in _symbols.size():
		var at := _symbol_art.to_local(_symbols[i]).round()
		var frame := warned_frame if i == _warned_symbol else rest
		_symbol_art.draw_texture_rect_region(art, Rect2(at - Vector2(cell, cell) / 2.0, Vector2(cell, cell)),
				Rect2(frame * cell, 0.0, cell, cell))


# --- Animation ---------------------------------------------------------------------------------

## Fading out plays `special`, fading in plays it backwards, the cast plays `attack`.
func _update_animation() -> void:
	if _sprite == null or state != State.ATTACK:
		super()
		return
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	if _anim_step == step:
		return
	_anim_step = step
	_anim_held = 0.0
	match step:
		Step.VANISH:
			_play_over(&"special", _monk.vanish_time)
		Step.APPEAR:
			_play_over(&"special", _monk.appear_time)
			_sprite.play_backwards(&"special")
		Step.CAST:
			_play_over(&"attack", data.attack_windup + data.attack_time)
		Step.RECOVER:
			_sprite.speed_scale = 1.0
			_sprite.play(&"idle")


func _play_over(anim: StringName, seconds: float) -> void:
	_sprite.play(anim)
	_sprite.speed_scale = _animation_length(anim) / maxf(seconds, 0.05)
