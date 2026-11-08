class_name ControllerPanel
extends PanelContainer
## Phone controller panel of the options screen: QR code and address of the LAN page, plus the
## connection status. It is only a view of the `RemoteControl` autoload, which owns the server:
## opening the panel starts it (if needed), closing the panel only hides it, so the phone keeps
## driving Nico during play. "Desconectar" stops the server.

signal closed

const QR_MODULE_PX := 2
const BUSY_SHOWN_SECONDS := 2.0

var qr_rect: TextureRect
var url_label: Label
var status_label: Label
var disconnect_button: Button
var back_button: Button
var _status_serial := 0


func _ready() -> void:
	theme = UiKit.theme()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	box.add_child(UiKit.menu_label(UiText.t("controller_title"), 20, UiKit.GOLD))
	box.add_child(UiKit.divider())
	qr_rect = TextureRect.new()
	qr_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	qr_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(qr_rect)
	url_label = UiKit.menu_label("", 10)
	box.add_child(url_label)
	status_label = UiKit.menu_label(UiText.t("controller_waiting"))
	box.add_child(status_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	box.add_child(buttons)
	disconnect_button = UiKit.button(UiText.t("controller_disconnect"), 120.0, 44.0)
	disconnect_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	disconnect_button.pressed.connect(disconnect_controller)
	buttons.add_child(disconnect_button)
	back_button = UiKit.button(UiText.t("controller_back"), 120.0, 44.0)
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_button.pressed.connect(close)
	buttons.add_child(back_button)

	# Method callables: the autoload outlives the panel and drops these when the panel is freed.
	RemoteControl.controller_connected.connect(_on_controller_connected)
	RemoteControl.controller_disconnected.connect(_on_controller_disconnected)
	RemoteControl.controller_rejected.connect(_on_controller_rejected)
	hide()


## Starts the phone controller (idempotent) and shows the QR; falls back to the error text.
func open() -> void:
	show()
	var error := RemoteControl.start()
	var urls: PackedStringArray = RemoteControl.get_urls()
	if error != OK:
		RemoteControl.stop()
		_show_error()
	elif urls.is_empty():
		# No address to show (e.g. the Wi-Fi dropped): a phone already attached keeps playing.
		_show_error()
	else:
		show_urls(urls)
		_set_status("controller_connected" if RemoteControl.has_controller() else "controller_waiting")
	back_button.grab_focus()


func is_open() -> bool:
	return visible


## Hides the panel. The phone controller keeps running.
func close() -> void:
	hide()
	closed.emit()


## Esc (ui_cancel) leaves the panel like its "Volver" button, in a menu and in the game alike.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Stops the phone controller; opening the panel again turns it back on.
func disconnect_controller() -> void:
	RemoteControl.stop()
	qr_rect.texture = null
	url_label.text = ""
	_set_status("controller_stopped")


## Shows the first address as a QR image and every address as text (the first one on top), so
## the player can type another one if the QR points at the wrong network.
func show_urls(urls: PackedStringArray) -> void:
	url_label.text = "\n".join(urls)
	var image := QrCode.make_image(urls[0], QR_MODULE_PX)
	if image == null:
		_show_error()
		return
	qr_rect.texture = ImageTexture.create_from_image(image)


func _show_error() -> void:
	qr_rect.texture = null
	url_label.text = ""
	_set_status("controller_error")


func _set_status(key: String) -> void:
	_status_serial += 1
	status_label.text = UiText.t(key)


func _on_controller_connected() -> void:
	_set_status("controller_connected")


func _on_controller_disconnected() -> void:
	# A manual stop also lands here first; disconnect_controller() then shows its own text.
	_set_status("controller_waiting")


func _on_controller_rejected() -> void:
	# A second phone was turned away; the first one is still the controller, so the busy
	# message is shown briefly and then replaced by the connected one, unless the status
	# changed in the meantime.
	_set_status("controller_busy")
	# Not awaited: a Callable connected to the timer is dropped when the panel is freed.
	get_tree().create_timer(BUSY_SHOWN_SECONDS).timeout.connect(_restore_status.bind(_status_serial))


func _restore_status(serial: int) -> void:
	if serial == _status_serial and RemoteControl.has_controller():
		_set_status("controller_connected")
