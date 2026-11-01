extends Node
## Player options (autoload "Settings"): master, music and effects volume and full screen, kept in
## `user://settings.json`.
## Disabled in headless mode and with `--no-save` so tests never touch the real file.

signal changed

const VERSION := 1

var save_path := "user://settings.json"
var persistence_enabled := true
## Linear master volume, 0..1.
var volume := 0.8
## Linear volume of the "Music" and "SFX" buses, 0..1 (under the master volume).
var music_volume := 0.8
var sfx_volume := 1.0
var fullscreen := false


func _ready() -> void:
	persistence_enabled = not OS.get_cmdline_user_args().has("--no-save") and DisplayServer.get_name() != "headless"
	if persistence_enabled:
		load_settings()
	apply()


func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	apply()
	save()
	changed.emit()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	apply()
	save()
	changed.emit()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	apply()
	save()
	changed.emit()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply()
	save()
	changed.emit()


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.0)
	_apply_bus(&"Music", music_volume)
	_apply_bus(&"SFX", sfx_volume)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(mode)


func _apply_bus(bus_name: StringName, value: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(bus, value <= 0.0)


func to_dict() -> Dictionary:
	return {"version": VERSION, "volume": volume, "music_volume": music_volume,
			"sfx_volume": sfx_volume, "fullscreen": fullscreen}


func from_dict(data: Dictionary) -> bool:
	if int(data.get("version", 0)) != VERSION:
		return false
	volume = clampf(float(data.get("volume", volume)), 0.0, 1.0)
	# Files saved before these existed keep the defaults.
	music_volume = clampf(float(data.get("music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", sfx_volume)), 0.0, 1.0)
	fullscreen = bool(data.get("fullscreen", fullscreen))
	return true


func save() -> void:
	if not persistence_enabled:
		return
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(to_dict(), "\t"))


func load_settings() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if parsed is Dictionary:
		from_dict(parsed)
