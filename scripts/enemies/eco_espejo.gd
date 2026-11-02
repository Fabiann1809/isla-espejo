class_name MirrorEcho
extends Enemy
## Eco del Espejo: a reflection of Nico that copies him with a delay. It keeps a record of where Nico
## stood and of every shot he fired (Events.player_shot); while it hunts him it walks his path as it
## was `echo_delay` seconds ago and, whenever Nico shot at that past moment, fires an orb in the same
## direction. Standing still lets it catch up, and touching it hurts lightly; killing it is the only
## way to stop it. Its art is Nico's, tinted like a mirror. Everything tunable lives in its
## MirrorEchoData.

var _echo: MirrorEchoData
## Seconds of physics time since it appeared: the clock of the record.
var _clock := 0.0
## Nico's positions over the last `echo_delay` seconds (and the sample just before), oldest first.
var _trail_times := PackedFloat64Array()
var _trail_points := PackedVector2Array()
## Nico's shots waiting to be echoed: [time, direction], oldest first.
var _shots: Array[Array] = []
var _pose_left := 0.0
var _touch_left := 0.0
var _touch_hitbox: Hitbox


func _ready() -> void:
	super()
	_echo = data as MirrorEchoData
	if _echo == null:
		push_error("MirrorEcho '%s' needs a MirrorEchoData." % name)
		_echo = MirrorEchoData.new()
	if _sprite != null:
		_sprite.self_modulate = _echo.echo_tint
	_build_touch()
	Events.player_shot.connect(_on_player_shot)


func _physics_process(delta: float) -> void:
	_clock += delta
	_pose_left = maxf(_pose_left - delta, 0.0)
	_record_player()
	super(delta)
	_echo_shots()
	_keep_touching(delta)


## Where Nico stood `echo_delay` seconds ago, or null before the record reaches that far back.
func echoed_position() -> Variant:
	var when := _clock - _echo.echo_delay
	if _trail_times.is_empty() or when < _trail_times[0]:
		return null
	for i in range(_trail_times.size() - 1, -1, -1):
		if _trail_times[i] <= when:
			if i == _trail_times.size() - 1:
				return _trail_points[i]
			var span := _trail_times[i + 1] - _trail_times[i]
			var along := (when - _trail_times[i]) / span if span > 0.0 else 0.0
			return _trail_points[i].lerp(_trail_points[i + 1], along)
	return null


# --- Behaviour ---------------------------------------------------------------------------------

## Walks Nico's past path at up to `follow_speed`.
func _process_chase(delta: float) -> void:
	if not _target_is_valid():
		return
	var spot: Variant = echoed_position()
	if spot == null:
		velocity = Vector2.ZERO
		return
	var goal: Vector2 = spot
	if home_area.has_area():
		goal = goal.clamp(home_area.position, home_area.end)
	var to_goal := goal - global_position
	var step := minf(_echo.follow_speed * _speed_scale(), to_goal.length() / delta)
	velocity = to_goal.normalized() * step if to_goal.length() > 0.5 else Vector2.ZERO
	if velocity.length() > 1.0:
		facing = velocity.normalized()


func _record_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or _is_dead_node(player):
		return
	_trail_times.append(_clock)
	_trail_points.append(player.global_position)
	# Keep one sample older than the delay, so the echoed spot can be interpolated.
	var oldest := _clock - _echo.echo_delay
	while _trail_times.size() >= 2 and _trail_times[1] <= oldest:
		_trail_times.remove_at(0)
		_trail_points.remove_at(0)


func _on_player_shot(direction: Vector2, _target_distance: float) -> void:
	if state != State.DEAD:
		_shots.append([_clock, direction])


## Fires the shots Nico made `echo_delay` seconds ago; while it is not hunting him they fade unechoed.
func _echo_shots() -> void:
	var due := _clock - _echo.echo_delay
	while not _shots.is_empty() and float(_shots[0][0]) <= due:
		var direction: Vector2 = _shots.pop_front()[1]
		if state == State.CHASE and _target_is_valid():
			_fire(direction)


func _fire(direction: Vector2) -> void:
	if _echo.projectile_scene == null or get_parent() == null:
		return
	Events.enemy_attacked.emit(self, &"shot")
	facing = direction.normalized()
	_pose_left = _echo.shot_pose_time
	var orb: EnemyOrb = _echo.projectile_scene.instantiate()
	orb.setup(facing, _echo.projectile_speed, _echo.projectile_range, ceili(data.attack_damage * damage_multiplier))
	orb.position = position + facing * _echo.muzzle_distance
	orb.modulate = _echo.shot_tint
	get_parent().add_child(orb)


# --- Touch -------------------------------------------------------------------------------------

func _build_touch() -> void:
	_touch_hitbox = Hitbox.new()
	_touch_hitbox.name = "TouchHitbox"
	_touch_hitbox.collision_layer = 1 << 4
	_touch_hitbox.collision_mask = 1 << 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _echo.touch_radius
	shape.shape = circle
	_touch_hitbox.add_child(shape)
	add_child(_touch_hitbox)
	_touch_hitbox.owner = self


## The touch hitbox hits once per activation, so it is switched on again every `touch_interval`.
func _keep_touching(delta: float) -> void:
	if state == State.DEAD:
		_touch_hitbox.deactivate()
		return
	_touch_left -= delta
	if _touch_left <= 0.0:
		_touch_left = _echo.touch_interval
		_touch_hitbox.damage = ceili(_echo.touch_damage * damage_multiplier)
		_touch_hitbox.activate()


func _on_died() -> void:
	_touch_hitbox.deactivate()
	_shots.clear()
	super()


# --- Animation ---------------------------------------------------------------------------------

## An echoed shot shows Nico's bow pose for a moment; everything else is the base's.
func _update_animation() -> void:
	if _sprite == null or state == State.DEAD or _pose_left <= 0.0 or state == State.HURT:
		super()
		return
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	if _sprite.animation != &"attack":
		_sprite.play(&"attack")
		_anim_held = 0.0
		_sprite.speed_scale = _animation_length(&"attack") / maxf(_echo.shot_pose_time, 0.05)
