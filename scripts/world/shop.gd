class_name Shop
extends RefCounted
## Buying from the Mercader. The gold is the player's (`Player.gold`, announced on
## `Events.player_gold_changed`); upgrades are written in GameState so they last the journey.

enum Result { BOUGHT, NO_GOLD, MAXED, FULL_HEALTH, NO_PLAYER }


## Times an upgrade has been bought (0 for potions and elixirs, which can be bought again forever).
static func level_of(item: ShopItem) -> int:
	return GameState.upgrade_level(item.upgrade_id) if item.is_upgrade() else 0


static func is_maxed(item: ShopItem) -> bool:
	return item.is_upgrade() and level_of(item) >= item.max_level


## What the next purchase of `item` costs now.
static func price_of(item: ShopItem) -> int:
	return item.price_at(level_of(item))


## Buys one `item` for `player`: spends the gold and applies the effect. Nothing is spent when it is
## refused (not enough gold, an upgrade at its maximum, healing at full health).
static func buy(item: ShopItem, player: Node) -> Result:
	if player == null or item == null:
		return Result.NO_PLAYER
	if is_maxed(item):
		return Result.MAXED
	if item.kind != ShopItem.Kind.UPGRADE and player.health.current >= player.health.max_health:
		return Result.FULL_HEALTH
	var price := price_of(item)
	if player.gold < price:
		return Result.NO_GOLD
	player.add_gold(-price)
	match item.kind:
		ShopItem.Kind.HEAL:
			player.health.heal(item.amount)
		ShopItem.Kind.FULL_HEAL:
			player.health.heal(player.health.max_health)
		ShopItem.Kind.UPGRADE:
			GameState.add_upgrade(item.upgrade_id)
			GameState.apply_upgrades(player)
	return Result.BOUGHT
