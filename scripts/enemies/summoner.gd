class_name Summoner
extends Enemy
## An enemy that grows minions from its body. While the player is in sight and it has room for more
## minions it spreads its arms (the warning) and they sprout around it; up close it slams like any
## melee enemy. When it dies its minions die with it. Everything tunable lives in its SummonerData.

var _summoner: SummonerData
var _minions: Array[Node2D] = []
var _summon_cooldown_left := 0.0
var _summon_requested := false
var _summoning := false


func _ready() -> void:
	super()
	_summoner = data as SummonerData
	if _summoner == null:
		push_error("Summoner '%s' needs a SummonerData." % name)
		_summoner = SummonerData.new()


func _physics_process(delta: float) -> void:
	_summon_cooldown_left = maxf(_summon_cooldown_left - delta, 0.0)
	super(delta)


func living_minions() -> int:
	var alive: Array[Node2D] = []
	for minion in _minions:
		if is_instance_valid(minion) and not (minion as Enemy).is_dead():
			alive.append(minion)
	_minions = alive
	return _minions.size()


func _process_chase(delta: float) -> void:
	if _target_is_valid() and _can_summon():
		_summon_requested = true
		_start_attack()
		return
	super(delta)


func _can_summon() -> bool:
	if _summon_cooldown_left > 0.0 or _attack_cooldown_left > 0.0 or _summoner.minion_scene == null:
		return false
	if living_minions() >= _summoner.max_minions:
		return false
	return global_position.distance_to(target.global_position) <= _summoner.summon_range and can_see(target)


func _start_attack() -> void:
	super()
	_summoning = _summon_requested
	_summon_requested = false
	if _summoning:
		_telegraph.hide()


func _process_attack(delta: float) -> void:
	if not _summoning:
		super(delta)
		return
	velocity = Vector2.ZERO
	_attack_time_left -= delta
	if _attack_time_left > 0.0:
		return
	match _attack_phase:
		AttackPhase.WINDUP:
			_spawn_minions()
			_attack_phase = AttackPhase.STRIKE
			_attack_time_left = data.attack_time
		AttackPhase.STRIKE:
			_attack_phase = AttackPhase.RECOVER
			_attack_time_left = data.attack_cooldown * 0.5
		AttackPhase.RECOVER:
			_attack_cooldown_left = data.attack_cooldown * 0.5
			_summon_cooldown_left = _summoner.summon_cooldown
			_summoning = false
			_enter_chase_or_idle()


func _spawn_minions() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var count := mini(_summoner.minions_per_summon, _summoner.max_minions - living_minions())
	var start_angle := randf() * TAU
	for i in count:
		var minion: Node2D = _summoner.minion_scene.instantiate()
		minion.position = position + Vector2.from_angle(start_angle + TAU * i / maxf(count, 1.0)) * _summoner.spawn_radius
		parent.add_child(minion)
		Placement.reset(minion)
		if parent.has_method("register_enemy"):
			parent.register_enemy(minion)
		_minions.append(minion)


func _on_died() -> void:
	for minion in _minions:
		if is_instance_valid(minion) and not (minion as Enemy).is_dead():
			(minion as Enemy).health.take_damage((minion as Enemy).health.max_health, global_position)
	super()
