extends CanvasLayer
## In-game HUD. Reads state from the Events bus only. Placeholder art (colored squares).

const HEART_SIZE := Vector2(10, 10)
const HEART_FULL := Color(0.85, 0.2, 0.25)
const HEART_EMPTY := Color(0.25, 0.1, 0.12)

const TOAST_SECONDS := 3.2
const TOAST_FADE := 0.8

@onready var _hearts: HBoxContainer = $Margin/Hearts
@onready var _message: Label = $Message
@onready var _toast: Label = $Toast
@onready var _prompt: Label = $Prompt
@onready var _boss_bar: Control = $BossBar
@onready var _boss_name: Label = $BossBar/Name
@onready var _boss_fill: ColorRect = $BossBar/Track/Fill

var _toast_queue: Array[String] = []
var _toast_busy := false


func _ready() -> void:
	Events.player_health_changed.connect(_on_player_health_changed)
	Director.plan_made.connect(_on_plan_made)
	Events.message_requested.connect(show_toast)
	Events.interaction_prompt_changed.connect(_on_prompt_changed)
	Events.boss_health_changed.connect(_on_boss_health_changed)
	Events.boss_defeated.connect(func(_id: StringName) -> void: _boss_bar.hide())
	Events.player_died.connect(func() -> void: _boss_bar.hide())
	_boss_bar.hide()
	_message.hide()
	_toast.hide()
	_prompt.hide()


func show_message(text: String) -> void:
	_message.text = text
	_message.show()


## A line that fades away by itself. Several lines are shown one after another.
func show_toast(text: String) -> void:
	if text == "":
		return
	_toast_queue.append(text)
	if not _toast_busy:
		_show_next_toast()


func _show_next_toast() -> void:
	if _toast_queue.is_empty():
		_toast_busy = false
		return
	_toast_busy = true
	_toast.text = _toast_queue.pop_front()
	_toast.modulate.a = 1.0
	_toast.show()
	var tween := create_tween()
	tween.tween_interval(TOAST_SECONDS)
	tween.tween_property(_toast, "modulate:a", 0.0, TOAST_FADE)
	tween.tween_callback(func() -> void:
		_toast.hide()
		_show_next_toast())


func _on_boss_health_changed(_boss_id: StringName, current: int, maximum: int, boss_name: String) -> void:
	_boss_name.text = boss_name
	_boss_fill.anchor_right = float(current) / maxf(maximum, 1)
	_boss_bar.show()


func _on_prompt_changed(prompt: String) -> void:
	_prompt.text = "[E] " + prompt
	_prompt.visible = prompt != ""


func _on_plan_made(plan: DirectorPlan) -> void:
	if plan.island_line != "":
		show_toast(plan.island_line)


func _on_player_health_changed(current: int, maximum: int) -> void:
	for child in _hearts.get_children():
		child.queue_free()
	for i in maximum:
		var heart := ColorRect.new()
		heart.custom_minimum_size = HEART_SIZE
		heart.color = HEART_FULL if i < current else HEART_EMPTY
		_hearts.add_child(heart)
