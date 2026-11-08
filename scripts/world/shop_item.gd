class_name ShopItem
extends Resource
## One thing the Mercader sells. The catalog lives in `data/shop/items.tres` (see ShopCatalog), so a new
## item is data, not code. Name and description are Spanish and stay here, never in scripts.

## HEAL: heals `amount` hearts. FULL_HEAL: heals everything. UPGRADE: raises `upgrade_id` one level
## (kept in GameState for the journey, up to `max_level`).
enum Kind { HEAL, FULL_HEAL, UPGRADE }

@export var id: StringName = &"item"
@export var display_name := "Objeto"
@export_multiline var description := ""
## Gold at level 0; an upgrade's price grows by `price_growth` (0.5 = +50%) of the base per level.
@export var price := 5
@export_range(0.0, 2.0) var price_growth := 0.0
@export var kind: Kind = Kind.HEAL
@export var amount := 1
@export var upgrade_id: StringName = &""
@export var max_level := 1
## Optional icon (`assets/sprites/shop/<id>.png`); without the file the menu draws `color` instead.
@export var icon_path := ""
@export var color := Color(0.8, 0.8, 0.9)


## Gold the next purchase costs when the item has been bought `level` times.
func price_at(level: int) -> int:
	return maxi(roundi(price * (1.0 + price_growth * level)), 1)


func is_upgrade() -> bool:
	return kind == Kind.UPGRADE


## The icon, or null when its file does not exist (yet).
func icon() -> Texture2D:
	if icon_path != "" and ResourceLoader.exists(icon_path):
		return load(icon_path) as Texture2D
	return null
