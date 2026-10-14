extends Level
## Sandbox that generates a map with the test scenario. Not part of the final game.
## R builds a new map. Dying shows what the island learned (profile summary); pressing E or J then
## starts a new map (new seed), like a roguelike run.

## All three skills are unlocked here so they can be tried without beating the bosses.
const SKILLS := [
	"res://data/skills/roots.tres",
	"res://data/skills/current.tres",
	"res://data/skills/shadow.tres",
]

@onready var _summary: Node = $ProfileSummary
@onready var _info: Label = $Debug/Info
@onready var _plan_info: Label = $Debug/PlanInfo


func _ready() -> void:
	generated.connect(_on_generated)
	_summary.dismissed.connect(get_tree().reload_current_scene)
	super()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_regenerate"):
		generate(0)


func _on_generated(map_layout: MapLayout) -> void:
	for path in SKILLS:
		player.skills.unlock(load(path))
	_info.text = "Seed %d  |  %d salas  |  R: nuevo mapa  |  1 2 3: habilidades" % [map_layout.map_seed, map_layout.cells.size()]
	_plan_info.text = "IA: " + plan.summary_line()
	print("Map seed %d\n%s" % [map_layout.map_seed, map_layout.to_ascii()])
