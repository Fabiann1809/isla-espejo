extends SceneTree
## Núcleo de cría test, with real physics: the core never moves; while it hunts Nico it breeds small
## tinted creatures into its room (with the `special` pulse), never more than its cap alive at once,
## and stops when its energy runs out (its art dims). Destroyed, it burns over a warning circle and
## then explodes: Nico inside the circle is hurt, outside he is not.
## Run: godot --headless --path . --script res://tests/test_nucleo_cria.gd

## A room-like territory around the test.
const HOME := Rect2(-230, -140, 460, 280)
const CORE_AT := Vector2(0, -40)

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
	_player.global_position = CORE_AT + Vector2(0, 140)

	var core = _spawn_core()
	var frames: SpriteFrames = core.data.sprite_frames
	for anim: StringName in [&"idle", &"walk", &"run", &"attack", &"special", &"hurt", &"death"]:
		_check(frames.has_animation(anim) and frames.get_frame_count(anim) > 0, "core has %s" % anim)
	_check(core.data is BroodCoreData and core.data.brood_scene != null, "the core uses a BroodCoreData with a creature")
	await _breeds(core)
	await _runs_out_of_energy(core)
	await _explodes(core, false)
	await _explodes(_spawn_core(0), true)
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _breeds(core) -> void:
	var saw_special := false
	for i in 240:
		await physics_frame
		saw_special = saw_special or core.get_node("Sprite").animation == &"special"
		if core.living_brood() > 0:
			break
	var brood: Array = _brood()
	_check(saw_special, "breeding plays the special pulse")
	_check(brood.size() == core.data.brood_per_spawn, "it breeds %d creatures at once (%d)" % [core.data.brood_per_spawn, brood.size()])
	_check(core.energy() == core.data.energy - brood.size(), "each one spends energy (%d left)" % core.energy())
	if brood.is_empty():
		return
	var creature = brood[0]
	_check(creature.modulate == core.data.brood_tint and creature.health.max_health <= 2,
			"the creatures are small, weak and tinted")
	_check(creature.home_area == HOME, "they live in the core's room")
	_check(String(creature.data.id) == creature.scene_file_path.get_file().get_basename(),
			"a creature's id is its scene's name")
	await create_timer(core.data.spawn_interval * 2.5).timeout
	_check(core.living_brood() == core.data.max_brood and _brood().size() == core.data.max_brood,
			"it never has more than %d alive (%d)" % [core.data.max_brood, _brood().size()])
	_check(core.global_position == CORE_AT, "the core never moves")


## Killing its creatures lets it breed again until its energy is spent; then it dims and stops.
func _runs_out_of_energy(core) -> void:
	for i in 12:
		for creature in _brood():
			creature.health.take_damage(creature.health.max_health, CORE_AT)
		await create_timer(core.data.spawn_interval * 0.5).timeout
		if core.energy() == 0:
			break
	_check(core.energy() == 0, "its energy runs out")
	for creature in _brood():
		creature.health.take_damage(creature.health.max_health, CORE_AT)
	await create_timer(core.data.spawn_interval * 2.0).timeout
	_check(_brood().is_empty(), "with no energy it breeds no more")
	var sprite: CanvasItem = core.get_node("Sprite")
	_check(sprite.self_modulate.is_equal_approx(core.data.spent_tint), "and its art is dimmed")


## Destroyed, it burns over a warning circle and then explodes: only Nico inside is hurt.
func _explodes(core, nico_inside: bool) -> void:
	await create_timer(1.0).timeout
	_player.global_position = CORE_AT + (Vector2(0, 30) if nico_inside else Vector2(0, core.data.explosion_radius + 40.0))
	await _frames(2)
	var hp: int = _player.health.current
	core.health.take_damage(core.health.max_health, _player.global_position)
	await _frames(2)
	_check(core.is_fusing() and not core.is_dead(), "destroyed, the core burns before it dies")
	_check(_zone_of(core.data.explosion_radius) != null, "a warning circle shows the blast")
	await create_timer(core.data.fuse_time * 0.5).timeout
	_check(_player.health.current == hp, "the blast waits for its warning")
	await create_timer(core.data.fuse_time * 0.5 + 0.3).timeout
	if nico_inside:
		_check(_player.health.current == hp - core.data.explosion_damage, "it explodes and hurts Nico inside (%d -> %d)" % [hp, _player.health.current])
	else:
		_check(_player.health.current == hp, "Nico outside the circle is not hurt")
	_check(core.is_dead(), "after the blast the core is dead")
	await create_timer(1.5).timeout
	_check(not is_instance_valid(core), "and goes away")


func _spawn_core(energy := -1) -> Node:
	var core = load("res://scenes/enemies/nucleo_cria.tscn").instantiate()
	core.data = core.data.duplicate()
	core.data.spawn_interval = 1.0
	core.data.first_spawn_delay = 0.3
	if energy >= 0:
		core.data.energy = energy
	core.position = CORE_AT
	core.home_area = HOME
	_room.add_child(core)
	return core


func _brood() -> Array:
	var brood: Array = []
	for enemy in get_nodes_in_group("enemies"):
		if String(enemy.data.id) == "cria_volcanica" and not enemy.is_dead():
			brood.append(enemy)
	return brood


func _zone_of(radius: float) -> Node:
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
