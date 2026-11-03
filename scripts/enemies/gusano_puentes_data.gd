class_name BridgeWormData
extends EnemyData
## Data of the bridge worm (BridgeWorm): the normal enemy stats plus its burrow, surge and body.
## `attack_damage` is what the head and every body segment deal; `attack_cooldown` is how long it
## stays under after diving before it can surface again; `chase_speed` is unused (it travels under at
## `burrow_speed`).

@export_group("Burrowed")
## Speed while it travels under the ground toward the spot where it will surface.
@export var burrow_speed := 85.0
## It surfaces this far from Nico, on its own side (or beside his path when he is moving).
@export var emerge_offset := 44.0
## Seconds of Nico's movement it anticipates when choosing where to surface and where to aim.
@export var emerge_lead := 0.35
## Close enough to the chosen spot to surface (px).
@export var emerge_arrive_distance := 6.0
## After this long under without reaching the spot (walls in the way), it surfaces where it is if
## Nico is within `surge_distance`.
@export var burrow_give_up_time := 2.5
## Rings of the ripple that betrays it under the ground.
@export var ripple_color := Color(1.0, 0.55, 0.2)
@export var ripple_radius := 9.0
## Optional drawn ripple instead of the rings: a strip of square cells that loop once per ripple
## cycle (drawn by tools/make_gusano_puentes_art.py for a `ripple_radius` of 9).
@export var ripple_art: Texture2D

@export_group("Emerge")
## Warning before it bursts out: a circle on the ground where it is.
@export var emerge_windup := 0.6
@export var emerge_warning_radius := 18.0
@export var emerge_warning_color := Color(1.0, 0.45, 0.2)

@export_group("Surge")
## It bursts out in a straight line toward Nico (through where he stands and beyond).
@export var surge_speed := 210.0
@export var surge_distance := 120.0
## Once the surge ends it stays out this long with its body laid across the way, then dives.
@export var surface_time := 1.1
## A surge that advances less than this fraction of its speed in a frame has hit a wall.
@export_range(0.0, 1.0) var surge_blocked_fraction := 0.25

@export_group("Body segments")
## Pieces that follow the head's path while it is out: solid for Nico and hurtful on contact.
@export var segment_count := 4
## Distance between two pieces (and between the head and the first one) along the path.
@export var segment_spacing := 13.0
## Radius of the solid part and of the hurting area (a little larger, so pressing against it hurts).
@export var segment_body_radius := 7.0
@export var segment_hit_radius := 10.0
## Art of the pieces: a strip of square cells, one per piece from the head to the tail (thinner);
## pieces past the last cell reuse it. Drawn by tools/make_gusano_puentes_art.py.
@export var segment_texture: Texture2D
@export var segment_offset := Vector2(0, -8)
@export var segment_tint := Color.WHITE
