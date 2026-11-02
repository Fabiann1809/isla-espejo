class_name GameFeel
extends Node2D
## What a blow feels like: a brief freeze (hit stop), the camera shaking, sparks in the enemy's
## color, damage numbers, a red flash when Nico is hurt and a red edge while his health is low.
## It only listens to the Events bus (combat code knows nothing about it) and every effect has its
## value and its off switch in Tuning. The Level adds one; it acts on the player's Camera2D.

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color;
void fragment() {
	float edge = smoothstep(0.3, 0.75, distance(UV, vec2(0.5)) * 1.2);
	COLOR = vec4(tint.rgb, tint.a * edge);
}
"""
## A flat silhouette of the sprite in one color: the dodge trail reads as a trail, not a second Nico.
const SILHOUETTE_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color;
void fragment() {
	COLOR = vec4(tint.rgb, COLOR.a * tint.a);
}
"""
## Above the actors and the props: these effects last an instant and must never hide behind a tree.
const EFFECT_Z := 10

## Off in headless runs, so tests that count frames or seconds are not slowed down by the freezes
## (tests switch it on to check it).
var hit_stop_enabled := DisplayServer.get_name() != "headless"

var _hit_stop_until := 0
var _shake_strength := 0.0
var _shake_time := 0.0
var _shake_total := 0.0
var _flash: ColorRect
var _low_health: ColorRect
var _low_health_on := false
var _pulse_time := 0.0
var _ghost_material: ShaderMaterial


func _ready() -> void:
	z_index = EFFECT_Z
	z_as_relative = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	if not Tuning.GAME_FEEL_ENABLED:
		return
	Events.enemy_damaged.connect(_on_enemy_damaged)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.player_damaged.connect(_on_player_damaged)
	Events.player_health_changed.connect(_on_player_health_changed)
	Events.player_dashed.connect(_on_player_dashed)
	Events.boss_attack_struck.connect(_on_boss_attack_struck)
	Events.boss_phase_changed.connect(func(_id: StringName, _phase: int) -> void:
		hit_stop(Tuning.HIT_STOP_BOSS_PHASE)
		shake(Tuning.SHAKE_BOSS_PHASE))
	Events.boss_defeated.connect(func(_id: StringName) -> void:
		hit_stop(Tuning.HIT_STOP_BOSS_DEFEATED)
		shake(Tuning.SHAKE_BOSS_DEFEATED))


func _exit_tree() -> void:
	# Never leave the game slowed down (a scene change in the middle of a freeze).
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	# Real time: these keep running during a hit stop (and the time scale does not slow them).
	var real_delta := delta / maxf(Engine.time_scale, 0.0001)
	if _hit_stop_until > 0 and Time.get_ticks_msec() >= _hit_stop_until:
		_hit_stop_until = 0
		Engine.time_scale = 1.0
	_update_shake(real_delta)
	if _low_health_on:
		_pulse_time += real_delta
		var tint := Tuning.LOW_HEALTH_PULSE
		tint.a *= 0.6 + 0.4 * sin(_pulse_time * 4.0)
		(_low_health.material as ShaderMaterial).set_shader_parameter("tint", tint)


## Freezes the game for `seconds` of real time (the longest of overlapping freezes wins).
func hit_stop(seconds: float) -> void:
	if not hit_stop_enabled or seconds <= 0.0:
		return
	_hit_stop_until = maxi(_hit_stop_until, Time.get_ticks_msec() + int(seconds * 1000.0))
	Engine.time_scale = Tuning.HIT_STOP_SCALE


## Shakes the camera: `amount.x` px at first, fading out over `amount.y` seconds. A stronger shake
## replaces a weaker one; a weaker one never cuts a strong one short.
func shake(amount: Vector2) -> void:
	if amount.x <= 0.0 or amount.y <= 0.0:
		return
	if amount.x >= _shake_strength * (_shake_time / maxf(_shake_total, 0.001)):
		_shake_strength = amount.x
		_shake_time = amount.y
		_shake_total = amount.y


