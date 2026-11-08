class_name LavaSurgeLogic
extends RefCounted
## The rules of a lava surge, with no nodes: a state machine that LavaSurge drives with the time and
## the kills and that answers with events. Sequence: WARNING -> RISING (stage 1) -> FIGHT; with two
## stages, enough kills warn again and the lava rises to stage 2; enough kills in the final stage make
## it RECEDE one level at a time until DONE. Waves are requested every `Tuning.TEMPLE_SURGE_WAVE_INTERVAL`
## while it fights and the kills are short of the target. Deaths by lava are never reported here.
##
## Events returned by `step`: &"warn", &"rise", &"risen", &"spawn_wave", &"recede", &"receded".

enum State { IDLE, WARNING, RISING, FIGHT, RECEDING, DONE }

var state := State.IDLE
## Levels flooded (or being flooded): 0 to 2.
var stage := 0
## Kills of the current fight (reset when the second stage is announced).
var kills := 0

var _stages: int
var _kills_stage_1: int
var _kills_to_recede: int
var _timer := 0.0
var _wave_timer := 0.0
var _pending: Array[StringName] = []


func _init(stages: int, kills_stage_1: int, kills_to_recede: int) -> void:
	_stages = clampi(stages, 1, 2)
	_kills_stage_1 = kills_stage_1
	_kills_to_recede = kills_to_recede


## IDLE -> WARNING. The first `step` reports &"warn".
func start() -> void:
	if state != State.IDLE:
		return
	_begin_warning()


func on_kill() -> void:
	if state == State.FIGHT:
		kills += 1


## The fight is won without more kills (nothing left to fight): the lava recedes now, whatever the stage.
func win_now() -> void:
	if state == State.FIGHT:
		state = State.RECEDING
		_timer = Tuning.TEMPLE_SURGE_RECEDE_SECONDS
		_pending.append(&"recede")


func flooded_levels() -> int:
	return stage


## Kills needed to end the current fight.
func kill_target() -> int:
	return _kills_stage_1 if _stages == 2 and stage == 1 else _kills_to_recede


## Seconds of warning left (0 outside WARNING), for the tremor and the glow.
func warning_left() -> float:
	return _timer if state == State.WARNING else 0.0


## How far level `level` (0 or 1) is covered, 0..1: full below the level being worked on, the progress
## of the rise or of the recede on it, nothing above.
func level_fraction(level: int) -> float:
	var top := stage - 1
	if level < top:
		return 1.0
	if level > top:
		return 0.0
	match state:
		State.RISING:
			return 1.0 - clampf(_timer / Tuning.TEMPLE_SURGE_RISE_SECONDS, 0.0, 1.0)
		State.RECEDING:
			return clampf(_timer / Tuning.TEMPLE_SURGE_RECEDE_SECONDS, 0.0, 1.0)
	return 1.0


func step(delta: float) -> Array[StringName]:
	var events: Array[StringName] = _pending.duplicate()
	_pending.clear()
	match state:
		State.WARNING:
			_timer -= delta
			if _timer <= 0.0:
				stage += 1
				state = State.RISING
				_timer = Tuning.TEMPLE_SURGE_RISE_SECONDS
				events.append(&"rise")
		State.RISING:
			_timer -= delta
			if _timer <= 0.0:
				state = State.FIGHT
				_wave_timer = Tuning.TEMPLE_SURGE_WAVE_INTERVAL
				events.append(&"risen")
		State.FIGHT:
			if kills >= kill_target():
				if _stages == 2 and stage == 1:
					_begin_warning()
					events.append_array(_pending)
					_pending.clear()
				else:
					state = State.RECEDING
					_timer = Tuning.TEMPLE_SURGE_RECEDE_SECONDS
					events.append(&"recede")
			else:
				_wave_timer -= delta
				if _wave_timer <= 0.0:
					_wave_timer = Tuning.TEMPLE_SURGE_WAVE_INTERVAL
					events.append(&"spawn_wave")
		State.RECEDING:
			_timer -= delta
			if _timer <= 0.0:
				stage -= 1
				if stage <= 0:
					stage = 0
					state = State.DONE
					events.append(&"receded")
				else:
					_timer = Tuning.TEMPLE_SURGE_RECEDE_SECONDS
					events.append(&"recede")
	return events


func _begin_warning() -> void:
	state = State.WARNING
	kills = 0
	_timer = Tuning.TEMPLE_SURGE_WARN_SECONDS
	_pending.append(&"warn")
