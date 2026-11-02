extends SceneTree
## Vasija poseída test, with real physics in a walled room: it scatters 2-3 decoy vases around itself
## (inside its room, off the door lanes, the same still frame, solid, a hit shatters one and nothing
## comes out); when Nico passes near it, it shakes (still looking like a vase), breaks and releases a
## creature that hunts and bites him; the vase leaves its room's count only when the creature dies.
## A hit on the real vase breaks it at once, and removing it takes its decoys and creature along.
## Run: godot --headless --path . --script res://tests/test_vasija_poseida.gd

const ARENA_OFFSET := Vector2(30, 20)
const ROOM := Rect2(0, 0, 400, 240)
const WALL := 16.0
const SPIRIT_SCENE := "res://scenes/enemies/espiritu_vasija.tscn"

var _ok := true
var _arena: Node2D
var _home: Rect2


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_arena = Node2D.new()
	_arena.position = ARENA_OFFSET
	root.add_child(_arena)
	_add_walls()
	_home = Rect2(ARENA_OFFSET + ROOM.position, ROOM.size)
	var player: Node2D = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(340, 200)
	_arena.add_child(player)
	player.health.set_max_health(50)

	var vase = _spawn(Vector2(110, 70))
	var died := [false]
	vase.died.connect(func() -> void: died[0] = true)
	await _frames(4)
	var phases = vase.Phase
	var sprite: AnimatedSprite2D = vase.get_node("Sprite")
	var frames: SpriteFrames = vase.data.sprite_frames
	for anim: StringName in [&"idle", &"special", &"death"]:
		_check(frames.has_animation(anim), "the vase has %s" % anim)

	# --- Decoys
	var decoys: Array = vase.decoys()
	_check(decoys.size() >= 2 and decoys.size() <= 3, "it scatters 2-3 decoy vases (%d)" % decoys.size())
	var center := _home.get_center()
	var placed_well := true
	var same_look := true
	for decoy in decoys:
		var distance: float = decoy.global_position.distance_to(vase.global_position)
		var at: Vector2 = decoy.global_position
		if distance < vase.data.decoy_min_distance - 0.5 or distance > vase.data.decoy_max_distance + 0.5 \
				or not _home.has_point(at) or absf(at.x - center.x) < 40.0 or absf(at.y - center.y) < 40.0:
			placed_well = false
		var art: AnimatedSprite2D = decoy.get_node("Sprite")
		if art.sprite_frames != frames or art.animation != sprite.animation or art.frame != sprite.frame \
				or art.is_playing() or art.position != sprite.position:
			same_look = false
	_check(placed_well, "decoys stand around it, inside its room and off the door lanes")
	_check(same_look and sprite.animation == &"idle" and not sprite.is_playing(),
			"decoys show the very same still frame as the real vase")
	_check(decoys.all(func(d: Node2D) -> bool: return d.get_collision_layer_value(1)), "decoys are solid props (world layer)")

	# A decoy blocks a moving body
	var blocker: Node2D = decoys[0]
	var walker := _walker(player.collision_mask)
	walker.global_position = blocker.global_position + Vector2(-26, 1)
	for i in 30:
		await physics_frame
		walker.velocity = Vector2(120, 0)
		walker.move_and_slide()
	_check(walker.global_position.x < blocker.global_position.x - 6.0, "a decoy blocks the way")
	walker.queue_free()

	# A hit shatters a decoy; nothing comes out
	var accepted: bool = blocker.get_node("Hurtbox").receive_hit(1, blocker.global_position + Vector2(-20, 0))
	_check(accepted and blocker.is_broken(), "a hit shatters a decoy")
	await _frames(100)
	_check(not is_instance_valid(blocker), "the shattered decoy is gone")
	_check(_spirits().is_empty() and vase.is_whole(), "nothing comes out of a decoy")

	# --- Nico passes near the real vase: shake, break, release
	var player_hp: int = player.health.current
	player.global_position = vase.global_position + Vector2(-22, 12)
	await _until(func() -> bool: return vase.phase != phases.DISGUISED, 30)
	_check(vase.phase == phases.SHAKE and vase.is_whole(), "first it shakes")
	var jitter := 0.0
	for i in 8:
		await physics_frame
		jitter = maxf(jitter, absf(sprite.position.x - vase.data.sprite_offset.x))
	_check(jitter > 0.5 and sprite.animation == &"idle", "shaking, its picture jumps but it still looks like a vase")
	await _until(func() -> bool: return vase.phase == phases.BREAK, 60)
	_check(vase.phase == phases.BREAK and sprite.animation == &"special", "then it breaks (special)")
	_check(not vase.is_in_group("enemies") and not vase.get_collision_layer_value(3), "broken, it is no longer a body or a target")
	await _until(func() -> bool: return not _spirits().is_empty(), 40)
	var spirits := _spirits()
	_check(spirits.size() == 1, "it releases a creature")
	if spirits.is_empty():
		_finish()
		return
	var spirit = spirits[0]
	_check(spirit.is_in_group("enemies") and spirit.home_area == vase.home_area, "the creature is an enemy of the same room")
	_check(spirit.health.max_health >= 2 and spirit.health.max_health <= 3, "the creature is frail (%d hp)" % spirit.health.max_health)
	await _until(func() -> bool: return player.health.current < player_hp, 300)
	_check(player.health.current < player_hp, "the creature hunts and bites Nico (%d -> %d)" % [player_hp, player.health.current])
	await _until(func() -> bool: return vase.phase == phases.RELEASED, 120)
	_check(vase.phase == phases.RELEASED and not sprite.visible, "the broken vase is gone")
	_check(not died[0] and is_instance_valid(vase), "while its creature lives the vase still counts for its room")
	spirit.health.take_damage(spirit.health.max_health, spirit.global_position + Vector2(10, 0))
	await _frames(3)
	_check(died[0], "when the creature dies the vase leaves its room's count")
	_check(not is_instance_valid(vase), "and frees itself")
	await _frames(60)

	# --- A hit on the real vase breaks it at once; removing it takes its decoys and creature along
	player.global_position = _home.position + Vector2(40, 200)
	var other = _spawn(Vector2(290, 175))
	await _frames(4)
	accepted = other.get_node("Hurtbox").receive_hit(1, other.global_position + Vector2(-20, 0))
	await _frames(2)
	_check(accepted and other.phase == other.Phase.BREAK, "a hit on the real vase breaks it at once")
	await _until(func() -> bool: return not _spirits().is_empty(), 40)
	var leftovers: Array = other.decoys() + _spirits()
	_check(not leftovers.is_empty(), "it has decoys and a creature out")
	other.queue_free()
	await _frames(3)
	_check(leftovers.all(func(n) -> bool: return not is_instance_valid(n) or n.is_queued_for_deletion()),
			"removing the vase removes its decoys and creature")
	_finish()


func _spawn(at: Vector2) -> Node2D:
	var vase = load("res://scenes/enemies/vasija_poseida.tscn").instantiate()
	vase.data = vase.data.duplicate()
	vase.home_area = _home
	vase.position = at
	_arena.add_child(vase)
	return vase


func _spirits() -> Array:
	return _arena.get_children().filter(func(n: Node) -> bool:
		return n.scene_file_path == SPIRIT_SCENE and not n.is_queued_for_deletion() and not n.is_dead())


func _walker(mask: int) -> CharacterBody2D:
	var walker := CharacterBody2D.new()
	walker.collision_layer = 0
	walker.collision_mask = mask
	walker.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(8, 8)
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


func _finish() -> void:
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


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