func is_shaking() -> bool:
	return _shake_time > 0.0


func is_hit_stopped() -> bool:
	return _hit_stop_until > 0


func _update_shake(real_delta: float) -> void:
	var camera := _camera()
	if camera == null:
		return
	if _shake_time <= 0.0:
		if camera.offset != Vector2.ZERO:
			camera.offset = Vector2.ZERO
		return
	_shake_time = maxf(_shake_time - real_delta, 0.0)
	var power := _shake_strength * (_shake_time / _shake_total)
	# Whole pixels: the art is pixel art and the view is 480x270.
	camera.offset = Vector2(roundf(randf_range(-power, power)), roundf(randf_range(-power, power)))


func _camera() -> Camera2D:
	var player := get_tree().get_first_node_in_group("player")
	return player.get_node_or_null("Camera2D") as Camera2D if player != null else null


# --- Reactions ------------------------------------------------------------------------------------

func _on_enemy_damaged(enemy: Node, amount: int) -> void:
	var body := enemy as Node2D
	if body == null or not is_instance_valid(body):
		return
	burst(body.global_position + Vector2(0, -8), _color_of(enemy), Tuning.HIT_PARTICLES, Tuning.HIT_PARTICLE_SPEED)
	damage_number(body.global_position + Vector2(0, -20), amount, enemy is Boss)


func _on_enemy_killed(enemy: Node) -> void:
	var body := enemy as Node2D
	if body == null or not is_instance_valid(body):
		return
	burst(body.global_position + Vector2(0, -8), _color_of(enemy), Tuning.DEATH_PARTICLES,
			Tuning.DEATH_PARTICLE_SPEED)
	if not enemy is Boss:
		hit_stop(Tuning.HIT_STOP_KILL)
		shake(Tuning.SHAKE_KILL)


func _on_player_damaged(_amount: int, _source_position: Vector2) -> void:
	hit_stop(Tuning.HIT_STOP_PLAYER_HURT)
	shake(Tuning.SHAKE_PLAYER_HURT)
	if Tuning.HURT_FLASH.a > 0.0 and Tuning.HURT_FLASH_TIME > 0.0:
		_flash.color = Tuning.HURT_FLASH
		var tween := create_tween()
		tween.set_ignore_time_scale(true)
		tween.tween_property(_flash, "color:a", 0.0, Tuning.HURT_FLASH_TIME)


func _on_player_health_changed(current: int, _maximum: int) -> void:
	_low_health_on = Tuning.LOW_HEALTH > 0 and current > 0 and current <= Tuning.LOW_HEALTH
	_low_health.visible = _low_health_on


func _on_player_dashed(_direction: Vector2) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	burst(player.global_position, Tuning.DASH_DUST_COLOR, Tuning.DASH_DUST, Tuning.DASH_DUST_SPEED)
	for i in Tuning.DASH_GHOSTS:
		if i > 0:
			await get_tree().create_timer(Tuning.DASH_GHOST_EVERY, false).timeout
		if not is_instance_valid(player):
			return
		afterimage(player)


## A still silhouette of the actor's current frame that fades where it stands.
func afterimage(actor: Node2D) -> void:
	var sprite := actor.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.flip_h = sprite.flip_h
	ghost.offset = sprite.offset
	ghost.centered = sprite.centered
	ghost.scale = sprite.scale
	ghost.material = _ghost_shader()
	# Under every actor (Nico runs ahead of his own trail), over the floors.
	ghost.z_as_relative = false
	ghost.z_index = RoomTheme.GROUND_FX_Z
	_keep_still(ghost)
	add_child(ghost)
	ghost.global_position = sprite.global_position
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, Tuning.DASH_GHOST_FADE)
	tween.tween_callback(ghost.queue_free)


