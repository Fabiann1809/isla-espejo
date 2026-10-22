class_name Npc
extends StaticBody2D
## A talkable character. Which lines it says is decided by its dialogue file
## (data/dialogues/<dialogue_id>.json) and the story flags, not by this script.
## Art is optional: with `sprite_frames` (64x64 cells, animation "idle") the NPC shows that;
## without it, a colored figure. Either way the speaker's name is shown above it.

## 64x64 NPC art is drawn at half size so the character is as tall as Nico (about 29 px).
const ART_SCALE := 0.5
## Local y of the feet of an NPC with art, and where they are in a 64x64 cell (row 62 of 64).
const FEET_Y := 7.0
const CELL_FEET_ROW := 30.0

@export var dialogue_id: StringName = &"elder"
@export var body_color := Color(0.75, 0.7, 0.6)
@export var sprite_frames: SpriteFrames
@export var sprite_scale := ART_SCALE

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
		_sprite.position.y = FEET_Y - CELL_FEET_ROW * sprite_scale
		_sprite.visible = true
		_sprite.play(&"idle")
		# The name sits right above the head, whatever the scale.
		_name.offset_bottom = FEET_Y - 2.0 * CELL_FEET_ROW * sprite_scale - 2.0
		_name.offset_top = _name.offset_bottom - 18.0
	_name.text = Dialogue.load_dialogue(dialogue_id).get("speaker", "")
	_talk.interacted.connect(_on_talk)


func _on_talk(_player: Node) -> void:
	Dialogue.start(dialogue_id)
