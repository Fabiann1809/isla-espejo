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
## When the player comes close enough for both to be seen together (`Tuning.NPC_GREET_DISTANCE`) the
## conversation starts by itself, once (the Anciano greets Nico): only while the dialogue would still play
## its "first" lines.
@export var talk_on_enter := false
## A merchant: once his conversation ends, the shop (ShopMenu) opens for the player who spoke to him.
@export var opens_shop := false

@onready var _talk: Interactable = $Talk
@onready var _body: ColorRect = $Body
@onready var _name: Label = $Name
@onready var _sprite: AnimatedSprite2D = $Sprite

var _greeted := false
var _shop: ShopMenu
var _talker: Node
## Seconds until the next gesture (only with a "gesture" animation).
var _gesture_left := 0.0
var _gesture_rng := RandomNumberGenerator.new()


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
		add_child(IdleBreath.new())
		if _has_gesture():
			_gesture_rng.randomize()
			_gesture_left = _next_gesture_delay()
			_sprite.animation_finished.connect(_on_sprite_animation_finished)
		# The name sits right above the head, whatever the scale.
		_name.offset_bottom = FEET_Y - 2.0 * CELL_FEET_ROW * sprite_scale - 2.0
		_name.offset_top = _name.offset_bottom - 18.0
	_name.text = Dialogue.load_dialogue(dialogue_id).get("speaker", "")
	_talk.interacted.connect(_on_talk)
	set_physics_process(talk_on_enter)
	if opens_shop:
		Events.dialogue_finished.connect(_on_dialogue_finished)


## Waits until the player is near (so the screen shows both of them), then greets after a beat.
func _physics_process(_delta: float) -> void:
	if _greeted or Dialogue.active:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or global_position.distance_to(player.global_position) > Tuning.NPC_GREET_DISTANCE:
		return
	if Dialogue.pick_state(Dialogue.load_dialogue(dialogue_id)) != &"first":
		_greeted = true           # they have met: he only talks when talked to
		return
	_greeted = true
	await get_tree().create_timer(Tuning.NPC_GREET_DELAY).timeout
	if is_inside_tree() and not Dialogue.active and global_position.distance_to(player.global_position) <= Tuning.NPC_GREET_DISTANCE * 1.5:
		Dialogue.start(dialogue_id)


func _process(delta: float) -> void:
	if not _has_gesture() or _sprite.animation == &"gesture":
		return
	_gesture_left -= delta
	if _gesture_left <= 0.0:
		play_gesture()


## Plays the NPC's gesture once, then it stands still on "idle" again.
func play_gesture() -> void:
	if _has_gesture():
		_sprite.play(&"gesture")


func _has_gesture() -> bool:
	return Tuning.NPC_GESTURES_ENABLED and sprite_frames != null and sprite_frames.has_animation(&"gesture")


func _next_gesture_delay() -> float:
	return _gesture_rng.randf_range(Tuning.NPC_GESTURE_MIN, Tuning.NPC_GESTURE_MAX)


func _on_sprite_animation_finished() -> void:
	if _sprite.animation == &"gesture":
		_sprite.play(&"idle")
		_gesture_left = _next_gesture_delay()


func _on_talk(player: Node) -> void:
	_talker = player
	play_gesture()
	Dialogue.start(dialogue_id)


func _on_dialogue_finished(finished_id: StringName, _state: StringName) -> void:
	if finished_id != dialogue_id or _talker == null or not Tuning.SHOP_ENABLED:
		return
	if _shop == null:
		_shop = ShopMenu.new()
		add_child(_shop)
	_shop.open(_talker)
