class_name Chest
extends StaticBody2D
## A chest with a basic reward. Opens once.

enum Reward { HEAL, MAX_HEALTH }

@export var reward: Reward = Reward.HEAL
## Health restored, or hearts added to the maximum.
@export var amount := 2
## What the island tells the player (Spanish).
@export var message := "Has encontrado una mejora."

var opened := false

@onready var _sprite: Sprite2D = $Sprite
@onready var _talk: Interactable = $Open


func _ready() -> void:
	add_to_group("chests")
	_sprite.texture = TileArt.tile(TileArt.CHEST_CLOSED)
	_talk.interacted.connect(_on_open)


func _on_open(player: Node) -> void:
	if opened:
		return
	opened = true
	_talk.enabled = false
	_sprite.texture = TileArt.tile(TileArt.CHEST_OPEN)
	match reward:
		Reward.HEAL:
			player.health.heal(amount)
		Reward.MAX_HEALTH:
			player.health.increase_max(amount)
	Events.message_requested.emit(message)
	Events.chest_opened.emit(self)
