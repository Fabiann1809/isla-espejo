extends CharacterBody2D
## Test target with health and knockback. Real enemies (next task) follow the same pattern.

@export var knockback_speed := 160.0
@export var knockback_decay := 600.0

var hits := 0

@onready var health: HealthComponent = $HealthComponent
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _body: ColorRect = $Body
@onready var _label: Label = $Label
@onready var _base_color := _body.color


func _ready() -> void:
	_hurtbox.hit.connect(_on_hit)
	health.died.connect(_on_died)
	health.changed.connect(func(current: int, _maximum: int) -> void: _label.text = str(current))
	_label.text = str(health.max_health)


func _physics_process(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
	move_and_slide()


func _on_hit(damage: int, from_position: Vector2) -> void:
	hits += 1
	Events.enemy_damaged.emit(self, damage)
	health.take_damage(damage, from_position)
	if health.is_dead():
		return
	velocity = (global_position - from_position).normalized() * knockback_speed
	_body.color = Color.WHITE
	create_tween().tween_property(_body, "color", _base_color, 0.12)


func _on_died() -> void:
	Events.enemy_killed.emit(self)
	queue_free()
