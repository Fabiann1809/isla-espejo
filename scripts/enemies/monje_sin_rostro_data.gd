class_name FacelessMonkData
extends EnemyData
## Data of the Monje sin rostro: the normal enemy stats (its `attack_range` is how close Nico must be
## for it to start a teleport, `attack_windup` the aim after it reappears, `attack_cooldown` the rest
## between two teleports) plus its floor symbols, the teleport and the spread of projectiles.

@export_group("Floor symbols")
## Symbols drawn on the floor when it appears (the first one under its feet).
@export var symbol_count := 4
## Symbols stay this far inside its room's edges; without a room, within `symbol_spread` of its spawn.
@export var symbol_margin := 40.0
@export var symbol_spread := 110.0
## Minimum distance between two symbols, and the free space (no wall, rock or pond) around each.
@export var symbol_gap := 70.0
@export var symbol_clearance := 12.0
## Random spots tried before it settles for fewer symbols.
@export var symbol_tries := 80
@export var symbol_radius := 10.0
@export var symbol_color := Color(0.75, 0.45, 1.0)
## Color of the destination symbol while the monk is gone (the warning of where it comes back).
@export var symbol_warning_color := Color(1.0, 0.55, 0.95)
## Pulses per second of the symbols' glow.
@export var symbol_pulse_rate := 0.8
## Drawn symbol (tools/make_monje_sin_rostro_art.py): a strip of square cells, 4 resting (one pulse)
## then 4 warned, looping at `symbol_warning_fps`. Without it the symbol is drawn with shapes.
@export var symbol_art: Texture2D
@export var symbol_warning_fps := 10.0

@export_group("Teleport")
## Fade out (still hittable), time gone (cannot be hit; the destination flares), fade in.
@export var vanish_time := 0.35
@export var hidden_time := 0.55
@export var appear_time := 0.25
## It prefers a symbol between these distances from Nico (not on top of him, not out of shot).
@export var min_player_distance := 50.0
@export var max_player_distance := 170.0
## While chasing it walks toward Nico until this close, then stands.
@export var preferred_distance := 120.0
## Pause after the shots before it walks again.
@export var recover_time := 0.5

@export_group("Projectiles")
## Shots fired at once: the middle one at Nico, the others `shot_spread` degrees apart from it.
@export var shot_count := 3
@export var shot_spread := 45.0
## A scene with an EnemyOrb root.
@export var projectile_scene: PackedScene
@export var projectile_speed := 95.0
@export var projectile_range := 220.0
@export var muzzle_distance := 10.0
@export var shot_tint := Color(0.85, 0.55, 1.0)
