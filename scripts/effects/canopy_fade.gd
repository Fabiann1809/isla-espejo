class_name CanopyFade
extends Node
## Trees turn see-through while Nico stands behind them, so he is never lost under a crown. Only
## the trees near him are checked; the value and the off switch live in Tuning. The Level adds one.

## Trees and structures farther than this from Nico (px) are not checked (the temple's pillars stand
## about 100 px tall above their foot).
const REACH := 128.0
## Nico's body center, above his feet (his origin).
const BODY := Vector2(0, -10)

## Tree -> its drawn rectangle in world coordinates (trees never move).
var _rects := {}
## Trees that are faded or fading back.
var _faded := {}


func _ready() -> void:
	# A new map frees the old trees.
	Events.level_started.connect(func(_id: StringName, _seed: int) -> void:
		_rects.clear()
		_faded.clear())


func _process(delta: float) -> void:
	if Tuning.CANOPY_FADE_ALPHA >= 1.0:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var covering := {}
	if player != null:
		var body := player.global_position + BODY
		for node in get_tree().get_nodes_in_group(RoomProp.CANOPY_GROUP):
			var tree := node as Node2D
			if absf(tree.global_position.x - body.x) > REACH or absf(tree.global_position.y - body.y) > REACH:
				continue
			# Behind = above the tree's sort line, inside what it draws.
			if player.global_position.y < tree.global_position.y and rect_of(tree).has_point(body):
				covering[tree] = true
				_faded[tree] = true
	var step := Tuning.CANOPY_FADE_SPEED * delta
	for tree in _faded.keys():
		if not is_instance_valid(tree):
			_faded.erase(tree)
			continue
		var target := Tuning.CANOPY_FADE_ALPHA if covering.has(tree) else 1.0
		tree.modulate.a = move_toward(tree.modulate.a, target, step)
		if tree.modulate.a == 1.0 and not covering.has(tree):
			_faded.erase(tree)


## What the tree draws, as a world rectangle (union of its sprites).
func rect_of(tree: Node2D) -> Rect2:
	if _rects.has(tree):
		return _rects[tree]
	var rect := Rect2(tree.global_position, Vector2.ZERO)
	for child in tree.get_children():
		var local := Rect2()
		var sprite := child as Node2D
		if child is Sprite2D and child.texture != null:
			local = child.get_rect()
		elif child is AnimatedSprite2D and child.sprite_frames != null:
			# An animated prop (the temple's): the size of its current frame, placed as the node draws it.
			var frame: Texture2D = child.sprite_frames.get_frame_texture(child.animation, child.frame)
			if frame == null:
				continue
			var size := frame.get_size()
			local = Rect2(child.offset - (size / 2.0 if child.centered else Vector2.ZERO), size)
		else:
			continue
		var top_left := sprite.global_transform * local.position
		var bottom_right := sprite.global_transform * local.end
		rect = rect.merge(Rect2(top_left, bottom_right - top_left).abs())
	_rects[tree] = rect
	return rect


## True while `tree` is see-through (tests).
func is_faded(tree: Node2D) -> bool:
	return tree.modulate.a < 1.0
