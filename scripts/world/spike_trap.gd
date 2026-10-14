extends Node2D
## Floor trap: cycles between retracted and extended. Extended spikes hurt the player.
## Reused later for the Templo del Eclipse traps.

@export var retracted_time := 1.4
@export var extended_time := 0.5
@export var damage := 1

var _active := false
var _time := 0.0

@onready var _hitbox: Hitbox = $Hitbox
@onready var _spikes: ColorRect = $Spikes


func _ready() -> void:
	_hitbox.damage = damage
	_set_active(false)


func _physics_process(delta: float) -> void:
	_time += delta
	if _active and _time >= extended_time:
		_set_active(false)
	elif not _active and _time >= retracted_time:
		_set_active(true)


func _set_active(active: bool) -> void:
	_active = active
	_time = 0.0
	_spikes.visible = active
	if active:
		_hitbox.activate()
	else:
		_hitbox.deactivate()
