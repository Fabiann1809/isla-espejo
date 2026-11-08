class_name SkillBar
extends HBoxContainer
## HUD bar with one slot per skill. A locked slot is dim with a padlock and its key faded; an
## unlocked one has the skill's own picture (or a square of its color), a frame in the skill's
## color and its key in a small badge; a cooldown is a dark clock-wise sweep that shrinks until the
## skill is ready, which flashes once. If the team's frame art exists it replaces the drawn frame.

const SLOT_SIZE := Vector2(36, 36)
const SLOT_GAP := 5
const PICTURE_SIZE := Vector2(24, 24)
const LOCKED_COLOR := Color(0.2, 0.2, 0.24)
## Optional team art (36x36 each); the drawn frame is used while a file is missing.
const FRAME_ART := "res://assets/ui/hud/skill_slot.png"
const LOCKED_ART := "res://assets/ui/hud/skill_slot_locked.png"

const BLOCKED_SECONDS := 0.18
const READY_FLASH_SECONDS := 0.25
const KEY_COLOR := Color(1, 1, 1)
const KEY_LOCKED_COLOR := Color(0.55, 0.55, 0.62)

var _manager: SkillManager
var _backs: Array[SlotFace] = []
var _fronts: Array[SlotFace] = []
var _pictures: Array[TextureRect] = []
var _keys: Array[Label] = []
var _frame_art: Texture2D
var _locked_art: Texture2D


## The two layers of a slot, drawn in code: `front == false` is the frame under the picture and
## `front == true` the sweep, flashes and key badge over it.
class SlotFace:
	extends Control

	var front := false
	var unlocked := false
	var color := Color.WHITE
	var ratio := 0.0
	var flash := 0.0
	var blocked := 0.0
	var frame_art: Texture2D
	var locked_art: Texture2D

	func _draw() -> void:
		if front:
			_draw_front()
		else:
			_draw_back()

	func _draw_back() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if not unlocked:
			draw_rect(r, Color(0.07, 0.07, 0.1, 0.88))
			if locked_art != null:
				draw_texture_rect(locked_art, r, false)
				return
			_border(r, 1.0, Color(0.3, 0.3, 0.37))
			_padlock()
			return
		draw_rect(r, Color(0.05, 0.06, 0.09, 0.92))
		if frame_art != null:
			draw_texture_rect(frame_art, r, false)
			return
		_border(r, 1.0, Color(0, 0, 0, 0.85))
		_border(r.grow(-1.0), 2.0, color.lerp(Color.WHITE, 0.15))
		_border(r.grow(-3.0), 1.0, Color(0, 0, 0, 0.5))

	func _draw_front() -> void:
		var inner := Rect2(Vector2(3, 3), size - Vector2(6, 6))
		if unlocked and ratio > 0.0:
			draw_colored_polygon(_sweep(inner, ratio), Color(0, 0, 0, 0.62))
		if flash > 0.0:
			draw_rect(inner, Color(1, 1, 1, 0.6 * flash))
		if blocked > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.9, 0.25, 0.2, 0.7 * blocked))
		draw_rect(Rect2(size.x - 12, size.y - 13, 10, 11), Color(0, 0, 0, 0.7 if unlocked else 0.45))

	func _border(rect: Rect2, width: float, col: Color) -> void:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, width)), col)
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - width), Vector2(rect.size.x, width)), col)
		draw_rect(Rect2(rect.position + Vector2(0, width), Vector2(width, rect.size.y - 2.0 * width)), col)
		draw_rect(Rect2(rect.position + Vector2(rect.size.x - width, width), Vector2(width, rect.size.y - 2.0 * width)), col)

	func _padlock() -> void:
		var cx := roundf(size.x / 2.0)
		var cy := roundf(size.y / 2.0) - 1.0
		var metal := Color(0.5, 0.5, 0.58)
		draw_rect(Rect2(cx - 3, cy - 7, 6, 2), metal)
		draw_rect(Rect2(cx - 3, cy - 5, 2, 5), metal)
		draw_rect(Rect2(cx + 1, cy - 5, 2, 5), metal)
		draw_rect(Rect2(cx - 5, cy, 10, 8), metal)
		draw_rect(Rect2(cx - 1, cy + 2, 2, 3), Color(0.12, 0.12, 0.16))

	## The part of `rect` still cooling, as a wedge from its center that starts at the top and
	## ends where the clock hand of the sweep is now (clockwise).
	func _sweep(rect: Rect2, share: float) -> PackedVector2Array:
		var center := rect.get_center()
		var half := rect.size / 2.0
		var from := -PI / 2.0 + (1.0 - share) * TAU
		var to := -PI / 2.0 + TAU
		var steps := maxi(ceili((to - from) / (PI / 36.0)), 1)
		var points := PackedVector2Array([center])
		for i in steps + 1:
			var angle := lerpf(from, to, float(i) / steps)
			var dir := Vector2(cos(angle), sin(angle))
			points.append(center + dir / maxf(absf(dir.x) / half.x, absf(dir.y) / half.y))
		return points


