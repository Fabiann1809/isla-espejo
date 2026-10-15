class_name UiText
extends RefCounted
## Player-facing texts of the menus (Spanish), read from `data/ui/texts.json` so no text lives in
## scripts. `UiText.t("menu_start")` returns the key itself if it is missing, which makes gaps visible.

const PATH := "res://data/ui/texts.json"

static var _texts := {}


static func t(key: String) -> String:
	if _texts.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_texts = parsed
		if _texts.is_empty():
			push_error("Could not read %s" % PATH)
			_texts = {"": ""}
	return str(_texts.get(key, key))
