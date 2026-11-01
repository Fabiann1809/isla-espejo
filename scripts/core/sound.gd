extends Node
## Sound effects and music (autoload "Sound"). Like the AI, it only listens to the Events bus: no
## gameplay code plays sounds. What each cue sounds like lives in data/audio/sound_bank.tres; this
## script only decides which cue goes with which event. Effects go to the "SFX" bus, music to "Music".

const BANK_PATH := "res://data/audio/sound_bank.tres"
## Effects playing at once; the oldest is cut when all are busy.
const VOICES := 12
## Each play changes the pitch by up to this much (1 = none), so repeats do not sound mechanical.
const PITCH_SPREAD := 0.08
## Sounds of things this far from Nico (px) are not heard; closer ones fade with the distance.
const HEARING_RANGE := 360.0
## The same cue is not played again before this many seconds (several hits in one frame).
const MIN_REPEAT := 0.05
const MUSIC_FADE := 1.2
## Nico's footsteps: one every this many seconds while he walks.
const STEP_EVERY := 0.32

var bank: SoundBank
## Music id that is playing (or fading in), empty when silent.
var current_music := StringName()
## Cues played, newest last (tests read it; trimmed to the last 64).
var played: Array[StringName] = []

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _last_played := {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
## The music player of the current track (the other one is free or fading out).
var _music_active: AudioStreamPlayer
var _music_tween: Tween
var _scenario_music := StringName()
var _boss_fight := false
var _step_left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bank = load(BANK_PATH) if ResourceLoader.exists(BANK_PATH) else SoundBank.new()
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"SFX"
		add_child(voice)
		_voices.append(voice)
	_music_a = _music_player()
	_music_b = _music_player()
	_music_active = _music_a
	_connect_events()


func _process(delta: float) -> void:
	_update_steps(delta)


# --- Public ---------------------------------------------------------------------------------------

## Plays a cue (if the bank has it). `at` = world position of the source, to fade it with the
## distance to Nico (Vector2.INF = everywhere at full volume, like the interface).
func play(cue: StringName, at := Vector2.INF, volume_db := 0.0) -> void:
	if bank == null or not bank.has_cue(cue):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(cue, -1.0)) < MIN_REPEAT:
		return
	var distance_db := _distance_db(at)
	if distance_db == -INF:
		return
	_last_played[cue] = now
	played.append(cue)
	if played.size() > 64:
		played.pop_front()
	var voice := _free_voice()
	voice.stream = bank.pick(cue)
	voice.volume_db = bank.volume_of(cue) + volume_db + distance_db
	voice.pitch_scale = randf_range(1.0 - PITCH_SPREAD, 1.0 + PITCH_SPREAD)
	voice.play()


## Cross-fades to the music `id` (a key of the bank's music). An empty id or an unknown one fades
## the music out.
func play_music(id: StringName) -> void:
	if id == current_music:
		return
	current_music = id if bank != null and bank.music.has(id) else StringName()
	# The player of the track that is heard now fades out; the other one brings the new track in.
	var outgoing := _music_active
	var incoming := _music_b if outgoing == _music_a else _music_a
	if _music_tween != null:
		_music_tween.kill()
	# A track still fading out from an earlier change stops now (its stop callback was killed).
	if incoming.playing:
		incoming.stop()
	_music_active = incoming
	_music_tween = create_tween().set_parallel(true)
	if outgoing.playing:
		_music_tween.tween_property(outgoing, "volume_db", -60.0, MUSIC_FADE)
		_music_tween.tween_callback(outgoing.stop).set_delay(MUSIC_FADE)
	if current_music != StringName():
		incoming.stream = bank.music[current_music]
		var target: float = bank.music_volumes_db.get(current_music, 0.0)
		incoming.volume_db = -40.0
		incoming.play()
		_music_tween.tween_property(incoming, "volume_db", target, MUSIC_FADE)


func stop_music() -> void:
	play_music(StringName())


# --- Events -> cues -------------------------------------------------------------------------------

