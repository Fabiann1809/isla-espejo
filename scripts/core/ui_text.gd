class_name UiText
extends RefCounted
## Player-facing texts, read from data files so no text lives in scripts. The language is the one
## chosen in the options (`Settings.language`: "es" or "en"). The Spanish file is the source; the
## English one falls back to Spanish for any key it lacks, and a missing key shows the key itself,
## which makes gaps visible.
##  - `UiText.t("menu_start")`: keys of `data/ui/texts.json` (es) and `data/ui/texts.en.json` (en).
##  - `UiText.data("Grunt")`: strings that live in .tres/.tscn data (display names, prompts, chapter
##    titles). They stay Spanish in the resources; `data/ui/data_strings_en.json` maps each Spanish
##    text to its English one. In Spanish the text is returned unchanged.

const PATH_ES := "res://data/ui/texts.json"
const PATH_EN := "res://data/ui/texts.en.json"
const DATA_EN_PATH := "res://data/ui/data_strings_en.json"

static var _texts := {}
static var _texts_en := {}
static var _data_en := {}


static func t(key: String) -> String:
	if _current_language() == "en":
		var english := _lookup(_texts_en, PATH_EN, key)
		if english != "":
			return english
	var spanish := _lookup(_texts, PATH_ES, key)
	return spanish if spanish != "" else key


static func data(text: String) -> String:
	if _current_language() != "en" or text == "":
		return text
	if _data_en.is_empty():
		_data_en = _read_json(DATA_EN_PATH)
	return str(_data_en.get(text, text))


## Looked up at runtime: tests load this script by path, before the Settings autoload is registered.
static func _current_language() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var settings: Node = tree.root.get_node_or_null("Settings") if tree != null else null
	return str(settings.get("language")) if settings != null else "es"


static func _lookup(cache: Dictionary, path: String, key: String) -> String:
	if cache.is_empty():
		cache.merge(_read_json(path))
	return str(cache.get(key, "")) if cache.has(key) else ""


static func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not read %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
