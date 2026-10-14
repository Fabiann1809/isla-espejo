extends CanvasLayer
## Screen shown when a run ends in death: what the island learned about the player.
## Listens to PlayerProfile.run_finished; all texts come from the profile config (data/ai/).

signal dismissed

## Input is ignored for this long so a key mashed during the death does not close it at once.
const MIN_DISPLAY_TIME := 0.8
const BAR_WIDTH := 220.0
const AGGRESSION_COLOR := Color(0.85, 0.3, 0.25)
const STEALTH_COLOR := Color(0.6, 0.4, 0.9)

var _visible_time := 0.0

@onready var _panel: PanelContainer = $Panel
@onready var _content: VBoxContainer = $Panel/Margin/Content


func _ready() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.05, 0.09, 0.94)
	background.border_color = Color(0.45, 0.35, 0.7)
	background.set_border_width_all(2)
	background.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", background)
	_panel.hide()
	PlayerProfile.run_finished.connect(_on_run_finished)


func _process(delta: float) -> void:
	if not _panel.visible:
		return
	_visible_time += delta
	if _visible_time >= MIN_DISPLAY_TIME \
			and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack")):
		_panel.hide()
		dismissed.emit()


func _on_run_finished(summary: Dictionary) -> void:
	if summary.reason != "death":
		return
	var texts: Dictionary = PlayerProfile.config.texts
	var stats: Dictionary = summary.stats
	for child in _content.get_children():
		child.queue_free()

	_add_label(texts.get("title", ""), 20)
	_add_label(texts.get("style_label", "") + ": " + summary.style_name, 16)
	_add_bar(texts.get("aggression", ""), summary.aggression, AGGRESSION_COLOR)
	_add_bar(texts.get("stealth", ""), summary.stealth, STEALTH_COLOR)
	_add_stats([
		texts.get("stat_time", "%s") % _format_time(stats.play_seconds),
		texts.get("stat_attacks", "%d") % stats.melee_attacks,
		texts.get("stat_skills", "%d") % stats.skill_uses,
		texts.get("stat_rooms", "%d") % stats.rooms_visited,
		texts.get("stat_evaded", "%d") % stats.rooms_evaded,
		texts.get("stat_detections", "%d") % stats.detections,
	])
	_add_label(summary.message, 14, true)
	_add_prepare_lines()
	_add_label(texts.get("continue", ""), 12)

	_visible_time = 0.0
	_panel.show()


## The stats in two columns, so the whole screen fits in the game's 640x360 view.
func _add_stats(lines: Array[String]) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 1)
	for line in lines:
		var label := Label.new()
		label.text = line
		label.add_theme_font_size_override("font_size", 12)
		grid.add_child(label)
	_content.add_child(grid)


## What the island will do next, according to the director's rules for the updated profile.
func _add_prepare_lines() -> void:
	var plan: DirectorPlan = Director.make_plan(false)
	if plan.hints.is_empty():
		return
	_add_label(Director.config.texts.get("prepare_title", ""), 13)
	for hint in plan.hints:
		_add_label("- " + hint, 12)


func _add_label(text: String, font_size: int, wrap := false) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 310
	_content.add_child(label)


func _add_bar(title: String, value: float, color: Color) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 80
	row.add_child(label)

	var track := ColorRect.new()
	track.color = Color(0.15, 0.15, 0.18)
	track.custom_minimum_size = Vector2(BAR_WIDTH, 14)
	var fill := ColorRect.new()
	fill.color = color
	fill.size = Vector2(BAR_WIDTH * clampf(value, 0.0, 1.0), 14)
	track.add_child(fill)
	row.add_child(track)
	_content.add_child(row)


func _format_time(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
