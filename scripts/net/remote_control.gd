extends Node
## Autoload `RemoteControl`: the phone controller for the whole app. It owns the `ControlServer`
## and the `RemoteControlMapper` and wires them together, so the phone keeps driving Nico after
## the controller panel is closed. The panel is only a view: it calls `start()` when it opens and
## listens to the forwarded signals. The server runs until `stop()` (the panel's "Desconectar"
## button) or until the game quits.
##
## Paused game: phone messages keep being applied while the tree is paused (this node and the
## server process always). They only press the gameplay actions (D3), which nothing reads while
## paused, so the pause menu cannot be driven from the phone and Nico resumes with whatever the
## phone holds when the game resumes.

signal controller_connected
signal controller_disconnected
signal controller_rejected

const PORT := 8080

var server: ControlServer
var mapper: RemoteControlMapper


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mapper = RemoteControlMapper.new()
	set_server(ControlServer.new())


## Opens the port (idempotent). ERR_UNAVAILABLE in headless runs and with `--no-save` (D7).
func start() -> Error:
	if server.is_running():
		return OK
	var error := server.start(PORT)
	if error != OK:
		server.stop()
	return error


## Closes the port, drops the phone and lets go of every action it held.
func stop() -> void:
	server.stop()
	mapper.release_all()


func is_running() -> bool:
	return server.is_running()


func has_controller() -> bool:
	return server.has_controller()


func get_urls() -> PackedStringArray:
	return server.get_urls()


## Replaces the server (stopping the old one) and wires the new one. Tests use it to plug in a
## server double that does not bind a port.
func set_server(new_server: ControlServer) -> void:
	if server != null:
		stop()
		server.message_received.disconnect(_on_message)
		server.controller_connected.disconnect(_on_connected)
		server.controller_disconnected.disconnect(_on_disconnected)
		server.controller_rejected.disconnect(_on_rejected)
		if server.get_parent() == self:
			remove_child(server)
		server.free()
	server = new_server
	server.message_received.connect(_on_message)
	server.controller_connected.connect(_on_connected)
	server.controller_disconnected.connect(_on_disconnected)
	server.controller_rejected.connect(_on_rejected)
	add_child(server)


## Every physics frame, before the level's nodes (autoloads come first in the tree): deferred
## button releases and the movement watchdog of the mapper.
func _physics_process(_delta: float) -> void:
	mapper.tick(Time.get_ticks_msec())


func _on_message(msg: Dictionary) -> void:
	mapper.apply(msg, Time.get_ticks_msec())


func _on_connected() -> void:
	controller_connected.emit()


func _on_disconnected() -> void:
	mapper.release_all()
	controller_disconnected.emit()


func _on_rejected() -> void:
	controller_rejected.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		stop()


func _exit_tree() -> void:
	stop()
