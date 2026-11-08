extends Node2D
## Crisp concentric colour bands soften lava contact without filtering the stone.
var stone: Dictionary = {}

func _draw() -> void:
	var colors: Array[Color] = [Color("fc6810"), Color("ff8a1e"), Color("9f260e"), Color("6a2219"), Color("3a1712"), Color("302221")]
	var width := mini(Tuning.TEMPLE_SHORE_WIDTH, colors.size())
	for cell: Vector2i in stone:
		for dir: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if stone.has(cell + dir):
				continue
			var origin := cell * 16
			for i in width:
				var at := origin
				var size := Vector2i(16, 1)
				if dir.x != 0:
					size = Vector2i(1, 16)
					at.x += 16 + i if dir.x > 0 else -1 - i
				else:
					at.y += 16 + i if dir.y > 0 else -1 - i
				draw_rect(Rect2(Vector2(at), Vector2(size)), colors[width - 1 - i])
