class_name SinkingFloor
extends Node2D
## A square of floor tiles drilled by a carving spider (CarvingSpider). It cracks first (the
## warning, with a crack running from the spider's drill to it), then sinks into a dark pit for a
## few seconds and closes again. When it sinks, Nico standing on it is held in the hole for a moment
## (a dodge breaks free); while it is a pit its own Hitbox hurts whoever stands in it every `tick`
## seconds. It lives in the room, so it outlasts the spider. Drawn on the ground, under every actor.

enum Phase { CRACKING, SUNK, CLOSING }

const PLAYER_LAYER := 2
const ENEMY_ATTACK_LAYER := 5
## player.apply_pull lets go as soon as Nico is near its anchor: the hold anchors this far away and
## pulls at speed 0, which only keeps him in place.
const HOLD_ANCHOR_DISTANCE := 64.0
## Rays of the crack drawn over the patch while it cracks.
const CRACK_RAYS := 5
## Frames of `art` (square cells): cracking, sinking, sunk (looping) and closing, in that order.
const ART_CRACK := 5
const ART_SINK := 2
const ART_SUNK := 3
const ART_CLOSE := 3
const ART_SUNK_FPS := 6.0
## The pit drops in over this long at the start of the sunk phase (s).
const DROP_TIME := 0.1
## Size of one piece of `trail_art` (px): it runs along x.
const TRAIL_PIECE := Vector2(8, 8)

var phase: Phase = Phase.CRACKING
var size := 32.0
var crack_time := 0.9
var sunk_time := 2.5
var close_time := 0.4
var damage := 1
var tick := 0.7
var hold_time := 0.5
var crack_color := Color.ORANGE
var pit_color := Color.BLACK
var rim_color := Color.ORANGE_RED
var trail_width := 1.0
## Where the crack starts (the spider's drill), in this node's coordinates; ZERO draws no trail.
var trail_from := Vector2.ZERO
## Optional drawn patch instead of the plain shapes: a strip of square cells (see ART_*), and the
## crack running from the drill as a strip of short pieces pointing along it, taken in turns.
var art: Texture2D
var trail_art: Texture2D
## Mirrored at random so patches side by side do not crack alike.
var art_flip := false

var _phase_left := 0.0
var _tick_left := 0.0
var _hitbox: Hitbox
var _rays: Array[PackedVector2Array] = []
var _trail := PackedVector2Array()


## A cracking patch on `center` (in its parent's coordinates), set up from the spider's data.
static func create(center: Vector2, data: CarvingSpiderData, hit_damage: int, drill_from: Vector2) -> SinkingFloor:
	var pit := SinkingFloor.new()
	pit.name = "SinkingFloor"
	pit.position = center
	pit.size = data.pit_tiles * TileArt.TILE
	pit.crack_time = data.crack_time
	pit.sunk_time = data.sunk_time
	pit.close_time = data.close_time
	pit.damage = hit_damage
	pit.tick = data.pit_tick
	pit.hold_time = data.hold_time
	pit.crack_color = data.crack_color
	pit.pit_color = data.pit_color
	pit.rim_color = data.rim_color
	pit.trail_width = data.crack_trail_width
	pit.trail_from = drill_from - center
	pit.art = data.pit_art
	pit.trail_art = data.crack_art
	pit.art_flip = randf() < 0.5
	return pit


func _ready() -> void:
	# The arena's reset clears ground hazards; a pit is one more.
	add_to_group(&"ground_hazards")
	z_as_relative = false
	z_index = RoomTheme.GROUND_FX_Z
	_hitbox = Hitbox.new()
	_hitbox.collision_layer = 1 << (ENEMY_ATTACK_LAYER - 1)
	_hitbox.collision_mask = 1 << (PLAYER_LAYER - 1)
	_hitbox.damage = damage
	var shape := CollisionShape2D.new()
	var square := RectangleShape2D.new()
	square.size = Vector2.ONE * size
	shape.shape = square
	_hitbox.add_child(shape)
	add_child(_hitbox)
	_phase_left = crack_time
	_build_cracks()


func _physics_process(delta: float) -> void:
	_phase_left -= delta
	match phase:
		Phase.CRACKING:
			if _phase_left <= 0.0:
				_sink()
		Phase.SUNK:
			_tick_left -= delta
			if _tick_left <= 0.0:
				_tick_left = tick
				_hitbox.activate()
			if _phase_left <= 0.0:
				phase = Phase.CLOSING
				_phase_left = close_time
				_hitbox.deactivate()
		Phase.CLOSING:
			if _phase_left <= 0.0:
				queue_free()
	queue_redraw()


func is_sunk() -> bool:
	return phase == Phase.SUNK


## True if `point` (world position) is on the patch.
func covers(point: Vector2) -> bool:
	return absf(point.x - global_position.x) <= size / 2.0 and absf(point.y - global_position.y) <= size / 2.0


func _sink() -> void:
	phase = Phase.SUNK
	_phase_left = sunk_time
	_tick_left = tick
	_hitbox.activate()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and player.has_method("apply_pull") and covers(player.global_position):
		player.apply_pull(player.global_position + Vector2.DOWN * HOLD_ANCHOR_DISTANCE, 0.0, hold_time)


