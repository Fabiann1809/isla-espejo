extends HBoxContainer
## HUD bar with one square per skill slot: locked (dark), ready (skill color) or on cooldown
## (a dark overlay that shrinks as the cooldown runs out). Placeholder art.

const SLOT_SIZE := Vector2(36, 36)
const LOCKED_COLOR := Color(0.2, 0.2, 0.24)

const BLOCKED_FLASH := Color(0.9, 0.25, 0.2, 0.7)
const BLOCKED_FLASH_SECONDS := 0.18

var _manager: SkillManager
var _icons: Array[ColorRect] = []
var _overlays: Array[ColorRect] = []
var _frames: Array[ColorRect] = []
var _pictures: Array[TextureRect] = []


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	for slot in SkillManager.SLOT_COUNT:
		_add_slot(slot)
	Events.skill_blocked.connect(_on_skill_blocked)


func _process(_delta: float) -> void:
	if _manager == null or not is_instance_valid(_manager):
		var player := get_tree().get_first_node_in_group("player")
		_manager = player.get_node_or_null("SkillManager") if player != null else null
	for slot in SkillManager.SLOT_COUNT:
		_refresh_slot(slot)


## For tests and debugging: whether the slot shows as unlocked and its cooldown fill (0..1).
func slot_state(slot: int) -> Dictionary:
	return {
		"unlocked": _manager != null and _manager.is_unlocked(slot),
		"cooldown_ratio": _overlays[slot].size.y / SLOT_SIZE.y,
	}


func _add_slot(slot: int) -> void:
	var holder := Control.new()
	holder.custom_minimum_size = SLOT_SIZE

	var frame := ColorRect.new()
	frame.color = Color(0, 0, 0, 0.6)
	frame.size = SLOT_SIZE
	holder.add_child(frame)
	_frames.append(frame)

	var icon := ColorRect.new()
	icon.color = LOCKED_COLOR
	icon.position = Vector2(3, 3)
	icon.size = SLOT_SIZE - Vector2(6, 6)
	holder.add_child(icon)
	_icons.append(icon)

	# The skill's own picture (24x24) over the square, shown when the skill has one.
	var picture := TextureRect.new()
	picture.position = Vector2(6, 6)
	picture.size = Vector2(24, 24)
	picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.visible = false
	holder.add_child(picture)
	_pictures.append(picture)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.position = Vector2(3, 3)
	overlay.size = Vector2(SLOT_SIZE.x - 6, 0)
	holder.add_child(overlay)
	_overlays.append(overlay)

	# The key, small in the slot's corner so it never covers the picture.
	var key := Label.new()
	key.text = str(slot + 1)
	key.add_theme_font_size_override("font_size", 9)
	key.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	key.add_theme_constant_override("outline_size", 3)
	key.position = Vector2(SLOT_SIZE.x - 11, SLOT_SIZE.y - 15)
	holder.add_child(key)

	add_child(holder)


## The slot blinks red for an instant: the key was heard, the skill is not ready.
func _on_skill_blocked(slot: int) -> void:
	if slot < 0 or slot >= _frames.size():
		return
	var frame := _frames[slot]
	frame.color = BLOCKED_FLASH
	var tween := frame.create_tween()
	tween.tween_property(frame, "color", Color(0, 0, 0, 0.6), BLOCKED_FLASH_SECONDS)


func _refresh_slot(slot: int) -> void:
	var unlocked := _manager != null and _manager.is_unlocked(slot)
	var skill: SkillData = _manager.get_skill(slot) if unlocked else null
	var picture := _pictures[slot]
	picture.visible = skill != null and skill.icon != null
	picture.texture = skill.icon if picture.visible else null
	# Under a picture the square is a dark backdrop; without one it is the skill's color.
	_icons[slot].color = (Color(0.08, 0.1, 0.12) if picture.visible else skill.color) if unlocked else LOCKED_COLOR
	var ratio := _manager.cooldown_ratio(slot) if unlocked else 0.0
	_overlays[slot].size.y = (SLOT_SIZE.y - 6) * ratio
	if unlocked and ratio == 0.0:
		_overlays[slot].size.y = 0.0
