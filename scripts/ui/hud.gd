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
## The team's 16x16 icon of a fragment; without the file the colored square above is used.
const FRAGMENT_ART := "res://assets/sprites/fragments/fragment_%s.png"
const FRAGMENT_ART_SIZE := Vector2(16, 16)
## A fragment not collected yet shows its icon dark and faded.
const FRAGMENT_ART_MISSING := Color(0.12, 0.12, 0.16, 0.7)
const FRAGMENT_ROW_Y := 24.0
## Gold coin, upgrade icons and their sizes in the top right corner.
const GOLD_ART := "res://assets/sprites/shop/gold_coin.png"
const COIN_SIZE := Vector2(12, 12)
const UPGRADE_ICON_SIZE := Vector2(12, 12)
const UPGRADE_ROW_Y := 24.0
const BUFF_ROW_Y := 40.0

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
const BUFF_ICON_SIZE := Vector2(12, 12)
const BUFF_BAR_X := 16.0
## Wide enough for the icon, the bar and the shield's "x2".
const BUFF_ROW_WIDTH := 76.0

var _fragment_icons := {}
var _fragment_has_art := false
var _fragment_row: HBoxContainer
var _gold_label: Label
var _upgrade_row: HBoxContainer
var _shop_catalog: ShopCatalog
## Holds one row per running buff; `_buff_rows` maps the buff id to its row's nodes and time.
var _buff_box: Control
var _buff_rows := {}
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
	Events.player_buff_charges_changed.connect(_on_buff_charges_changed)
	Events.objective_changed.connect(func(text: String) -> void: _objective.text = text)
	Events.fragment_collected.connect(func(_id: StringName) -> void: _refresh_fragments())
	_build_upgrades()
	GameState.upgrade_changed.connect(func(_id: StringName, _level: int) -> void: _refresh_upgrades())
	Events.shop_bought.connect(func(_id: StringName) -> void: _refresh_upgrades())
	Events.level_started.connect(func(_id: StringName, _seed: int) -> void:
		_refresh_upgrades()
		_refresh_fragments())
	_boss_bar.hide()
	_message.hide()
	_toast.hide()
	_prompt.hide()


## Three compass fragment icons (dim until collected) and the objective line under the hearts.
func _build_fragments_and_objective() -> void:
	_fragment_row = HBoxContainer.new()
	_fragment_row.position = Vector2(8, FRAGMENT_ROW_Y)
	_fragment_row.add_theme_constant_override("separation", 4)
	add_child(_fragment_row)
	for id: StringName in FRAGMENT_COLORS:
		var path := FRAGMENT_ART % id
		var icon: Control
		if ResourceLoader.exists(path):
			var picture := TextureRect.new()
			picture.texture = load(path) as Texture2D
			picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.custom_minimum_size = FRAGMENT_ART_SIZE
			icon = picture
			_fragment_has_art = true
		else:
			var square := ColorRect.new()
			square.custom_minimum_size = FRAGMENT_SIZE
			icon = square
		icon.name = "Fragment_%s" % id
		_fragment_row.add_child(icon)
		_fragment_icons[id] = icon
	_objective = Label.new()
	# Under the icons, whatever their size.
	_objective.position = Vector2(8, FRAGMENT_ROW_Y + (FRAGMENT_ART_SIZE.y if _fragment_has_art else FRAGMENT_SIZE.y) + 6.0)
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
	var coin_icon: Control
	if ResourceLoader.exists(GOLD_ART):
		var picture := TextureRect.new()
		picture.texture = load(GOLD_ART) as Texture2D
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = COIN_SIZE
		coin_icon = picture
	else:
		var square := ColorRect.new()
		square.custom_minimum_size = Vector2(8, 8)
		square.color = GOLD_COLOR
		coin_icon = square
	coin_icon.name = "Coin"
	gold_row.add_child(coin_icon)
	gold_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_gold_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_buff_box = Control.new()
	_buff_box.name = "Buffs"
	_buff_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_buff_box.position = Vector2(-8 - BUFF_ROW_WIDTH, BUFF_ROW_Y)
	add_child(_buff_box)


## One row per running buff, stacked top to bottom in the order they started: its icon (the art when it
## exists, else a square in the buff's colour), a bar that shrinks with the time left and, for a shield,
## the hits it can still absorb. Taking the same buff again only refills its bar.
func _on_buff_changed(buff_id: StringName, duration: float, color: Color) -> void:
	if duration <= 0.0:
		if _buff_rows.has(buff_id):
			_buff_rows[buff_id]["row"].queue_free()
			_buff_rows.erase(buff_id)
			_layout_buff_rows()
		return
	if not _buff_rows.has(buff_id):
		_buff_rows[buff_id] = _build_buff_row(buff_id, color)
		_layout_buff_rows()
	var entry: Dictionary = _buff_rows[buff_id]
	entry["left"] = duration
	entry["total"] = maxf(duration, 0.01)
	entry["fill"].size.x = BUFF_BAR_SIZE.x


