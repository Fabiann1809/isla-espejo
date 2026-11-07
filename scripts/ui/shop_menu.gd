class_name ShopMenu
extends CanvasLayer
## The Mercader's shop: a list of the catalog's items (icon, name, description, price, level) and
## Nico's gold. Built in code with UiKit like the other menus; texts come from data/ui/texts.json and
## the items from data/shop/items.tres. It pauses the game while open. Navigate with the arrows or the
## stick, buy with accept or E, close with Esc (`pause`) or cancel.

const ROW_SIZE := Vector2(404, 30)
const ICON_SIZE := 24.0
const PRICE_NO_GOLD := Color(0.9, 0.45, 0.45)
const MESSAGE_OK := Color(0.55, 0.9, 0.6)
const MESSAGE_REFUSED := Color(0.95, 0.6, 0.5)

## One button per item, in the catalog's order, and the button that closes the shop.
var item_buttons: Array[Button] = []
var close_button: Button
var message_label: Label
var gold_label: Label
var catalog: ShopCatalog

var _root: Control
var _panel: PanelContainer
var _player: Node
var _prices: Array[Label] = []
var _levels: Array[Label] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("shop_menu")
	layer = 31
	catalog = ShopCatalog.load_default()
	_root = Control.new()
	_root.theme = UiKit.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	_panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	var title := UiKit.menu_label(UiText.t("shop_title"), 16, UiKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	gold_label = UiKit.menu_label("", UiKit.FONT_SIZE, Color(1.0, 0.85, 0.3), HORIZONTAL_ALIGNMENT_RIGHT)
	header.add_child(gold_label)
	box.add_child(UiKit.divider())

	for item in catalog.items:
		box.add_child(_build_row(item))

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	box.add_child(footer)
	close_button = UiKit.button(UiText.t("shop_close"), 90.0, 22.0)
	close_button.pressed.connect(close)
	footer.add_child(close_button)
	message_label = UiKit.menu_label("", UiKit.SMALL_FONT_SIZE, UiKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(message_label)

	Events.player_gold_changed.connect(func(_total: int) -> void: _refresh())
	_root.hide()


func _exit_tree() -> void:
	# Never leave the game frozen if the map goes away with the shop open.
	if _root != null and _root.visible and get_tree() != null:
		get_tree().paused = false


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		var index := item_buttons.find(get_viewport().gui_get_focus_owner())
		if index >= 0:
			item_buttons[index].pressed.emit()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _root != null and _root.visible


## Opens the shop for `player` (whose gold pays) and pauses the game.
func open(player: Node) -> void:
	_player = player
	message_label.text = UiText.t("shop_hint")
	message_label.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	_refresh()
	get_tree().paused = true
	_root.show()
	if not item_buttons.is_empty():
		item_buttons[0].grab_focus()


func close() -> void:
	if not is_open():
		return
	_root.hide()
	get_tree().paused = false


## Buys the item of row `index` and tells the player what happened.
func buy(index: int) -> Shop.Result:
	var item: ShopItem = catalog.items[index]
	var result := Shop.buy(item, _player)
	match result:
		Shop.Result.BOUGHT:
			_say(UiText.t("shop_bought") % item.display_name, MESSAGE_OK)
		Shop.Result.NO_GOLD:
			_say(UiText.t("shop_no_gold"), MESSAGE_REFUSED)
		Shop.Result.MAXED:
			_say(UiText.t("shop_maxed_msg"), MESSAGE_REFUSED)
		Shop.Result.FULL_HEALTH:
			_say(UiText.t("shop_full_health"), MESSAGE_REFUSED)
	_refresh()
	return result


func _say(text: String, color: Color) -> void:
	message_label.text = text
	message_label.add_theme_color_override("font_color", color)


func _build_row(item: ShopItem) -> Button:
	var row := UiKit.button("", ROW_SIZE.x, ROW_SIZE.y)
	row.pressed.connect(func() -> void: buy(item_buttons.find(row)))
	item_buttons.append(row)

	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)
	content.add_theme_constant_override("separation", 6)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(content)
	content.add_child(_icon(item))

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", -1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(text)
	text.add_child(_ignore(UiKit.menu_label(item.display_name, 11, UiKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT)))
	text.add_child(_ignore(UiKit.menu_label(item.description, 9, UiKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT)))

	var numbers := VBoxContainer.new()
	numbers.add_theme_constant_override("separation", -1)
	numbers.alignment = BoxContainer.ALIGNMENT_CENTER
	numbers.custom_minimum_size.x = 80.0
	numbers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(numbers)
	var price := _ignore(UiKit.menu_label("", 11, Color(1.0, 0.85, 0.3), HORIZONTAL_ALIGNMENT_RIGHT))
	var level := _ignore(UiKit.menu_label("", 9, UiKit.LAVENDER, HORIZONTAL_ALIGNMENT_RIGHT))
	numbers.add_child(price)
	numbers.add_child(level)
	_prices.append(price)
	_levels.append(level)
	return row


func _ignore(label: Label) -> Label:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## The item's picture, or a colored square while its file has not been drawn.
func _icon(item: ShopItem) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture := item.icon()
	if texture != null:
		var picture := TextureRect.new()
		picture.texture = texture
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.set_anchors_preset(Control.PRESET_FULL_RECT)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(picture)
	else:
		var swatch := ColorRect.new()
		swatch.color = item.color
		swatch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(swatch)
	return holder


func _refresh() -> void:
	var gold: int = _player.gold if _player != null else 0
	gold_label.text = UiText.t("shop_gold") % gold
	for i in catalog.items.size():
		var item: ShopItem = catalog.items[i]
		var maxed := Shop.is_maxed(item)
		_prices[i].text = UiText.t("shop_maxed") if maxed else UiText.t("shop_price") % Shop.price_of(item)
		var affordable := maxed or gold >= Shop.price_of(item)
		_prices[i].add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if affordable else PRICE_NO_GOLD)
		_levels[i].text = UiText.t("shop_level") % [Shop.level_of(item), item.max_level] if item.is_upgrade() else ""
