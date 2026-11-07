class_name Pickup
extends Area2D
## A resource lying on the ground. The player takes it by touching it; some fly to him when close.
## Drawn with simple shapes until there is art.

const BLINK_SECONDS := 3.0
const MAGNET_SPEED := 150.0
const BOB_HEIGHT := 1.5

## The team's spinning gold coin (a horizontal strip of square frames); without the file the coin
## is drawn with circles.
const GOLD_ART := "res://assets/sprites/pickups/gold_coin_spin.png"
## The heart's strip, and (in `Tuning.BUFF_PICKUP_PATH`) one per temporary buff, named `buff_<id>.png`.
const HEART_ART := "res://assets/sprites/pickups/heart.png"

var data: ResourceData
## The coin's, heart's or buff's art, or null (then it is drawn with shapes).
var art: AnimatedSprite2D

var _time := 0.0
var _life_left := 0.0
var _taken := false


## Sets what it is before it enters the tree.
func setup(resource: ResourceData) -> void:
	data = resource


func _ready() -> void:
	add_to_group("pickups")
	_life_left = data.lifetime
	body_entered.connect(_on_body_entered)
	match data.kind:
		ResourceData.Kind.GOLD:
			art = StripArt.build(GOLD_ART, 10.0)
		ResourceData.Kind.HEAL:
			art = StripArt.build(HEART_ART, Tuning.BUFF_PICKUP_FPS)
		_:
			if data.is_buff():
				art = StripArt.build(Tuning.BUFF_PICKUP_PATH % data.id, Tuning.BUFF_PICKUP_FPS)
	if art != null:
		add_child(art)


func _physics_process(delta: float) -> void:
	_time += delta
	if data.lifetime > 0.0:
		_life_left -= delta
		if _life_left <= 0.0:
			queue_free()
			return
	if data.magnet_radius > 0.0:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and not player.is_dead() \
				and global_position.distance_to(player.global_position) <= data.magnet_radius:
			global_position = global_position.move_toward(player.global_position, MAGNET_SPEED * delta)
	# A heart that was left because health was full is taken as soon as there is room.
	for body in get_overlapping_bodies():
		_on_body_entered(body)
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player") or body.is_dead():
		return
	if data.apply(body):
		_taken = true
		if data.message != "":
			Events.message_requested.emit(data.message)
		Events.resource_collected.emit(data.id)
		queue_free()


func _draw() -> void:
	if data == null:
		return
	var blinked_off := data.lifetime > 0.0 and _life_left < BLINK_SECONDS and int(_life_left * 6.0) % 2 == 0
	if art != null:
		art.visible = not blinked_off
		art.position = Vector2(0, -6 + sin(_time * 4.0) * BOB_HEIGHT)
	if blinked_off:
		return
	var lift := Vector2(0, -4 + sin(_time * 4.0) * BOB_HEIGHT)
	draw_circle(Vector2(0, 2), 3.0, Color(0, 0, 0, 0.3))
	if art != null:
		return
	match data.kind:
		ResourceData.Kind.HEAL:
			draw_circle(lift + Vector2(-2.5, -1), 2.8, data.color)
			draw_circle(lift + Vector2(2.5, -1), 2.8, data.color)
			draw_colored_polygon(PackedVector2Array([lift + Vector2(-5, 0), lift + Vector2(5, 0), lift + Vector2(0, 6)]), data.color)
		ResourceData.Kind.ARROWS, ResourceData.Kind.BUFF:
			_draw_buff_orb(lift)
		ResourceData.Kind.GOLD:
			draw_circle(lift, 3.8, data.color.darkened(0.35))
			draw_circle(lift, 2.8, data.color)
			draw_circle(lift + Vector2(-0.8, -0.8), 1.0, data.color.lightened(0.5))


## A temporary buff without art: an orb in the buff's colour with a tiny symbol of its effect.
func _draw_buff_orb(lift: Vector2) -> void:
	draw_circle(lift, Tuning.BUFF_ORB_RADIUS, data.color.darkened(0.4))
	draw_circle(lift, Tuning.BUFF_ORB_RADIUS - 1.5, data.color)
	if data.kind == ResourceData.Kind.ARROWS:
		for dir in [-0.6, 0.0, 0.6]:
			draw_line(lift + Vector2(-2, 2).rotated(dir), lift + Vector2(3, -2).rotated(dir), Color.WHITE, 1.0)
		return
	match data.effect:
		ResourceData.Effect.PIERCE:
			draw_line(lift + Vector2(-3, 0), lift + Vector2(3, 0), Color.WHITE, 1.0)
			draw_line(lift + Vector2(1, -2), lift + Vector2(3, 0), Color.WHITE, 1.0)
			draw_line(lift + Vector2(1, 2), lift + Vector2(3, 0), Color.WHITE, 1.0)
			draw_line(lift + Vector2(-1, -2), lift + Vector2(-1, 2), Color.WHITE, 1.0)
		ResourceData.Effect.FROST:
			for angle in [0.0, PI / 3.0, 2.0 * PI / 3.0]:
				var arm := Vector2.from_angle(angle) * 3.0
				draw_line(lift - arm, lift + arm, Color.WHITE, 1.0)
		ResourceData.Effect.HASTE:
			for dx in [-2.0, 1.0]:
				draw_polyline(PackedVector2Array([lift + Vector2(dx, -2), lift + Vector2(dx + 2, 0), lift + Vector2(dx, 2)]), Color.WHITE, 1.0)
		ResourceData.Effect.SHIELD:
			draw_colored_polygon(PackedVector2Array([lift + Vector2(-2.5, -3), lift + Vector2(2.5, -3),
					lift + Vector2(2.5, 0.5), lift + Vector2(0, 3.5), lift + Vector2(-2.5, 0.5)]), Color.WHITE)
