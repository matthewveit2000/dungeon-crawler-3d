class_name SnapshotManager
extends RefCounted
## Tier 2 Pure System: Floor-Entry Snapshot & Save-and-Quit Persistence (D-014, D-017, D-018).
## - On entering a floor: snapshots level, progression, gold, equipment, inventory, floor number & seed.
## - On floor collapse OR combat death: restores the exact Floor-Entry Snapshot with a fresh 5-day floor.
## - On Save-and-Quit: writes full mid-floor state + preserved Floor-Entry Snapshot to JSON for exact resume.

const DEFAULT_SAVE_PATH := "user://savegame_v01.json"

var floor_entry_snapshot: Dictionary = {}


func capture_floor_entry_snapshot(state: Dictionary) -> Dictionary:
	floor_entry_snapshot = {
		"floor_number": int(state.get("floor_number", 1)),
		"run_seed": int(state.get("run_seed", 1337)),
		"gold": int(state.get("gold", 0)),
		"equipment": state.get("equipment", {}).duplicate(true),
		"inventory": state.get("inventory", []).duplicate(true),
		"progression": state.get("progression", {}).duplicate(true),
	}
	return floor_entry_snapshot.duplicate(true)


func has_snapshot() -> bool:
	return not floor_entry_snapshot.is_empty()


func restore_floor_entry_snapshot() -> Dictionary:
	return floor_entry_snapshot.duplicate(true)


func save_session_to_file(session_state: Dictionary, path: String = DEFAULT_SAVE_PATH) -> bool:
	var payload := {
		"version": 1,
		"floor_entry_snapshot": floor_entry_snapshot.duplicate(true),
		"session": session_state.duplicate(true),
	}
	var json_text := JSON.stringify(payload, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SnapshotManager: Failed to open save path '%s' for writing." % path)
		return false
	file.store_string(json_text)
	file.close()
	return true


func load_session_from_file(path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	floor_entry_snapshot = parsed.get("floor_entry_snapshot", {}).duplicate(true)
	return parsed.get("session", {}).duplicate(true)


static func delete_save_file(path: String = DEFAULT_SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
