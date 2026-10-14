extends SceneTree
## Smoke test used locally and by CI.
## Loads every .gd, .tscn and .tres under res:// and fails if any cannot be loaded.
## Run: godot --headless --path . --script res://tests/run_checks.gd

const SKIP_DIRS := [".godot", ".git", "addons", "docs"]


func _initialize() -> void:
	var failures: Array[String] = []
	var checked := 0
	for path in _collect("res://"):
		checked += 1
		var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res == null:
			failures.append("cannot load: " + path)
		elif res is GDScript and not (res as GDScript).can_instantiate() and not (res as GDScript).is_abstract():
			failures.append("script has errors: " + path)
		elif res is PackedScene:
			var node := (res as PackedScene).instantiate()
			if node == null:
				failures.append("cannot instantiate: " + path)
			else:
				node.free()

	print("Checked %d files, %d failures" % [checked, failures.size()])
	for f in failures:
		printerr(f)
	quit(1 if failures.size() > 0 else 0)


func _collect(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			if not SKIP_DIRS.has(name):
				out.append_array(_collect(full))
		elif name.ends_with(".gd") or name.ends_with(".tscn") or name.ends_with(".tres"):
			if full != "res://tests/run_checks.gd":
				out.append(full)
		name = dir.get_next()
	return out
