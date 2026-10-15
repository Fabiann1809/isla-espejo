class_name EnemyData
extends Resource
## Data-driven definition of an enemy. One `.tres` per enemy in `data/enemies/`.
## Tuning an enemy or creating a new one must not require touching `enemy.gd`.

@export var id: StringName = &"enemy"
## Player-facing name (Spanish).
@export var display_name := "Enemigo"
@export var placeholder_color := Color(0.8, 0.25, 0.25)

@export_group("Sprite")
## Optional art. Animations used if present: idle, walk, run, attack, hurt, death. Sprites face
## right; the enemy flips them when it faces left. Without it the colored square is shown.
@export var sprite_frames: SpriteFrames
@export var sprite_scale := 1.0
@export var sprite_offset := Vector2.ZERO

@export_group("Stats")
@export var max_health := 3
@export var move_speed := 40.0
@export var chase_speed := 70.0

@export_group("Senses")
@export var detection_range := 120.0
## Distance at which a chasing enemy gives up.
@export var lose_range := 220.0
## Field of view in degrees. 360 sees all around.
@export_range(1.0, 360.0) var vision_angle := 360.0

@export_group("Attack")
@export var attack_range := 22.0
@export var attack_damage := 1
## Telegraph before the hit lands, so the player can react.
@export var attack_windup := 0.4
## How long the hitbox stays active.
@export var attack_time := 0.15
@export var attack_cooldown := 0.8

@export_group("Reactions")
@export var hurt_time := 0.3
@export var knockback_speed := 120.0
## 0 = full knockback, 1 = immune.
@export_range(0.0, 1.0) var knockback_resistance := 0.0

@export_group("Patrol")
## 0 = stands still while idle.
@export var patrol_radius := 60.0
@export var patrol_wait := 1.0
