class_name SkillManager
extends Node
## The player's skills: which are unlocked, cooldowns and activation. Lives as a child of the player.
## Bosses unlock skills with `unlock()`; the keys (skill_1..3) trigger them.

signal skill_unlocked(skill: SkillData)
signal skill_used(skill: SkillData, affected: int)

const SLOT_COUNT := 3

var _skills: Array[SkillData] = [null, null, null]
var _cooldowns: Array[float] = [0.0, 0.0, 0.0]

@onready var _player: Node2D = get_parent()


func _physics_process(delta: float) -> void:
	for slot in SLOT_COUNT:
		_cooldowns[slot] = maxf(_cooldowns[slot] - delta, 0.0)
		if Input.is_action_just_pressed("skill_%d" % (slot + 1)):
			try_use(slot)


func unlock(skill: SkillData) -> void:
	if _skills[skill.slot] == skill:
		return
	_skills[skill.slot] = skill
	_cooldowns[skill.slot] = 0.0
	skill_unlocked.emit(skill)
	Events.skill_unlocked.emit(skill.id)


func is_unlocked(slot: int) -> bool:
	return _skills[slot] != null


func get_skill(slot: int) -> SkillData:
	return _skills[slot]


func cooldown_left(slot: int) -> float:
	return _cooldowns[slot]


## 1 right after use, 0 when ready again.
func cooldown_ratio(slot: int) -> float:
	var skill := _skills[slot]
	if skill == null or skill.cooldown <= 0.0:
		return 0.0
	return clampf(_cooldowns[slot] / skill.cooldown, 0.0, 1.0)


## Tries to cast the skill in `slot`. Returns true if it was cast.
func try_use(slot: int) -> bool:
	var skill := _skills[slot]
	if skill == null or skill.effect == null or _cooldowns[slot] > 0.0:
		return false
	if _player.has_method("can_cast") and not _player.can_cast():
		return false
	_cooldowns[slot] = skill.cooldown
	var direction: Vector2 = _player.get("facing")
	var affected := skill.effect.activate(_player, skill, direction)
	skill_used.emit(skill, affected)
	Events.skill_used.emit(skill.id, direction, affected)
	return true