## Effects appear where they belong and stay there: with physics interpolation the game would draw
## their first frame on the way from the map's origin, a stray copy of Nico far from him.
func _keep_still(node: Node2D) -> void:
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _ghost_shader() -> ShaderMaterial:
	if _ghost_material == null:
		var shader := Shader.new()
		shader.code = SILHOUETTE_SHADER
		_ghost_material = ShaderMaterial.new()
		_ghost_material.shader = shader
		_ghost_material.set_shader_parameter("tint", Tuning.DASH_GHOST_TINT)
	return _ghost_material


func _on_boss_attack_struck(_boss_id: StringName, pattern: StringName, _at: Vector2) -> void:
	# Heavy blows (a slam, a charge) shake hard; spread attacks (roots, a spit) shake lightly.
	shake(Tuning.SHAKE_BOSS_SLAM if pattern in [&"slam", &"charge"] else Tuning.SHAKE_BOSS_ROOTS)


# --- Effects --------------------------------------------------------------------------------------

## Throws `count` square sparks of `color` from `at` (world position); they free themselves.
func burst(at: Vector2, color: Color, count: int, speed: float) -> void:
	if count <= 0:
		return
	var sparks := CPUParticles2D.new()
	sparks.texture = RoomDressing.pixel()
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = count
	sparks.lifetime = Tuning.PARTICLE_LIFETIME
	sparks.direction = Vector2.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = speed * 0.4
	sparks.initial_velocity_max = speed
	sparks.gravity = Vector2(0, Tuning.PARTICLE_GRAVITY)
	sparks.damping_min = Tuning.PARTICLE_DAMPING.x
	sparks.damping_max = Tuning.PARTICLE_DAMPING.y
	sparks.scale_amount_min = Tuning.PARTICLE_SIZE.x
	sparks.scale_amount_max = Tuning.PARTICLE_SIZE.y
	sparks.color = color
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	sparks.color_ramp = fade
	_keep_still(sparks)
	add_child(sparks)
	sparks.global_position = at
	sparks.emitting = true
	# A timer, not `finished`: that signal does not come when the particles are not drawn.
	get_tree().create_timer(sparks.lifetime + 0.1, false).timeout.connect(sparks.queue_free)


## A number that rises and fades over `at` (world position).
func damage_number(at: Vector2, amount: int, boss := false) -> void:
	if Tuning.DAMAGE_NUMBER_TIME <= 0.0 or amount <= 0:
		return
	var label := Label.new()
	label.text = str(amount)
	label.add_theme_font_size_override("font_size", Tuning.DAMAGE_NUMBER_SIZE)
	label.add_theme_color_override("font_color", Tuning.DAMAGE_NUMBER_BOSS_COLOR if boss else Tuning.DAMAGE_NUMBER_COLOR)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.05))
	label.add_theme_constant_override("outline_size", 4)
	var font := UiKit.pixel_font()
	if font != null:
		label.add_theme_font_override("font", font)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(24, 16)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	# A little sideways jitter so numbers of quick hits do not stack into one.
	label.global_position = at - label.size / 2.0 + Vector2(randf_range(-4.0, 4.0), 0)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - Tuning.DAMAGE_NUMBER_RISE,
			Tuning.DAMAGE_NUMBER_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, Tuning.DAMAGE_NUMBER_TIME * 0.5) \
			.set_delay(Tuning.DAMAGE_NUMBER_TIME * 0.5)
	tween.tween_callback(label.queue_free)


func _color_of(enemy: Node) -> Color:
	var data = enemy.get("data")
	return data.placeholder_color if data != null else Color.WHITE


## The red flash and the low-health edge, over the world and under the HUD.
func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "FeelOverlay"
	add_child(layer)
	_flash = ColorRect.new()
	_flash.name = "HurtFlash"
	_flash.color = Color(0, 0, 0, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)
	_low_health = ColorRect.new()
	_low_health.name = "LowHealth"
	_low_health.set_anchors_preset(Control.PRESET_FULL_RECT)
	_low_health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("tint", Tuning.LOW_HEALTH_PULSE)
	_low_health.material = material
	_low_health.visible = false
	layer.add_child(_low_health)
