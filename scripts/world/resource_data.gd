class_name ResourceData
extends Resource
## A basic resource of a run (heart, arrow orb, gold). One `.tres` per resource in `data/resources/`.
## Enemies may leave it on the ground (see DropSpawner); the player takes it by walking over it.
## Everything is lost when the run ends, so none of it goes into GameState.

enum Kind { HEAL, ARROWS, GOLD }

@export var id: StringName = &"resource"
## Player-facing name (Spanish).
@export var display_name := "Recurso"
## Line shown when it is taken (Spanish); empty = silent (hearts and gold are obvious).
@export var message := ""
@export var kind: Kind = Kind.HEAL
@export var color := Color(0.9, 0.25, 0.3)

@export_group("Effect")
## HEAL: health restored. GOLD: coins (a random amount from `amount` to `amount_max`).
@export var amount := 1
@export var amount_max := 1
## ARROWS: seconds the effect lasts.
@export var duration := 12.0
## ARROWS: arrows added to every shot, and the angle between neighbouring arrows.
@export var extra_arrows := 2
@export var spread_degrees := 14.0

@export_group("Drop")
## Chance to appear when an enemy dies (0..1).
@export_range(0.0, 1.0) var drop_chance := 0.1
## It becomes this many times likelier while the player has half his health or less.
@export var hurt_chance_multiplier := 1.0
## A drop is guaranteed after this many kills without one (0 = never).
@export var pity_kills := 0
## At most this many of it lie on the ground at once.
@export var max_on_floor := 2
## Seconds before it vanishes (0 = stays).
@export var lifetime := 14.0
## Pixels from which it flies to the player by itself (0 = only by touching it).
@export var magnet_radius := 0.0


## Gives the resource to the player. Returns false when it would do nothing (a heart at full health
## stays on the ground). The caller announces it (this script must not touch autoloads, so tools can load it).
func apply(player: Node, rng: RandomNumberGenerator = null) -> bool:
	match kind:
		Kind.HEAL:
			if player.health.current >= player.health.max_health:
				return false
			player.health.heal(amount)
		Kind.ARROWS:
			player.start_arrow_buff(self)
		Kind.GOLD:
			var picker := rng if rng != null else RandomNumberGenerator.new()
			player.add_gold(picker.randi_range(amount, maxi(amount, amount_max)))
	return true
