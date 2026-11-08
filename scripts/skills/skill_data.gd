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
## Color of the skill: the cast burst, the HUD slot without an icon, the zone drawn without art.
@export var color := Color.WHITE
@export var effect: SkillEffect
## The zone's art (data/skills/<id>_frames.tres, built by tools/make_skill_frames.gd from the
## strips of tools/make_skill_art.py): `start` plays once, `loop` holds while the zone lasts and
## `end` plays once before it goes. Empty = the zone is drawn with shapes.
@export var zone_frames: SpriteFrames
## The HUD icon (24x24). Empty = a square of `color`.
@export var icon: Texture2D
