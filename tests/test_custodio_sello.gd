extends SceneTree
## Custodio del sello test, with real physics: once it hunts Nico it raises its seal (a ring on the
## ground warns of it), every enemy inside the ring is shielded (hits blocked) and linked to it on the
## ground, an enemy outside is not; a hit while it raises the seal cuts it short; an ally lured away
## loses its shield, and killing the guardian ends every shield it gave almost at once.
## Run: godot --headless --path . --script res://tests/test_custodio_sello.gd

## A room-like territory around the test.
const HOME := Rect2(-230, -140, 460, 280)

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
	_player.global_position = Vector2(0, 100)

	var guardian = _spawn("res://scenes/enemies/custodio_sello.tscn", Vector2.ZERO)
	var frames: SpriteFrames = guardian.data.sprite_frames
	for anim: StringName in [&"idle", &"walk", &"run", &"attack", &"special", &"hurt", &"death"]:
		_check(frames.has_animation(anim) and frames.get_frame_count(anim) > 0, "guardian has %s" % anim)
	_check(guardian.data is SealGuardianData, "the guardian uses a SealGuardianData")
	var near_a = _spawn_ally(Vector2(-50, 0))
	var near_b = _spawn_ally(Vector2(50, 10))
	var far = _spawn_ally(Vector2(200, -100))
	await _frames(2)

	# --- It raises its seal with a ring on the ground, playing `special`.
	var raised := false
	var saw_special := false
	var ringed := false
	for i in 240:
		await physics_frame
		if guardian.is_sealing():
			raised = true
			saw_special = saw_special or guardian.get_node("Sprite").animation == &"special"
			ringed = ringed or _ring_of(guardian.data.seal_radius) != null
		if not guardian.shielded_allies().is_empty():
			break
	_check(raised, "the guardian raises its seal")
	_check(saw_special, "raising the seal plays the special animation")
	_check(ringed, "a ring on the ground warns of the seal")

	# --- Allies inside the ring are shielded and linked; the one outside is not.
	var shielded: Array = guardian.shielded_allies()
	_check(near_a in shielded and near_b in shielded and not far in shielded,
			"it shields the allies inside its ring and only those (%d)" % shielded.size())
	_check(near_a.is_shielded() and near_b.is_shielded() and not far.is_shielded(), "they carry the shield")
	var links: Node2D = guardian.get_node("SealLinks")
	_check(links.z_index == RoomTheme.GROUND_FX_Z and not links.z_as_relative, "the links lie on the ground")
	var hp: int = near_a.health.current
	near_a.get_node("Hurtbox").receive_hit(1, _player.global_position)
	_check(near_a.health.current == hp, "a shielded ally takes no damage")
	var far_hp: int = far.health.current
	far.get_node("Hurtbox").receive_hit(1, _player.global_position)
	_check(far.health.current == far_hp - 1, "the ally outside the ring is hurt normally")

	# --- An ally lured away from the guardian loses its link and its shield.
	near_b.global_position = Vector2(-200, 120)
	await create_timer(guardian.data.shield_refresh + 0.15).timeout
	_check(not near_b.is_shielded() and not near_b in guardian.shielded_allies(),
			"an ally taken away from the guardian loses its shield")
	_check(near_a.is_shielded(), "the one still close keeps it")

	# --- Killing the guardian ends its shields almost at once.
	guardian.health.take_damage(guardian.health.max_health, _player.global_position)
	await create_timer(guardian.data.shield_refresh + 0.15).timeout
	_check(not near_a.is_shielded(), "killing the guardian ends the shields it gave")
	hp = near_a.health.current
	near_a.get_node("Hurtbox").receive_hit(1, _player.global_position)
	_check(near_a.health.current == hp - 1, "and hits land on its allies again")
	await _hit_cuts_the_seal()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


## A hit while it raises the seal cuts it short: no shield, the ring goes away.
func _hit_cuts_the_seal() -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await _frames(2)
	var guardian = _spawn("res://scenes/enemies/custodio_sello.tscn", Vector2.ZERO)
	var ally = _spawn_ally(Vector2(40, 0))
	for i in 240:
		await physics_frame
		if guardian.is_sealing():
			break
	_check(guardian.is_sealing(), "a second guardian starts raising its seal")
	guardian.get_node("Hurtbox").receive_hit(1, _player.global_position)
	await _frames(2)
	_check(not guardian.is_sealing() and _ring_of(guardian.data.seal_radius) == null,
			"a hit while it raises the seal cuts it short")
	await create_timer(guardian.data.seal_windup).timeout
	_check(not ally.is_shielded(), "and the ally gets no shield")


func _spawn(path: String, at: Vector2) -> Node:
	var enemy = load(path).instantiate()
	enemy.data = enemy.data.duplicate()
	enemy.data.patrol_radius = 0.0
	enemy.position = at
	enemy.home_area = HOME
	_room.add_child(enemy)
	return enemy


## A skeleton that stands still and never notices Nico, so only the guardian acts.
func _spawn_ally(at: Vector2) -> Node:
	var ally = load("res://scenes/enemies/esqueleto.tscn").instantiate()
	ally.data = ally.data.duplicate()
	ally.data.patrol_radius = 0.0
	ally.data.detection_range = 1.0
	ally.position = at
	ally.home_area = HOME
	_room.add_child(ally)
	return ally


func _ring_of(radius: float) -> Node:
	for child in _room.get_children():
		if child is SkillZone and not child.is_queued_for_deletion() and is_equal_approx(child.radius, radius):
			return child
	return null


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
