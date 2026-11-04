extends SceneTree
## The dialogue panel: a name tag, colors per speaker from data, text that types itself and a blinking arrow.
## Run: godot --headless --path . --script res://tests/test_dialogue_box.gd

var _ok := true


func _initialize() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var script: GDScript = load("res://scripts/ui/dialogue_box.gd")
	var nico: Dictionary = script.style_of("Nico")
	var elder: Dictionary = script.style_of("El Anciano")
	var stranger: Dictionary = script.style_of("Alguien sin color")
	var fallback: Dictionary = script.style_of("default")
	_check(nico.fill != elder.fill, "each speaker has its own colors")
	_check(stranger == fallback and stranger.has("tag"), "an unknown speaker uses the default colors")

	var box: Node = load("res://scenes/ui/dialogue_box.tscn").instantiate()
	root.add_child(box)
	await process_frame
	box.show_line("El Anciano", "Otro viajero... La isla ya te estaba esperando.", false)
	var tag: Control = box.get_node("Tag")
	var arrow: Label = box.get_node("Arrow")
	_check(tag.visible and box.get_node("Tag/Name").text == "El Anciano", "the name tag shows the speaker")
	_check(box.is_typing() and not arrow.visible, "the text types itself and the arrow waits")
	box.complete_line()
	_check(not box.is_typing() and arrow.visible and arrow.text.contains("▼"), "a complete line shows the arrow")
	box.show_line("Nico", "Lo logré.", true)
	box.complete_line()
	_check(arrow.text.contains("■"), "the last line shows a stop mark instead")
	box.show_line("", "Sin nombre.", true)
	_check(not tag.visible, "a line with no speaker has no tag")
	box.hide_box()
	_check(not box.get_node("Panel").visible and not arrow.visible and not tag.visible, "hiding it hides everything")
	box.free()
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