func _ready() -> void:
	add_theme_constant_override("separation", SLOT_GAP)
	if ResourceLoader.exists(FRAME_ART):
		_frame_art = load(FRAME_ART) as Texture2D
	if ResourceLoader.exists(LOCKED_ART):
		_locked_art = load(LOCKED_ART) as Texture2D
	for slot in SkillManager.SLOT_COUNT:
		_add_slot(slot)
	Events.skill_blocked.connect(_on_skill_blocked)


func _process(delta: float) -> void:
	if _manager == null or not is_instance_valid(_manager):
		var player := get_tree().get_first_node_in_group("player")
		_manager = player.get_node_or_null("SkillManager") if player != null else null
	for slot in SkillManager.SLOT_COUNT:
		_refresh_slot(slot, delta)


## For tests and debugging: whether the slot shows as unlocked and its cooldown fill (0..1).
func slot_state(slot: int) -> Dictionary:
	return {
		"unlocked": _manager != null and _manager.is_unlocked(slot),
		"cooldown_ratio": _fronts[slot].ratio,
	}


func _add_slot(slot: int) -> void:
	var holder := Control.new()
	holder.custom_minimum_size = SLOT_SIZE
	holder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var back := _new_face(false)
	holder.add_child(back)
	_backs.append(back)

	# The skill's own picture (24x24), or a square of its color, centered in the slot.
	var picture := TextureRect.new()
	picture.position = ((SLOT_SIZE - PICTURE_SIZE) / 2.0).floor()
	picture.size = PICTURE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.visible = false
	holder.add_child(picture)
	_pictures.append(picture)

	var front := _new_face(true)
	holder.add_child(front)
	_fronts.append(front)

	# The key sits in the badge of the slot's corner so it never covers the picture.
	var key := Label.new()
	key.text = str(slot + 1)
	key.add_theme_font_size_override("font_size", 9)
	key.position = Vector2(SLOT_SIZE.x - 12, SLOT_SIZE.y - 13)
	key.size = Vector2(10, 11)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(key)
	_keys.append(key)

	add_child(holder)


func _new_face(is_front: bool) -> SlotFace:
	var face := SlotFace.new()
	face.front = is_front
	face.size = SLOT_SIZE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.frame_art = _frame_art
	face.locked_art = _locked_art
	return face


## The slot blinks red for an instant: the key was heard, the skill is not ready.
func _on_skill_blocked(slot: int) -> void:
	if slot >= 0 and slot < _fronts.size():
		_fronts[slot].blocked = 1.0
		_fronts[slot].queue_redraw()


func _refresh_slot(slot: int, delta: float) -> void:
	var unlocked := _manager != null and _manager.is_unlocked(slot)
	var skill: SkillData = _manager.get_skill(slot) if unlocked else null
	var picture := _pictures[slot]
	var has_icon := skill != null and skill.icon != null
	picture.visible = unlocked
	picture.texture = skill.icon if has_icon else null
	var ratio := _manager.cooldown_ratio(slot) if unlocked else 0.0
	var back := _backs[slot]
	var front := _fronts[slot]
	var changed := back.unlocked != unlocked or front.ratio != ratio
	# A skill without a picture shows a square of its own color on the dark backdrop.
	var color: Color = skill.color if skill != null else LOCKED_COLOR
	if back.color != color or back.unlocked != unlocked:
		back.color = color
		back.unlocked = unlocked
		back.queue_redraw()
	if unlocked and not has_icon:
		# No picture: the swatch is a small tinted rectangle drawn through the picture node.
		picture.texture = _swatch(color)
	if front.unlocked and front.ratio > 0.0 and ratio == 0.0:
		front.flash = 1.0
	front.unlocked = unlocked
	front.ratio = ratio
	_keys[slot].add_theme_color_override("font_color", KEY_COLOR if unlocked else KEY_LOCKED_COLOR)
	_keys[slot].add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_keys[slot].add_theme_constant_override("outline_size", 2)
	if front.flash > 0.0:
		front.flash = maxf(front.flash - delta / READY_FLASH_SECONDS, 0.0)
		changed = true
	if front.blocked > 0.0:
		front.blocked = maxf(front.blocked - delta / BLOCKED_SECONDS, 0.0)
		changed = true
	if changed:
		front.queue_redraw()


var _swatches := {}


func _swatch(color: Color) -> Texture2D:
	if not _swatches.has(color):
		var image := Image.create(PICTURE_SIZE.x as int, PICTURE_SIZE.y as int, false, Image.FORMAT_RGBA8)
		image.fill_rect(Rect2i(4, 4, 16, 16), color)
		_swatches[color] = ImageTexture.create_from_image(image)
	return _swatches[color]
