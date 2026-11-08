class_name ResourceData
extends Resource
## A basic resource of a run (heart, timed power-ups, gold). One `.tres` per resource in `data/resources/`.
## Enemies may leave it on the ground (see DropSpawner); the player takes it by walking over it.
## Everything is lost when the run ends, so none of it goes into GameState.

## ARROWS is the fan of extra arrows and BUFF any other timed power-up (see `Effect`); both count as
## "buffs" (`is_buff`): the player keeps one running per id, several at once.
enum Kind { HEAL, ARROWS, GOLD, BUFF }
## What a BUFF does while it lasts. A new buff = a new value here, its numbers below and one small hook
## in `Player` (the hook reads the numbers with `Player.buff_data(effect)`).
enum Effect { PIERCE, FROST, HASTE, SHIELD }

@export var id: StringName = &"resource"
## Player-facing name (Spanish).
@export var display_name := "Recurso"
## Line shown when it is taken (Spanish); empty = silent (hearts and gold are obvious).
@export var message := ""
@export var kind: Kind = Kind.HEAL
## BUFF only: what it does.
@export var effect: Effect = Effect.PIERCE
@export var color := Color(0.9, 0.25, 0.3)

@export_group("Effect")
## HEAL: health restored. GOLD: coins (a random amount from `amount` to `amount_max`).
@export var amount := 1
@export var amount_max := 1
## ARROWS and BUFF: seconds the effect lasts.
@export var duration := 12.0
## ARROWS: arrows added to every shot, and the angle between neighbouring arrows.
@export var extra_arrows := 2
@export var spread_degrees := 14.0

@export_group("Buffs")
## PIERCE: how many enemies one arrow can hit before it stops (each enemy only once per arrow).
@export var pierce_count := 3
## FROST: every arrow hit slows the enemy to this fraction of its speed for `slow_seconds`.
@export var slow_factor := 0.5
@export var slow_seconds := 2.0
## HASTE: extra walking speed (0.35 = +35%) and the share of the time between shots that is cut.
@export var speed_bonus := 0.35
@export var cooldown_cut := 0.4
## SHIELD: hits it absorbs, and the invulnerability (s) after each absorbed hit.
@export var shield_charges := 2
@export var shield_invulnerability := 0.6

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


## True for the temporary power-ups (the arrow fan and every BUFF).
func is_buff() -> bool:
	return kind == Kind.ARROWS or kind == Kind.BUFF


## Gives the resource to the player. Returns false when it would do nothing (a heart at full health
## stays on the ground). The caller announces it (this script must not touch autoloads, so tools can load it).
func apply(player: Node, rng: RandomNumberGenerator = null) -> bool:
	match kind:
		Kind.HEAL:
			if player.health.current >= player.health.max_health:
				return false
			player.health.heal(amount)
		Kind.ARROWS, Kind.BUFF:
			player.start_buff(self)
		Kind.GOLD:
			var picker := rng if rng != null else RandomNumberGenerator.new()
			player.add_gold(picker.randi_range(amount, maxi(amount, amount_max)))
	return true
