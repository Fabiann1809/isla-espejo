class_name AmbientLife
extends Node2D
## Quiet life in the forest: a few fireflies drifting slowly and leaves falling. Two small particle
## emitters that follow the camera (so the cost does not grow with the map), drawn at ground level:
## under Nico, the enemies and every warning, never over them. Set and switched off in Tuning.

const NODE_NAME := "AmbientLife"
## The area around the camera where particles appear: the 640x360 view at zoom 2, plus a margin.
const AREA := Vector2(380, 220)

var _fireflies: CPUParticles2D
var _leaves: CPUParticles2D
## False until the emitters have been restarted around the camera (on start and on every new map:
## the preprocessed particles would otherwise be left where the node was).
var _placed := false


## Turns the forest's life on or off for the scenario being played, creating it the first time.
static func apply(level: Node, enabled: bool) -> void:
	var life := level.get_node_or_null(NODE_NAME) as AmbientLife
	if life == null:
		if not enabled:
			return
		life = AmbientLife.new()
		life.name = NODE_NAME
		level.add_child(life)
	life.set_enabled(enabled)


func _ready() -> void:
	z_index = RoomTheme.GROUND_FX_Z
	z_as_relative = false


func set_enabled(enabled: bool) -> void:
	visible = enabled
	set_process(enabled)
	_placed = false
	_clear()


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	global_position = camera.get_screen_center_position()
	if not _placed:
		_placed = true
		_build()


## The emitters are made where the camera already is: they prefill their particles (preprocess)
## when they enter the tree, and restarting them later did not.
func _build() -> void:
	if Tuning.FIREFLIES > 0:
		_fireflies = _emitter("Fireflies", Tuning.FIREFLIES, Tuning.FIREFLY_COLOR, 7.0)
		_fireflies.gravity = Vector2.ZERO
		_fireflies.initial_velocity_min = 2.0
		_fireflies.initial_velocity_max = 6.0
		_fireflies.spread = 180.0
		_fireflies.scale_amount_min = Tuning.FIREFLY_SIZE
		_fireflies.scale_amount_max = Tuning.FIREFLY_SIZE
		# They glow in and out instead of popping.
		_fireflies.color_ramp = _pulse(Tuning.FIREFLY_COLOR)
		add_child(_fireflies)
	if Tuning.FALLING_LEAVES > 0:
		_leaves = _emitter("Leaves", Tuning.FALLING_LEAVES, Tuning.LEAF_COLOR, 9.0)
		_leaves.direction = Vector2(0.4, 1.0)
		_leaves.spread = 20.0
		_leaves.gravity = Vector2(0, 2.0)
		_leaves.initial_velocity_min = 6.0
		_leaves.initial_velocity_max = 11.0
		_leaves.angular_velocity_min = -40.0
		_leaves.angular_velocity_max = 40.0
		_leaves.scale_amount_min = Tuning.LEAF_SIZE.x
		_leaves.scale_amount_max = Tuning.LEAF_SIZE.y
		_leaves.color_ramp = _pulse(Tuning.LEAF_COLOR)
		add_child(_leaves)


func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_fireflies = null
	_leaves = null


func _emitter(emitter_name: String, amount: int, color: Color, lifetime: float) -> CPUParticles2D:
	var emitter := CPUParticles2D.new()
	emitter.name = emitter_name
	emitter.amount = maxi(amount, 1)
	emitter.emitting = amount > 0
	emitter.lifetime = lifetime
	emitter.preprocess = lifetime
	emitter.randomness = 1.0
	# In the world: they stay where they are while the camera moves.
	emitter.local_coords = false
	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emitter.emission_rect_extents = AREA / 2.0
	emitter.color = color
	# Without a texture the emitter draws nothing: one white pixel, tinted by `color`.
	emitter.texture = _pixel()
	return emitter


static func _pixel() -> Texture2D:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func _pulse(color: Color) -> Gradient:
	# Offsets set in order: points added one by one are not sorted and the fade came out wrong.
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	ramp.colors = PackedColorArray([Color(color, 0.0), color, color, Color(color, 0.0)])
	return ramp
