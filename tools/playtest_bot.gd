extends SceneTree
## Plays a whole forest run by itself (needs a window, not --headless) and reports what happened:
## time and damage per room, who hurt Nico, shots and hits, and pictures every few seconds. The bot
## walks from room to room by jumping (no pathfinding), then fights with the real input actions:
## it keeps its distance, turns to the nearest enemy, shoots and dodges when something gets close.
##   godot --path . --script res://tools/playtest_bot.gd -- <seed> <output folder> [picture every s] [rooms]

const ROOM_TIME_LIMIT := 75.0
const KEEP_DISTANCE := 90.0
const TOO_CLOSE := 55.0

var _out := "user://"
var _level: Node
var _player: Node2D
var _room_damage := 0
var _hurt_by := {}
var _kills := {}
var _shots := 0
var _hits := 0
var _dead := false
var _shot_index := 0
var _next_shot := 0.0
var _clock := 0.0
var _shot_every := 4.0
var _max_rooms := 999


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var map_seed := int(args[0]) if args.size() > 0 else 4242
	_out = args[1] if args.size() > 1 else "user://"
	_shot_every = float(args[2]) if args.size() > 2 else 4.0
	_max_rooms = int(args[3]) if args.size() > 3 else 999
	await process_frame
	# Run with a window, saving would be on: never touch the player's save or profile.
	root.get_node("SaveGame").persistence_enabled = false
	root.get_node("PlayerProfile").persistence_enabled = false
	var events := root.get_node("Events")
	events.player_damaged.connect(_on_player_damaged)
	events.enemy_killed.connect(func(enemy: Node) -> void:
		var key := _kind(enemy)
		_kills[key] = _kills.get(key, 0) + 1)
	events.player_shot.connect(func(_d: Vector2, _t: float) -> void: _shots += 1)
	events.player_hit_enemy.connect(func(_e: Node, _a: int) -> void: _hits += 1)
	events.player_died.connect(func() -> void: _dead = true)

	_level = load("res://scenes/levels/forest_level.tscn").instantiate()
	_level.seed_value = map_seed
	root.add_child(_level)
	await _wait(2.0)
	_player = _level.player
	print("BOT seed %d, map:\n%s" % [map_seed, _level.layout.to_ascii()])

	# Every room, nearest first, the boss last.
	var distances: Dictionary = _level.layout.distances_from(_level.layout.start_cell)
	var order: Array = distances.keys()
	order.erase(_level.layout.boss_cell)
	order.sort_custom(func(a, b) -> bool: return distances[a] < distances[b])
	order.append(_level.layout.boss_cell)
	var run_start := _clock
	for coord in order.slice(0, _max_rooms):
		if _dead:
			break
		await _play_room(coord)
	print("BOT run %s after %.0f s. Shots %d, hits %d (%.0f%%). Kills %s" % [
			"LOST" if _dead else "ended", _clock - run_start, _shots, _hits,
			100.0 * _hits / maxi(_shots, 1), _kills])
	print("BOT hurt by %s" % _hurt_by)
	await _wait(4.0)
	_release_all()
	quit(0)


func _play_room(coord: Vector2i) -> void:
	var room: Node2D = _level.rooms[coord]
	var type := String(RoomData.RoomType.keys()[room.data.type])
	_player.global_position = room.global_position + room.center()
	_player.snap_camera()
	_room_damage = 0
	var start := _clock
	await _wait(0.5)
	var enemies_at_start := _enemies_in(room).size()
	while _clock - start < ROOM_TIME_LIMIT and not _dead:
		var targets := _enemies_in(room)
		if targets.is_empty():
			break
		await _fight_step(targets)
	_release_all()
	var health = _player.health
	print("BOT room %s %s: %d enemies, %.1f s, damage taken %d, health %d/%d%s" % [
			coord, type, enemies_at_start, _clock - start, _room_damage, health.current,
			health.max_health, " TIMED OUT" if _clock - start >= ROOM_TIME_LIMIT else ""])
	await _wait(1.0)


func _fight_step(targets: Array) -> void:
	var dialogue := root.get_node("Dialogue")
	if dialogue.active:
		_release_all()
		Input.action_press("interact")
		await _wait(0.05)
		Input.action_release("interact")
		await _wait(0.3)
		return
	var nearest: Node2D = targets[0]
	for enemy in targets:
		if _player.global_position.distance_to(enemy.global_position) < _player.global_position.distance_to(nearest.global_position):
			nearest = enemy
	var to_enemy: Vector2 = nearest.global_position - _player.global_position
	var distance := to_enemy.length()
	var aim := to_enemy.normalized()
	if distance < TOO_CLOSE and _player._dash_cooldown_left == 0.0:
		# Face away and dodge.
		_press_direction(-aim.rotated(0.6))
		await physics_frame
		Input.action_press("dash")
		await physics_frame
		Input.action_release("dash")
	elif _player._attack_cooldown_left == 0.0:
		_press_direction(aim)
		await physics_frame
		Input.action_press("attack")
		await physics_frame
		Input.action_release("attack")
	else:
		# Keep a comfortable distance, sliding sideways so the bot does not back into a wall.
		var side := aim.orthogonal() * (1.0 if int(_clock / 2.0) % 2 == 0 else -1.0)
		var move := side
		if distance < KEEP_DISTANCE:
			move = (-aim + side).normalized()
		elif distance > KEEP_DISTANCE * 1.6:
			move = (aim + side * 0.5).normalized()
		_press_direction(move)
		await physics_frame
	_tick(0.0)


func _enemies_in(room: Node2D) -> Array:
	var rect := Rect2(room.global_position, room.pixel_size())
	var result := []
	for node in get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy != null and is_instance_valid(enemy) and not enemy.is_dead() and rect.has_point(enemy.global_position):
			result.append(enemy)
	return result


func _press_direction(direction: Vector2) -> void:
	_set_axis("move_left", "move_right", direction.x)
	_set_axis("move_up", "move_down", direction.y)


func _set_axis(negative: String, positive: String, value: float) -> void:
	if value < -0.2:
		Input.action_press(negative, minf(-value, 1.0))
		Input.action_release(positive)
	elif value > 0.2:
		Input.action_press(positive, minf(value, 1.0))
		Input.action_release(negative)
	else:
		Input.action_release(negative)
		Input.action_release(positive)


func _release_all() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "attack", "dash", "interact"]:
		Input.action_release(action)


func _on_player_damaged(amount: int, source_position: Vector2) -> void:
	_room_damage += amount
	var best := "?"
	var best_distance := INF
	for node in get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy != null and is_instance_valid(enemy):
			var d := enemy.global_position.distance_to(source_position)
			if d < best_distance:
				best_distance = d
				best = _kind(enemy)
	if best_distance > 24.0:
		best += " (projectile?)"
	_hurt_by[best] = _hurt_by.get(best, 0) + amount


func _kind(enemy: Node) -> String:
	var path := enemy.scene_file_path
	return path.get_file().get_basename() if path != "" else enemy.name


func _wait(seconds: float) -> void:
	var end := _clock + seconds
	while _clock < end:
		await physics_frame
		_tick(0.0)


## Advances the bot's clock (physics ticks at 60 Hz) and takes a picture every few seconds.
func _tick(_unused: float) -> void:
	_clock += 1.0 / Engine.physics_ticks_per_second
	if _clock >= _next_shot:
		_next_shot = _clock + _shot_every
		var image := root.get_texture().get_image()
		image.save_png("%s/bot_%03d.png" % [_out, _shot_index])
		_shot_index += 1
