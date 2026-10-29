class_name ExitPortal
extends Node2D
## The way out of a scenario. It stays closed and unusable until the scenario's boss has been
## defeated (its story flag is set); then E takes the player to the next chapter.
## Placeholder art: a glowing violet doorway on a base of flagstones. The base shows from the start
## (the player knows where the way out will be); light and sparks join the glow once it opens.

## The portal opens when this flag is set (the boss's `defeated_flag`).
@export var required_flag: StringName = &"forest_boss_defeated"
## How far down the base's sort point goes (past the bottom of any room).
const BASE_SORT_OFFSET := 320.0

## Set by the Level that places the portal.
var scenario_id: StringName = &""
var _time := 0.0
var _light: Sprite2D
var _sparks: CPUParticles2D

@onready var _glow: Polygon2D = $Glow
@onready var _use: Interactable = $Use


func _ready() -> void:
	add_to_group("exit_portals")
	_build_base()
	_use.interacted.connect(_on_used)
	Events.boss_defeated.connect(func(_id: StringName) -> void: _refresh())
	_refresh()


func _process(delta: float) -> void:
	if _glow.visible:
		_time += delta
		_glow.modulate.a = 0.6 + 0.3 * sin(_time * 4.0)
		if _light != null:
			_light.modulate.a = Tuning.PORTAL_LIGHT.a * (0.8 + 0.2 * sin(_time * 4.0))


func is_open() -> bool:
	return GameState.has_flag(required_flag)


func _refresh() -> void:
	var open := is_open()
	_glow.visible = open
	_use.enabled = open
	if _light != null:
		_light.visible = open
	if _sparks != null:
		_sparks.emitting = open


func _on_used(_player: Node) -> void:
	if is_open():
		Events.scenario_completed.emit(scenario_id)


## Flagstones under the doorway (on the floor), and the light and sparks it shows once open.
func _build_base() -> void:
	if not Tuning.PORTAL_BASE:
		return
	var base := Node2D.new()
	base.name = "Base"
	base.z_index = RoomTheme.FLOOR_Z
	base.z_as_relative = false
	# With the floors, but sorted after the room's ground decoration (the arena's shade and roots,
	# whose origin is the room's bottom), so they never cover the flagstones.
	base.position = Vector2(0, BASE_SORT_OFFSET)
	add_child(base)
	move_child(base, 0)
	var size := Vector2i(3, 2)
	for y in size.y:
		for x in size.x:
			var tile := TileArt.nine_slice_tile(TileArt.STONE_FLOOR, x, y, size)
			base.add_child(TileArt.sprite_of(tile, Vector2(x * TileArt.TILE - 24, y * TileArt.TILE - 8 - BASE_SORT_OFFSET)))
	if Tuning.PORTAL_LIGHT.a > 0.0:
		_light = RoomDressing.make_glow(Tuning.PORTAL_LIGHT, Vector2.ONE * Tuning.PORTAL_LIGHT_RADIUS * 2.0, true)
		_light.name = "Light"
		_light.position = Vector2(0, 4)
		_light.z_index = RoomTheme.GROUND_FX_Z
		_light.z_as_relative = false
		add_child(_light)
	if Tuning.PORTAL_SPARKS > 0:
		_sparks = CPUParticles2D.new()
		_sparks.name = "Sparks"
		_sparks.amount = Tuning.PORTAL_SPARKS
		_sparks.lifetime = 1.2
		_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_sparks.emission_rect_extents = Vector2(9, 3)
		_sparks.position = Vector2(0, 6)
		_sparks.direction = Vector2.UP
		_sparks.spread = 12.0
		_sparks.gravity = Vector2.ZERO
		_sparks.initial_velocity_min = 10.0
		_sparks.initial_velocity_max = 18.0
		_sparks.color = Color(0.85, 0.7, 1.0, 0.9)
		_sparks.texture = RoomDressing.pixel()
		_sparks.scale_amount_min = 1.0
		_sparks.scale_amount_max = 2.0
		_sparks.emitting = false
		add_child(_sparks)
