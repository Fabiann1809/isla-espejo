class_name CreditsScreen
extends PanelContainer
## The credits, read from `CREDITS.md` (the single list every third-party asset is added to), so the
## screen is always up to date. The file is shipped with the game (see include_filter in
## export_presets.cfg).

signal closed

const PATH := "res://CREDITS.md"

var back_button: Button
var body: Label


func _ready() -> void:
	theme = UiKit.theme()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	box.add_child(UiKit.label(UiText.t("credits_title"), 18))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 190)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	body = UiKit.label(read_credits(), 12, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(400, 0)
	scroll.add_child(body)
	back_button = UiKit.button(UiText.t("credits_back"))
	box.add_child(back_button)
	back_button.pressed.connect(close)
	hide()


func open() -> void:
	show()
	back_button.grab_focus()


func close() -> void:
	hide()
	closed.emit()


static func read_credits() -> String:
	if not FileAccess.file_exists(PATH):
		return UiText.t("credits_missing")
	return format(FileAccess.get_file_as_string(PATH))


## Turns the markdown into plain text: headings lose their `#`, and each table row becomes
## "- Resource (Author, License)"; the top heading is dropped. The table's header and separator rows are dropped.
static func format(markdown: String) -> String:
	var lines: Array[String] = []
	var header_seen := false
	for raw in markdown.split("\n"):
		var line := raw.strip_edges()
		if line == "":
			continue
		if line.begins_with("|"):
			if not header_seen:
				header_seen = true
				continue
			if line.begins_with("|---") or line.begins_with("| ---"):
				continue
			var cells := line.trim_prefix("|").trim_suffix("|").split("|")
			if cells.size() >= 3:
				lines.append("- %s (%s, %s)" % [cells[0].strip_edges(), cells[1].strip_edges(), cells[2].strip_edges()])
			continue
		if line.begins_with("# "):
			continue  # the screen already has its own title
		lines.append(line.replace("**", "").replace("`", "").lstrip("# ").strip_edges())
	return "\n\n".join(lines)
