class_name SoundBank
extends Resource
## Every sound of the game, by cue name (data/audio/sound_bank.tres, made by
## tools/make_sound_data.gd from the files in assets/audio/). A cue has one or more variations; one
## is picked at random each time, with a little pitch change, so repeated sounds do not tire.

## Cue -> Array of AudioStream (variations).
@export var cues: Dictionary = {}
## Cue -> volume in dB (missing = 0).
@export var volumes_db: Dictionary = {}
## Cue -> another cue it sounds like (e.g. &"death_esqueleto" -> &"death_bones").
@export var aliases: Dictionary = {}
## Music id (menu, a scenario id, boss) -> looping AudioStream.
@export var music: Dictionary = {}
## Music id -> volume in dB (missing = 0).
@export var music_volumes_db: Dictionary = {}


## The cue's real name after following its alias (or the name itself).
func resolve(cue: StringName) -> StringName:
	return aliases.get(cue, cue) if not cues.has(cue) else cue


func has_cue(cue: StringName) -> bool:
	return cues.has(resolve(cue))


func pick(cue: StringName) -> AudioStream:
	var variations: Array = cues.get(resolve(cue), [])
	return variations.pick_random() if not variations.is_empty() else null


## The cue's own volume, else the volume of the cue it borrows its sound from.
func volume_of(cue: StringName) -> float:
	return volumes_db.get(cue, volumes_db.get(resolve(cue), 0.0))
