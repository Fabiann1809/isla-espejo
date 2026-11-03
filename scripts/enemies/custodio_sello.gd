class_name SealGuardian
extends Enemy
## Custodio del sello: a slow, weak support. While it hunts Nico it keeps close to its allies and,
## every so often, raises its seal (a ring on the ground warns of it): every other enemy inside the
## ring is shielded (Enemy.apply_shield, hits blocked) for a while, and a link on the ground shows who.
## The shields are renewed in short pieces while the guardian lives and the ally stays close, so
## killing it (or luring the ally away) ends them almost at once: it is the one to defeat first.
## Up close it only has a weak swing. Everything tunable lives in its SealGuardianData.
## Each shielded ally carries a golden dome (`dome_art`) that rises, holds and fades with its shield.

## Layout of `dome_art`: frames that raise the dome, that loop while it holds, that let it go.
const DOME_RISE := 3
const DOME_HOLD := 4
const DOME_FADE := 2
const DOME_FPS := 10.0
## The dome's base sits this far under the middle of its cell; an enemy's feet are about 6 px
## under its origin, so the base goes there.
const DOME_BASE_BELOW_CENTER := 16.0
const ENEMY_FEET_Y := 6.0

var _guardian: SealGuardianData
var _sealing := false
var _seal_cooldown_left := 0.0
## Allies under its seal -> seconds of shield left.
var _shielded := {}
var _seal_ring: SkillZone
var _links: Node2D
## Ally -> its dome: {sprite, age, fade} (`fade` < 0 while the shield holds).
var _domes := {}


func _ready() -> void:
	super()
	_guardian = data as SealGuardianData
	if _guardian == null:
		push_error("SealGuardian '%s' needs a SealGuardianData." % name)
		_guardian = SealGuardianData.new()
	_links = Node2D.new()
	_links.name = "SealLinks"
	_links.z_as_relative = false
	_links.z_index = RoomTheme.GROUND_FX_Z
	_links.draw.connect(_draw_links)
	add_child(_links)


func _physics_process(delta: float) -> void:
	_seal_cooldown_left = maxf(_seal_cooldown_left - delta, 0.0)
	super(delta)
	# A hit, a push or a lost target cuts the raising short.
	if _sealing and state != State.ATTACK:
		_cancel_seal()
	_keep_shields(delta)
	_update_domes(delta)
	_links.queue_redraw()


## Allies it is shielding right now (tests read it).
func shielded_allies() -> Array[Enemy]:
	var allies: Array[Enemy] = []
	for ally: Variant in _shielded:
		if is_instance_valid(ally):
			allies.append(ally as Enemy)
	return allies


func is_sealing() -> bool:
	return _sealing


func _process_chase(delta: float) -> void:
	if not _target_is_valid():
		return
	var to_target := target.global_position - global_position
	if to_target.length() <= data.attack_range or _allies_within(INF).is_empty():
		super(delta)
		return
	if _seal_cooldown_left == 0.0 and _attack_cooldown_left == 0.0 \
			and not _allies_within(_guardian.seal_radius).is_empty():
		_start_seal()
		return
	var ally := _nearest_ally()
	var to_ally := ally.global_position - global_position
	facing = to_target.normalized()
	if to_ally.length() > _guardian.seal_radius * _guardian.ally_keep_fraction:
		velocity = to_ally.normalized() * data.chase_speed * _speed_scale()
	else:
		velocity = Vector2.ZERO


func _start_seal() -> void:
	state = State.ATTACK
	velocity = Vector2.ZERO
	_sealing = true
	_attack_phase = AttackPhase.WINDUP
	_attack_time_left = _guardian.seal_windup
	var room := get_parent()
	if room != null:
		var center := (room as Node2D).to_local(global_position) if room is Node2D else global_position
		_seal_ring = SkillZone.circle(center, _guardian.seal_radius, _guardian.seal_color, _guardian.seal_windup)
		room.add_child(_seal_ring)


func _process_attack(delta: float) -> void:
	if not _sealing:
		super(delta)
		return
	velocity = Vector2.ZERO
	_attack_time_left -= delta
	if _attack_time_left > 0.0:
		return
	match _attack_phase:
		AttackPhase.WINDUP:
			_raise_seal()
			_attack_phase = AttackPhase.RECOVER
			_attack_time_left = _guardian.seal_recover
		_:
			_sealing = false
			_seal_cooldown_left = _guardian.seal_cooldown
			_attack_cooldown_left = data.attack_cooldown * 0.5
			_enter_chase_or_idle()


func _raise_seal() -> void:
	_seal_ring = null
	Events.enemy_attacked.emit(self, &"summon")
	for ally in _allies_within(_guardian.seal_radius):
		_shielded[ally] = _guardian.shield_time
		ally.apply_shield(_guardian.shield_refresh)


