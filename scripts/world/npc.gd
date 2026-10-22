class_name Npc
extends StaticBody2D
## A talkable character. Which lines it says is decided by its dialogue file
## (data/dialogues/<dialogue_id>.json) and the story flags, not by this script.
## Art is optional: with `sprite_frames` (64x64 cells, animation "idle") the NPC shows that;
## without it, a colored figure. Either way the speaker's name is shown above it.

## Taller than the colored figure, so the name goes higher.
const SPRITE_NAME_TOP := -66.0

@export var dialogue_id: StringName = &"elder"
@export var body_color := Color(0.75, 0.7, 0.6)
@export var sprite_frames: SpriteFrames
@export var sprite_scale := 1.0

@onready var _talk: Interactable = $Talk
@onready var _body: ColorRect = $Body
@onready var _name: Label = $Name
@onready var _sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	add_to_group("npcs")
	_body.color = body_color
	if sprite_frames != null:
		_body.visible = false
		_sprite.sprite_frames = sprite_frames
		_sprite.scale = Vector2.ONE * sprite_scale
		_sprite.visible = true
		_sprite.play(&"idle")
		_name.offset_top = SPRITE_NAME_TOP
		_name.offset_bottom = SPRITE_NAME_TOP + 18.0
	_name.text = Dialogue.load_dialogue(dialogue_id).get("speaker", "")
	_talk.interacted.connect(_on_talk)


func _on_talk(_player: Node) -> void:
	Dialogue.start(dialogue_id)
