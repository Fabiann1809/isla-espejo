extends HBoxContainer
## HUD bar with one square per skill slot: locked (dark), ready (skill color) or on cooldown
## (a dark overlay that shrinks as the cooldown runs out). Placeholder art.

const SLOT_SIZE := Vector2(36, 36)
const LOCKED_COLOR := Color(0.2, 0.2, 0.24)

var _manager: SkillManager
var _icons: Array[ColorRect] = []
var _overlays: Array[ColorRect] = []


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	for slot in SkillManager.SLOT_COUNT:
		_add_slot(slot)


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

	var icon := ColorRect.new()
	icon.color = LOCKED_COLOR
	icon.position = Vector2(3, 3)
	icon.size = SLOT_SIZE - Vector2(6, 6)
	holder.add_child(icon)
	_icons.append(icon)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.position = Vector2(3, 3)
	overlay.size = Vector2(SLOT_SIZE.x - 6, 0)
	holder.add_child(overlay)
	_overlays.append(overlay)

	var key := Label.new()
	key.text = str(slot + 1)
	key.position = Vector2(5, 2)
	holder.add_child(key)

	add_child(holder)


func _refresh_slot(slot: int) -> void:
	var unlocked := _manager != null and _manager.is_unlocked(slot)
	_icons[slot].color = _manager.get_skill(slot).color if unlocked else LOCKED_COLOR
	var ratio := _manager.cooldown_ratio(slot) if unlocked else 0.0
	_overlays[slot].size.y = (SLOT_SIZE.y - 6) * ratio
	if unlocked and ratio == 0.0:
		_overlays[slot].size.y = 0.0
