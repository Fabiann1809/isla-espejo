class_name HungryTileData
extends EnemyData
## Data of the Baldosa hambrienta: the normal enemy stats plus its ambush. `detection_range` is how
## far it notices Nico (it never chases), `move_speed` its crawl once revealed and `attack_cooldown`
## the rest between two bites.

@export_group("Ambush")
## Nico closer than this to its center (px) makes it bite.
@export var trigger_radius := 22.0
## Seconds its cracks glow before the bite: the only warning.
@export var tell_time := 0.25
## Seconds its jaws (the hitbox) stay open.
@export var bite_time := 0.25
## Seconds a bitten Nico is held in place (a dodge breaks free).
@export var hold_time := 0.6

@export_group("Revealed")
## Seconds it stays out (solid, hittable) after a bite before closing again.
@export var reveal_time := 2.5
## Revealed, it crawls toward Nico but never farther than this from its spot (px).
@export var crawl_leash := 16.0
## Seconds it may spend crawling back to its spot before it closes wherever it is.
@export var close_timeout := 2.0
## Seconds after closing before it can bite again.
@export var rearm_time := 1.0