func _connect_events() -> void:
	Events.player_shot.connect(func(_d: Vector2, _t: float) -> void: play(&"shot"))
	Events.player_dashed.connect(func(_d: Vector2) -> void: play(&"dash"))
	Events.arrow_blocked.connect(func(at: Vector2) -> void: play(&"arrow_wall", at))
	Events.player_damaged.connect(func(_a: int, _p: Vector2) -> void: play(&"player_hurt"))
	Events.player_died.connect(_on_player_died)
	Events.enemy_damaged.connect(_on_enemy_damaged)
	Events.enemy_killed.connect(func(enemy: Node) -> void:
		var cue := StringName("death_" + _enemy_id(enemy))
		play(cue if bank.has_cue(cue) else &"enemy_death", _where(enemy)))
	Events.enemy_attacked.connect(func(enemy: Node, kind: StringName) -> void:
		var cue := StringName("attack_" + _enemy_id(enemy))
		play(cue if bank.has_cue(cue) else StringName("attack_" + kind), _where(enemy), -4.0))
	Events.enemy_detected_player.connect(func(enemy: Node) -> void: play(&"alert", _where(enemy)))
	Events.resource_collected.connect(func(id: StringName) -> void: play(StringName("pickup_" + id)))
	Events.chest_opened.connect(func(_chest: Node) -> void: play(&"chest"))
	Events.skill_used.connect(func(id: StringName, _d: Vector2, _n: int) -> void:
		play(StringName("skill_" + id)))
	Events.dialogue_started.connect(func(_id: StringName) -> void: play(&"dialogue"))
	Events.fragment_collected.connect(func(_id: StringName) -> void: play(&"fragment"))
	Events.scenario_completed.connect(func(_id: StringName) -> void: play(&"portal"))
	Events.boss_attack_warned.connect(func(_id: StringName, _pattern: StringName) -> void: play(&"boss_warn"))
	Events.boss_attack_struck.connect(func(_id: StringName, pattern: StringName, _at: Vector2) -> void:
		play(StringName("boss_" + pattern)))
	Events.boss_health_changed.connect(_on_boss_health_changed)
	Events.boss_defeated.connect(_on_boss_defeated)
	Events.level_started.connect(_on_level_started)


func _on_enemy_damaged(enemy: Node, _amount: int) -> void:
	# The boss answers with a heavier blow so hitting it feels different.
	play(&"enemy_hurt" if enemy.get("data") is BossData else &"arrow_hit", _where(enemy))


func _on_player_died() -> void:
	play(&"player_death")
	_boss_fight = false
	stop_music()


func _on_level_started(scenario_id: StringName, _seed: int) -> void:
	_scenario_music = scenario_id
	_boss_fight = false
	play_music(scenario_id)


func _on_boss_health_changed(_id: StringName, current: int, _maximum: int, _name: String) -> void:
	# The bar appears when the fight starts: the boss theme takes over until the boss falls.
	if not _boss_fight and current > 0:
		_boss_fight = true
		play_music(&"boss")


func _on_boss_defeated(_id: StringName) -> void:
	play(&"boss_defeated")
	_boss_fight = false
	play_music(_scenario_music)


# --- Helpers --------------------------------------------------------------------------------------

func _update_steps(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null or get_tree().paused or player.velocity.length() < 20.0 \
			or not player.has_method("can_cast") or not player.can_cast():
		_step_left = 0.0
		return
	_step_left -= delta
	if _step_left <= 0.0:
		_step_left = STEP_EVERY
		play(&"step", Vector2.INF, -10.0)


## Volume change for a sound at `at`: 0 dB near Nico, softer farther, -INF out of hearing range.
func _distance_db(at: Vector2) -> float:
	if at == Vector2.INF:
		return 0.0
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return 0.0
	var distance := player.global_position.distance_to(at)
	if distance > HEARING_RANGE:
		return -INF
	return linear_to_db(1.0 - 0.7 * distance / HEARING_RANGE)


func _where(node: Node) -> Vector2:
	var body := node as Node2D
	return body.global_position if body != null and is_instance_valid(body) else Vector2.INF


func _enemy_id(enemy: Node) -> String:
	var data = enemy.get("data") if is_instance_valid(enemy) else null
	return String(data.id) if data != null else ""


func _free_voice() -> AudioStreamPlayer:
	for voice in _voices:
		if not voice.playing:
			return voice
	_next_voice = (_next_voice + 1) % _voices.size()
	return _voices[_next_voice]


func _music_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = &"Music"
	add_child(player)
	return player
