extends Node2D
## Visual relief entirely inside the already reserved islet footprint.
var tops: Dictionary = {}
var ruined := false
var feet: Dictionary = {}
var fall := false

func _draw() -> void:
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in tops:
		if tops.has(cell + Vector2i.DOWN) and tops.has(cell + Vector2i.RIGHT):
			candidates.append(cell)
	if candidates.is_empty():
		return
	var cell := candidates[candidates.size() / 2]
	var at := Vector2(cell * 16)
	var points := PackedVector2Array([Vector2(1,22), Vector2(0,11), Vector2(6,2), Vector2(15,0), Vector2(23,8), Vector2(27,23), Vector2(17,29)])
	for i in points.size():
		points[i] += at
	draw_colored_polygon(points, Color("201216"))
	draw_colored_polygon(PackedVector2Array([at+Vector2(1,11),at+Vector2(6,2),at+Vector2(15,0),at+Vector2(18,13),at+Vector2(9,20)]),Color("564a4c"))
	draw_colored_polygon(PackedVector2Array([at+Vector2(18,13),at+Vector2(23,8),at+Vector2(27,23),at+Vector2(17,29),at+Vector2(9,20)]),Color("302221"))
	draw_line(at+Vector2(6,3),at+Vector2(14,1),Color("6a5c5c"))
	if ruined:
		# A snapped column and fallen capital, large enough to read in the sea.
		draw_rect(Rect2(at+Vector2(4,19),Vector2(22,6)),Color("302221"))
		draw_rect(Rect2(at+Vector2(6,17),Vector2(18,4)),Color("8f5f59"))
		draw_colored_polygon(PackedVector2Array([at+Vector2(10,18),at+Vector2(10,3),at+Vector2(14,5),at+Vector2(17,1),at+Vector2(21,4),at+Vector2(21,18)]),Color("6a5c5c"))
		draw_line(at+Vector2(11,5),at+Vector2(11,17),Color("a8766a"))
		draw_line(at+Vector2(18,5),at+Vector2(18,17),Color("443a3d"),2)
		draw_rect(Rect2(at+Vector2(22,25),Vector2(8,3)),Color("a8766a"))

	if fall and not feet.is_empty():
		var cells: Array = feet.keys()
		var foot: Vector2i = cells[cells.size() / 2]
		var lip := foot
		for top: Vector2i in tops:
			if top.x == foot.x and top.y < lip.y:
				lip = top
		# The stream starts at the south edge of this column's lowest top.
		for top: Vector2i in tops:
			if top.x == foot.x and top.y > lip.y:
				lip = top
		var x := foot.x * 16 + 5
		var y := lip.y * 16 + 13
		var length := (foot.y + 1) * 16 - y
		draw_rect(Rect2(x-1,y,9,length),Color("9f260e"))
		draw_rect(Rect2(x,y,7,length),Color("fb4b03"))
		draw_rect(Rect2(x+1,y,3,length),Color("ff8a1e"))
		draw_rect(Rect2(x+1,y,1,length),Color("ffd36a"))
		draw_rect(Rect2(x-3,y+length-2,13,2),Color("ff8a1e"))
