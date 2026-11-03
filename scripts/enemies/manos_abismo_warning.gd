extends SkillZone
## The Manos del abismo's grab warning: a SkillZone circle (same radius, lifetime and ground layer)
## drawn with its pixel-art strip instead of a translucent disc. Its frames are spread over the
## lifetime, so the cracks reach the center just as the hand bursts out.

## Radius (px) the strip's ring is drawn at; other radii scale the picture.
const ART_RADIUS := 14.0

var art: Texture2D
var art_frames := 1


func _draw() -> void:
	if art == null:
		super()
		return
	var cell := float(art.get_height())
	var progress := clampf(_age / maxf(lifetime, 0.001), 0.0, 0.999)
	var frame := mini(int(progress * art_frames), art_frames - 1)
	var size := cell * radius / ART_RADIUS
	draw_texture_rect_region(art, Rect2(-size / 2.0, -size / 2.0, size, size),
			Rect2(frame * cell, 0, cell, cell))
