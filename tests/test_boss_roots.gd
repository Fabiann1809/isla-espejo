extends SceneTree
## Roots art of the forest boss: one piece per eruption over its warning circle, aviso -> brote
## (ending right when the hit lands) -> pico -> retirada -> freed; phase two extra roots; cleanup
## when the boss dies mid-attack; bosses without roots art spawn none. Damage stays the circle's.
## Run: godot --headless --path . --script res://tests/test_boss_roots.gd

const ARENA := Vector2(300, 180)
const ROOTS_SCRIPT := "res://scripts/effects/boss_roots.gd"

var _ok := true
var _room: Node
var _player: Node2D


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	root.get_node("PlayerProfile").persistence_enabled = false
	root.get_node("GameState").reset()
	_check(ResourceLoader.exists("res://data/enemies/boss_roots_frames.tres"), "the roots SpriteFrames exists")
	var frames: SpriteFrames = load("res://data/enemies/boss_roots_frames.tres")
	var anims_ok := true
	for anim in ["aviso", "brote", "pico", "retirada"]:
		for variant in ["A", "B"]:
			var name := StringName("%s_%s" % [anim, variant])
			anims_ok = anims_ok and frames.has_animation(name)
	_check(anims_ok and frames.get_frame_count(&"brote_A") == 6 and frames.get_animation_loop(&"aviso_A")
			and not frames.get_animation_loop(&"retirada_B"), "it has the 8 animations (aviso/brote/pico/retirada x A/B)")

	_room = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(_room)
	await _frames(4)
	_player = _room.get_node("Player")
	_player.health.max_health = 999
	_player.health.heal(999)

	await _test_sequence()
	await _test_phase_two()
	await _test_death_mid_attack()
	await _test_boss_without_art()
	await _test_player_drawn_over_roots()

	root.get_node("GameState").reset()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _test_sequence() -> void:
	var boss := await _roots_attack("forest_guardian")
	var art := _arts()
	_check(art.size() == boss._roots_spots.size() and art.size() == boss._boss.roots_count,
			"one piece of art per eruption (%d)" % art.size())
	var placed := true
	for i in art.size():
		placed = placed and art[i].position == boss._roots_spots[i] and art[i].get_node("Sprite").offset == Vector2(0, -12)
	_check(placed, "each piece sits on its spot with the (0, -12) offset")
	_check(_all_playing(art, "aviso"), "while the attack winds up the roots warn (aviso)")
	_check(_circles() >= art.size(), "the real warning circles are still there under the art")
	var art_index: int = art[0].get_index()
	var circles_below := true
	for child in _room.get_children():
		if child is SkillZone and child.get_index() > art_index:
			circles_below = false
	_check(circles_below, "the art is drawn over the circles")

	var windup_left: float = boss._step_left
	var sprout_seen := false
	var sprout_ended_on_time := false
	var last_frame := -1
	while boss.step == boss.Step.WINDUP:
		await physics_frame
		if _all_playing(art, "brote"):
			if not sprout_seen:
				print("  sprout started with %.2f s of windup left" % boss._step_left)
			sprout_seen = true
			last_frame = art[0].get_node("Sprite").frame
	_check(windup_left > 0.5 and sprout_seen, "in the last 0.5 s of the windup the roots sprout (brote)")
	_check(last_frame >= 4, "the sprout reaches its last frames right when the hit lands (frame %d of 0-5)" % last_frame)
	_check(_all_playing(art, "pico"), "when the hit lands the roots show their peak (pico)")
	var on_top := true
	for child in _room.get_children():
		if child is SkillZone:
			for piece in art:
				on_top = on_top and child.get_index() < piece.get_index()
	_check(on_top, "the hit flash circles stay under the art")
	while boss.step == boss.Step.STRIKE:
		await physics_frame
	_check(_all_playing(art, "retirada"), "when the boss recovers the roots retract (retirada)")
	await _frames(40)
	_check(_arts().is_empty(), "after retracting the art frees itself")
	boss.free()


func _test_phase_two() -> void:
	var boss := await _roots_attack("forest_guardian", 2)
	var expected: int = boss._boss.roots_count + boss._boss.phase_two_extra_roots
	_check(_arts().size() == expected, "in phase two the extra eruptions get their art too (%d)" % expected)
	boss.free()
	await _frames(2)
	_check(_all_playing(_arts(), "retirada"), "a boss removed mid-attack (not killed) also retracts its roots")
	await _frames(40)
	_check(_arts().is_empty(), "and they free themselves")


func _test_death_mid_attack() -> void:
	var boss := await _roots_attack("forest_guardian")
	_check(not _arts().is_empty(), "a roots attack is under way")
	boss.health.take_damage(9999, ARENA)
	await _frames(3)
	_check(_all_playing(_arts(), "retirada"), "if the boss dies mid-attack the roots retract")
	await _frames(40)
	_check(_arts().is_empty(), "and nothing is left hanging")
	for child in _room.get_children():
		if child != _player and child.get_script() == null and child is Area2D:
			child.free()  # the fragment it dropped


func _test_boss_without_art() -> void:
	var boss := await _roots_attack("ancient_guardian")
	_check(boss.pattern == boss.Pattern.ROOTS and _circles() > 0 and _arts().is_empty(),
			"a boss without roots art keeps only its circles")
	boss.free()


## In a real level the player is a child of the Level, after the whole map: roots (children of a
## room) can never be drawn over Nico.
func _test_player_drawn_over_roots() -> void:
	var level = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.seed_value = 4242
	level.use_director = false
	root.add_child(level)
	await _frames(3)
	var map: Node = level.get_node("Map")
	_check(level.player.get_parent() == level and level.player.get_index() > map.get_index()
			and level.player.z_index >= 0, "in a level Nico is drawn after every room, so roots never cover him")
	level.free()


## Spawns a boss, makes it engage and start a roots attack (as if its last attack was a slam and
## the player stands out of slam range).
func _roots_attack(scene: String, phase := 1) -> Node2D:
	for child in _room.get_children():
		if child is SkillZone:
			child.free()
	var boss: Node2D = load("res://scenes/enemies/%s.tscn" % scene).instantiate()
	boss.position = ARENA
	_room.add_child(boss)
	if phase == 2:
		boss._enter_phase_two()
	_player.global_position = ARENA + Vector2(100, 0)
	for i in 120:
		await physics_frame
		boss._last_pattern = boss.Pattern.SLAM
		if boss.state == boss.State.ATTACK:
			break
	_check(boss.state == boss.State.ATTACK and boss.pattern == boss.Pattern.ROOTS, "%s starts a roots attack" % scene)
	await physics_frame
	return boss


func _arts() -> Array:
	var found := []
	for child in _room.get_children():
		var script: Script = child.get_script()
		if script != null and script.resource_path == ROOTS_SCRIPT and not child.is_queued_for_deletion():
			found.append(child)
	return found


func _circles() -> int:
	var count := 0
	for child in _room.get_children():
		if child is SkillZone:
			count += 1
	return count


func _all_playing(art: Array, base: String) -> bool:
	if art.is_empty():
		return false
	for piece in art:
		if not String(piece.get_node("Sprite").animation).begins_with(base + "_"):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
