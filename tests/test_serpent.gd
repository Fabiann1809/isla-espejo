extends SceneTree
## Boss test (Serpiente de piedra): data and sounds, engagement, moving between zones, the charge
## (warned lane, dash along it, hurts only inside it, stops at walls), the spit (fan of orbs, more in
## phase two), super armor, phase two (charges in a row), territory and the reward (blue fragment +
## Corriente). Run: godot --headless --path . --script res://tests/test_serpent.gd
## `Boss`/`Enemy`/`StoneSerpent` types must not be referenced here (autoload compile order).

const ARENA := Vector2(0, 0)
const SCENE := "res://scenes/enemies/stone_serpent.tscn"

var _ok := true
var _room: Node
var _player: Node2D
var _messages: Array[String] = []
var _boss_bars: Array = []
var _defeated: Array = []
var _warned: Array = []
var _struck: Array = []


func _initialize() -> void:
	create_timer(150.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var events: Node = root.get_node("Events")
	events.message_requested.connect(func(text: String) -> void: _messages.append(text))
	events.boss_health_changed.connect(func(id: StringName, current: int, maximum: int, boss_name: String) -> void:
		_boss_bars.append([id, current, maximum, boss_name]))
	events.boss_defeated.connect(func(id: StringName) -> void: _defeated.append(id))
	events.boss_attack_warned.connect(func(id: StringName, pattern: StringName) -> void: _warned.append([id, pattern]))
	events.boss_attack_struck.connect(func(id: StringName, pattern: StringName, _at: Vector2) -> void: _struck.append([id, pattern]))
	root.get_node("PlayerProfile").persistence_enabled = false
	root.get_node("GameState").reset()

	_test_data()
	await _make_room()
	await _test_engagement_and_zones()
	await _test_charge()
	await _test_charge_stops_at_wall()
	await _test_spit()
	await _test_super_armor()
	await _test_phase_two_and_territory()
	await _test_defeat_and_rewards()

	root.get_node("GameState").reset()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


# --- Data -------------------------------------------------------------------------------------------

func _test_data() -> void:
	var boss: Resource = load("res://data/enemies/stone_serpent.tres")
	var guardian: Resource = load("res://data/enemies/forest_guardian.tres")
	_check(boss != null and boss.id == &"stone_serpent" and boss.display_name == "Serpiente de piedra", "the Serpiente de piedra has its data")
	_check(boss.max_health > guardian.max_health and boss.max_health <= guardian.max_health * 1.5,
			"a bit tougher than the Guardián del bosque (%d vs %d health)" % [boss.max_health, guardian.max_health])
	_check(boss.charge_windup >= 0.5 and boss.spit_windup >= 0.5 and boss.charge_chain_windup >= 0.4
			and boss.charge_windup * boss.phase_two_windup >= 0.5,
			"its warnings are long enough to react to, also in phase two")
	_check(boss.charge_damage >= 1 and boss.orb_damage >= 1 and boss.charge_width >= 20.0, "its attacks deal damage")
	_check(boss.orb_speed < 120.0, "the poison orbs are slow (%.0f px/s)" % boss.orb_speed)
	_check(boss.phase_two_extra_orbs > 0 and boss.phase_two_charges >= 2 and boss.phase_two_windup < 1.0, "phase two is harder")
	_check(boss.intro_lines.size() == 2 and boss.intro_lines[0].begins_with("Nico:") and "Las piedras recuerdan" in boss.intro_lines[1],
			"it has its two intro lines")
	_check(boss.defeat_lines.size() == 1 and "Dos fragmentos" in boss.defeat_lines[0], "and its defeat line")
	_check(boss.pickup_scene != null and boss.defeated_flag == &"ruins_boss_defeated", "it drops the fragment and sets the story flag")
	_check(boss.knockback_resistance == 1.0 and boss.projectile_scene != null and boss.sprite_frames != null, "it cannot be knocked back and has orbs and art")
	for anim in [&"idle", &"run", &"charge_windup", &"charge", &"spit_windup", &"spit", &"phase_two", &"death"]:
		_check(boss.sprite_frames.has_animation(anim) and boss.sprite_frames.get_frame_count(anim) > 0, "its art has '%s'" % anim)
	var bank = root.get_node("Sound").bank
	for cue in [&"death_stone_serpent", &"boss_charge", &"boss_spit"]:
		_check(bank.has_cue(cue), "the sound bank has '%s'" % cue)


# --- Arena setup ---------------------------------------------------------------------------------

func _make_room() -> void:
	_room = load("res://scenes/levels/test_room.tscn").instantiate()
	for extra in ["Trap1", "Trap2", "Grunt1", "Grunt2", "Dummy1", "Dummy2", "Dummy3"]:
		_room.get_node(extra).free()
	root.add_child(_room)
	await _frames(4)
	_player = _room.get_node("Player")
	_player.health.max_health = 30
	_player.global_position = ARENA + Vector2(0, 600)
	_player.health.heal(30)


func _spawn_boss(at := ARENA) -> Node2D:
	_clear_effects()
	var boss: Node2D = load(SCENE).instantiate()
	boss.position = at
	_room.add_child(boss)
	return boss


func _clear_effects() -> void:
	for child in _room.get_children():
		if child is SkillZone or child.is_in_group("attack_lanes") or _is_orb(child):
			child.free()


## The boss notices the player at once (no detection timing) without starting its first relocation.
## Called right after spawning, before any physics frame, so it has not moved on its own.
func _engage(boss: Node2D) -> void:
	boss._acquire_target(_player)
	boss._needs_zone = false


func _lanes() -> Array:
	return _room.get_children().filter(func(n: Node) -> bool: return n.is_in_group("attack_lanes"))


func _orbs() -> Array:
	return _room.get_children().filter(func(n: Node) -> bool: return _is_orb(n) and not n.is_queued_for_deletion())


func _is_orb(node: Node) -> bool:
	var script: Script = node.get_script()
	return script != null and script.resource_path.ends_with("enemy_orb.gd")


# --- Engagement and zones -----------------------------------------------------------------------------

func _test_engagement_and_zones() -> void:
	var boss := _spawn_boss()
	var max_health: int = boss.data.max_health
	_check(boss.health.max_health == max_health, "the boss starts with its data's health (%d)" % max_health)
	_messages.clear()
	await _frames(30)
	_check(boss.state == boss.State.IDLE and boss.target == null and _messages.is_empty(), "far away the boss stays quiet and idle")

	_player.global_position = ARENA + Vector2(150, 0)
	await _frames(25)
	_check(boss.target == _player, "when the player comes close the boss notices them")
	_check(_messages.size() == 2 and _messages[0].begins_with("Nico:") and _messages[1].begins_with("Serpiente:"),
			"the fight opens with the two intro lines (%s)" % [_messages])
	_check(_boss_bars.size() > 0 and _boss_bars[-1] == [&"stone_serpent", max_health, max_health, "Serpiente de piedra"], "the boss health bar is announced")

	# Before attacking it slithers to another spot, away from Nico, instead of walking at him.
	var start: Vector2 = boss.global_position
	await _frames(20)
	var zone: Vector2 = boss._zone
	_check(boss.state == boss.State.CHASE and zone.distance_to(start) >= boss.data.zone_min_move * 0.9,
			"it picks another spot of the arena (%.0f px away)" % zone.distance_to(start))
	_check(zone.distance_to(_player.global_position) >= boss.data.zone_keep_distance * 0.9, "a spot not on top of Nico")
	_check(zone.distance_to(ARENA) <= boss.data.arena_radius, "inside its arena")
	_check(boss.global_position.distance_to(start) > 10.0 and boss._sprite.animation == &"run", "and slithers there")
	var attacked := false
	for i in 180:
		if boss.state == boss.State.ATTACK:
			attacked = true
			break
		await physics_frame
	_check(attacked, "after moving it attacks")
	_player.global_position = ARENA + Vector2(0, 600)
	await _frames(3)
	boss.free()


# --- The charge -------------------------------------------------------------------------------------

func _test_charge() -> void:
	# Standing in the lane hurts.
	var boss := _spawn_boss()
	_player.global_position = ARENA + Vector2(120, 0)
	_player.health.heal(30)
	_engage(boss)
	_warned.clear()
	_struck.clear()
	boss._begin_attack(boss.Attack.CHARGE)
	await _frames(2)
	var before: int = _player.health.current
	var lanes := _lanes()
	_check(boss.state == boss.State.ATTACK and boss.step == boss.Step.WINDUP and lanes.size() == 1, "the charge is warned with a lane on the ground")
	_check(_warned == [[&"stone_serpent", &"charge"]], "the warning is published (%s)" % [_warned])
	if lanes.size() == 1:
		_check(lanes[0].z_index == RoomTheme.GROUND_FX_Z and lanes[0]._span.normalized().dot(Vector2.RIGHT) > 0.99 and lanes[0]._span.length() > 120.0,
				"the lane points at Nico, lies on the ground and reaches past him (%.0f px)" % lanes[0]._span.length())
	_check(boss._sprite.animation == &"charge_windup", "the serpent rears up while it warns")
	await _frames(30)
	_check(boss.step == boss.Step.WINDUP and boss.global_position.distance_to(ARENA) < 1.0 and _player.health.current == before,
			"no move and no damage during the warning")
	var base_offset: Vector2 = boss.data.sprite_offset
	var base_scale: Vector2 = Vector2.ONE * boss.data.sprite_scale
	_check(boss._sprite.position.x < base_offset.x and boss._sprite.scale.x > base_scale.x,
			"while it warns it pulls back and squashes, only its picture (%s)" % boss._sprite.position)
	var furthest := 0.0
	var off_lane := 0.0
	var saw_slither := false
	var ghosts := 0
	var stretched := false
	for i in 90:
		furthest = maxf(furthest, boss.global_position.x - ARENA.x)
		off_lane = maxf(off_lane, absf(boss.global_position.y - ARENA.y))
		if boss.step == boss.Step.STRIKE:
			saw_slither = saw_slither or (boss._sprite.animation == &"run" and boss._sprite.is_playing())
			stretched = stretched or boss._sprite.scale.x > base_scale.x * 1.05
		ghosts = maxi(ghosts, _room.get_children().filter(func(n: Node) -> bool:
				return n.get_child_count() == 1 and n.get_child(0) is Sprite2D and n.z_index == RoomTheme.GROUND_FX_Z).size())
		if boss.step == boss.Step.RECOVER:
			break
		await physics_frame
	_check(saw_slither and stretched, "the dash slithers fast and stretched, not one still frame")
	_check(ghosts > 0, "the dash leaves fading afterimages (%d at once)" % ghosts)
	_check(_struck.size() == 1 and _struck[0] == [&"stone_serpent", &"charge"], "the dash is published")
	_check(furthest > 150.0 and off_lane < 2.0, "it dashes along the lane (%.0f px)" % furthest)
	_check(furthest <= boss._lane_length + 1.0, "and stops at the lane's end")
	_check(_player.health.current == before - boss.data.charge_damage,
			"standing in the lane costs %d health (%d -> %d)" % [boss.data.charge_damage, before, _player.health.current])
	await _frames(30)
	_check(boss._sprite.position == base_offset and boss._sprite.scale.is_equal_approx(base_scale),
			"after the recoil its picture is back in place")
	boss.free()
	await _frames(90)

	# Stepping out of the lane during the warning avoids it.
	boss = _spawn_boss()
	_player.global_position = ARENA + Vector2(120, 0)
	_player.health.heal(30)
	_engage(boss)
	boss._begin_attack(boss.Attack.CHARGE)
	await _frames(10)
	_player.global_position = ARENA + Vector2(120, 40)
	before = _player.health.current
	var saw_dash_pose := false
	for i in 150:
		if boss.step == boss.Step.STRIKE and boss._sprite.animation == &"charge":
			saw_dash_pose = true
		if boss.step == boss.Step.RECOVER:
			break
		await physics_frame
	_check(saw_dash_pose, "it lunges while it dashes")
	_check(absf(boss.global_position.y - ARENA.y) < 2.0 and boss.global_position.x > 150.0, "the dash keeps to the warned lane, not to Nico")
	_check(_player.health.current == before, "leaving the lane avoids the charge")
	boss.free()
	await _frames(5)


func _test_charge_stops_at_wall() -> void:
	# The test room's right wall is at x = 480.
	var home := Vector2(380, 0)
	var boss := _spawn_boss(home)
	_player.global_position = Vector2(460, 0)
	_engage(boss)
	boss._begin_attack(boss.Attack.CHARGE)
	await _frames(2)
	_check(boss._lane_length < 90.0, "a lane toward a wall is cut short (%.0f px)" % boss._lane_length)
	for i in 120:
		if boss.step == boss.Step.RECOVER:
			break
		await physics_frame
	_check(boss.step == boss.Step.RECOVER and boss.global_position.x < 470.0, "the dash stops at the wall (x %.0f)" % boss.global_position.x)
	boss.free()
	await _frames(60)


# --- The spit ----------------------------------------------------------------------------------------------

func _test_spit() -> void:
	var boss := _spawn_boss()
	_player.global_position = ARENA + Vector2(0, 140)
	_player.health.heal(30)
	_engage(boss)
	_warned.clear()
	boss._begin_attack(boss.Attack.SPIT)
	await _frames(2)
	_check(boss.step == boss.Step.WINDUP and _warned == [[&"stone_serpent", &"spit"]] and _orbs().is_empty(),
			"the spit is warned first (no orbs yet)")
	_check(boss._sprite.animation == &"spit_windup", "the serpent rears with venom in its mouth")
	for i in 80:
		if boss.step != boss.Step.WINDUP:
			break
		await physics_frame
	await physics_frame
	var orbs := _orbs()
	_check(orbs.size() == boss.data.spit_count, "it spits a fan of %d orbs (%d)" % [boss.data.spit_count, orbs.size()])
	_check(boss._sprite.animation == &"spit", "with its spitting pose")
	var aimed := orbs.filter(func(orb: Node2D) -> bool: return orb._velocity.normalized().dot(Vector2.DOWN) > 0.99)
	_check(aimed.size() == 1 and is_equal_approx(aimed[0]._velocity.length(), boss.data.orb_speed), "the middle one flies slowly straight at Nico")
	_check(orbs.all(func(orb: Node2D) -> bool: return orb.scene_file_path == "res://scenes/enemies/poison_orb.tscn"), "they are green poison orbs")
	var before: int = _player.health.current
	await _frames(120)
	_check(_player.health.current == before - boss.data.orb_damage, "an orb that reaches Nico hurts him (%d -> %d)" % [before, _player.health.current])
	boss.free()
	_clear_effects()
	await _frames(60)


# --- Super armor ------------------------------------------------------------------------------------------

func _test_super_armor() -> void:
	var boss := _spawn_boss()
	_player.global_position = ARENA + Vector2(0, 600)
	await _frames(3)
	var hurtbox: Hurtbox = boss.get_node("Hurtbox")
	hurtbox.receive_hit(1, ARENA + Vector2(-20, 0))
	_check(boss.health.current == boss.health.max_health - 1 and boss.state != boss.State.HURT, "a hit hurts the boss but does not interrupt it")
	_check(boss.target == _player, "being hit makes the boss aware of the player")
	boss.apply_knockback(Vector2(300, 0))
	_check(boss.state != boss.State.HURT and boss.velocity.length() < 1.0, "the Corriente cannot push the boss")
	boss.apply_root(5.0)
	_check(not boss.is_rooted(), "Raíces cannot hold the boss")
	boss.free()
	await _frames(3)


# --- Phase two and territory ------------------------------------------------------------------------------

func _test_phase_two_and_territory() -> void:
	var boss := _spawn_boss()
	_player.global_position = ARENA + Vector2(0, 600)
	await _frames(3)
	var phases: Array = []
	root.get_node("Events").boss_phase_changed.connect(func(_id: StringName, value: int) -> void: phases.append(value))
	var line := int(floor(boss.health.max_health * boss.data.phase_two_threshold))
	boss.get_node("Hurtbox").receive_hit(boss.health.max_health - line - 1, ARENA)
	_check(boss.phase == 1, "still phase one above half health")
	boss.get_node("Hurtbox").receive_hit(1, ARENA)
	_check(boss.phase == 2 and phases == [2], "at half health the boss enters phase two")
	_check(is_equal_approx(boss._scaled(1.0), boss.data.phase_two_windup), "phase two gives the player less time to react")
	await _frames(2)
	_check(boss._sprite.animation == &"phase_two", "it opens its hood")
	boss.free()
	await _frames(3)

	# More orbs.
	boss = _spawn_boss()
	_player.global_position = ARENA + Vector2(0, 140)
	boss.phase = 2
	_engage(boss)
	boss._begin_attack(boss.Attack.SPIT)
	for i in 80:
		if boss.step != boss.Step.WINDUP:
			break
		await physics_frame
	await physics_frame
	_check(_orbs().size() == boss.data.spit_count + boss.data.phase_two_extra_orbs, "phase two spits more orbs (%d)" % _orbs().size())
	boss.free()
	_clear_effects()
	await _frames(60)

	# A second charge in a row.
	boss = _spawn_boss(Vector2(-150, 0))
	_player.global_position = Vector2(-40, 0)
	_player.health.heal(30)
	boss.phase = 2
	_engage(boss)
	_warned.clear()
	boss._begin_attack(boss.Attack.CHARGE)
	var dashes := 0
	var was_dashing := false
	for i in 240:
		if boss._dashing and not was_dashing:
			dashes += 1
			# Out of the way, so the next lane is aimed somewhere else.
			_player.global_position = boss.global_position + Vector2(0, 90)
		was_dashing = boss._dashing
		if boss.step == boss.Step.RECOVER:
			break
		await physics_frame
	_check(dashes == boss.data.phase_two_charges and _warned.size() == boss.data.phase_two_charges,
			"phase two charges %d times in a row, each one warned (%d dashes, %d warnings)" % [boss.data.phase_two_charges, dashes, _warned.size()])
	boss.free()
	await _frames(3)

	# In a room (anything with pixel_size(), like Room) its arena is the room's floor.
	var room_script := GDScript.new()
	room_script.source_code = "extends Node2D
func pixel_size() -> Vector2:
	return Vector2(480, 288)
"
	room_script.reload()
	var arena_room := Node2D.new()
	arena_room.set_script(room_script)
	arena_room.position = Vector2(3000, 0)
	root.add_child(arena_room)
	boss = load(SCENE).instantiate()
	boss.position = Vector2(240, 88)
	arena_room.add_child(boss)
	await _frames(2)
	var floor_rect := Rect2(arena_room.global_position, Vector2(480, 288)).grow(-boss.data.floor_margin)
	boss.global_position = arena_room.global_position + Vector2(470, 280)
	await _frames(2)
	_check(floor_rect.grow(0.5).has_point(boss.global_position) and boss.global_position.distance_to(floor_rect.end) < 1.0,
			"in a room it keeps to the room's floor, off its border (%s)" % boss.global_position)
	var lane: float = boss._lane_reach(boss.global_position, Vector2.LEFT)
	_check(is_equal_approx(lane, minf(boss.data.charge_length, floor_rect.size.x)), "and can charge across it from a corner (%.0f px)" % lane)
	lane = boss._lane_reach(boss.global_position, Vector2.RIGHT)
	_check(lane < 1.0, "but not out of it (%.0f px)" % lane)
	arena_room.free()

	boss = _spawn_boss()
	await _frames(3)
	boss.global_position = ARENA + Vector2(500, 0)
	await _frames(3)
	_check(boss.global_position.distance_to(ARENA) <= boss.data.arena_radius + 0.5,
			"the boss is territorial: it never leaves its arena (%.0f px from home)" % boss.global_position.distance_to(ARENA))
	boss.free()
	await _frames(3)


# --- Defeat, fragment and skill ------------------------------------------------------------------

func _test_defeat_and_rewards() -> void:
	var state: Node = root.get_node("GameState")
	state.reset()
	var boss := _spawn_boss()
	_player.global_position = ARENA + Vector2(0, 600)
	await _frames(3)
	_defeated.clear()
	_messages.clear()
	boss.get_node("Hurtbox").receive_hit(999, ARENA)
	await _frames(3)
	_check(_defeated == [&"stone_serpent"], "Events.boss_defeated is emitted")
	_check(state.has_flag(&"ruins_boss_defeated"), "the story flag is set")
	_check(boss.state == boss.State.DEAD and boss._sprite.animation == &"death", "the boss dies turning to stone")
	_check(_messages == ["Nico: Dos fragmentos. La brújula ya casi señala a casa."], "Nico says the defeat line (%s)" % [_messages])
	var pickups := get_nodes_in_group("fragments")
	_check(pickups.size() == 1 and pickups[0].global_position.distance_to(ARENA) < 2.0 and pickups[0].fragment_id == &"blue",
			"a blue fragment appears where the boss fell")

	_messages.clear()
	_player.global_position = pickups[0].global_position + Vector2(0, 20)
	await _frames(4)
	await _tap("interact")
	_check(state.has_fragment(&"blue"), "the blue fragment is recorded")
	var slot: int = load("res://data/skills/current.tres").slot
	_check(state.skills.has(&"current") and _player.skills.is_unlocked(slot) and _player.skills.get_skill(slot).id == &"current",
			"the player learns Corriente")
	_check(_messages == ["Fragmento de brújula obtenido.", "Habilidad aprendida: Corriente"], "the player is told what they got (%s)" % [_messages])
	await create_timer(2.0).timeout
	_check(not is_instance_valid(boss), "the stone body fades away")


# --- Helpers ----------------------------------------------------------------------------------------------

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
	await _frames(3)
	await process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(2)
