class_name FragmentPickup
extends Node2D
## A compass fragment left by a boss. Taking it (E) records it in GameState, teaches the player the
## skill that goes with it and tells the player. Placeholder art: a glowing diamond.

@export var fragment_id: StringName = &"green"
@export var skill_id: StringName = &"roots"
@export var color := Color(0.35, 0.85, 0.4)
## Spanish texts. `%s` in the second one is the skill name.
## Spanish; empty = the lines of data/ui/texts.json.
@export var fragment_message := "":
	get:
		return fragment_message if fragment_message != "" else UiText.t("fragment_taken")
@export var skill_message := "":
	get:
		return skill_message if skill_message != "" else UiText.t("skill_learned")

## The team's picture of this fragment lying in the world (one picture or a strip of square
## frames); without the file the glowing diamond is drawn.
const WORLD_ART := "res://assets/sprites/fragments/fragment_%s_world.png"

var _time := 0.0
## The art that replaces the diamond, or null.
var art: AnimatedSprite2D

@onready var _gem: Polygon2D = $Gem
@onready var _take: Interactable = $Take


func _ready() -> void:
	add_to_group("fragments")
	_gem.color = color
	_take.interacted.connect(_on_taken)
	art = StripArt.build(WORLD_ART % fragment_id)
	if art != null:
		_gem.hide()
		add_child(art)


func _process(delta: float) -> void:
	_time += delta
	var bob := sin(_time * 3.0) * 2.0
	var glow := 0.75 + 0.25 * sin(_time * 5.0)
	_gem.position.y = bob
	_gem.modulate.a = glow
	if art != null:
		art.position.y = bob
		art.modulate.a = glow


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
