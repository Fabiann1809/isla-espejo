class_name HungryTile
extends Enemy
## Baldosa hambrienta (island 3): a floor tile that is alive. Hidden it lies flat on the ground like
## any other tile: drawn on the ground layer, no shadow, no body (Nico walks over it), no hurtbox,
## and it never chases. When Nico steps within its trigger radius its cracks glow for an instant,
## then it opens its mouth and bites, holding him a moment (`player.apply_pull` at speed 0; a dodge
## breaks free). Then it stays revealed for a while (solid, hittable, crawling a tile at most toward
## Nico and biting again if he stays close), crawls back to its spot and closes.
## Everything tunable lives in its HungryTileData.

enum Phase { HIDDEN, TELL, BITE, REVEALED, CLOSING }

const ENEMY_LAYER := 3
## Special frames of the warning (cracks glowing) and of the open jaws.
const TELL_FIRST_FRAME := 1
const TELL_LAST_FRAME := 4
const BITE_FRAME := 5
## It closes only when this close to its spot (px), so it lies back exactly where it was.
const HOME_SNAP := 0.5
## Below this speed (px/s) it counts as still for its animation.
const CRAWL_ANIM_SPEED := 2.0

var phase: Phase = Phase.HIDDEN

var _tile: HungryTileData
var _phase_left := 0.0


func _ready() -> void:
	super()
	_tile = data as HungryTileData
	if _tile == null:
		push_error("HungryTile '%s' needs a HungryTileData." % name)
		_tile = HungryTileData.new()
	_hurtbox.invulnerability_check = func() -> bool: return not is_revealed()
	_hitbox.hit_landed.connect(_on_bite_landed)
	_set_revealed(false)


func _physics_process(delta: float) -> void:
	_phase_left = maxf(_phase_left - delta, 0.0)
	super(delta)
	var shadow := get_node_or_null(^"Shadow") as CanvasItem
	if shadow != null:
		shadow.visible = is_revealed() or state == State.DEAD


## True while it is out of its disguise: solid and hittable.
func is_revealed() -> bool:
	return phase in [Phase.BITE, Phase.REVEALED, Phase.CLOSING]


# Hidden it is just a tile: pushes, roots, slows and allies' statuses would give it away.
func apply_knockback(push: Vector2) -> void:
	if is_revealed():
		super(push)


func apply_root(duration: float) -> void:
	if is_revealed():
		super(duration)


func apply_slow(factor: float, duration: float) -> void:
	if is_revealed():
		super(factor, duration)


func apply_shield(duration: float) -> void:
	if is_revealed():
		super(duration)


func apply_frenzy(speed_factor: float, cooldown_rate: float, duration: float) -> void:
	if is_revealed():
		super(speed_factor, cooldown_rate, duration)


# --- Behaviour ---------------------------------------------------------------------------------

func _process_idle(delta: float) -> void:
	_process_tile(delta)


func _process_patrol(delta: float) -> void:
	_process_tile(delta)


func _process_chase(delta: float) -> void:
	_process_tile(delta)


## Outside its bite it never walks after Nico: hidden it waits, revealed it crawls a little.
func _process_tile(delta: float) -> void:
	velocity = Vector2.ZERO
	match phase:
		Phase.TELL:
			# Cut off before biting (Nico left): it simply stays a tile.
			phase = Phase.HIDDEN
		Phase.BITE:
			_begin_reveal()
		Phase.HIDDEN:
			if _can_bite():
				_start_attack()
		Phase.REVEALED:
			if _can_bite():
				_start_attack()
			elif _phase_left <= 0.0:
				phase = Phase.CLOSING
				_phase_left = _tile.close_timeout
			else:
				_crawl(delta)
		Phase.CLOSING:
			var to_home := _home - global_position
			if to_home.length() <= HOME_SNAP or _phase_left <= 0.0:
				_close()
			else:
				facing = to_home.normalized()
				velocity = facing * minf(data.move_speed * _speed_scale(), to_home.length() / delta)


func _start_attack() -> void:
	state = State.ATTACK
	velocity = Vector2.ZERO
	phase = Phase.TELL
	_phase_left = _tile.tell_time
	if _target_is_valid():
		facing = (target.global_position - global_position).normalized()


