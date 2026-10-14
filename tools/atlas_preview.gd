extends SceneTree
## Renders part of a tileset image with the (column,row) index written over every tile, so tiles
## can be picked by coordinates. Needs a window (do NOT use --headless).
##
##   godot --path . --script res://tools/atlas_preview.gd -- <image> <out.png> <col0> <row0> <cols> <rows> [scale] [tile] [margin]
##
## Example (Kenney Roguelike/RPG sheet: 16 px tiles with a 1 px margin):
##   godot --path . --script res://tools/atlas_preview.gd -- sheet.png out.png 10 8 15 8 4 16 1

const LABEL_COLOR := Color(1, 1, 0.2)

var _viewport: SubViewport
var _frames := 0
var _out := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 6:
		printerr("usage: -- <image> <out.png> <col0> <row0> <cols> <rows> [scale] [tile] [margin]")
		quit(1)
		return
	var source := Image.load_from_file(args[0])
	_out = args[1]
	var col0 := int(args[2])
	var row0 := int(args[3])
	var cols := int(args[4])
	var rows := int(args[5])
	var scale := int(args[6]) if args.size() > 6 else 4
	var tile := int(args[7]) if args.size() > 7 else 16
	var margin := int(args[8]) if args.size() > 8 else 0
	var stride := tile + margin

	var size := Vector2i(cols, rows) * stride * scale
	_viewport = SubViewport.new()
	_viewport.size = size
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	root.add_child(_viewport)

	var background := ColorRect.new()
	background.color = Color(0.25, 0.3, 0.4)
	background.size = Vector2(size)
	_viewport.add_child(background)

	for row in rows:
		for col in cols:
			var region := Rect2i((col0 + col) * stride, (row0 + row) * stride, tile, tile)
			if region.end.x > source.get_width() or region.end.y > source.get_height():
				continue
			var texture := ImageTexture.create_from_image(source.get_region(region))
			var rect := TextureRect.new()
			rect.texture = texture
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			rect.stretch_mode = TextureRect.STRETCH_SCALE
			rect.position = Vector2(col, row) * stride * scale
			rect.size = Vector2(tile, tile) * scale
			_viewport.add_child(rect)

			var label := Label.new()
			label.text = "%d,%d" % [col0 + col, row0 + row]
			label.position = rect.position
			label.add_theme_font_size_override("font_size", 9)
			label.add_theme_color_override("font_color", LABEL_COLOR)
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 3)
			_viewport.add_child(label)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 4 and _viewport != null:
		_viewport.get_texture().get_image().save_png(_out)
		print("saved ", _out)
		return true
	return _frames > 10
