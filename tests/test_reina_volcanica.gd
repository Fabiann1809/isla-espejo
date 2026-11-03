extends SceneTree
## Reina volcánica test, with real physics: it is built from its own data and flies (water does not
## stop it); close to Nico it marks a lane, then lunges along it with its stinger (a Hitbox on the
## enemy_attack layer) and hurts him; while it hunts it summons crías volcánicas into its room, never
## more than its cap alive, and they burn out when it dies; the director's speed multiplier scales
## its flight.
## Run: godot --headless --path . --script res://tests/test_reina_volcanica.gd

## A room-like territory around the test.
const HOME := Rect2(-230, -140, 460, 280)
const QUEEN_AT := Vector2(0, -40)
const PLAYER_LAYER := 2
const ENEMY_ATTACK_LAYER := 5
const WATER_LAYER := 7
## Frames over which the flying speed is measured.
const SPEED_FRAMES := 20

var _ok := true
var _room: Node2D
var _player: Node2D


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_room = load("res://scenes/levels/test_room.tscn").instantiate()
	for node_name in ["Trap1", "Trap2", "Grunt1", "Grunt2", "Dummy1", "Dummy2", "Dummy3"]:
		_room.get_node(node_name).free()
	root.add_child(_room)
	await _frames(3)
	_player = _room.get_node("Player")
	_player.health.set_max_health(50)
	_player.global_position = QUEEN_AT + Vector2(0, 160)

	var queen = _spawn({"first_summon_delay": 100.0})
	await _frames(2)
	_check_data(queen)
	await _stings(queen)
	queen.queue_free()
	await _frames(2)

	await _summons()
	await _speed(1.0)
	await _speed(0.5)
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check_data(queen) -> void:
	_check(queen.data is VolcanicQueenData, "the queen uses a VolcanicQueenData")
	_check(String(queen.data.id) == queen.scene_file_path.get_file().get_basename(),
			"its id is its scene's name (%s)" % queen.data.id)
	var frames: SpriteFrames = queen.data.sprite_frames
	_check(frames != null, "it has its own art")
	if frames != null:
		for anim: StringName in [&"idle", &"walk", &"run", &"attack", &"special", &"hurt", &"death"]:
			_check(frames.has_animation(anim) and frames.get_frame_count(anim) > 0, "the queen has %s" % anim)
	var brood: PackedScene = queen.data.brood_scene
	_check(brood != null and brood.resource_path == "res://scenes/enemies/cria_volcanica.tscn",
			"it summons crías volcánicas")
	_check(queen.collision_layer == 0 and not queen.get_collision_mask_value(WATER_LAYER),
			"it flies: Nico does not bump into it and water does not stop it")
	var hitbox: Area2D = queen.get_node("AttackPivot/Hitbox")
	_check(hitbox.collision_layer == 1 << (ENEMY_ATTACK_LAYER - 1) and hitbox.collision_mask == 1 << (PLAYER_LAYER - 1),
			"its stinger is a Hitbox on the enemy_attack layer that hurts the player")


## Close to Nico it marks the lane of its lunge, then lunges along it and hurts him.
func _stings(queen) -> void:
	_player.global_position = QUEEN_AT + Vector2(40, 0)
	for i in 120:
		await physics_frame
		if queen.state == queen.State.ATTACK:
			break
	_check(queen.state == queen.State.ATTACK and not queen.is_summoning(), "close to Nico it starts a sting")
	if queen.state != queen.State.ATTACK:
		return
	var telegraph: Control = queen.get_node("AttackPivot/Telegraph")
	var hitbox: Area2D = queen.get_node("AttackPivot/Hitbox")
	var reach: float = queen.data.lunge_speed * queen.data.attack_time
	_check(telegraph.visible and telegraph.size.x >= reach, "a lane as long as the lunge warns of it (%.0f px)" % telegraph.size.x)
	_check(not hitbox.monitoring, "the stinger does not hurt while it warns")
	var start: Vector2 = queen.global_position
	var hp: int = _player.health.current
	var stung := false
	for i in 120:
		await physics_frame
		stung = stung or hitbox.monitoring
		if queen._attack_phase == queen.AttackPhase.RECOVER or queen.state != queen.State.ATTACK:
			break
	_check(stung, "it lunges with the stinger out")
	_check(queen.global_position.x - start.x > reach * 0.6,
			"the lunge carries it along the lane (%.0f px)" % (queen.global_position.x - start.x))
	_check(_player.health.current < hp, "the sting hurts Nico (%d -> %d)" % [hp, _player.health.current])
	await _frames(2)
	_check(not hitbox.monitoring and not telegraph.visible, "after the lunge the stinger and the lane are off")
	for i in 120:
		await physics_frame
		if queen.state != queen.State.ATTACK:
			break
	_check(queen.state != queen.State.ATTACK and queen._attack_cooldown_left > 0.0,
			"then it must rest before the next sting")


