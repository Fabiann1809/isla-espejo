class_name RunStats
extends RefCounted
## Raw counters of one run (one attempt at a scenario). Pure data: no nodes, no Events, no clock.
## Time only advances through `advance()`, which keeps simulations and tests deterministic.

var play_time := 0.0
var melee_attacks := 0
var melee_hits := 0
var dashes := 0
var kills := 0
var detections := 0
var damage_taken := 0
## Skill id -> times used.
var skill_uses := {}
var aggressive_skill_uses := 0
var stealth_skill_uses := 0
var stealth_time := 0.0

var rooms_visited := 0
## Rooms that had living enemies when the player entered.
var rooms_with_enemies := 0
## Enemy rooms where the player killed at least one enemy.
var rooms_fought := 0
## Enemy rooms the player crossed without killing anything.
var rooms_evaded := 0
var rooms_cleared := 0
var room_time_total := 0.0

var _config: ProfileConfig
var _stealth_active := false
var _in_room := false
var _room_enemies_at_entry := 0
var _room_kills := 0
var _room_cleared := false


func _init(config: ProfileConfig = null) -> void:
	_config = config if config != null else ProfileConfig.new()


func advance(delta: float) -> void:
	play_time += delta
	if _stealth_active:
		stealth_time += delta
	if _in_room:
		room_time_total += delta


func on_attack() -> void:
	melee_attacks += 1


func on_hit() -> void:
	melee_hits += 1


func on_dash() -> void:
	dashes += 1


func on_damage(amount: int) -> void:
	damage_taken += amount


func on_detected() -> void:
	detections += 1


func on_stealth(active: bool) -> void:
	_stealth_active = active


func on_kill() -> void:
	kills += 1
	if _in_room:
		_room_kills += 1


func on_skill(skill_id: StringName) -> void:
	skill_uses[skill_id] = skill_uses.get(skill_id, 0) + 1
	match _config.skill_styles.get(skill_id, &""):
		&"aggressive":
			aggressive_skill_uses += 1
		&"stealth":
			stealth_skill_uses += 1


func on_room_entered(enemies_alive: int) -> void:
	if _in_room:
		on_room_exited()
	_in_room = true
	_room_enemies_at_entry = enemies_alive
	_room_kills = 0
	_room_cleared = false


func on_room_cleared() -> void:
	if _in_room and not _room_cleared:
		_room_cleared = true
		rooms_cleared += 1


func on_room_exited() -> void:
	if not _in_room:
		return
	_in_room = false
	rooms_visited += 1
	if _room_enemies_at_entry > 0:
		rooms_with_enemies += 1
		if _room_kills > 0 or _room_cleared:
			rooms_fought += 1
		else:
			rooms_evaded += 1


## Closes the room the player is still in (call when the run ends).
func finalize() -> void:
	on_room_exited()
	_stealth_active = false


func total_skill_uses() -> int:
	var total := 0
	for count in skill_uses.values():
		total += count
	return total


func minutes() -> float:
	return maxf(play_time / 60.0, 0.001)


func attacks_per_minute() -> float:
	return melee_attacks / minutes()


func stealth_fraction() -> float:
	return stealth_time / maxf(play_time, 0.001)


func average_room_seconds() -> float:
	return room_time_total / maxf(rooms_visited, 1)


func to_dict() -> Dictionary:
	return {
		"play_seconds": snappedf(play_time, 0.1),
		"melee_attacks": melee_attacks,
		"melee_hits": melee_hits,
		"dashes": dashes,
		"kills": kills,
		"detections": detections,
		"damage_taken": damage_taken,
		"skill_uses": total_skill_uses(),
		"stealth_seconds": snappedf(stealth_time, 0.1),
		"rooms_visited": rooms_visited,
		"rooms_with_enemies": rooms_with_enemies,
		"rooms_fought": rooms_fought,
		"rooms_evaded": rooms_evaded,
		"rooms_cleared": rooms_cleared,
		"average_room_seconds": snappedf(average_room_seconds(), 0.1),
	}
