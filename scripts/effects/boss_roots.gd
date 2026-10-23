class_name BossRoots
extends Node2D
## The art of one root eruption of a boss (scenes/effects/boss_roots.tscn), placed on the spot.
## Only visual: the boss keeps the warning circle and decides the damage. The boss drives it:
## warn() while the attack winds up, sprout(time_left) for the last moments of the windup, strike()
## when the hit lands and retract() when it recovers (the node frees itself afterwards).
## Each eruption picks variant A or B at random.

## The sprout lasts at most this long (or the whole windup if it is shorter).
const SPROUT_TIME := 0.5

var variant := "A"

@onready var _sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	variant = "A" if randi() % 2 == 0 else "B"
	_sprite.animation_finished.connect(_on_animation_finished)
	warn()


func warn() -> void:
	_play("aviso")


## Plays the 6 sprout frames so they end exactly `time_left` seconds from now (when the hit lands).
func sprout(time_left: float) -> void:
	var anim := StringName("brote_" + variant)
	var frames := _sprite.sprite_frames
	var length := frames.get_frame_count(anim) / frames.get_animation_speed(anim)
	_play("brote")
	_sprite.speed_scale = length / maxf(time_left, 0.05)


func strike() -> void:
	_play("pico")


func retract() -> void:
	_play("retirada")


func current_animation() -> StringName:
	return _sprite.animation


func _play(base: String) -> void:
	_sprite.speed_scale = 1.0
	_sprite.play(StringName(base + "_" + variant))


func _on_animation_finished() -> void:
	if String(_sprite.animation).begins_with("retirada"):
		queue_free()
