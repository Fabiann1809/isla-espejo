class_name ShopCatalog
extends Resource
## The Mercader's stock (`data/shop/items.tres`), in the order the menu lists it.

const DEFAULT_PATH := "res://data/shop/items.tres"

@export var items: Array[ShopItem] = []


static func load_default() -> ShopCatalog:
	return load(DEFAULT_PATH) as ShopCatalog


func find(item_id: StringName) -> ShopItem:
	for item in items:
		if item.id == item_id:
			return item
	return null
