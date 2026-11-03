class_name ControllerPanel
extends PanelContainer
## Phone controller panel of the options screen: QR code and address of the LAN page, plus the
## connection status. It creates and owns the `ControlServer` and the `RemoteControlMapper`
## (they exist only while the panel is open) and wires them together.

signal closed

const PORT := 8080
const QR_MODULE_PX := 3
const BUSY_SHOWN_SECONDS := 2.0

var server: ControlServer
var mapper: RemoteControlMapper
var qr_rect: TextureRect
var url_label: Label
var status_label: Label
var back_button: Button
var _status_serial := 0


func _ready() -> void:
	theme = UiKit.theme()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	box.add_child(UiKit.label(UiText.t("controller_title"), 18))
	box.add_child(UiKit.label(UiText.t("controller_hint"), 11))
	qr_rect = TextureRect.new()
	qr_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	qr_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(qr_rect)
	url_label = UiKit.label("", 12)
	box.add_child(url_label)
	status_label = UiKit.label(UiText.t("controller_waiting"), 14)
	box.add_child(status_label)
	back_button = UiKit.button(UiText.t("controller_back"))
	back_button.pressed.connect(close)
	box.add_child(back_button)

	mapper = RemoteControlMapper.new()
	server = ControlServer.new()
	add_child(server)
	server.message_received.connect(mapper.apply)
	server.controller_connected.connect(func() -> void: _set_status("controller_connected"))
	server.controller_disconnected.connect(_on_controller_disconnected)
	server.controller_rejected.connect(_on_controller_rejected)
	hide()


## Starts the server and shows the QR; falls back to the error text when it cannot.
func open() -> void:
	show()
	_set_status("controller_waiting")
	var error := server.start(PORT)
	var urls := server.get_urls()
	if error != OK or urls.is_empty():
		server.stop()
		_show_error()
	else:
		show_url(urls[0])
	back_button.grab_focus()


func is_open() -> bool:
	return visible


func close() -> void:
	server.stop()
	mapper.release_all()
	hide()
	closed.emit()


## Shows the address as text and as a QR image.
func show_url(url: String) -> void:
	url_label.text = url
	var image := QrCode.make_image(url, QR_MODULE_PX)
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


func _on_controller_disconnected() -> void:
	mapper.release_all()
	_set_status("controller_waiting")


func _on_controller_rejected() -> void:
	# A second phone was turned away; the first one is still the controller, so the busy
	# message is shown briefly and then replaced by the connected one, unless the status
	# changed in the meantime.
	_set_status("controller_busy")
	var serial := _status_serial
	await get_tree().create_timer(BUSY_SHOWN_SECONDS).timeout
	if serial == _status_serial and server != null and server.has_controller():
		_set_status("controller_connected")


func _exit_tree() -> void:
	if server != null:
		server.stop()
	if mapper != null:
		mapper.release_all()
