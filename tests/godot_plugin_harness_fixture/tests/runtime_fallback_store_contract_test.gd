extends RefCounted

const RuntimeFallbackStoreScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_fallback_store.gd")
const FALLBACK_FILE_PATH := "user://godot_mcp_runtime_fallback_store_contract.json"


func run_case(_tree: SceneTree) -> Dictionary:
	_cleanup_fallback_file()

	var store = RuntimeFallbackStoreScript.new()
	store.configure({
		"fallback_file_path": FALLBACK_FILE_PATH,
		"max_stored_events": 3
	})

	store.append_event("runtime_reply", {
		"request_id": "reply-1",
		"ok": true
	}, 7)
	store.flush()
	var initial_events := store.read_events()
	if initial_events.size() != 1:
		return _failure("Fallback store did not persist the first event.")

	for index in range(5):
		store.append_event("runtime_event", {
			"index": index
		}, index)
	store.flush()

	var events := store.read_events()
	if events.size() != 3:
		return _failure("Fallback store did not enforce the max_stored_events limit.")

	var last_event := events[events.size() - 1]
	if not (last_event is Dictionary):
		return _failure("Fallback store did not return dictionary events.")

	var last_payload = (last_event as Dictionary).get("payload", {})
	if not (last_payload is Dictionary) or int((last_payload as Dictionary).get("index", -1)) != 4:
		return _failure("Fallback store did not preserve the newest event after trimming.")

	store.dispose()
	return {
		"name": "runtime_fallback_store_contracts",
		"success": true,
		"error": "",
		"details": {
			"persisted_event_count": events.size(),
			"last_event_kind": str((last_event as Dictionary).get("kind", "")),
			"trimmed_to_limit": events.size() == 3
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	_cleanup_fallback_file()


func _cleanup_fallback_file() -> void:
	var absolute_path := ProjectSettings.globalize_path(FALLBACK_FILE_PATH)
	if FileAccess.file_exists(FALLBACK_FILE_PATH):
		DirAccess.remove_absolute(absolute_path)


func _failure(message: String) -> Dictionary:
	return {
		"name": "runtime_fallback_store_contracts",
		"success": false,
		"error": message
	}
