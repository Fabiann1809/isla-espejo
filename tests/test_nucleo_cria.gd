extends SceneTree
## Núcleo de cría test, with real physics: the core never moves; while it hunts Nico it breeds small
## tinted creatures into its room (with the `special` pulse), never more than its cap alive at once,
## and stops when its energy runs out (its art dims). Destroyed, it burns over a warning circle and
## then explodes: Nico inside the circle is hurt, outside he is not.
## As it is hurt it breaks in stages (more broken art, a fiercer, tinted brood with the director's
## multipliers times the stage's) and near the end lets its queen out once, over a warning ring
## (or at its blast if it is destroyed first).
## Run: godot --headless --path . --script res://tests/test_nucleo_cria.gd

## A room-like territory around the test.
const HOME := Rect2(-230, -140, 460, 280)
const CORE_AT := Vector2(0, -40)

var _ok := true
var _room: Node2D
var _player: Node2D


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
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
	_check(core.data.stages.size() == 2, "it breaks in three stages (%d after the first)" % core.data.stages.size())
	for stage in core.data.stages:
		var stage_frames: SpriteFrames = stage.sprite_frames
		_check(stage_frames != null and stage_frames != frames and stage_frames.has_animation(&"crack")
				and stage_frames.has_animation(&"death"), "each broken stage has its own art and a crack")
	if core.data.stages.size() == 2:
		_check(core.data.stages[1].sprite_frames.has_animation(&"open"), "the broken hive can open for the queen")
	# Its own data (the cores spawned here drop the queen unless a check needs her).
	var has_queen: bool = load("res://data/enemies/nucleo_cria.tres").queen_scene != null
	_check(has_queen, "the core has a queen to let out")
	await _breeds(core)
	await _runs_out_of_energy(core)
	await _explodes(core, false)
	await _explodes(_spawn_core(0), true)
	await _stages()
	if has_queen:
		await _queen_once()
		await _queen_at_blast()
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


## Hurt into each stage: its art cracks, it breeds again soon, and each stage's brood is faster and
## fiercer than the last (on top of what the director set on the core) and tinted.
func _stages() -> void:
	_player.global_position = CORE_AT + Vector2(0, 140)
	var core = _spawn_core(-1, false, 1.1)
	await _frames(3)
	var max_health: int = core.health.max_health
	_check(max_health >= 20, "the core is tougher (%d health)" % max_health)
	_check(core.stage() == 1, "it starts whole")
	var base_cooldown: float = load("res://data/enemies/cria_volcanica.tres").attack_cooldown
	var last_speed := 1.0
	var last_cooldown := base_cooldown
	for index in core.data.stages.size():
		var stage = core.data.stages[index]
		for creature in _brood():
			creature.health.take_damage(creature.health.max_health, CORE_AT)
		var energy_before: int = core.energy()
		core.health.take_damage(core.health.current - int(floor(max_health * stage.health_below)), CORE_AT)
		await _frames(2)
		var sprite: AnimatedSprite2D = core.get_node("Sprite")
		_check(core.stage() == index + 2, "hurt under %d%% it enters stage %d" % [roundi(stage.health_below * 100.0), core.stage()])
		_check(sprite.sprite_frames == stage.sprite_frames and sprite.animation == &"crack",
				"its art cracks into the stage (%s)" % sprite.animation)
		_check(core.energy() == energy_before + stage.energy_bonus, "and it gets energy back")
		var bred := false
		for i in 300:
			await physics_frame
			if not _brood().is_empty():
				bred = true
				break
		_check(bred, "the stage breeds soon")
		if not bred:
			continue
		var creature = _brood()[0]
		_check(is_equal_approx(creature.speed_multiplier, 1.1 * stage.brood_speed)
				and is_equal_approx(creature.damage_multiplier, core.damage_multiplier * stage.brood_damage),
				"its brood gets the director's multipliers times the stage's (speed %.2f)" % creature.speed_multiplier)
		_check(is_equal_approx(creature.data.attack_cooldown, base_cooldown * stage.brood_cooldown),
				"and bites more often (cooldown %.2f)" % creature.data.attack_cooldown)
		_check(creature.modulate == stage.brood_tint and creature.modulate != core.data.brood_tint, "and is tinted")
		_check(creature.speed_multiplier > last_speed and creature.data.attack_cooldown < last_cooldown,
				"each stage's brood is fiercer than the last")
		last_speed = creature.speed_multiplier
		last_cooldown = creature.data.attack_cooldown
		_check(not core.is_dead() and not core.has_released_queen(), "with no queen data there is no queen")
	for creature in _brood():
		creature.queue_free()
	core.queue_free()
	await _frames(2)


