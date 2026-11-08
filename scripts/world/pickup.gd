class_name Pickup
extends Area2D
## A resource lying on the ground. The player takes it by touching it; some fly to him when close.
## The heart and the arrow orb are pixel art (assets/sprites/pickups/, tools/make_pickup_art.py); the
## gold coin is drawn with shapes (the HUD's coin copies that design).

const BLINK_SECONDS := 3.0
const MAGNET_SPEED := 150.0
const BOB_HEIGHT := 1.5
const HEART_ART := preload("res://assets/sprites/pickups/heart.png")
const ORB_ART := preload("res://assets/sprites/pickups/arrow_orb.png")

var data: ResourceData

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
	if data.lifetime > 0.0 and _life_left < BLINK_SECONDS and int(_life_left * 6.0) % 2 == 0:
		return
	var lift := Vector2(0, -4 + sin(_time * 4.0) * BOB_HEIGHT)
	draw_circle(Vector2(0, 2), 3.0, Color(0, 0, 0, 0.3))
	match data.kind:
		ResourceData.Kind.HEAL:
			draw_texture(HEART_ART, (lift - HEART_ART.get_size() / 2.0).round())
		ResourceData.Kind.ARROWS:
			draw_texture(ORB_ART, (lift - ORB_ART.get_size() / 2.0).round())
		ResourceData.Kind.GOLD:
			draw_circle(lift, 3.8, data.color.darkened(0.35))
			draw_circle(lift, 2.8, data.color)
			draw_circle(lift + Vector2(-0.8, -0.8), 1.0, data.color.lightened(0.5))
