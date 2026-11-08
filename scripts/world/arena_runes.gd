class_name ArenaRunes
extends Node2D
## A ring of runes on the ground under the boss. It glows faintly while the boss sleeps, flares up when the
## boss wakes (`Events.boss_awakened`) and fades out when it falls (`Events.boss_defeated`).
## Drawn with lines; the color and size are in `Tuning`.

const GLYPHS := 8

var _energy := 0.3
var _target := 0.3
var _time := 0.0


func _ready() -> void:
	Events.boss_awakened.connect(func(_id: StringName, _at: Vector2) -> void:
		_energy = 1.4
		_target = 0.85)
	Events.boss_defeated.connect(func(_id: StringName) -> void: _target = 0.0)


func _process(delta: float) -> void:
	_time += delta
	_energy = move_toward(_energy, _target, delta * 0.7)
	queue_redraw()


func _draw() -> void:
	var color := Tuning.BOSS_RUNE_COLOR
	var radius := Tuning.BOSS_RUNE_RADIUS
	var strength := (0.45 + 0.15 * sin(_time * 1.7)) * (0.35 + _energy)
	var line := Color(color, clampf(strength, 0.0, 1.0))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, line, 1.0)
	draw_arc(Vector2.ZERO, radius - 7.0, 0.0, TAU, 44, Color(line, line.a * 0.6), 1.0)
	for i in GLYPHS:
		# Each glyph is a stroke across the band between the two rings with a tick and a dot.
		var angle := TAU * i / GLYPHS + 0.2
		var out := Vector2.from_angle(angle)
		var side := out.orthogonal()
		var base := out * (radius - 3.5)
		var lit := 0.6 + 0.4 * sin(_time * 2.4 + i * 1.3)
		var glyph := Color(color.lightened(0.3), clampf(strength * (0.7 + 0.5 * lit), 0.0, 1.0))
		draw_line(base - out * 2.5, base + out * 2.5, glyph, 1.0)
		draw_line(base - side * 2.0 + out * (0.5 if i % 2 == 0 else -0.5), base + side * 2.0, glyph, 1.0)
		if i % 3 == 0:
			draw_circle(base + side * 3.5, 0.8, glyph)
