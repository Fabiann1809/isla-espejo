class_name FragmentPickup
extends Node2D
## A compass fragment left by a boss. Taking it (E) records it in GameState, teaches the player the
## skill that goes with it and tells the player. Placeholder art: a glowing diamond.

@export var fragment_id: StringName = &"green"
@export var skill_id: StringName = &"roots"
@export var color := Color(0.35, 0.85, 0.4)
## Spanish texts. `%s` in the second one is the skill name.
@export var fragment_message := "Fragmento de brújula obtenido."
@export var skill_message := "Habilidad aprendida: %s"

var _time := 0.0

@onready var _gem: Polygon2D = $Gem
@onready var _take: Interactable = $Take


func _ready() -> void:
	add_to_group("fragments")
	_gem.color = color
	_take.interacted.connect(_on_taken)


func _process(delta: float) -> void:
	_time += delta
	_gem.position.y = sin(_time * 3.0) * 2.0
	_gem.modulate.a = 0.75 + 0.25 * sin(_time * 5.0)


func _on_taken(player: Node) -> void:
	_take.enabled = false
	GameState.collect_fragment(fragment_id)
	var skill: SkillData = null
	if skill_id != &"":
		skill = load(GameState.SKILL_PATH % skill_id)
		GameState.learn_skill(skill_id)
		player.skills.unlock(skill)
	Events.message_requested.emit(fragment_message)
	if skill != null:
		Events.message_requested.emit(skill_message % skill.display_name)
	queue_free()
