class_name ParasiteMaskData
extends EnemyData
## Data of the Máscara parásita: the normal enemy stats (its `attack_*` numbers are the weak bite it
## uses on Nico once no host is left) plus how it finds, rides and leaves a host.

@export_group("Finding a host")
## It looks for the nearest other living enemy (in its room) within this distance.
@export var seek_range := 220.0
## Flying speed toward a host (px/s), and how close it must get to latch on.
@export var seek_speed := 85.0
@export var attach_distance := 8.0

@export_group("Riding")
## Its art sits this high over the host's position (on its head).
@export var ride_height := 14.0
## The host goes faster by `frenzy_speed` and its attacks come back `frenzy_cooldown_rate` times
## sooner. The frenzy is given in pieces of `frenzy_refresh` seconds while the mask rides, so it
## fades that soon after the mask leaves.
@export var frenzy_speed := 1.45
@export var frenzy_cooldown_rate := 1.8
@export var frenzy_refresh := 0.3

@export_group("Losing its host")
## When its host dies it flees from Nico this fast for `flee_time`, and waits `reattach_delay` more
## before it looks for another host (it can be hit all that time).
@export var flee_speed := 95.0
@export var flee_time := 0.8
@export var reattach_delay := 1.0
