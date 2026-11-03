class_name BasaltRam
extends Enemy
## Carnero de basalto: when Nico is in sight within its range it plants itself and marks a lane on
## the ground toward him (up to the first wall), then charges along it at high speed with its horns
## out. The charge ends against a wall or obstacle, after its distance, or at the edge of its room;
## crashing into a wall leaves it stunned (still, no attacks, stars over its head) for a while.
## Everything tunable lives in its BasaltRamData.

enum Charge { WINDUP, RUSH, STUNNED, RECOVER }
## Rows of tiles in BasaltRamData.lane_art.
enum LaneTiles { MARKED, FILLED, HOT }

## Length of one lane tile along the lane (px).
const LANE_TILE := 18.0
## Past this much of the windup the filled lane flickers, this many times a second.
const LANE_FLICKER_FROM := 0.6
const LANE_FLICKER_FPS := 8.0

## Bodies a charge crashes into (and the lane stops at): world and ponds.
const BLOCKING_MASK := (1 << (WORLD_LAYER - 1)) | (1 << (WATER_LAYER - 1))
## The stars' orbit is squashed vertically so it reads as a ring seen from above.
const STAR_TILT := 0.4

var charge_step: Charge = Charge.WINDUP

var _ram: BasaltRamData
var _step_left := 0.0
var _charge_dir := Vector2.RIGHT
var _travelled := 0.0
var _lane: Node2D
var _lane_length := 0.0
var _stars: Node2D
var _star_angle := 0.0


func _ready() -> void:
	super()
	_ram = data as BasaltRamData
	if _ram == null:
		push_error("BasaltRam '%s' needs a BasaltRamData." % name)
		_ram = BasaltRamData.new()
	_stars = Node2D.new()
	_stars.name = "StunStars"
	_stars.position = Vector2(0, -_ram.star_height)
	_stars.visible = false
	_stars.draw.connect(_draw_stars)
	add_child(_stars)


func _physics_process(delta: float) -> void:
	super(delta)
	# A push (a skill), a lost target or death ends the attack: no lane or stars left behind.
	if state != State.ATTACK:
		_clear_lane()
		_stars.visible = false
	if _stars.visible:
		_star_angle = wrapf(_star_angle + _ram.star_spin * TAU * delta, 0.0, TAU)
		_stars.queue_redraw()
	if is_instance_valid(_lane):
		_lane.queue_redraw()


func _exit_tree() -> void:
	_clear_lane()


func is_stunned() -> bool:
	return state == State.ATTACK and charge_step == Charge.STUNNED


# --- Behaviour ---------------------------------------------------------------------------------

func _process_chase(_delta: float) -> void:
	if not _target_is_valid():
		return
	var to_target := target.global_position - global_position
	facing = to_target.normalized()
	if to_target.length() <= data.attack_range and _attack_cooldown_left == 0.0 and can_see(target):
		_start_attack()
		return
	# Close in until well inside its range, then wait for the cooldown.
	if to_target.length() > data.attack_range * 0.6:
		velocity = facing * data.chase_speed * _speed_scale()
	else:
		velocity = Vector2.ZERO


func _start_attack() -> void:
	super()
	# The lane on the ground is the warning, not the generic one in front of it.
	_telegraph.hide()
	charge_step = Charge.WINDUP
	_step_left = _ram.charge_windup
	_charge_dir = facing
	_show_lane()


func _process_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	_step_left -= delta
	match charge_step:
		Charge.WINDUP:
			if _step_left <= 0.0:
				_start_rush()
		Charge.RUSH:
			_process_rush(delta)
		Charge.STUNNED, Charge.RECOVER:
			if _step_left <= 0.0:
				_stars.visible = false
				_attack_cooldown_left = data.attack_cooldown
				_enter_chase_or_idle()


func _start_rush() -> void:
	_clear_lane()
	_pivot.rotation = _charge_dir.angle()
	_hitbox.damage = ceili(data.attack_damage * damage_multiplier)
	_hitbox.activate()
	Events.enemy_attacked.emit(self, &"melee")
	charge_step = Charge.RUSH
	_travelled = 0.0


func _process_rush(delta: float) -> void:
	# The last move ran into a wall: that is the crash.
	if _hit_world():
		_end_rush(Charge.STUNNED, _ram.stun_time)
		_stars.visible = true
		return
	var rush := _charge_dir * _ram.charge_speed * _speed_scale()
	if _travelled >= _ram.charge_distance or not _dash_allowed(global_position + rush * delta):
		_end_rush(Charge.RECOVER, _ram.charge_recover)
		return
	velocity = rush
	_travelled += rush.length() * delta


func _end_rush(next: Charge, seconds: float) -> void:
	velocity = Vector2.ZERO
	_hitbox.deactivate()
	charge_step = next
	_step_left = seconds


# --- Lane and stars ----------------------------------------------------------------------------

