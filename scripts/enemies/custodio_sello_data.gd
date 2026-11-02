class_name SealGuardianData
extends EnemyData
## Data of the Custodio del sello: the normal enemy stats (its `attack_*` numbers are a weak melee
## swing for when Nico comes too close) plus the seal it raises to shield the enemies around it.

@export_group("Seal")
## Enemies within this distance when the seal goes up are shielded.
@export var seal_radius := 90.0
## Raising the seal (the warning: a ring on the ground). A hit in this time cuts it short.
@export var seal_windup := 0.8
## Pose held after the seal goes up before it moves again.
@export var seal_recover := 0.4
## How long the shields last, and the rest before it raises the seal again.
@export var shield_time := 3.5
@export var seal_cooldown := 6.0
## A shielded ally that walks farther than this from the guardian loses its link and its shield.
@export var link_range := 150.0
## Shields are given in short pieces renewed while the link holds, so they fade this many seconds
## after the guardian dies or the link breaks.
@export var shield_refresh := 0.25

@export_group("Staying behind its allies")
## While allies live it keeps within this fraction of `seal_radius` of the nearest one instead of
## walking at Nico (it still swings if he comes within `attack_range`).
@export_range(0.1, 1.0) var ally_keep_fraction := 0.55

@export_group("Seal look")
@export var seal_color := Color(0.45, 0.9, 1.0)
## Links drawn on the ground from the guardian to each shielded ally, and a ring under that ally.
@export var link_width := 1.0
@export var link_alpha := 0.6
@export var ally_ring_radius := 10.0
