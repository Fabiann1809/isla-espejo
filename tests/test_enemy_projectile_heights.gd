extends SceneTree
## Temple shooters on raised floors: the acolyte's flames, the echo's shot and the monk's spread are
## born with their shooter's height_level, so their wall sensor does not end them at the muzzle
## against the shooter's own raised floor (layer 8 holds every cell of height 1 or more).
## Run: godot --headless --path . --script res://tests/test_enemy_projectile_heights.gd

const PLAN := """
#############....#############
#............................#
#............................#
#..1111111111....22222222222.#
#..1111111111....22222222222.#
#..1111111111....22222222222.#
#..1111111111....22222222222.#
...1111111111....22222222222..
...1111111111....22222222222..
...1111111111....22222222222..
...1111111111....22222222222..
#..1111111111....22222222222.#
#..1111111111....22222222222.#
#..1111111111....22222222222.#
#..1111111111....22222222222.#
#............................#
#............................#
#############....#############
"""
const SCENES := {
	"acolito": "res://scenes/enemies/acolito_brasero.tscn",
	"eco": "res://scenes/enemies/eco_espejo.tscn",
	"monje": "res://scenes/enemies/monje_sin_rostro.tscn",
}

var _ok := true
var _room: Node2D


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var theme: Resource = load("res://data/themes/temple.tres")
	TileArt.use_profile(theme.tileset)
	_room = load("res://scenes/levels/rooms/room_base.tscn").instantiate()
	_room.theme = theme
	_room.debug_label = false
	var data: Resource = load("res://scripts/world/room_data.gd").new()
	data.id = "temple_projectiles"
	var doors: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	_room.setup(data, doors)
	var shape: Node2D = load("res://scripts/world/temple_shape.gd").new()
	shape.name = "Shape"
	shape.rows = PLAN
	_room.add_child(shape)
	root.add_child(_room)
	var player: Node2D = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(240, 250)
	_room.add_child(player)
	await _frames(3)

	for level in [1, 2]:
		var at := Vector2(128, 128) if level == 1 else Vector2(352, 128)
		for key: String in SCENES:
			await _shoot(key, level, at)
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _shoot(key: String, level: int, at: Vector2) -> void:
	var enemy = load(SCENES[key]).instantiate()
	enemy.position = at
	_room.add_child(enemy)
	await _frames(2)
	_check(Heights.level_of(enemy) == level, "%s is born on level %d (%d)" % [key, level, Heights.level_of(enemy)])
	enemy.facing = Vector2.RIGHT
	if key == "eco":
		enemy._fire(Vector2.RIGHT)
	else:
		enemy._fire()
	var orbs := _orbs()
	_check(not orbs.is_empty(), "%s fires on level %d" % [key, level])
	await _frames(6)
	var alive := 0
	for orb in orbs:
		if is_instance_valid(orb) and not orb.is_queued_for_deletion():
			alive += 1
			_check(orb.height_level == level, "%s orb carries level %d (%d)" % [key, level, orb.height_level])
	_check(alive == orbs.size(), "%s: every orb survives its first frames on level %d (%d of %d)" % [key, level, alive, orbs.size()])
	for orb in _orbs():
		orb.free()
	enemy.free()


func _orbs() -> Array:
	var orbs: Array = []
	for child in _room.get_children():
		if child is EnemyOrb and not child.is_queued_for_deletion():
			orbs.append(child)
	return orbs


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		printerr("FAIL: ", message)
		_ok = false
