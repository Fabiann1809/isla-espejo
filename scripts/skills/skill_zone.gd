class_name SkillZone
extends Node2D
## The visual a skill leaves on the ground (a circle or a wave) that fades out and frees itself.
## With `frames` (the skill's `zone_frames`) it shows pixel art: `start` once, then `loop` while it
## lasts and `end` for its last moments; a wave travels along its direction. Without art it draws
## shapes. A circle can also call `on_tick` at a fixed interval, which is how lasting zones (Raíces)
## keep affecting enemies.

enum Shape { CIRCLE, WAVE }

var shape := Shape.CIRCLE
var color := Color.WHITE
var radius := 40.0
var lifetime := 1.0
var tick_interval := 0.1
var on_tick := Callable()
## Pixel art of the zone (see SkillData.zone_frames); null = drawn with shapes.
var frames: SpriteFrames
## WAVE only
var direction := Vector2.RIGHT
var arc := deg_to_rad(90.0)

var _age := 0.0
var _tick_left := 0.0
var _art: AnimatedSprite2D
var _ending := false


## A circle centered on `center` (world position) that lasts `seconds`.
static func circle(center: Vector2, circle_radius: float, circle_color: Color, seconds: float,
		tick := Callable(), art: SpriteFrames = null) -> SkillZone:
	var zone := SkillZone.new()
	zone.shape = Shape.CIRCLE
	zone.radius = circle_radius
	zone.color = circle_color
	zone.lifetime = seconds
	zone.on_tick = tick
	zone.frames = art
	zone.position = center
	return zone


## A wave that expands from `origin` up to `reach` in `facing`, spanning `arc_degrees`.
static func wave(origin: Vector2, facing: Vector2, reach: float, arc_degrees: float,
		wave_color: Color, seconds := 0.35, art: SpriteFrames = null) -> SkillZone:
	var zone := SkillZone.new()
	zone.shape = Shape.WAVE
	zone.radius = reach
	zone.direction = facing
	zone.arc = deg_to_rad(arc_degrees)
	zone.color = wave_color
	zone.lifetime = seconds
	zone.frames = art
	zone.position = origin
	return zone


func has_art() -> bool:
	return _art != null


func _ready() -> void:
	# Warnings and skill areas lie on the ground: the level is y-sorted, so at z 0 a circle would be
	# drawn over whoever stands above its center.
	z_index = RoomTheme.GROUND_FX_Z
	if frames != null and frames.has_animation(&"start"):
		_build_art()


func _build_art() -> void:
	_art = AnimatedSprite2D.new()
	_art.name = "Art"
	_art.sprite_frames = frames
	_art.animation_finished.connect(_on_art_finished)
	add_child(_art)
	if shape == Shape.WAVE:
		# The art faces right and travels with the wave: it is turned to the cast's direction, and
		# its one animation is fitted to the zone's life.
		_art.rotation = direction.angle()
		_art.speed_scale = _length_of(&"start") / maxf(lifetime, 0.05)
	_art.play(&"start")


func _length_of(anim: StringName) -> float:
	return frames.get_frame_count(anim) / maxf(frames.get_animation_speed(anim), 0.01)


## After `start`: hold the loop while the zone lasts; after `end`: nothing more to show.
func _on_art_finished() -> void:
	if _art.animation == &"start" and frames.has_animation(&"loop") and not _ending:
		_art.play(&"loop")
	elif _art.animation == &"end":
		_art.visible = false


func _physics_process(delta: float) -> void:
	_age += delta
	if on_tick.is_valid():
		_tick_left -= delta
		if _tick_left <= 0.0:
			_tick_left = tick_interval
			on_tick.call()
	if _art != null:
		_update_art()
	else:
		queue_redraw()
	if _age >= lifetime:
		queue_free()


func _update_art() -> void:
	var progress := clampf(_age / maxf(lifetime, 0.001), 0.0, 1.0)
	if shape == Shape.WAVE:
		# The crest rides from the caster to the wave's reach.
		_art.position = direction * radius * (0.15 + 0.75 * progress)
		return
	# A lasting circle: its `end` starts so that it finishes with the zone.
	if not _ending and frames.has_animation(&"end") and lifetime - _age <= _length_of(&"end"):
		_ending = true
		_art.play(&"end")
	elif _ending or not frames.has_animation(&"end"):
		# Without an `end` the art fades over the last part of the zone's life.
		if not frames.has_animation(&"end"):
			_art.modulate.a = clampf((1.0 - progress) * 3.0, 0.0, 1.0)


func _draw() -> void:
	if _art != null:
		return
	var progress := clampf(_age / maxf(lifetime, 0.001), 0.0, 1.0)
	match shape:
		Shape.CIRCLE:
			var fill := color
			fill.a = 0.22 * (1.0 - progress * 0.6)
			draw_circle(Vector2.ZERO, radius, fill)
			# A dark ring under the colored edge so the warning reads on bright grass too.
			if Tuning.ZONE_OUTLINE_ALPHA > 0.0:
				var shade := Color(0, 0, 0, Tuning.ZONE_OUTLINE_ALPHA * (1.0 - progress))
				draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, shade, 4.0)
			var edge := color
			edge.a = 0.8 * (1.0 - progress)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, edge, 2.0)
		Shape.WAVE:
			var reach := radius * (0.3 + 0.7 * progress)
			var edge := color
			edge.a = 0.9 * (1.0 - progress)
			var center_angle := direction.angle()
			draw_arc(Vector2.ZERO, reach, center_angle - arc / 2.0, center_angle + arc / 2.0, 20, edge, 4.0)
