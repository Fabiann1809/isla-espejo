extends SceneTree
## Language test: every UI key has an English text, the English texts keep the placeholders of the
## Spanish ones, the English dialogues and prologue keep the Spanish structure, and switching the
## language changes what UiText returns (the main menu is rebuilt from it).
## Run: godot --headless --path . --script res://tests/test_language.gd

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var settings := root.get_node("Settings")
	root.get_node("SaveGame").persistence_enabled = false
	settings.persistence_enabled = false

	var es := _read("res://data/ui/texts.json")
	var en := _read("res://data/ui/texts.en.json")
	_check(es.size() > 0 and en.size() == es.size(), "texts.en.json has every key of texts.json")
	for key in es:
		_check(en.has(key), "English text exists for %s" % key)
		_check(_placeholders(str(es[key])) == _placeholders(str(en.get(key, ""))),
				"placeholders match for %s" % key)

	var data_en := _read("res://data/ui/data_strings_en.json")
	_check(data_en.size() > 0, "data_strings_en.json has entries")
	for text in data_en:
		_check(_placeholders(str(text)) == _placeholders(str(data_en[text])), "placeholders match in data string: %s" % text)

	for name in ["elder", "forest_guardian", "merchant", "traveler"]:
		var spanish: Variant = _read_any("res://data/dialogues/%s.json" % name)
		var english: Variant = _read_any("res://data/dialogues/en/%s.json" % name)
		_check(_same_shape(spanish, english), "English dialogue %s has the Spanish structure" % name)
	_check(_same_shape(_read_any("res://data/story/prologue.json"), _read_any("res://data/story/en/prologue.json")),
			"English prologue has the Spanish structure")

	settings.language = "es"
	var spanish_start: String = UiText.t("menu_start")
	settings.language = "en"
	var english_start: String = UiText.t("menu_start")
	_check(spanish_start != english_start and english_start == en["menu_start"], "switching to English changes the menu text")
	settings.language = "es"
	_check(UiText.t("menu_start") == spanish_start, "switching back to Spanish restores it")

	print("ALL OK" if _ok else "SOME CHECKS FAILED")
	quit(0 if _ok else 1)


func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _read_any(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _placeholders(text: String) -> Array:
	var found := []
	var regex := RegEx.new()
	regex.compile("%[-+0#]*\\d*(\\.\\d+)?[sdfxcg]")
	for match in regex.search_all(text):
		found.append(match.get_string())
	found.sort()
	return found


## Same keys and list lengths everywhere; only the string values may differ.
func _same_shape(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.keys().size() != b.keys().size():
			return false
		for key in a:
			if not b.has(key) or not _same_shape(a[key], b[key]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _same_shape(a[i], b[i]):
				return false
		return true
	if a is String and b is String:
		return true
	return typeof(a) == typeof(b) and (a == b or a is String)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_ok = false
		printerr("FAIL %s" % label)
