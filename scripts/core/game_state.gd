extends Node
## Story progress that must survive dying: compass fragments, learned skills and story flags
## (autoload "GameState"). A roguelike death restarts the map, not this (see docs/JUEGO.md).
## Saving to disk belongs to the save/menu task; `to_dict()` / `from_dict()` are ready for it.

signal fragment_collected(fragment_id: StringName)
signal skill_learned(skill_id: StringName)

const VERSION := 1
const SKILL_PATH := "res://data/skills/%s.tres"

## Fragment ids: "green", "blue", "violet".
var fragments: Array[StringName] = []
## Ids of learned skills (file names in data/skills/).
var skills: Array[StringName] = []
## Story flags (dialogue state, defeated bosses...). Name -> true.
var flags := {}


func set_flag(flag: StringName) -> void:
	flags[flag] = true


func has_flag(flag: StringName) -> bool:
	return flags.has(flag)


func has_fragment(fragment_id: StringName) -> bool:
	return fragments.has(fragment_id)


func collect_fragment(fragment_id: StringName) -> void:
	if has_fragment(fragment_id):
		return
	fragments.append(fragment_id)
	fragment_collected.emit(fragment_id)
	Events.fragment_collected.emit(fragment_id)


## Remembers a skill; `apply_to_player` gives it to every new player.
func learn_skill(skill_id: StringName) -> void:
	if skills.has(skill_id):
		return
	skills.append(skill_id)
	skill_learned.emit(skill_id)


## Unlocks every learned skill on `player` (call when a player is created).
func apply_to_player(player: Node) -> void:
	for skill_id in skills:
		player.skills.unlock(load(SKILL_PATH % skill_id))


func reset() -> void:
	fragments.clear()
	skills.clear()
	flags.clear()


func to_dict() -> Dictionary:
	return {"version": VERSION, "fragments": fragments, "skills": skills, "flags": flags.keys()}


func from_dict(data: Dictionary) -> bool:
	if int(data.get("version", 0)) != VERSION:
		return false
	reset()
	for id in data.get("fragments", []):
		fragments.append(StringName(id))
	for id in data.get("skills", []):
		skills.append(StringName(id))
	for flag in data.get("flags", []):
		flags[StringName(flag)] = true
	return true