## The lane lies on the ground of the room, from the ram to where the charge would stop.
func _show_lane() -> void:
	_clear_lane()
	_lane_length = _ram.charge_distance
	var query := PhysicsRayQueryParameters2D.create(global_position,
			global_position + _charge_dir * _ram.charge_distance, BLOCKING_MASK)
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_lane_length = global_position.distance_to(hit.position)
	var parent := get_parent() as Node2D
	_lane = Node2D.new()
	_lane.name = "ChargeLane"
	_lane.z_as_relative = false
	_lane.z_index = RoomTheme.GROUND_FX_Z
	_lane.position = parent.to_local(global_position) if parent != null else global_position
	_lane.rotation = _charge_dir.angle()
	_lane.draw.connect(_draw_lane.bind(_lane))
	get_parent().add_child(_lane)


func _clear_lane() -> void:
	if is_instance_valid(_lane):
		_lane.queue_free()
	_lane = null


## It fills in as the windup runs out, so the player reads how soon the charge comes.
func _draw_lane(canvas: Node2D) -> void:
	var progress := 1.0 - clampf(_step_left / maxf(_ram.charge_windup, 0.01), 0.0, 1.0)
	if _ram.lane_art != null:
		_draw_lane_tiles(canvas, LaneTiles.MARKED, _lane_length)
		# The filled part flickers once the charge is close.
		var elapsed := _ram.charge_windup - _step_left
		var hot := progress > LANE_FLICKER_FROM and int(elapsed * LANE_FLICKER_FPS) % 2 == 0
		_draw_lane_tiles(canvas, LaneTiles.HOT if hot else LaneTiles.FILLED, _lane_length * progress)
		return
	var half := _ram.lane_width / 2.0
	var area := Rect2(0.0, -half, _lane_length, _ram.lane_width)
	canvas.draw_rect(area, Color(_ram.lane_color, 0.12 + 0.2 * progress))
	canvas.draw_rect(Rect2(0.0, -half, _lane_length * progress, _ram.lane_width), Color(_ram.lane_color, 0.25))
	canvas.draw_rect(area, Color(_ram.lane_color, 0.8), false, 1.0)


## Lays the lane's tiles from the ram up to `upto` px: a start tile, middle tiles taking turns, and
## the end tile always at the lane's end (the last middle tile is cut short to meet it).
func _draw_lane_tiles(canvas: Node2D, row: LaneTiles, upto: float) -> void:
	var art := _ram.lane_art
	var half := _ram.lane_width / 2.0
	var end_start := maxf(_lane_length - LANE_TILE, 0.0)
	var x := 0.0
	var i := 0
	while x < upto:
		var tile := 3 if x >= end_start else (0 if i == 0 else 1 + i % 2)
		var width := LANE_TILE if tile == 3 else minf(LANE_TILE, end_start - x)
		width = minf(width, upto - x)
		if width <= 0.0:
			break
		var source := Rect2((row * 4 + tile) * LANE_TILE, 0.0, width, art.get_height())
		canvas.draw_texture_rect_region(art, Rect2(x, -half, width, _ram.lane_width), source)
		x += width
		i += 1
		if tile == 3:
			break


func _draw_stars() -> void:
	for i in _ram.star_count:
		var angle := _star_angle + TAU * i / maxf(_ram.star_count, 1)
		var at := Vector2(cos(angle), sin(angle) * STAR_TILT) * _ram.star_orbit
		var arm := _ram.star_size
		_stars.draw_line(at - Vector2(arm, 0), at + Vector2(arm, 0), _ram.star_color, 1.0)
		_stars.draw_line(at - Vector2(0, arm), at + Vector2(0, arm), _ram.star_color, 1.0)


# --- Animation ---------------------------------------------------------------------------------

## Windup: the head-down pose of `attack`; rush: `special` (the gallop) over and over; stunned:
## `hurt`, held on its last frame; recover: `idle`.
func _update_animation() -> void:
	if _sprite == null or state != State.ATTACK:
		super()
		return
	if absf(_charge_dir.x) > 0.1:
		_sprite.flip_h = _charge_dir.x < 0.0
	_sprite.speed_scale = 1.0
	match charge_step:
		Charge.WINDUP:
			_hold_frame(&"attack", 2)
		Charge.RUSH:
			if _sprite.animation != &"special" or not _sprite.is_playing():
				_sprite.play(&"special")
		Charge.STUNNED:
			if _sprite.animation != &"hurt":
				_sprite.play(&"hurt")
		Charge.RECOVER:
			if _sprite.animation != &"idle":
				_sprite.play(&"idle")


func _hold_frame(anim: StringName, frame: int) -> void:
	if not _sprite.sprite_frames.has_animation(anim):
		return
	frame = mini(frame, _sprite.sprite_frames.get_frame_count(anim) - 1)
	if _sprite.animation == anim and _sprite.frame == frame and not _sprite.is_playing():
		return
	_sprite.play(anim)
	_sprite.pause()
	_sprite.frame = frame
