class_name StoneExecutioner
extends Enemy
## Verdugo de piedra: huge, slow and hard to push. When Nico gets close it raises its hammer (a
## warning circle at its feet), smashes the ground and releases a shockwave: a ring that grows from
## the hammer to its max radius and hurts Nico once when its band passes over him. Walking away
## does not outrun it; dashing through it does (Nico is invulnerable while dashing). Ridden by a
## Máscara parásita its wave reaches farther in the same time (so it is faster too).
## Everything tunable lives in its StoneExecutionerData.

var _executioner: StoneExecutionerData
var _warning: Node2D
## The ring drawn on the ground (null when no wave is running) and where it started (world).
var _wave: Node2D
var _wave_center := Vector2.ZERO
var _wave_age := 0.0
var _wave_radius := 0.0
## How far this wave grows (fixed at the slam, so a mask jumping off mid-wave does not shrink it).
var _wave_max := 0.0
var _wave_landed := false


func _ready() -> void:
	super()
	_executioner = data as StoneExecutionerData
	if _executioner == null:
		push_error("StoneExecutioner '%s' needs a StoneExecutionerData." % name)
		_executioner = StoneExecutionerData.new()


func _physics_process(delta: float) -> void:
	super(delta)
	# A push (a skill) can cut the windup short: its warning must not stay promising a slam.
	if state != State.ATTACK and is_instance_valid(_warning):
		_warning.queue_free()
	_update_wave(delta)


func _exit_tree() -> void:
	_end_wave()
	if is_instance_valid(_warning):
		_warning.queue_free()


## Current radius of the shockwave, or -1 when there is none.
func wave_radius() -> float:
	return _wave_radius if _wave != null else -1.0


## How far its next shockwave reaches: farther (and so faster) while a Máscara parásita rides it.
func wave_max_radius() -> float:
	return _executioner.masked_wave_max_radius if is_masked() else _executioner.wave_max_radius


# --- Behaviour ---------------------------------------------------------------------------------

func _start_attack() -> void:
	super()
	# The circle on the ground is the warning, not the generic lane in front of it.
	_telegraph.hide()
	_warning = SkillZone.circle(_to_parent_local(global_position), _executioner.warning_radius,
			_executioner.warning_color, data.attack_windup)
	get_parent().add_child(_warning)


func _process_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	_attack_time_left -= delta
	if _attack_time_left > 0.0:
		return
	match _attack_phase:
		AttackPhase.WINDUP:
			_slam()
			_attack_phase = AttackPhase.STRIKE
			_attack_time_left = data.attack_time
		AttackPhase.STRIKE:
			_attack_phase = AttackPhase.RECOVER
			_attack_time_left = _executioner.recover_time
		AttackPhase.RECOVER:
			_attack_cooldown_left = data.attack_cooldown
			_enter_chase_or_idle()


func _slam() -> void:
	Events.enemy_attacked.emit(self, &"melee")
	_end_wave()
	_wave_center = global_position
	_wave_age = 0.0
	_wave_radius = 0.0
	_wave_max = wave_max_radius()
	_wave_landed = false
	_wave = Node2D.new()
	_wave.name = "Shockwave"
	_wave.z_as_relative = false
	_wave.z_index = RoomTheme.GROUND_FX_Z
	_wave.position = _to_parent_local(_wave_center)
	_wave.draw.connect(_draw_wave.bind(_wave))
	get_parent().add_child(_wave)


func _update_wave(delta: float) -> void:
	if _wave == null:
		return
	_wave_age += delta
	var previous := _wave_radius
	_wave_radius = _wave_max * clampf(_wave_age / maxf(_executioner.wave_time, 0.01), 0.0, 1.0)
	if not _wave_landed:
		_hurt_player_in_band(previous, _wave_radius)
	_wave.queue_redraw()
	if _wave_age >= _executioner.wave_time:
		_end_wave()


## The band swept this tick covers from the trailing edge of the old ring to the new ring.
func _hurt_player_in_band(from_radius: float, to_radius: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var distance := player.global_position.distance_to(_wave_center)
	if distance < from_radius - _executioner.wave_band or distance > to_radius:
		return
	var hurtbox := player.get_node_or_null("Hurtbox") as Hurtbox
	# Refused while dashing: the ring goes on and he is through it.
	if hurtbox != null and hurtbox.receive_hit(ceili(_executioner.wave_damage * damage_multiplier), _wave_center):
		_wave_landed = true


func _end_wave() -> void:
	if is_instance_valid(_wave):
		_wave.queue_free()
	_wave = null


func _draw_wave(canvas: Node2D) -> void:
	var progress := clampf(_wave_age / maxf(_executioner.wave_time, 0.01), 0.0, 1.0)
	var fade := 1.0 - progress * 0.7
	if _executioner.wave_art != null:
		_draw_wave_art(canvas, fade)
		return
	var band := _executioner.wave_band
	var middle := maxf(_wave_radius - band / 2.0, 1.0)
	if Tuning.ZONE_OUTLINE_ALPHA > 0.0:
		canvas.draw_arc(Vector2.ZERO, _wave_radius, 0.0, TAU, 48, Color(0, 0, 0, Tuning.ZONE_OUTLINE_ALPHA * fade), 2.0)
	canvas.draw_arc(Vector2.ZERO, middle, 0.0, TAU, 48, Color(_executioner.wave_color, 0.35 * fade), band)
	canvas.draw_arc(Vector2.ZERO, _wave_radius, 0.0, TAU, 48, Color(_executioner.wave_color.lightened(0.3), 0.9 * fade), 2.0)


## Frame k of the strip is the ring at k / (frames - 1) of its full radius: the nearest one to the
## current radius is shown, so the drawn front never strays from the band that hurts.
func _draw_wave_art(canvas: Node2D, fade: float) -> void:
	var art := _executioner.wave_art
	var cell := float(art.get_height())
	var frames := int(art.get_width() / cell)
	var frame := clampi(roundi(_wave_radius / maxf(_wave_max, 1.0) * (frames - 1)), 0, frames - 1)
	# Scaled when this wave's radius differs from the one the art was drawn for (tuned, or masked).
	var size := cell * _wave_max / maxf(_executioner.wave_art_radius, 1.0)
	canvas.draw_texture_rect_region(art, Rect2(-size / 2.0, -size / 2.0, size, size),
			Rect2(frame * cell, 0.0, cell, cell), Color(1.0, 1.0, 1.0, fade))


## Rings and warnings are children of the room, which in a generated map is not at the origin.
func _to_parent_local(world_point: Vector2) -> Vector2:
	var parent := get_parent() as Node2D
	return parent.to_local(world_point) if parent != null else world_point


## The whole slam is the `special` animation (hammer up during the windup, on the ground at the
## strike); it holds its last frame through the recover.
func _update_animation() -> void:
	if _sprite == null or state != State.ATTACK or not _sprite.sprite_frames.has_animation(&"special"):
		super()
		return
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	if _sprite.animation != &"special":
		_sprite.play(&"special")
		_sprite.speed_scale = _animation_length(&"special") / maxf(data.attack_windup + data.attack_time, 0.05)
		_anim_held = 0.0
