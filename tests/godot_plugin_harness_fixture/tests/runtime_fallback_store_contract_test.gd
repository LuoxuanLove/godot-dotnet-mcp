extends RefCounted

# {"name": "runtime_fallback_store_contracts"}

const MCPRuntimeFallbackStoreScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_fallback_store.gd")
const FALLBACK_PATH := "user://godot_dotnet_mcp/test_runtime_fallback_store_contracts/events.json"


func run_case(_tree: SceneTree) -> Dictionary:
	_cleanup_file()
	_seed_events([
		_build_event(10, "OLD A"),
		_build_event(11, "OLD B")
	])

	var store = MCPRuntimeFallbackStoreScript.new()
	store.configure({
		"fallback_file_path": FALLBACK_PATH,
		"max_stored_events": 2
	})
	store.append_event("runtime_log", {"message": "NEW C", "level": "info"}, 3)
	store.flush()
	var events := store.read_events()
	if events.size() != 2:
		return _failure("Fallback store should keep max_stored_events after flushing a new event.")
	if str(events[0].get("payload", {}).get("message", "")) != "OLD B":
		return _failure("Fallback store should trim the oldest cached event before pending events.")
	if str(events[1].get("payload", {}).get("message", "")) != "NEW C":
		return _failure("Fallback store should preserve the newly appended pending event when cache is full.")
	if int(events[1].get("event_id", 0)) <= 11:
		return _failure("Fallback store should assign event_id values after persisted fallback events.")

	store.clear_memory()
	_seed_events([
		_build_event(20, "OLD D"),
		_build_event(21, "OLD E")
	])
	var loaded_events := store.read_events()
	if loaded_events.size() != 2:
		return _failure("Fallback store should load seeded persisted events.")
	store.append_event("runtime_log", {"message": "NEW F", "level": "info"}, 4)
	store.flush()
	events = store.read_events()
	if events.size() != 2 or str(events[1].get("payload", {}).get("message", "")) != "NEW F":
		return _failure("Fallback store should keep pending events even when append follows a loaded full cache.")
	if int(events[1].get("event_id", 0)) <= 21:
		return _failure("Fallback store should continue event_id values after a loaded full cache.")

	_cleanup_file()
	return {
		"name": "runtime_fallback_store_contracts",
		"success": true,
		"error": "",
		"details": {"event_count": events.size()}
	}


func cleanup_case(_tree: SceneTree) -> void:
	_cleanup_file()


func _build_event(event_id: int, message: String) -> Dictionary:
	return {
		"event_id": event_id,
		"timestamp_unix": event_id,
		"timestamp_text": "2026-01-01T00:00:%02d" % event_id,
		"kind": "runtime_log",
		"session_id": 1,
		"payload": {"message": message, "level": "info"}
	}


func _seed_events(events: Array) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FALLBACK_PATH.get_base_dir()))
	var file := FileAccess.open(FALLBACK_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(events))
		file.close()


func _cleanup_file() -> void:
	if FileAccess.file_exists(FALLBACK_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FALLBACK_PATH))


func _failure(message: String) -> Dictionary:
	_cleanup_file()
	return {
		"name": "runtime_fallback_store_contracts",
		"success": false,
		"error": message
	}
