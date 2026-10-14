extends Level
## Sandbox that generates a map with the test scenario. Not part of the final game.
## R builds a new map. Dying shows what the island learned (profile summary); pressing E or J then
## starts a new map (new seed), like a roguelike run.

## With `unlock_all_skills` the three skills are unlocked from the start (the test scenario does it).
## In the real scenarios they are earned from the bosses; U unlocks them for debugging.
const SKILLS := [
	"res://data/skills/roots.tres",
	"res://data/skills/current.tres",
	"res://data/skills/shadow.tres",
]

@export var unlock_all_skills := true

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
	elif event.is_action_pressed("debug_unlock_skills"):
		_unlock_all_skills()


func _unlock_all_skills() -> void:
	for path in SKILLS:
		player.skills.unlock(load(path))


func _on_generated(map_layout: MapLayout) -> void:
	if unlock_all_skills:
		_unlock_all_skills()
	_info.text = "Seed %d  |  %d salas  |  R: nuevo mapa  |  1 2 3: habilidades" % [map_layout.map_seed, map_layout.cells.size()]
	_plan_info.text = "IA: " + plan.summary_line()
	print("Map seed %d\n%s" % [map_layout.map_seed, map_layout.to_ascii()])