## While it hunts it summons pairs of crías into its room, never more than its cap alive at once;
## when it dies they burn out with it.
func _summons() -> void:
	_player.global_position = QUEEN_AT + Vector2(0, 120)
	# No stings and no flying here: only the summons.
	var queen = _spawn({"first_summon_delay": 0.3, "summon_interval": 0.6, "attack_range": 0.0, "chase_speed": 0.0})
	var saw_special := false
	for i in 240:
		await physics_frame
		saw_special = saw_special or queen.get_node("Sprite").animation == &"special"
		if queen.living_brood() > 0:
			break
	var brood: Array = _brood()
	_check(saw_special, "summoning plays special")
	_check(brood.size() == queen.data.brood_per_summon,
			"it summons %d crías at once (%d)" % [queen.data.brood_per_summon, brood.size()])
	if brood.is_empty():
		return
	var creature = brood[0]
	_check(creature.home_area == HOME, "they live in the queen's room")
	_check(String(creature.data.id) == "cria_volcanica", "they are crías volcánicas")
	var most := 0
	for i in 240:
		await physics_frame
		most = maxi(most, _brood().size())
	_check(most == queen.data.max_brood and queen.living_brood() == queen.data.max_brood,
			"it never has more than %d alive (most %d)" % [queen.data.max_brood, most])
	for each in _brood():
		each.health.take_damage(each.health.max_health, QUEEN_AT)
	for i in 120:
		await physics_frame
		if queen.living_brood() > 0:
			break
	_check(queen.living_brood() > 0, "with its crías dead it summons again")
	queen.health.take_damage(queen.health.max_health, _player.global_position)
	await _frames(2)
	_check(queen.is_dead() and _brood().is_empty(), "its crías burn out when it dies")
	await create_timer(2.0).timeout


## The director's speed multiplier scales how fast it flies after Nico.
func _speed(multiplier: float) -> void:
	_player.global_position = QUEEN_AT + Vector2(150, 0)
	var queen = _spawn({"first_summon_delay": 100.0, "attack_range": 0.0}, multiplier)
	for i in 120:
		await physics_frame
		if queen.state == queen.State.CHASE:
			break
	await _frames(3)
	var from: Vector2 = queen.global_position
	await _frames(SPEED_FRAMES)
	var speed: float = queen.global_position.distance_to(from) * Engine.physics_ticks_per_second / SPEED_FRAMES
	var expected: float = queen.data.chase_speed * multiplier
	_check(absf(speed - expected) <= expected * 0.1,
			"at %.1fx speed it flies at %.0f px/s (expected %.0f)" % [multiplier, speed, expected])
	queen.queue_free()
	await _frames(2)


func _spawn(overrides: Dictionary, multiplier := 1.0) -> Node:
	var queen = load("res://scenes/enemies/reina_volcanica.tscn").instantiate()
	queen.data = queen.data.duplicate()
	queen.data.patrol_radius = 0.0
	for key: String in overrides:
		queen.data.set(key, overrides[key])
	queen.speed_multiplier = multiplier
	queen.position = QUEEN_AT
	queen.home_area = HOME
	_room.add_child(queen)
	return queen


func _brood() -> Array:
	var brood: Array = []
	for enemy in get_nodes_in_group("enemies"):
		if String(enemy.data.id) == "cria_volcanica" and not enemy.is_dead():
			brood.append(enemy)
	return brood


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