func _process_attack(_delta: float) -> void:
	velocity = Vector2.ZERO
	if _phase_left > 0.0:
		return
	match phase:
		Phase.TELL:
			_bite()
		Phase.BITE:
			_hitbox.deactivate()
			_attack_cooldown_left = data.attack_cooldown
			_begin_reveal()
			_enter_chase_or_idle()
		_:
			_enter_chase_or_idle()


func _bite() -> void:
	phase = Phase.BITE
	_phase_left = _tile.bite_time
	_set_revealed(true)
	_hitbox.damage = ceili(data.attack_damage * damage_multiplier)
	_hitbox.activate()
	Events.enemy_attacked.emit(self, &"melee")


func _begin_reveal() -> void:
	phase = Phase.REVEALED
	_phase_left = _tile.reveal_time
	_set_revealed(true)


func _close() -> void:
	velocity = Vector2.ZERO
	phase = Phase.HIDDEN
	_set_revealed(false)
	_attack_cooldown_left = maxf(_attack_cooldown_left, _tile.rearm_time)


func _can_bite() -> bool:
	return _attack_cooldown_left == 0.0 and _target_is_valid() \
			and global_position.distance_to(target.global_position) <= _tile.trigger_radius


## Revealed it creeps toward Nico, never past `crawl_leash` from its spot.
func _crawl(delta: float) -> void:
	var goal := _home
	if _target_is_valid():
		facing = (target.global_position - global_position).normalized()
		goal = _home + (target.global_position - _home).limit_length(_tile.crawl_leash)
	var to_goal := goal - global_position
	if to_goal.length() > ARRIVE_DISTANCE:
		velocity = to_goal.normalized() * minf(data.move_speed * _speed_scale(), to_goal.length() / delta)


## Nico is caught in its jaws: held where he stands for a moment.
func _on_bite_landed(hurtbox: Hurtbox) -> void:
	var victim := hurtbox.owner as Node2D
	if victim == null or not victim.has_method("apply_pull"):
		return
	# At speed 0 the anchor only has to be far enough for the pull not to end at once.
	var away := (victim.global_position - global_position).normalized()
	if away == Vector2.ZERO:
		away = Vector2.DOWN
	victim.apply_pull(victim.global_position + away * _tile.trigger_radius * 4.0, 0.0, _tile.hold_time)


## Hidden: no body for Nico to bump into, no hurtbox, drawn on the ground under every actor.
func _set_revealed(revealed: bool) -> void:
	set_collision_layer_value(ENEMY_LAYER, revealed)
	_hurtbox.get_node("CollisionShape2D").set_deferred("disabled", not revealed)
	if _sprite != null:
		_sprite.z_index = 0 if revealed else RoomTheme.GROUND_FX_Z


# --- Animation ---------------------------------------------------------------------------------

## Hidden: the calm first idle frame, never flipped, like the tiles around it. Tell: the cracks glow
## (special); bite: the open jaws (special); revealed: the open mouth (last attack frame), walking
## when it crawls; closing: crawling back, then the calm tile again.
func _update_animation() -> void:
	if _sprite == null or state == State.DEAD:
		return
	_sprite.speed_scale = 1.0
	match phase:
		Phase.HIDDEN:
			_sprite.flip_h = false
			_hold_frame(&"idle", 0)
			return
		Phase.TELL:
			var progress := 1.0 - _phase_left / maxf(_tile.tell_time, 0.01)
			_hold_frame(&"special", TELL_FIRST_FRAME + floori(progress * (TELL_LAST_FRAME - TELL_FIRST_FRAME + 0.99)))
			return
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	if phase == Phase.BITE:
		_hold_frame(&"special", BITE_FRAME)
	elif state == State.HURT:
		if _sprite.animation != &"hurt":
			_sprite.play(&"hurt")
	elif velocity.length() > CRAWL_ANIM_SPEED:
		if _sprite.animation != &"walk" or not _sprite.is_playing():
			_sprite.play(&"walk")
	else:
		_hold_frame(&"attack", _sprite.sprite_frames.get_frame_count(&"attack") - 1)


func _hold_frame(anim: StringName, frame: int) -> void:
	if not _sprite.sprite_frames.has_animation(anim):
		return
	frame = clampi(frame, 0, _sprite.sprite_frames.get_frame_count(anim) - 1)
	if _sprite.animation == anim and _sprite.frame == frame and not _sprite.is_playing():
		return
	_sprite.play(anim)
	_sprite.pause()
	_sprite.frame = frame
