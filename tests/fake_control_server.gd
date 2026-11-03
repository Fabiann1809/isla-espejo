extends "res://scripts/net/control_server.gd"
## Test double of ControlServer: it pretends to listen and never binds a port.
## Used by test_remote_control.gd and test_controller_panel.gd through RemoteControl.set_server().

var fake_running := false
var fake_controller := false
var start_calls := 0
var stop_calls := 0
var fake_urls := PackedStringArray(["http://192.168.1.20:8080/", "http://10.0.0.7:8080/"])


func start(_port: int = 8080) -> Error:
	start_calls += 1
	fake_running = true
	return OK


func stop() -> void:
	stop_calls += 1
	fake_running = false
	if fake_controller:
		fake_controller = false
		controller_disconnected.emit()


func is_running() -> bool:
	return fake_running


func has_controller() -> bool:
	return fake_controller


func get_urls() -> PackedStringArray:
	return fake_urls
