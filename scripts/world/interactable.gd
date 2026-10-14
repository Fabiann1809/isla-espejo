class_name Interactable
extends Area2D
## Something the player can use with the interact key (E): a chest, an NPC, a door...
## Put it as a child of the object, with a CollisionShape2D a bit larger than the object. The player
## detects the nearest one, shows its `prompt` and calls `interact()` when E is pressed.
## Subclass and override `_on_interact`, or connect to `interacted`.

signal interacted(player: Node)

## Short Spanish verb shown to the player ("Hablar", "Abrir").
@export var prompt := "Interactuar"
var enabled := true


func _ready() -> void:
	collision_layer = 32
	collision_mask = 0
	monitoring = false


func interact(player: Node) -> void:
	if not enabled:
		return
	_on_interact(player)
	interacted.emit(player)


func _on_interact(_player: Node) -> void:
	pass
