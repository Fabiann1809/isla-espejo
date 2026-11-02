extends SceneTree
## Writes data/audio/sound_bank.tres from the files in assets/audio/: every `sfx/<cue>_<n>.ogg|wav`
## becomes a variation of `<cue>` and every `music/<id>.ogg` a music track. Volumes and the cues
## that borrow another cue's sound (aliases) are set below. Run it again after adding sounds.
## Run: godot --headless --path . --script res://tools/make_sound_data.gd

const SFX_DIR := "res://assets/audio/sfx"
const MUSIC_DIR := "res://assets/audio/music"

## Cue -> dB. Loud Kenney impacts are brought down; the quiet synth sounds are left at 0.
const VOLUMES := {
	&"shot": -12.0,
	&"arrow_hit": -8.0,
	&"arrow_wall": -10.0,
	&"enemy_hurt": -4.0,
	&"death_slime": -4.0,
	&"death_bones": -6.0,
	&"death_wood": -4.0,
	&"player_hurt": -2.0,
	&"dash": -6.0,
	&"step": -8.0,
	&"pickup_heart": -8.0,
	&"pickup_gold": -6.0,
	&"chest": -4.0,
	&"ui_click": -8.0,
	&"ui_hover": -14.0,
	&"ui_confirm": -8.0,
	&"ui_back": -8.0,
	&"boss_slam": 0.0,
	&"boss_roots": -2.0,
	&"boss_warn": -4.0,
	&"skill_roots": -4.0,
	&"skill_current": -6.0,
	&"skill_shadow": -6.0,
	&"dialogue": -12.0,
	&"alert": -12.0,
	&"attack_shot": -8.0,
	&"attack_summon": -4.0,
}
## Cue -> the cue whose sound it uses (enemy ids are the scene file names).
const ALIASES := {
	&"enemy_death": &"death_slime",
	&"death_brote": &"death_wood",
	&"death_ente": &"death_wood",
	&"death_forest_guardian": &"death_wood",
	&"death_esqueleto": &"death_bones",
	&"death_planta_tiradora": &"death_slime",
	&"attack_planta_tiradora": &"spit",
	&"attack_shot": &"spit",
	&"attack_summon": &"summon",
	&"pickup_arrows": &"pickup_heart",
}
const MUSIC_VOLUMES := {
	&"menu": -8.0,
	&"forest": -10.0,
	&"boss": -9.0,
}


func _initialize() -> void:
	var bank := SoundBank.new()
	for file in _files(SFX_DIR):
		var base := file.get_basename()
		var cut := base.rfind("_")
		if cut <= 0 or not base.substr(cut + 1).is_valid_int():
			continue
		var cue := StringName(base.substr(0, cut))
		if not bank.cues.has(cue):
			bank.cues[cue] = []
		bank.cues[cue].append(load(SFX_DIR + "/" + file))
	for file in _files(MUSIC_DIR):
		# Looping is set in each track's import settings (loop=true in its .import file).
		var stream: AudioStream = load(MUSIC_DIR + "/" + file)
		bank.music[StringName(file.get_basename())] = stream
	bank.volumes_db = VOLUMES.duplicate()
	bank.aliases = ALIASES.duplicate()
	bank.music_volumes_db = MUSIC_VOLUMES.duplicate()
	var error := ResourceSaver.save(bank, "res://data/audio/sound_bank.tres")
	print("sound bank: %d cues, %d tracks (error %d)" % [bank.cues.size(), bank.music.size(), error])
	quit(0 if error == OK else 1)


## Audio files of a folder (also in an exported build, where they appear as .import/.remap).
func _files(dir: String) -> Array[String]:
	var result: Array[String] = []
	for file in ResourceLoader.list_directory(dir):
		if file.get_extension() in ["ogg", "wav"]:
			result.append(file)
	result.sort()
	return result
