extends SceneTree
## Skill system test: unlocking, cooldowns, input, the three effects on real enemies, stealth,
## Events and the HUD bar. Do not reference `SkillManager`/`Enemy` types here (autoload compile order).
## Run: godot --headless --path . --script res://tests/test_skills.gd

## Empty corner of the test room, away from dummies, traps and the room's own grunts.
const ARENA := Vector2(300, 180)

var _ok := true
var _room: Node
var _player: Node2D
var _grunt: PackedScene
var _used: Array = []
var _unlocked: Array = []
var _stealth: Array = []


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	var events: Node = root.get_node("Events")
	events.skill_used.connect(func(id: StringName, _dir: Vector2, affected: int) -> void: _used.append([id, affected]))
	events.skill_unlocked.connect(func(id: StringName) -> void: _unlocked.append(id))
	events.player_stealth_changed.connect(func(active: bool) -> void: _stealth.append(active))

	_grunt = load("res://scenes/enemies/grunt.tscn")
	_room = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(_room)
	await _frames(5)
	_player = _room.get_node("Player")
	_player.global_position = ARENA
	_player.facing = Vector2.RIGHT
	await _frames(3)
	var mgr = _player.skills
	var bar = _room.get_node("Hud/SkillBar")

	# --- Locked skills do nothing
	_check(not mgr.is_unlocked(0) and not mgr.try_use(0), "a locked skill cannot be used")
	_check(_used.is_empty(), "no Events.skill_used for a locked skill")
	_check(not bar.slot_state(0).unlocked, "HUD shows the slot as locked")

	# --- Unlocking
	mgr.unlock(load("res://data/skills/roots.tres"))
	mgr.unlock(load("res://data/skills/current.tres"))
	mgr.unlock(load("res://data/skills/shadow.tres"))
	_check(_unlocked == [&"roots", &"current", &"shadow"], "Events.skill_unlocked emitted for each skill")
	_check(mgr.is_unlocked(0) and mgr.is_unlocked(1) and mgr.is_unlocked(2), "all three skills unlocked")
	_check(mgr.get_skill(0).id == &"roots" and mgr.get_skill(1).id == &"current" and mgr.get_skill(2).id == &"shadow",
			"each skill sits in its own slot")
	await _frames(3)
	await process_frame
	await process_frame
	_check(bar.slot_state(0).unlocked, "HUD shows the slot as unlocked")

	# --- Cooldown
	_equip(0, 0.4, {"duration": 0.1})
	_check(mgr.try_use(0), "an unlocked skill can be cast")
	_check(not mgr.try_use(0), "a skill on cooldown cannot be cast again")
	_check(mgr.cooldown_ratio(0) > 0.9, "cooldown ratio starts near 1 (%.2f)" % mgr.cooldown_ratio(0))
	await _frames(3)
	await process_frame
	await process_frame
	_check(bar.slot_state(0).cooldown_ratio > 0.5, "HUD shows the cooldown filling the slot (%.2f)" % bar.slot_state(0).cooldown_ratio)
	await _frames(35)
	_check(mgr.cooldown_ratio(0) == 0.0 and mgr.try_use(0), "skill is ready again after its cooldown")
	await _frames(3)

	# --- Input: key 2 casts Corriente and reports the event
	_equip(1, 0.0)
	_used.clear()
	await _tap("skill_2")
	_check(_used.size() == 1 and _used[0][0] == &"current", "pressing skill_2 casts Corriente (Events.skill_used)")

	# --- Raíces: roots enemies in the zone only
	_equip(0, 0.0, {"duration": 0.5})
	_player.global_position = ARENA
	var inside = _spawn(ARENA + Vector2(66, 0))
	var outside = _spawn(ARENA + Vector2(0, -100))
	await _frames(12)
	_check(inside.target == _player and outside.target == _player, "both enemies are chasing before the cast")
	_used.clear()
	var inside_start: Vector2 = inside.global_position
	var outside_start: Vector2 = outside.global_position
	await _settle()
	mgr.try_use(0)
	_check(_used.size() == 1 and _used[0][1] == 1, "Raíces reports exactly 1 enemy affected (%s)" % [_used])
	_check(inside.is_rooted() and not outside.is_rooted(), "only the enemy inside the zone is rooted")
	await _frames(30)
	_check(inside.global_position.distance_to(inside_start) < 1.5, "the rooted enemy does not move")
	_check(outside.global_position.distance_to(outside_start) > 10.0, "the enemy outside keeps chasing")
	await _frames(70)
	_check(not inside.is_rooted(), "the root ends after the zone disappears")
	inside.free()
	outside.free()

	# --- Corriente: pushes and slows enemies in front, ignores the rest
	_equip(1, 0.0, {}, 2)
	_player.global_position = ARENA
	_player.facing = Vector2.RIGHT
	var front = _spawn(ARENA + Vector2(50, 0))
	var behind = _spawn(ARENA + Vector2(-50, 0))
	var side = _spawn(ARENA + Vector2(0, 60))
	var far_front = _spawn(ARENA + Vector2(130, 0))
	await _frames(2)
	_used.clear()
	var front_start: float = front.global_position.x
	var front_health: int = front.health.current
	await _settle()
	mgr.try_use(1)
	_check(_used.size() == 1 and _used[0][1] == 1, "Corriente reports exactly 1 enemy affected (%s)" % [_used])
	_check(front.is_slowed(), "the enemy in front is slowed")
	_check(not behind.is_slowed() and not side.is_slowed() and not far_front.is_slowed(),
			"enemies behind, to the side or out of reach are not affected")
	await _frames(10)
	_check(front.global_position.x > front_start + 15.0, "the enemy in front is pushed away (%.0f px)" % (front.global_position.x - front_start))
	_check(front.health.current == front_health - 2, "skill damage goes through the enemy's hurtbox (%d -> %d)" % [front_health, front.health.current])
	for enemy in [front, behind, side, far_front]:
		enemy.free()

	# --- Sombra: teleport, wall limit, stealth, detection, hunters losing track
	_equip(2, 0.0)
	_player.global_position = ARENA
	_player.facing = Vector2.RIGHT
	await _frames(2)
	_used.clear()
	_stealth.clear()
	await _settle()
	mgr.try_use(2)
	_check(absf(_player.global_position.x - (ARENA.x + 110.0)) < 2.0, "Sombra teleports the full distance in open space (%.0f)" % _player.global_position.x)
	_check(_player.is_stealthed() and _player.visibility < 0.5, "the player becomes harder to detect (visibility %.2f)" % _player.visibility)
	_check(_stealth == [true], "Events.player_stealth_changed(true) emitted")

	var watcher = _spawn(_player.global_position + Vector2(-80, 0))
	await _frames(30)
	_check(watcher.target == null, "an enemy at 80px does not notice the hidden player (range 120 x 0.3)")
	await _tap("attack")
	_check(not _player.is_stealthed() and _player.visibility == 1.0, "attacking breaks the stealth")
	_check(_stealth == [true, false], "Events.player_stealth_changed(false) emitted")
	await _frames(20)
	_check(watcher.target == _player, "once visible again the same enemy notices the player")
	watcher.free()

	# Wall: stops before the wall instead of going through
	_player.global_position = Vector2(440, 180)
	_player.facing = Vector2.RIGHT
	await _frames(15)
	await _settle()
	mgr.try_use(2)
	_check(_player.global_position.x > 440.0 and _player.global_position.x < 480.0 - 5.0,
			"Sombra stops before the wall (x = %.1f, wall at 480)" % _player.global_position.x)
	_player.end_stealth()

	# Enemies hunting the player lose track after a teleport
	_player.global_position = ARENA
	_player.facing = Vector2.RIGHT
	await _frames(15)
	var hunter = _spawn(ARENA + Vector2(-100, 0))
	await _frames(15)
	_check(hunter.target == _player, "the hunter is chasing the player")
	_used.clear()
	await _settle()
	mgr.try_use(2)
	await _frames(10)
	_check(_used.size() == 1 and _used[0][1] == 1, "Sombra reports the hunter it escaped from (%s)" % [_used])
	_check(hunter.target == null, "the hunter loses track of the hidden player")
	hunter.free()

	# Stealth expires by itself
	_player.end_stealth()
	_equip(2, 0.0, {"stealth_time": 0.3})
	_player.global_position = ARENA
	await _frames(15)
	await _settle()
	mgr.try_use(2)
	_check(_player.is_stealthed(), "stealth is active right after the cast")
	await _frames(30)
	_check(not _player.is_stealthed() and _player.visibility == 1.0, "stealth expires after its duration")

	# --- Skills cannot be cast while attacking
	_equip(0, 0.0)
	await _frames(40)
	await _tap("attack")
	_check(_player.state == _player.State.ATTACK and not mgr.try_use(0), "skills cannot be cast during an attack")

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


## Skills cannot be cast while the player is hurt, attacking or dashing. Enemies of the previous
## section may have hit the player, so wait until the player can act again (and refill health).
func _settle() -> void:
	for i in 90:
		if _player.can_cast():
			break
		await physics_frame
	_player.health.heal(5)


## Loads a skill into its slot as a private copy with the given cooldown and optional effect
## overrides, so one test does not leak its tuning into the next.
func _equip(slot: int, cooldown: float, effect_values := {}, damage := 0) -> void:
	var paths := ["roots", "current", "shadow"]
	var skill: SkillData = load("res://data/skills/%s.tres" % paths[slot]).duplicate()
	skill.cooldown = cooldown
	skill.damage = damage
	skill.effect = skill.effect.duplicate()
	for key in effect_values:
		skill.effect.set(key, effect_values[key])
	_player.skills.unlock(skill)


func _spawn(at: Vector2) -> Node2D:
	var enemy = _grunt.instantiate()
	# Own copy of the data without random patrol, so positions only change because of the skills.
	enemy.data = enemy.data.duplicate()
	enemy.data.patrol_radius = 0.0
	enemy.position = at
	_room.add_child(enemy)
	return enemy


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _tap(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(5)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
