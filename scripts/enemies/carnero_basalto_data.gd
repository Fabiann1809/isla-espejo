class_name BasaltRamData
extends EnemyData
## Data of the Carnero de basalto: the normal enemy stats plus its charge. `attack_range` is how far
## away it starts a charge (it needs a clear line to Nico) and `attack_cooldown` the rest after one.

@export_group("Charge")
## Seconds it marks its lane on the ground before rushing.
@export var charge_windup := 0.7
@export var charge_speed := 230.0
## Longest run of a charge (px); it stops sooner against a wall or at the edge of its room.
@export var charge_distance := 260.0
## Seconds it stands after a charge that did not crash.
@export var charge_recover := 0.5
## Seconds it stays stunned (still, no attacks) after crashing into a wall.
@export var stun_time := 1.6

@export_group("Lane")
## Width of the lane drawn on the ground during the windup (px).
@export var lane_width := 18.0
@export var lane_color := Color(1.0, 0.45, 0.2)
## Drawn lane (tools/make_carnero_basalto_art.py): a strip of 18 px tiles, start, middle, middle
## and end, three times (marked, filled, filled and flickering). Without it the lane is plain shapes.
@export var lane_art: Texture2D

@export_group("Stun stars")
@export var star_count := 3
## The stars circle over its head: orbit radius (px), height above its center (px), turns per second.
@export var star_orbit := 8.0
@export var star_height := 30.0
@export var star_spin := 1.5
## Half the length of each star's arms (px).
@export var star_size := 2.0
@export var star_color := Color(1.0, 0.9, 0.35)
