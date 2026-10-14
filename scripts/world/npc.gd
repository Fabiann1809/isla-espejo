class_name Npc
extends StaticBody2D
## A talkable character. Which lines it says is decided by its dialogue file
## (data/dialogues/<dialogue_id>.json) and the story flags, not by this script.
## Placeholder art: a colored figure with the speaker's name above it.

@export var dialogue_id: StringName = &"elder"
@export var body_color := Color(0.75, 0.7, 0.6)

@onready var _talk: Interactable = $Talk
@onready var _body: ColorRect = $Body
@onready var _name: Label = $Name


func _ready() -> void:
	add_to_group("npcs")
	_body.color = body_color
	_name.text = Dialogue.load_dialogue(dialogue_id).get("speaker", "")
	_talk.interacted.connect(_on_talk)


func _on_talk(_player: Node) -> void:
	Dialogue.start(dialogue_id)
