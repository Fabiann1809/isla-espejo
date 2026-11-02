extends SceneTree
## Baldosa hambrienta test, with real physics in a walled room: hidden it lies on the ground layer as
## a calm tile, has no body (a walker crosses it) and cannot be hurt; it does not chase a Nico who
## is near but not on it; when he steps on it it warns for an instant, bites and holds him (walking
## does nothing until the hold ends), then stays revealed (solid, hittable, crawling at most a tile)
## and finally crawls back to its spot and becomes a tile again.
## Run: godot --headless --path . --script res://tests/test_baldosa_hambrienta.gd

const ROOM := Rect2(0, 0, 400, 240)
const WALL := 16.0
const HOME := Vector2(200, 120)
const ENEMY_LAYER := 3
const GROUND_FX_Z := -1

var _ok := true
var _arena: Node2D


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_arena = Node2D.new()
	_arena.position = Vector2(30, 20)
	root.add_child(_arena)
	_add_walls()
	var player: Node2D = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(60, 120)
	_arena.add_child(player)
	player.health.set_max_health(50)
	var tile = load("res://scenes/enemies/baldosa_hambrienta.tscn").instantiate()
	tile.data = tile.data.duplicate()
	tile.home_area = Rect2(_arena.position + ROOM.position, ROOM.size)
	tile.position = HOME
	_arena.add_child(tile)
	await _frames(3)
	var home: Vector2 = tile.global_position
	var phases = tile.Phase
	var sprite: AnimatedSprite2D = tile.get_node("Sprite")

	var frames: SpriteFrames = tile.data.sprite_frames
	for anim: StringName in [&"idle", &"walk", &"attack", &"special", &"hurt", &"death"]:
		_check(frames.has_animation(anim), "the tile has %s" % anim)

	# --- Hidden: a calm tile on the ground, no body, no hurtbox
	_check(tile.phase == phases.HIDDEN and not tile.is_revealed(), "it starts hidden")
	_check(not tile.get_collision_layer_value(ENEMY_LAYER), "hidden it has no body on the enemy layer")
	_check(sprite.z_index == GROUND_FX_Z, "hidden it is drawn on the ground, under the actors")
	_check(sprite.animation == &"idle" and sprite.frame == 0 and not sprite.is_playing() and not sprite.flip_h,
			"hidden it shows its calm still tile frame")
	var hp: int = tile.health.current
	var accepted: bool = tile.get_node("Hurtbox").receive_hit(1, home + Vector2(-20, 0))
	_check(not accepted and tile.health.current == hp, "hidden it cannot be hurt")
	var walker := _walker(player.collision_mask)
	walker.global_position = home + Vector2(0, 60)
	await _frames(2)
	walker.global_position = home + Vector2(-30, 0)
	for i in 40:
		await physics_frame
		walker.velocity = Vector2(120, 0)
		walker.move_and_slide()
	_check(walker.global_position.x > home.x + 30.0, "a body walks over the hidden tile (x %.0f)" % walker.global_position.x)
	walker.queue_free()

	# --- Near but not on it: it does not chase or bite
	player.global_position = home + Vector2(-34, 0)
	await _frames(45)
	_check(tile.phase == phases.HIDDEN and tile.global_position.distance_to(home) < 0.5,
			"Nico near it: it stays a still hidden tile")

	# --- On it: a tiny tell, then the bite that holds him
	var player_hp: int = player.health.current
	player.global_position = home + Vector2(-14, 0)
	await _until(func() -> bool: return tile.phase != phases.HIDDEN, 30)
	_check(tile.phase == phases.TELL and not tile.is_revealed(), "first a tell, still hidden")
	_check(sprite.animation == &"special", "the tell glows (special)")
	await _until(func() -> bool: return tile.phase == phases.BITE, 30)
	_check(tile.phase == phases.BITE and sprite.animation == &"special", "then it opens its mouth (special)")
	await _until(func() -> bool: return player.health.current < player_hp, 20)
	_check(player.health.current < player_hp, "the bite hurts Nico (%d -> %d)" % [player_hp, player.health.current])
	_check(player.is_pulled(), "the bite holds Nico")
	var held_at: Vector2 = player.global_position
	Input.action_press("move_left")
	await _frames(12)
	_check(player.global_position.distance_to(held_at) < 1.0, "held, walking does not move him")
	await _until(func() -> bool: return not player.is_pulled(), 90)
	await _frames(12)
	_check(player.global_position.x < held_at.x - 5.0, "free again, he walks away (x %.0f -> %.0f)" % [held_at.x, player.global_position.x])
	Input.action_release("move_left")

	# --- Revealed: solid, on the actors' layer, hittable, crawling a tile at most
	_check(tile.is_revealed() and tile.get_collision_layer_value(ENEMY_LAYER), "revealed it is a body")
	_check(sprite.z_index == 0, "revealed it is drawn with the actors")
	player.global_position = home + Vector2(-70, 0)
	hp = tile.health.current
	accepted = tile.get_node("Hurtbox").receive_hit(1, home + Vector2(-20, 0))
	_check(accepted and tile.health.current == hp - 1, "revealed it can be hurt")
	var farthest := 0.0
	for i in 50:
		await physics_frame
		farthest = maxf(farthest, tile.global_position.distance_to(home))
	_check(farthest > 4.0 and farthest <= tile.data.crawl_leash + 1.0,
			"it crawls toward Nico but no more than a tile (%.1f px)" % farthest)

	# --- It crawls back and becomes a tile again
	await _until(func() -> bool: return tile.phase == phases.HIDDEN, 400)
	_check(tile.phase == phases.HIDDEN, "it closes again")
	_check(tile.global_position.distance_to(home) <= 1.0, "back on its spot (%.1f px off)" % tile.global_position.distance_to(home))
	_check(not tile.get_collision_layer_value(ENEMY_LAYER) and sprite.z_index == GROUND_FX_Z,
			"closed it has no body and lies on the ground again")
	await _frames(2)
	hp = tile.health.current
	accepted = tile.get_node("Hurtbox").receive_hit(1, home + Vector2(-20, 0))
	_check(not accepted and tile.health.current == hp, "closed it cannot be hurt")
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _walker(mask: int) -> CharacterBody2D:
	var walker := CharacterBody2D.new()
	walker.collision_layer = 0
	walker.collision_mask = mask
	walker.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(12, 12)
	shape.shape = box
	walker.add_child(shape)
	_arena.add_child(walker)
	return walker


func _add_walls() -> void:
	var walls: Array[Rect2] = [
		Rect2(-WALL, -WALL, ROOM.size.x + WALL * 2.0, WALL), Rect2(-WALL, ROOM.size.y, ROOM.size.x + WALL * 2.0, WALL),
		Rect2(-WALL, 0, WALL, ROOM.size.y), Rect2(ROOM.size.x, 0, WALL, ROOM.size.y)]
	for rect in walls:
		var wall := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		wall.add_child(shape)
		wall.position = rect.get_center()
		_arena.add_child(wall)


func _until(condition: Callable, max_frames: int) -> void:
	for i in max_frames:
		if condition.call():
			return
		await physics_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
