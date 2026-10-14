extends Level
## Sandbox that generates a map with the test scenario. Not part of the final game.
## R builds a new map; dying also starts a new one (new seed), like a roguelike run.

const RESTART_DELAY := 1.5

@onready var _hud: Node = $Hud
@onready var _info: Label = $Debug/Info


func _ready() -> void:
	generated.connect(_on_generated)
	Events.player_died.connect(_on_player_died)
	super()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_regenerate"):
		generate(0)


func _on_generated(map_layout: MapLayout) -> void:
	_info.text = "Seed %d  |  %d salas  |  R: nuevo mapa" % [map_layout.map_seed, map_layout.cells.size()]
	print("Map seed %d\n%s" % [map_layout.map_seed, map_layout.to_ascii()])


func _on_player_died() -> void:
	_hud.show_message("Has muerto. Nuevo mapa...")
	await get_tree().create_timer(RESTART_DELAY).timeout
	get_tree().reload_current_scene()
