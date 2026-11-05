extends CanvasLayer
## In-game HUD. Reads state from the Events bus only. Hearts are small pixel icons drawn in code.

const HEART_FULL := Color(0.85, 0.2, 0.25)
const HEART_EMPTY := Color(0.25, 0.1, 0.12)
## A 9x8 heart: 1 = fill, 2 = highlight, 3 = dark outline.
const HEART_SHAPE := [
	"033303330",
	"312231113",
	"311111113",
	"311111113",
	"031111130",
	"003111300",
	"000313000",
	"000030000",
]
## The boss bar's pale trail shows the damage of the last hits, then catches up.
const BOSS_TRAIL_COLOR := Color(1.0, 0.85, 0.7, 0.9)
const BOSS_TRAIL_DELAY := 0.35
const BOSS_TRAIL_TIME := 0.4
## The boss's name over the screen when its fight starts, with black bars above and below.
const BOSS_CARD_TIME := 2.2
const BOSS_CARD_BARS := 22.0

## Compass fragment ids in story order, with the color each one has in the world.
const FRAGMENT_COLORS := {&"green": Color(0.35, 0.85, 0.4), &"blue": Color(0.35, 0.6, 0.95), &"violet": Color(0.7, 0.45, 0.95)}
const FRAGMENT_SIZE := Vector2(8, 8)
const FRAGMENT_MISSING := Color(0.2, 0.2, 0.26)

const TOAST_SECONDS := 3.2
const TOAST_FADE := 0.8
## The small "saved" note in the bottom right corner.
const SAVED_SECONDS := 1.4
const SAVED_FADE := 0.6

@onready var _hearts: HBoxContainer = $Margin/Hearts
@onready var _message: Label = $Message
@onready var _toast: Label = $Toast
@onready var _prompt: Label = $Prompt
@onready var _boss_bar: Control = $BossBar
@onready var _boss_name: Label = $BossBar/Name
@onready var _boss_fill: ColorRect = $BossBar/Track/Fill

const GOLD_COLOR := Color(1.0, 0.8, 0.25)
const BUFF_BAR_SIZE := Vector2(40, 3)

var _fragment_icons := {}
var _gold_label: Label
var _buff_row: Control
var _buff_icon: ColorRect
var _buff_fill: ColorRect
var _buff_left := 0.0
var _buff_total := 1.0
var _objective: Label
var _toast_queue: Array[String] = []
var _toast_busy := false
var _heart_full: Texture2D
var _heart_empty: Texture2D
var _boss_trail: ColorRect
var _boss_trail_tween: Tween
var _announced_bosses := {}
## The controls hint of a new journey: it leaves once the player has shot and dodged.
var _hint: Label
var _hint_dodged := false
var _hint_shot := false
var _saved_note: Label
var _saved_tween: Tween


func _ready() -> void:
	Events.player_health_changed.connect(_on_player_health_changed)
	Director.plan_made.connect(_on_plan_made)
	Events.message_requested.connect(show_toast)
	Events.interaction_prompt_changed.connect(_on_prompt_changed)
	Events.boss_health_changed.connect(_on_boss_health_changed)
	Events.boss_defeated.connect(func(_id: StringName) -> void: _boss_bar.hide())
	Events.player_died.connect(func() -> void: _boss_bar.hide())
	_heart_full = _heart_texture(HEART_FULL)
	_heart_empty = _heart_texture(HEART_EMPTY)
	_build_boss_trail()
	_build_controls_hint()
	_build_saved_note()
	_build_fragments_and_objective()
	_build_resources()
	Events.player_gold_changed.connect(func(total: int) -> void: _gold_label.text = str(total))
	Events.player_buff_changed.connect(_on_buff_changed)
	Events.objective_changed.connect(func(text: String) -> void: _objective.text = text)
	Events.fragment_collected.connect(func(_id: StringName) -> void: _refresh_fragments())
	_boss_bar.hide()
	_message.hide()
	_toast.hide()
	_prompt.hide()


## Three compass fragment icons (dim until collected) and the objective line under the hearts.
func _build_fragments_and_objective() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(8, 24)
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	for id: StringName in FRAGMENT_COLORS:
		var icon := ColorRect.new()
		icon.custom_minimum_size = FRAGMENT_SIZE
		row.add_child(icon)
		_fragment_icons[id] = icon
	_objective = Label.new()
	_objective.position = Vector2(8, 38)
	_objective.add_theme_font_size_override("font_size", 10)
	_objective.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	_outline(_objective)
	add_child(_objective)
	_refresh_fragments()