func _on_buff_charges_changed(buff_id: StringName, charges: int) -> void:
	if _buff_rows.has(buff_id):
		_buff_rows[buff_id]["charges"].text = "x%d" % charges


func _build_buff_row(buff_id: StringName, color: Color) -> Dictionary:
	var row := Control.new()
	row.name = "Buff_%s" % buff_id
	var path: String = Tuning.BUFF_ICON_PATH % buff_id
	var icon: Control
	if ResourceLoader.exists(path):
		var picture := TextureRect.new()
		picture.texture = load(path) as Texture2D
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon = picture
	else:
		var square := ColorRect.new()
		square.color = color
		icon = square
	icon.size = BUFF_ICON_SIZE
	row.add_child(icon)
	var track := ColorRect.new()
	track.color = Color(0, 0, 0, 0.5)
	track.size = BUFF_BAR_SIZE
	track.position = Vector2(BUFF_BAR_X, 4)
	row.add_child(track)
	var fill := ColorRect.new()
	fill.color = color
	fill.size = BUFF_BAR_SIZE
	fill.position = track.position
	row.add_child(fill)
	var charges := Label.new()
	charges.position = Vector2(BUFF_BAR_X + BUFF_BAR_SIZE.x + 3, -2)
	charges.add_theme_font_size_override("font_size", 10)
	charges.add_theme_color_override("font_color", color.lightened(0.4))
	row.add_child(charges)
	_buff_box.add_child(row)
	return {"row": row, "fill": fill, "charges": charges, "left": 0.0, "total": 1.0}


func _layout_buff_rows() -> void:
	var index := 0
	for id in _buff_rows:
		_buff_rows[id]["row"].position = Vector2(0, index * Tuning.BUFF_ROW_HEIGHT)
		index += 1


func _process(delta: float) -> void:
	for id in _buff_rows:
		var entry: Dictionary = _buff_rows[id]
		entry["left"] = maxf(entry["left"] - delta, 0.0)
		entry["fill"].size.x = BUFF_BAR_SIZE.x * entry["left"] / entry["total"]


func _refresh_fragments() -> void:
	for id: StringName in _fragment_icons:
		var have := GameState.has_fragment(id)
		var icon: Control = _fragment_icons[id]
		if icon is TextureRect:
			icon.modulate = Color.WHITE if have else FRAGMENT_ART_MISSING
		else:
			(icon as ColorRect).color = FRAGMENT_COLORS[id] if have else FRAGMENT_MISSING


## Row of the shop's upgrades the player owns (small icon and level), under the gold. Rebuilt
## from GameState whenever something is bought; hidden while there are none.
func _build_upgrades() -> void:
	_shop_catalog = ShopCatalog.load_default()
	_upgrade_row = HBoxContainer.new()
	_upgrade_row.name = "Upgrades"
	_upgrade_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_upgrade_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_upgrade_row.position = Vector2(-8, UPGRADE_ROW_Y)
	_upgrade_row.add_theme_constant_override("separation", 6)
	_upgrade_row.alignment = BoxContainer.ALIGNMENT_END
	add_child(_upgrade_row)
	_refresh_upgrades()


func _refresh_upgrades() -> void:
	for child in _upgrade_row.get_children():
		_upgrade_row.remove_child(child)
		child.queue_free()
	for item: ShopItem in _shop_catalog.items:
		var level := GameState.upgrade_level(item.upgrade_id) if item.is_upgrade() else 0
		if level <= 0:
			continue
		var entry := HBoxContainer.new()
		entry.name = "Upgrade_%s" % item.id
		entry.add_theme_constant_override("separation", 2)
		var texture := item.icon()
		if texture != null:
			var picture := TextureRect.new()
			picture.texture = texture
			picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.custom_minimum_size = UPGRADE_ICON_SIZE
			entry.add_child(picture)
		else:
			var swatch := ColorRect.new()
			swatch.color = item.color
			swatch.custom_minimum_size = UPGRADE_ICON_SIZE - Vector2(4, 4)
			entry.add_child(swatch)
		var text := Label.new()
		text.text = UiText.t("hud_upgrade_level") % level
		text.add_theme_font_size_override("font_size", 9)
		text.add_theme_color_override("font_color", Color(0.85, 0.8, 1.0))
		_outline(text)
		entry.add_child(text)
		_upgrade_row.add_child(entry)
	_upgrade_row.visible = _upgrade_row.get_child_count() > 0


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