func _cancel_seal() -> void:
	_sealing = false
	_seal_cooldown_left = _guardian.seal_cooldown * 0.5
	if _seal_ring != null and is_instance_valid(_seal_ring):
		_seal_ring.queue_free()
	_seal_ring = null


## Renews each ally's shield while the guardian lives, the ally is alive and close enough, and its
## time has not run out; anything else drops the link and lets the last piece fade.
func _keep_shields(delta: float) -> void:
	for ally: Variant in _shielded.keys():
		var left: float = _shielded[ally] - delta
		var keep: bool = state != State.DEAD and left > 0.0 and is_instance_valid(ally) \
				and not (ally as Enemy).is_dead() \
				and global_position.distance_to((ally as Enemy).global_position) <= _guardian.link_range
		if keep:
			_shielded[ally] = left
			(ally as Enemy).apply_shield(minf(_guardian.shield_refresh, left))
		else:
			_shielded.erase(ally)


## Lays a dome over each newly shielded ally, plays it, and lets it fade when its shield goes.
func _update_domes(delta: float) -> void:
	if _guardian.dome_art == null:
		return
	for ally: Variant in _shielded:
		if not _domes.has(ally) and is_instance_valid(ally):
			_domes[ally] = {"sprite": _make_dome(ally as Node2D), "age": 0.0, "fade": -1.0}
	for ally: Variant in _domes.keys():
		var dome: Dictionary = _domes[ally]
		# Checked untyped first: an ally freed with its dome leaves freed instances, which a typed
		# variable refuses.
		if not is_instance_valid(ally) or not is_instance_valid(dome["sprite"]):
			_domes.erase(ally)
			continue
		var sprite: Sprite2D = dome["sprite"]
		dome["age"] += delta
		if dome["fade"] < 0.0 and not _shielded.has(ally):
			dome["fade"] = 0.0
		if dome["fade"] >= 0.0:
			dome["fade"] += delta
			if dome["fade"] >= DOME_FADE / DOME_FPS:
				sprite.queue_free()
				_domes.erase(ally)
				continue
			sprite.frame = DOME_RISE + DOME_HOLD + mini(int(dome["fade"] * DOME_FPS), DOME_FADE - 1)
		elif dome["age"] < DOME_RISE / DOME_FPS:
			sprite.frame = int(dome["age"] * DOME_FPS)
		else:
			sprite.frame = DOME_RISE + int((dome["age"] - DOME_RISE / DOME_FPS) * DOME_FPS) % DOME_HOLD


## The dome is a child of the ally so it follows it and sorts with it, drawn over its sprite.
func _make_dome(ally: Node2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "SealDome"
	sprite.texture = _guardian.dome_art
	sprite.hframes = DOME_RISE + DOME_HOLD + DOME_FADE
	sprite.position = Vector2(0.0, ENEMY_FEET_Y - DOME_BASE_BELOW_CENTER)
	ally.add_child(sprite)
	return sprite


func _exit_tree() -> void:
	# Its domes live on its allies: they go with it.
	for ally: Variant in _domes:
		var sprite: Variant = _domes[ally]["sprite"]
		if is_instance_valid(sprite):
			(sprite as Node).queue_free()
	_domes.clear()


func _allies_within(radius: float) -> Array[Enemy]:
	var allies: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var ally := node as Enemy
		if ally == null or ally == self or ally.is_dead() or ally.is_queued_for_deletion():
			continue
		if global_position.distance_to(ally.global_position) <= radius:
			allies.append(ally)
	return allies


func _nearest_ally() -> Enemy:
	var best: Enemy = null
	for ally in _allies_within(INF):
		if best == null or global_position.distance_squared_to(ally.global_position) \
				< global_position.distance_squared_to(best.global_position):
			best = ally
	return best


func _draw_links() -> void:
	var color := _guardian.seal_color
	color.a = _guardian.link_alpha
	for ally: Variant in _shielded:
		if not is_instance_valid(ally):
			continue
		var at := _links.to_local((ally as Node2D).global_position)
		_links.draw_line(Vector2.ZERO, at, color, _guardian.link_width)
		_links.draw_arc(at, _guardian.ally_ring_radius, 0.0, TAU, 20, color, 1.0)


func _on_died() -> void:
	_cancel_seal()
	_shielded.clear()
	_links.queue_redraw()
	super()


## Raising the seal plays `special` over the windup; the swing keeps `attack`.
func _update_animation() -> void:
	if _sprite == null or state != State.ATTACK or not _sealing:
		super()
		return
	if absf(facing.x) > 0.1:
		_sprite.flip_h = facing.x < 0.0
	if _sprite.animation != &"special":
		_sprite.play(&"special")
		_anim_held = 0.0
		var span := _guardian.seal_windup + _guardian.seal_recover
		_sprite.speed_scale = _animation_length(&"special") / maxf(span, 0.05)