## Gold counter and the timed-effect icon, both in the top right corner. The effect only shows
## while it lasts, so the HUD stays empty otherwise.
func _build_resources() -> void:
	var gold_row := HBoxContainer.new()
	gold_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	gold_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	gold_row.position = Vector2(-8, 8)
	gold_row.add_theme_constant_override("separation", 4)
	gold_row.alignment = BoxContainer.ALIGNMENT_END
	add_child(gold_row)
	_gold_label = Label.new()
	_gold_label.text = "0"
	_gold_label.add_theme_font_size_override("font_size", 10)
	_gold_label.add_theme_color_override("font_color", GOLD_COLOR)
	_outline(_gold_label)
	gold_row.add_child(_gold_label)
	var coin := ColorRect.new()
	coin.custom_minimum_size = Vector2(8, 8)
	coin.color = GOLD_COLOR
	gold_row.add_child(coin)

	_buff_row = Control.new()
	_buff_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_buff_row.position = Vector2(-8 - 58, 24)
	_buff_icon = ColorRect.new()
	_buff_icon.size = Vector2(8, 8)
	_buff_row.add_child(_buff_icon)
	var track := ColorRect.new()
	track.color = Color(0, 0, 0, 0.5)
	track.size = BUFF_BAR_SIZE
	track.position = Vector2(12, 3)
	_buff_row.add_child(track)
	_buff_fill = ColorRect.new()
	_buff_fill.size = BUFF_BAR_SIZE
	_buff_fill.position = Vector2(12, 3)
	_buff_row.add_child(_buff_fill)
	add_child(_buff_row)
	_buff_row.hide()


func _on_buff_changed(_buff_id: StringName, duration: float, color: Color) -> void:
	_buff_left = duration
	_buff_total = maxf(duration, 0.01)
	_buff_row.visible = duration > 0.0
	_buff_icon.color = color
	_buff_fill.color = color


func _process(delta: float) -> void:
	if _buff_left > 0.0:
		_buff_left = maxf(_buff_left - delta, 0.0)
		_buff_fill.size.x = BUFF_BAR_SIZE.x * _buff_left / _buff_total


func _refresh_fragments() -> void:
	for id: StringName in _fragment_icons:
		_fragment_icons[id].color = FRAGMENT_COLORS[id] if GameState.has_fragment(id) else FRAGMENT_MISSING


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


func _on_boss_health_changed(boss_id: StringName, current: int, maximum: int, boss_name: String) -> void:
	_boss_name.text = boss_name
	var share := float(current) / maxf(maximum, 1)
	var first := not _boss_bar.visible
	_boss_fill.anchor_right = share
	_boss_bar.show()
	if _boss_trail_tween != null:
		_boss_trail_tween.kill()
	if first or share >= _boss_trail.anchor_right:
		_boss_trail.anchor_right = share
	else:
		_boss_trail_tween = create_tween()
		_boss_trail_tween.tween_interval(BOSS_TRAIL_DELAY)
		_boss_trail_tween.tween_property(_boss_trail, "anchor_right", share, BOSS_TRAIL_TIME)
	if not _announced_bosses.has(boss_id):
		_announced_bosses[boss_id] = true
		_show_boss_card(boss_name)


func _build_boss_trail() -> void:
	_boss_trail = ColorRect.new()
	_boss_trail.name = "Trail"
	_boss_trail.color = BOSS_TRAIL_COLOR
	_boss_trail.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := _boss_fill.get_parent()
	track.add_child(_boss_trail)
	track.move_child(_boss_trail, _boss_fill.get_index())


