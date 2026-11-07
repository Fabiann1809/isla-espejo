extends Node
## Story progress of the current journey: compass fragments, learned skills and story flags
## (autoload "GameState"). Dying wipes it (Level._on_player_died); only the player profile, which
## is what the island learned, survives (see docs/JUEGO.md).
## Saving to disk belongs to the save/menu task; `to_dict()` / `from_dict()` are ready for it.

signal fragment_collected(fragment_id: StringName)
signal skill_learned(skill_id: StringName)
## A shop upgrade went up a level (the save listens).
signal upgrade_changed(upgrade_id: StringName, level: int)

const VERSION := 1
const SKILL_PATH := "res://data/skills/%s.tres"

## Fragment ids: "green", "blue", "violet".
var fragments: Array[StringName] = []
## Ids of learned skills (file names in data/skills/).
var skills: Array[StringName] = []
## Story flags (dialogue state, defeated bosses...). Name -> true.
var flags := {}
## Shop upgrades of this journey: upgrade id -> level (see ShopItem; ids "bow_damage", "crit_chance",
## "max_health"). Wiped on death like everything else here.
var upgrades := {}


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


func upgrade_level(upgrade_id: StringName) -> int:
	return int(upgrades.get(upgrade_id, 0))


## Raises an upgrade by one level (the shop checks gold and the maximum before).
func add_upgrade(upgrade_id: StringName) -> int:
	var level := upgrade_level(upgrade_id) + 1
	upgrades[upgrade_id] = level
	upgrade_changed.emit(upgrade_id, level)
	return level


## Unlocks every learned skill and every bought upgrade on `player` (call when a player is created
## or put on a new map: it is idempotent).
func apply_to_player(player: Node) -> void:
	for skill_id in skills:
		player.skills.unlock(load(SKILL_PATH % skill_id))
	apply_upgrades(player)


## Puts the shop's upgrades on `player`: arrow damage, crit chance and maximum health.
func apply_upgrades(player: Node) -> void:
	player.set_upgrades(upgrade_level(&"bow_damage") * Tuning.UPGRADE_BOW_DAMAGE_PER_LEVEL,
			upgrade_level(&"crit_chance") * Tuning.UPGRADE_CRIT_PER_LEVEL,
			upgrade_level(&"max_health") * Tuning.UPGRADE_HEALTH_PER_LEVEL)


func reset() -> void:
	fragments.clear()
	skills.clear()
	flags.clear()
	upgrades.clear()


func to_dict() -> Dictionary:
	return {"version": VERSION, "fragments": fragments, "skills": skills, "flags": flags.keys(),
			"upgrades": upgrades}


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
	# Saves from before the shop have no "upgrades": they load with none.
	var saved_upgrades: Variant = data.get("upgrades", {})
	if saved_upgrades is Dictionary:
		for id in saved_upgrades:
			upgrades[StringName(id)] = maxi(int(saved_upgrades[id]), 0)
	return true