## Hurt under its queen threshold: the comb opens over a ring, then the queen comes out once (more
## hits and its death do not bring another), into the core's room.
func _queen_once() -> void:
	var core = _spawn_core(-1, true)
	core.data.queen_windup = 0.5
	await _frames(3)
	var max_health: int = core.health.max_health
	core.health.take_damage(max_health - int(floor(max_health * core.data.queen_health_below)), CORE_AT)
	await _frames(3)
	_check(core.is_hatching() and core.stage() == 3, "under its queen threshold the broken hive opens")
	_check(core.get_node("Sprite").animation == &"open", "playing open")
	_check(_zone_of(core.data.queen_ring_radius) != null, "a ring warns where the queen comes out")
	_check(_queens().is_empty(), "the queen waits for her warning")
	await create_timer(core.data.queen_windup + 0.2).timeout
	var queens := _queens()
	_check(queens.size() == 1 and core.has_released_queen(), "then the queen comes out (%d)" % queens.size())
	if queens.size() == 1:
		_check(queens[0] == core.queen() and queens[0].home_area == HOME, "into the core's room")
	core.health.take_damage(1, CORE_AT)
	await create_timer(core.data.queen_windup + 0.2).timeout
	_check(_queens().size() == 1 and not core.is_hatching(), "more hits bring no other queen")
	core.health.take_damage(core.health.current, CORE_AT)
	await create_timer(core.data.fuse_time + core.data.blast_time + 0.3).timeout
	_check(_queens().size() == 1, "nor does its death")
	await _clear_queens()


## Destroyed in one blow before its threshold: the queen still comes out, once, at its blast.
func _queen_at_blast() -> void:
	var core = _spawn_core(-1, true)
	await _frames(3)
	core.health.take_damage(core.health.max_health, CORE_AT)
	await _frames(3)
	_check(core.is_fusing() and core.stage() == 3, "destroyed whole, it burns in its broken art")
	_check(_zone_of(core.data.queen_ring_radius) != null and _queens().is_empty(),
			"her ring shows while it burns, before she comes out")
	await create_timer(core.data.fuse_time + core.data.blast_time + 0.3).timeout
	_check(_queens().size() == 1, "she comes out at its blast (%d)" % _queens().size())
	await _clear_queens()


func _queens() -> Array:
	var queens: Array = []
	for enemy in get_nodes_in_group("enemies"):
		if String(enemy.data.id) == "reina_volcanica" and not enemy.is_dead():
			queens.append(enemy)
	return queens


func _clear_queens() -> void:
	for enemy in get_nodes_in_group("enemies"):
		if String(enemy.data.id) == "reina_volcanica":
			enemy.queue_free()
	await _frames(2)


## `with_queen` false keeps the old checks free of a queen; `speed` stands for the director's
## multiplier on the core.
func _spawn_core(energy := -1, with_queen := false, speed := 1.0) -> Node:
	var core = load("res://scenes/enemies/nucleo_cria.tscn").instantiate()
	core.data = core.data.duplicate()
	core.data.spawn_interval = 1.0
	core.data.first_spawn_delay = 0.3
	if energy >= 0:
		core.data.energy = energy
	if not with_queen:
		core.data.queen_scene = null
	core.speed_multiplier = speed
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