## The boss's name in big letters between two black bars, for a moment, when its fight begins.
func _show_boss_card(boss_name: String) -> void:
	var card := Control.new()
	card.name = "BossCard"
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.offset_top = -BOSS_CARD_BARS if top else 0.0
		bar.offset_bottom = 0.0 if top else BOSS_CARD_BARS
		card.add_child(bar)
		var slide := create_tween()
		slide.tween_property(bar, "offset_top" if top else "offset_bottom", 0.0, 0.3)
		slide.parallel().tween_property(bar, "offset_bottom" if top else "offset_top",
				BOSS_CARD_BARS if top else -BOSS_CARD_BARS, 0.3)
	var title := UiKit.label(boss_name.to_upper(), 20, Color(1.0, 0.85, 0.75))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.offset_left = -220
	title.offset_right = 220
	title.offset_top = 52
	title.offset_bottom = 80
	title.modulate.a = 0.0
	card.add_child(title)
	var tween := create_tween()
	tween.tween_property(title, "modulate:a", 1.0, 0.3)
	tween.tween_interval(BOSS_CARD_TIME)
	tween.tween_property(card, "modulate:a", 0.0, 0.5)
	tween.tween_callback(card.queue_free)


## A dark edge around a text drawn over the world, so it reads on bright grass and glowing crystals.
func _outline(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 3)


func _on_prompt_changed(prompt: String) -> void:
	_prompt.text = UiText.t("prompt_prefix") + prompt
	_prompt.visible = prompt != ""


func _on_plan_made(plan: DirectorPlan) -> void:
	if plan.island_line != "":
		show_toast(plan.island_line)


func _on_player_health_changed(current: int, maximum: int) -> void:
	for child in _hearts.get_children():
		child.queue_free()
	for i in maximum:
		var heart := TextureRect.new()
		heart.texture = _heart_full if i < current else _heart_empty
		heart.stretch_mode = TextureRect.STRETCH_KEEP
		_hearts.add_child(heart)


func _build_controls_hint() -> void:
	_hint = UiKit.label(UiText.t("hint_controls"), 10, Color(0.95, 0.95, 1.0))
	_hint.name = "ControlsHint"
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hint.add_theme_constant_override("outline_size", 3)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -200
	_hint.offset_right = 200
	_hint.offset_top = -74
	_hint.offset_bottom = -58
	_hint.hide()
	add_child(_hint)
	# Only on the first island of a journey: later islands assume the player knows.
	Events.level_started.connect(func(_id: StringName, _seed: int) -> void:
		_hint_dodged = false
		_hint_shot = false
		_hint.modulate.a = 1.0
		_hint.visible = GameState.fragments.is_empty())
	Events.player_shot.connect(func(_d: Vector2, _t: float) -> void:
		_hint_shot = true
		_maybe_hide_hint())
	Events.player_dashed.connect(func(_d: Vector2) -> void:
		_hint_dodged = true
		_maybe_hide_hint())


## A quiet note in the bottom right corner each time the progress is written to disk.
func _build_saved_note() -> void:
	_saved_note = UiKit.label(UiText.t("saved_note"), 10, Color(0.8, 0.85, 0.95))
	_saved_note.name = "SavedNote"
	_saved_note.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_saved_note.add_theme_constant_override("outline_size", 3)
	_saved_note.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_saved_note.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_saved_note.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_saved_note.offset_right = -8
	_saved_note.offset_bottom = -6
	_saved_note.hide()
	add_child(_saved_note)
	Events.game_saved.connect(_on_game_saved)


func _on_game_saved() -> void:
	if _saved_tween != null:
		_saved_tween.kill()
	_saved_note.modulate.a = 1.0
	_saved_note.show()
	_saved_tween = create_tween()
	_saved_tween.tween_interval(SAVED_SECONDS)
	_saved_tween.tween_property(_saved_note, "modulate:a", 0.0, SAVED_FADE)
	_saved_tween.tween_callback(_saved_note.hide)


func _maybe_hide_hint() -> void:
	if not _hint.visible or not (_hint_dodged and _hint_shot):
		return
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(_hint, "modulate:a", 0.0, 0.8)
	tween.tween_callback(_hint.hide)


func _heart_texture(fill: Color) -> Texture2D:
	var image := Image.create(9, 8, false, Image.FORMAT_RGBA8)
	var colors := {"1": fill, "2": fill.lightened(0.5), "3": Color(0.1, 0.03, 0.05)}
	for y in HEART_SHAPE.size():
		var row: String = HEART_SHAPE[y]
		for x in row.length():
			if colors.has(row[x]):
				image.set_pixel(x, y, colors[row[x]])
	return ImageTexture.create_from_image(image)
