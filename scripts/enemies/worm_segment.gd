class_name WormSegment
extends StaticBody2D
## One piece of a bridge worm's body (BridgeWorm). It lives in the worm's room, beside the worm, so it
## is y-sorted with the actors and stays where the head's path put it. While out it is solid for Nico
## (enemy layer, which his body collides with; other enemies and projectiles pass), its Hitbox hurts
## him on contact and its Hurtbox passes hits on to the worm. Under the ground it is hidden and off.

const ENEMY_LAYER := 3
const PLAYER_LAYER := 2
const ENEMY_ATTACK_LAYER := 5

var hitbox: Hitbox
var hurtbox: Hurtbox
var is_out := false

var _body_shape: CollisionShape2D
var _hit_shape: CollisionShape2D
var _hurt_shape: CollisionShape2D
var _art: Sprite2D


## A hidden piece, ready to be added to the worm's room; `piece` counts from the head (its picture
## is that cell of the data's strip).
static func create(data: BridgeWormData, piece: int) -> WormSegment:
	var segment := WormSegment.new()
	segment.name = "WormSegment"
	segment.collision_layer = 1 << (ENEMY_LAYER - 1)
	segment.collision_mask = 0
	segment._body_shape = _circle_shape(data.segment_body_radius)
	segment.add_child(segment._body_shape)

	segment.hitbox = Hitbox.new()
	segment.hitbox.collision_layer = 1 << (ENEMY_ATTACK_LAYER - 1)
	segment.hitbox.collision_mask = 1 << (PLAYER_LAYER - 1)
	segment._hit_shape = _circle_shape(data.segment_hit_radius)
	segment.hitbox.add_child(segment._hit_shape)
	segment.add_child(segment.hitbox)

	segment.hurtbox = Hurtbox.new()
	segment.hurtbox.collision_layer = 1 << (ENEMY_LAYER - 1)
	segment.hurtbox.collision_mask = 0
	segment._hurt_shape = _circle_shape(data.segment_hit_radius)
	segment.hurtbox.add_child(segment._hurt_shape)
	segment.add_child(segment.hurtbox)
	# Knockback of a contact hit is pushed away from this piece, not from the worm's head.
	segment.hitbox.owner = segment
	segment.hurtbox.owner = segment

	segment._art = Sprite2D.new()
	segment._art.texture = data.segment_texture
	if data.segment_texture != null:
		var cell := maxf(data.segment_texture.get_height(), 1.0)
		segment._art.hframes = maxi(floori(data.segment_texture.get_width() / cell), 1)
		segment._art.frame = mini(piece, segment._art.hframes - 1)
	segment._art.position = data.segment_offset
	segment._art.modulate = data.segment_tint
	segment.add_child(segment._art)
	segment.set_out(false, 0)
	return segment


static func _circle_shape(radius: float) -> CollisionShape2D:
	var circle := CircleShape2D.new()
	circle.radius = radius
	var shape := CollisionShape2D.new()
	shape.shape = circle
	return shape


## Out: shown, solid and hurting (`damage`). In: hidden and harmless. Shapes change deferred because
## this is called from physics callbacks.
func set_out(out: bool, damage: int) -> void:
	if out == is_out and (out or not visible):
		return
	is_out = out
	visible = out
	hitbox.damage = damage
	for shape: CollisionShape2D in [_body_shape, _hit_shape, _hurt_shape]:
		shape.set_deferred("disabled", not out)
	if out:
		hitbox.activate()
	else:
		hitbox.deactivate()


## The piece faces the way the body runs (the art faces right).
func face(direction: Vector2) -> void:
	if absf(direction.x) > 0.1:
		_art.flip_h = direction.x < 0.0
