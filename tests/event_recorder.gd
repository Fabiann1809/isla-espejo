extends Node
## Test helper: records every InputEventAction it sees as "name:1" (pressed) or "name:0".

var seen: Array = []


func _input(event: InputEvent) -> void:
	if event is InputEventAction:
		seen.append("%s:%d" % [event.action, 1 if event.pressed else 0])
