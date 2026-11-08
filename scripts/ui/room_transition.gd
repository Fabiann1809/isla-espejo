class_name RoomTransition
extends CanvasLayer
## The entrance to the boss's arena: the first time Nico steps in, the screen dips for an instant and the
## camera breathes in (a tiny zoom that settles). Ordinary rooms have no transition and no text (the whole
## island has one name, shown by the chapter intro). `Level` creates it (see its `room_transitions` option);
## every value is in `Tuning.ROOM_*`.

var _level: Level
var _seen: Dictionary = {}
var _dip: ColorRect
var _dip_tween: Tween
var _zoom_tween: Tween


func start(level: Level) -> void:
	_level = level
	layer = 3
	_dip = ColorRect.new()
	_dip.color = Color(0, 0, 0, 0)
	_dip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dip)
	Events.room_entered.connect(_on_room_entered)
	level.generated.connect(func(_layout: MapLayout) -> void: _seen.clear())


func _on_room_entered(room: Node) -> void:
	var data: RoomData = room.data if "data" in room else null
	if data == null or _seen.has(room.get_instance_id()):
		return
	_seen[room.get_instance_id()] = true
	if data.type != RoomData.RoomType.BOSS or _level.has_node("ChapterIntro"):
		return
	play()


## The dip and the camera breath.
func play() -> void:
	_dip_tween = _restart(_dip_tween)
	_dip.color.a = Tuning.ROOM_DIP_ALPHA
	_dip_tween.tween_property(_dip, "color:a", 0.0, Tuning.ROOM_DIP_SECONDS)
	_breathe()


## The camera starts a hair closer and settles back at the game's own zoom.
func _breathe() -> void:
	var player: Node = _level.player
	var camera: Camera2D = player.get_node_or_null("Camera2D") if player != null else null
	var mine := _zoom_tween != null and _zoom_tween.is_valid()
	if camera == null or (camera.zoom != Vector2.ONE and not mine):
		return                       # somebody else (the chapter intro) is moving the zoom
	_zoom_tween = _restart(_zoom_tween)
	camera.zoom = Vector2.ONE * Tuning.ROOM_PUNCH_ZOOM
	_zoom_tween.tween_property(camera, "zoom", Vector2.ONE, Tuning.ROOM_PUNCH_SECONDS) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _restart(tween: Tween) -> Tween:
	if tween != null and tween.is_valid():
		tween.kill()
	return create_tween()
