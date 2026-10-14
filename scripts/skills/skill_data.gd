class_name SkillData
extends Resource
## Definition of a player skill. One `.tres` per skill in `data/skills/`.
## What the skill does lives in `effect`; adding a skill = a new SkillData + (if needed) a new
## SkillEffect script. The skill system itself never changes.

@export var id: StringName = &"skill"
## Player-facing text (Spanish).
@export var display_name := "Habilidad"
@export_multiline var description := ""
## Which key it uses: 0, 1 or 2 (actions skill_1, skill_2, skill_3).
@export_range(0, 2) var slot := 0
@export var cooldown := 5.0
## Reach of the skill in pixels (distance to the zone, length of the wave, teleport distance...).
## Each effect decides how to use it.
@export var range := 60.0
## Damage to affected enemies (0 for pure control skills).
@export var damage := 0
## Placeholder color for the HUD icon and the visual effect, until real art exists.
@export var color := Color.WHITE
@export var effect: SkillEffect
