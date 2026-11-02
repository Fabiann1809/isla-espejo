class_name TrapClockmakerData
extends EnemyData
## Data of the Relojero de trampas: the normal enemy stats (its `attack_*` numbers are a weak jab
## when Nico corners it) plus the traps it sets around itself (ClockTrap), the rhythm it fires them
## on and how it flees.

@export_group("Setting the traps")
## One trap per entry, in order around it: `spikes`, `saw` or `fire`.
@export var trap_kinds: Array[StringName] = [&"spikes", &"saw", &"fire", &"spikes"]
## Traps sit on a ring this far from where it appears, kept `trap_margin` inside its room.
@export var trap_ring_radius := 60.0
@export var trap_margin := 28.0
@export var trap_damage := 1
## How long it shows the special animation (setting the traps) when it appears.
@export var set_time := 0.8

@export_group("Rhythm")
## Every `tick_interval` seconds it fires the next trap in turn (while Nico is in its room);
## `wind_time` is how long it shows the attack animation (its signal) for each tick.
@export var tick_interval := 0.8
@export var wind_time := 0.4

@export_group("Fleeing")
## It runs from Nico when he is closer than this, looking `flee_lookahead` px ahead in
## `flee_directions` directions for the way that takes it farthest from him inside its room.
@export var flee_distance := 110.0
@export var flee_lookahead := 40.0
@export var flee_directions := 12
## Its flight keeps this far inside the edges of its room.
@export var flee_margin := 20.0

@export_group("Spikes")
## Spikes peek out (`spikes_warn_time`, harmless) and then stab for `spikes_time`.
@export var spikes_size := 16.0
@export var spikes_warn_time := 0.45
@export var spikes_time := 0.4

@export_group("Saw")
## The saw runs along a track this long (across the ring), from one end to the other each time.
@export var saw_track_length := 56.0
@export var saw_radius := 7.0
@export var saw_warn_time := 0.35
@export var saw_travel_time := 0.7

@export_group("Fire jet")
## The jet fires toward the middle of its room (or outward without a room), this long and wide.
@export var fire_length := 56.0
@export var fire_width := 12.0
@export var fire_warn_time := 0.5
@export var fire_time := 0.5

@export_group("Looks")
@export var trap_base_color := Color(0.22, 0.2, 0.2)
@export var trap_metal_color := Color(0.82, 0.8, 0.78)
@export var trap_warn_color := Color(1.0, 0.75, 0.25)
@export var fire_color := Color(1.0, 0.45, 0.1, 0.85)
@export var dormant_color := Color(0.4, 0.38, 0.38)
