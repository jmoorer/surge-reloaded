class_name SaveGame
extends RefCounted
## Disk I/O for the two save files:
## - profile: what survives between runs (banked samples, run counts).
## - run save: a mid-run snapshot from save-and-quit. Deleted the moment it's loaded.

## Tests point this somewhere else so they never touch the player's real files.
static var prefix := "user://"


static func run_path() -> String:
	return prefix + "run_save.json"


static func profile_path() -> String:
	return prefix + "profile.json"


static func has_run() -> bool:
	return FileAccess.file_exists(run_path())


static func save_run(data: Dictionary) -> bool:
	return _write(run_path(), data)


## Returns the saved run and deletes it (no save scumming). Empty if none.
static func take_run() -> Dictionary:
	if not has_run():
		return {}
	var data := _read(run_path())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run_path()))
	return data


static func delete_run() -> void:
	if has_run():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(run_path()))


static func load_profile() -> Dictionary:
	var p := {"banked_samples": 0, "extractions": 0, "deaths": 0}
	if FileAccess.file_exists(profile_path()):
		p.merge(_read(profile_path()), true)
	return p


static func save_profile(p: Dictionary) -> bool:
	return _write(profile_path(), p)


static func _write(path: String, data: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SaveGame: can't write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(data, "\t"))
	return true


static func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


static func vec3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func to_vec3(a: Variant) -> Vector3:
	return Vector3(a[0], a[1], a[2]) if a is Array and a.size() == 3 else Vector3.ZERO
