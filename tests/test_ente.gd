extends SceneTree
## Ente del bosque test (the forest's mini boss): its art and data load, it grows Brotes while the
## player is in sight (never more than its limit), its minions hunt the player and die with it, and
## its slam still hurts up close. The Brote itself is generic melee.
## Run: godot --headless --path . --script res://tests/test_ente.gd

const ARENA := Vector2(300, 180)

var _ok := true
var _room: Node
var _player: Node2D


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	_room = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(_room)
	await _frames(3)
	_player = _room.get_node("Player")
	_player.global_position = ARENA

	var ente = _spawn("ente", ARENA + Vector2(120, 0))
	var frames: SpriteFrames = ente.data.sprite_frames
	for anim: StringName in [&"idle", &"walk", &"run", &"attack", &"hurt", &"death"]:
		_check(frames.has_animation(anim) and frames.get_frame_count(anim) > 0, "ente has %s" % anim)
	_check(frames.get_frame_count(&"attack") == 7, "ente attack has the 7-frame arm-spread")
	_check(ente.data is SummonerData and ente.data.minion_scene != null, "the Ente uses a SummonerData with a minion")
	var brote_frames: SpriteFrames = load("res://data/enemies/brote_frames.tres")
	for anim: StringName in [&"idle", &"walk", &"run", &"attack", &"hurt", &"death"]:
		_check(brote_frames.has_animation(anim), "brote has %s" % anim)

	# It grows minions while the player is in sight, never past its limit.
	var most := 0
	var first_seen := -1
	for i in 900:
		await physics_frame
		_player.health.heal(5)
		var alive: int = ente.living_minions()
		most = maxi(most, alive)
		if alive > 0 and first_seen < 0:
			first_seen = i
	_check(first_seen >= 0 and first_seen < 240, "it grows its first minions soon (frame %d)" % first_seen)
	_check(most >= 2 and most <= ente.data.max_minions, "it keeps up to %d minions alive, never more (most: %d)" % [ente.data.max_minions, most])
	var minions := _minions()
	_check(not minions.is_empty() and minions.all(func(m: Node) -> bool: return m.target == _player), "the minions hunt the player")
	_check(minions.size() == ente.living_minions(), "the room's count matches the Ente's minions")

	# Its minions die with it.
	ente.health.take_damage(ente.health.max_health, ente.global_position)
	await _frames(4)
	_check(_minions().all(func(m: Node) -> bool: return m.is_dead()), "its minions die when the Ente dies")
	_check(ente.is_dead() and _room.get_children().filter(func(n: Node) -> bool:
			return n.is_in_group("enemies") and n.data.id in [&"ente", &"brote"] and not n.is_dead()).is_empty(),
			"neither the Ente nor any Brote is left alive")
	await _frames(40)

	# Without minions to grow, it still slams a player who stays next to it.
	_player.global_position = ARENA
	var slammer = _spawn("ente", ARENA + Vector2(24, 0))
	slammer.data.minion_scene = null
	var before: int = _player.health.current
	await _frames(240)
	_check(_player.health.current < before, "the slam hurts a player in reach (%d -> %d)" % [before, _player.health.current])
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _minions() -> Array:
	return _room.get_children().filter(func(n: Node) -> bool: return n.is_in_group("enemies") and n.data.id == &"brote")


func _spawn(id: String, at: Vector2) -> Node:
	var enemy = load("res://scenes/enemies/%s.tscn" % id).instantiate()
	enemy.data = enemy.data.duplicate()
	_room.add_child(enemy)
	enemy.global_position = at
	return enemy


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
