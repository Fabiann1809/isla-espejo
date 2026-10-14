extends Node2D
## Sandbox room for testing player mechanics. Not part of the final game.

const BOUNDS := Rect2(-480, -270, 960, 540)
const MARKER_SPACING := 120
const MARKER_SIZE := 16
const MARKER_COLOR := Color(0.1, 0.18, 0.12)
const RESTART_DELAY := 1.5

@onready var _player: Node = $Player
@onready var _hud: Node = $Hud


func _ready() -> void:
	_add_markers()
	_player.set_camera_limits(BOUNDS)
	Events.player_died.connect(_on_player_died)


## Dark squares on the floor so camera and player movement are easy to see.
func _add_markers() -> void:
	var markers := Node2D.new()
	markers.name = "Markers"
	add_child(markers)
	move_child(markers, 1)
	for x in range(int(BOUNDS.position.x) + MARKER_SPACING, int(BOUNDS.end.x), MARKER_SPACING):
		for y in range(int(BOUNDS.position.y) + MARKER_SPACING / 2, int(BOUNDS.end.y), MARKER_SPACING):
			var marker := ColorRect.new()
			marker.color = MARKER_COLOR
			marker.size = Vector2(MARKER_SIZE, MARKER_SIZE)
			marker.position = Vector2(x, y) - marker.size / 2.0
			markers.add_child(marker)


func _on_player_died() -> void:
	_hud.show_message("Has muerto. Reiniciando...")
	await get_tree().create_timer(RESTART_DELAY).timeout
	get_tree().reload_current_scene()
