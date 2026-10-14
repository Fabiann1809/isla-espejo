class_name ExitPortal
extends Node2D
## The way out of a scenario. It stays hidden and unusable until the scenario's boss has been
## defeated (its story flag is set); then E takes the player to the next chapter.
## Placeholder art: a glowing violet doorway.

## The portal opens when this flag is set (the boss's `defeated_flag`).
@export var required_flag: StringName = &"forest_boss_defeated"
## Set by the Level that places the portal.
var scenario_id: StringName = &""
var _time := 0.0

@onready var _glow: Polygon2D = $Glow
@onready var _use: Interactable = $Use


func _ready() -> void:
	add_to_group("exit_portals")
	_use.interacted.connect(_on_used)
	Events.boss_defeated.connect(func(_id: StringName) -> void: _refresh())
	_refresh()


func _process(delta: float) -> void:
	if _glow.visible:
		_time += delta
		_glow.modulate.a = 0.6 + 0.3 * sin(_time * 4.0)


func is_open() -> bool:
	return GameState.has_flag(required_flag)


func _refresh() -> void:
	var open := is_open()
	_glow.visible = open
	_use.enabled = open


func _on_used(_player: Node) -> void:
	if is_open():
		Events.scenario_completed.emit(scenario_id)
