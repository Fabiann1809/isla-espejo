class_name Chest
extends StaticBody2D
## A chest with a random prize, rolled when it opens (once): health, gold or, very rarely, a free shop
## upgrade. Weights and amounts are exports (data in the scene). The roll uses `rng`, which the level
## seeds from the map seed and tests can seed too, so it is repeatable.

enum Prize { HEAL, GOLD, UPGRADE }

## Relative odds of each prize (65 / 30 / 5 by default).
@export var weight_heal := 65.0
@export var weight_gold := 30.0
@export var weight_upgrade := 5.0
## Hearts restored by a health prize.
@export var heal_amount := 2
## Gold coins of a gold prize, inclusive range.
@export var gold_min := 4
@export var gold_max := 8

var opened := false
## What the chest gave (set when opened).
var prize: Prize = Prize.HEAL
## Id of the shop upgrade given, when the prize was an upgrade.
var upgrade_given: StringName = &""
var rng := RandomNumberGenerator.new()

@onready var _sprite: Sprite2D = $Sprite
@onready var _talk: Interactable = $Open


func _ready() -> void:
	add_to_group("chests")
	_sprite.texture = TileArt.tile(TileArt.CHEST_CLOSED)
	_sprite.scale *= TileArt.draw_scale()
	_talk.interacted.connect(_on_open)


func _on_open(player: Node) -> void:
	if opened:
		return
	opened = true
	_talk.enabled = false
	_sprite.texture = TileArt.tile(TileArt.CHEST_OPEN)
	Events.message_requested.emit(give_prize(player))
	Events.chest_opened.emit(self)


## Rolls the prize, gives it to `player` and returns the Spanish line that announces it.
func give_prize(player: Node) -> String:
	prize = _roll()
	if prize == Prize.HEAL and player.health.current >= player.health.max_health:
		prize = Prize.GOLD
	var upgrade: ShopItem = null
	if prize == Prize.UPGRADE:
		upgrade = _pick_upgrade()
		if upgrade == null:
			prize = Prize.GOLD
	match prize:
		Prize.HEAL:
			player.health.heal(heal_amount)
			return UiText.t("chest_heal") % heal_amount
		Prize.UPGRADE:
			upgrade_given = upgrade.upgrade_id
			GameState.add_upgrade(upgrade.upgrade_id)
			GameState.apply_upgrades(player)
			return UiText.t("chest_upgrade") % upgrade.display_name
	var coins := rng.randi_range(mini(gold_min, gold_max), maxi(gold_min, gold_max))
	player.add_gold(coins)
	return UiText.t("chest_gold") % coins


func _roll() -> Prize:
	var total := weight_heal + weight_gold + weight_upgrade
	if total <= 0.0:
		return Prize.GOLD
	var pick := rng.randf() * total
	if pick < weight_heal:
		return Prize.HEAL
	if pick < weight_heal + weight_gold:
		return Prize.GOLD
	return Prize.UPGRADE


## A random shop upgrade that is not at its maximum level yet (null when all are).
func _pick_upgrade() -> ShopItem:
	var catalog := ShopCatalog.load_default()
	if catalog == null:
		return null
	var open: Array[ShopItem] = []
	for item in catalog.items:
		if item.is_upgrade() and not Shop.is_maxed(item):
			open.append(item)
	if open.is_empty():
		return null
	return open[rng.randi_range(0, open.size() - 1)]