## Crooked rays from the middle of the patch and a crooked crack from the drill, made once.
func _build_cracks() -> void:
	for i in CRACK_RAYS:
		var angle := TAU * i / CRACK_RAYS + randf_range(-0.4, 0.4)
		var ray := PackedVector2Array([Vector2.ZERO])
		for step in 3:
			var reach := size * 0.5 * (step + 1) / 3.0
			ray.append(Vector2.from_angle(angle + randf_range(-0.35, 0.35)) * reach)
		_rays.append(ray)
	if trail_from.length() < size * 0.5:
		return
	var steps := maxi(int(trail_from.length() / 8.0), 2)
	var across := trail_from.orthogonal().normalized()
	for i in steps + 1:
		var point := trail_from.lerp(Vector2.ZERO, float(i) / steps)
		if i > 0 and i < steps:
			point += across * randf_range(-2.5, 2.5)
		_trail.append(point)


func _draw() -> void:
	if art != null:
		_draw_art()
		return
	var half := size / 2.0
	var square := Rect2(-half, -half, size, size)
	match phase:
		Phase.CRACKING:
			var progress := 1.0 - clampf(_phase_left / maxf(crack_time, 0.001), 0.0, 1.0)
			var edge := Color(crack_color, crack_color.a * (0.3 + 0.5 * progress))
			draw_rect(square, edge, false, 1.0)
			_draw_cracks(progress)
		Phase.SUNK:
			# It drops in over the first tenth of a second.
			var sunk := 1.0 - clampf((_phase_left - (sunk_time - DROP_TIME)) / DROP_TIME, 0.0, 1.0)
			draw_rect(square.grow(-half * (1.0 - sunk)), pit_color)
			draw_rect(square.grow(-3.0), Color(0, 0, 0, 0.5 * sunk))
			draw_rect(square, rim_color, false, 2.0)
		Phase.CLOSING:
			var left := clampf(_phase_left / maxf(close_time, 0.001), 0.0, 1.0)
			draw_rect(square.grow(-half * (1.0 - left)), Color(pit_color, pit_color.a * left))
			draw_rect(square, Color(rim_color, rim_color.a * left), false, 1.0)


func _draw_cracks(progress: float) -> void:
	if _trail.size() >= 2 and trail_width > 0.0:
		var count := maxi(int(ceil(_trail.size() * progress)), 2)
		draw_polyline(_trail.slice(0, count), crack_color, trail_width)
	for ray in _rays:
		var count := maxi(int(ceil(ray.size() * progress)), 2)
		draw_polyline(ray.slice(0, count), crack_color, 1.0)


## The drawn patch: the frame follows the phase's progress (the sunk pit loops), the crack from the
## drill grows like the plain one.
func _draw_art() -> void:
	var frame := 0
	var fade := 1.0
	match phase:
		Phase.CRACKING:
			var progress := 1.0 - clampf(_phase_left / maxf(crack_time, 0.001), 0.0, 1.0)
			frame = mini(ART_CRACK - 1, int(progress * ART_CRACK))
			_draw_trail_art(progress)
		Phase.SUNK:
			var sunk_for := sunk_time - _phase_left
			if sunk_for < DROP_TIME:
				frame = ART_CRACK + mini(ART_SINK - 1, int(sunk_for / DROP_TIME * ART_SINK))
			else:
				frame = ART_CRACK + ART_SINK + int((sunk_for - DROP_TIME) * ART_SUNK_FPS) % ART_SUNK
		Phase.CLOSING:
			var left := clampf(_phase_left / maxf(close_time, 0.001), 0.0, 1.0)
			frame = ART_CRACK + ART_SINK + ART_SUNK + mini(ART_CLOSE - 1, int((1.0 - left) * ART_CLOSE))
			# The last of the rubble fades out over the second half.
			fade = clampf(left * 2.0, 0.0, 1.0)
	var cell := float(art.get_height())
	var half := size / 2.0
	if art_flip:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
	draw_texture_rect_region(art, Rect2(-half, -half, size, size), Rect2(frame * cell, 0.0, cell, cell),
			Color(1.0, 1.0, 1.0, fade))
	draw_set_transform(Vector2.ZERO)


## Each piece of the crack lies along one step of the trail, stretched to its length.
func _draw_trail_art(progress: float) -> void:
	if trail_art == null or _trail.size() < 2:
		return
	var count := maxi(int(ceil(_trail.size() * progress)), 2)
	var piece := TRAIL_PIECE
	var pieces := maxi(int(trail_art.get_width() / piece.x), 1)
	for i in count - 1:
		var from := _trail[i]
		var step := _trail[i + 1] - from
		draw_set_transform(from, step.angle())
		draw_texture_rect_region(trail_art, Rect2(0.0, -piece.y / 2.0, step.length(), piece.y),
				Rect2((i % pieces) * piece.x, 0.0, piece.x, piece.y))
	draw_set_transform(Vector2.ZERO)
