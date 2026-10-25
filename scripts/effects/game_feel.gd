class_name GameFeel
extends Node
## Small, subtle effects that make hits read better: a hit stop of a few frames when Nico lands a
## hit, a short camera shake when he is hurt and a puff of particles when an enemy dies (enemies
## already flash white when hit). A playable level adds one GameFeel node (it listens to the Events
## bus and is freed with the level); all of it is set and can be switched off in Tuning.
## Headless runs (tests) skip the hit stop unless `force_hitstop` is set, so frame-counting tests
## keep their timing.

static var force_hitstop := false

var _hitstop_until := 0


## Adds the node that listens to the combat events for `level` (a Level with a `player`).
static func attach(level: Node) -> void:
	var feel := GameFeel.new()
	feel.name = "GameFeel"
	# Keeps running during the hit stop and the pause menu, to always give the time back.
	feel.process_mode = Node.PROCESS_MODE_ALWAYS
	level.add_child(feel)


func _ready() -> void:
	# Bound to this node: the connections go away with the level.
	Events.player_hit_enemy.connect(_on_player_hit_enemy)
	Events.player_damaged.connect(_on_player_damaged)
	Events.enemy_killed.connect(_on_enemy_killed)


func _on_player_hit_enemy(_enemy: Node, _damage: int) -> void:
	hitstop()


func _on_player_damaged(_amount: int, _from: Vector2) -> void:
	var player = get_parent().get("player")
	if player != null and is_instance_valid(player):
		shake(player.get_node_or_null("Camera2D"))


func _on_enemy_killed(enemy: Node) -> void:
	if enemy is Node2D and enemy.get_parent() != null:
		death_puff(enemy.get_parent(), enemy.position, _color_of(enemy))


## Freezes the game for Tuning.HITSTOP_FRAMES frames of real time; `_process` resumes it (timers
## that ignore the time scale proved unreliable while it is 0).
func hitstop() -> void:
	if Tuning.HITSTOP_FRAMES <= 0 or (DisplayServer.get_name() == "headless" and not force_hitstop):
		return
	var duration_usec := roundi(Tuning.HITSTOP_FRAMES * 1000000.0 / Engine.physics_ticks_per_second)
	# Several hits in a row extend the stop instead of stacking.
	_hitstop_until = maxi(_hitstop_until, Time.get_ticks_usec() + duration_usec)
	Engine.time_scale = 0.0


func _process(_delta: float) -> void:
	if _hitstop_until > 0 and Time.get_ticks_usec() >= _hitstop_until:
		_resume()


func _exit_tree() -> void:
	if _hitstop_until > 0:
		_resume()


func _resume() -> void:
	_hitstop_until = 0
	Engine.time_scale = 1.0


## A short random shake of the camera's offset.
static func shake(camera: Camera2D) -> void:
	if camera == null or Tuning.SHAKE_STRENGTH <= 0.0:
		return
	var tween := camera.create_tween()
	var steps := maxi(roundi(Tuning.SHAKE_DURATION / 0.03), 1)
	for i in steps:
		var fade := 1.0 - float(i) / steps
		var push := Vector2.from_angle(randf() * TAU) * Tuning.SHAKE_STRENGTH * fade
		tween.tween_property(camera, "offset", push.round(), 0.03)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.03)


## A one-shot burst of small squares where an enemy died.
static func death_puff(parent: Node, at: Vector2, color: Color) -> void:
	if Tuning.DEATH_PARTICLES <= 0:
		return
	var particles := CPUParticles2D.new()
	particles.name = "DeathPuff"
	particles.position = at
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = Tuning.DEATH_PARTICLES
	particles.lifetime = Tuning.DEATH_PARTICLE_LIFETIME
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, 60)
	particles.initial_velocity_min = 25.0
	particles.initial_velocity_max = 55.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	particles.color = color
	var fade := Gradient.new()
	fade.set_color(0, color)
	fade.set_color(1, Color(color, 0.0))
	particles.color_ramp = fade
	particles.finished.connect(particles.queue_free)
	parent.add_child(particles)
	particles.emitting = true


## The dark mist enemies leave: their placeholder color darkened, or a neutral shade.
static func _color_of(enemy: Node) -> Color:
	var data = enemy.get("data")
	if data != null and data.get("placeholder_color") != null:
		return (data.placeholder_color as Color).lerp(Tuning.DEATH_PARTICLE_COLOR, 0.6)
	return Tuning.DEATH_PARTICLE_COLOR
