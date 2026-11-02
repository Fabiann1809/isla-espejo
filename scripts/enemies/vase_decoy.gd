class_name VaseDecoy
extends StaticBody2D
## A harmless temple vase scattered by a Vasija poseída around itself so the real one hides among
## them. It shows the same still frame as the real vase and blocks like a prop (world layer); a hit
## (its Hurtbox is on the enemy layer, so Nico's attacks reach it) shatters it and it is gone.

var _frames: SpriteFrames
var _offset := Vector2.ZERO
var _art_scale := 1.0
var _broken := false

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _shape: CollisionShape2D = $CollisionShape2D


## Takes the real vase's picture (call before adding it to the tree).
func dress(frames: SpriteFrames, offset: Vector2, art_scale: float) -> void:
	_frames = frames
	_offset = offset
	_art_scale = art_scale


func _ready() -> void:
	if _frames != null:
		_sprite.sprite_frames = _frames
		_sprite.position = _offset
		_sprite.scale = Vector2.ONE * _art_scale
	_sprite.play(&"idle")
	_sprite.pause()
	_sprite.frame = 0
	_hurtbox.hit.connect(func(_damage: int, _from: Vector2) -> void: shatter())


func is_broken() -> bool:
	return _broken


## Breaks into shards (the vase's death animation), stops blocking and goes away.
func shatter() -> void:
	if _broken:
		return
	_broken = true
	_shape.set_deferred("disabled", true)
	_hurtbox.get_node("CollisionShape2D").set_deferred("disabled", true)
	var fade_delay := 0.0
	if _sprite.sprite_frames.has_animation(&"death"):
		_sprite.play(&"death")
		fade_delay = _sprite.sprite_frames.get_frame_count(&"death") / _sprite.sprite_frames.get_animation_speed(&"death")
	var tween := create_tween()
	tween.tween_interval(fade_delay)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
