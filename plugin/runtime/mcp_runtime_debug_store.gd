@tool
extends RefCounted
class_name MCPRuntimeDebugStore

const MAX_EVENTS := 300
const FALLBACK_FILE_PATH := "user://godot_mcp_runtime_bridge_events.json"

static var _events: Array[Dictionary] = []
static var _sessions: Dictionary = {}
static var _bridge_status := {
	"installed": false,
	"autoload_name": "MCPRuntimeBridge",
	"autoload_path": "",
	"message": "Runtime bridge not installed"
}


static func record_runtime_event(kind: String, payload: Dictionary, session_id: int = -1) -> Dictionary:
	var event := {
		"timestamp_unix": int(Time.get_unix_time_from_system()),
		"timestamp_text": Time.get_datetime_string_from_system(true, true),
		"kind": kind,
		"session_id": session_id,
		"payload": payload.duplicate(true)
	}
	_events.append(event)
	if _events.size() > MAX_EVENTS:
		_events = _events.slice(_events.size() - MAX_EVENTS)
	return event.duplicate(true)


static func record_session_state(session_id: int, state: String, metadata: Dictionary = {}) -> void:
	_sessions[str(session_id)] = {
		"session_id": session_id,
		"state": state,
		"updated_at_unix": int(Time.get_unix_time_from_system()),
		"updated_at_text": Time.get_datetime_string_from_system(true, true),
		"metadata": metadata.duplicate(true)
	}


static func get_recent(limit: int = 50) -> Array[Dictionary]:
	var merged_events := _get_merged_events()
	var resolved_limit := maxi(limit, 0)
	if resolved_limit == 0:
		return []
	var start_index := maxi(merged_events.size() - resolved_limit, 0)
	return merged_events.slice(start_index).duplicate(true)


static func get_errors(limit: int = 50) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for event in _get_merged_events():
		var payload := event.get("payload", {})
		var level := str((payload if payload is Dictionary else {}).get("level", ""))
		if level in ["warning", "error"]:
			filtered.append(event.duplicate(true))

	var resolved_limit := maxi(limit, 0)
	if resolved_limit == 0 or filtered.size() <= resolved_limit:
		return filtered
	return filtered.slice(filtered.size() - resolved_limit)


static func get_sessions() -> Dictionary:
	return _sessions.duplicate(true)


static func get_summary() -> Dictionary:
	return {
		"bridge_status": get_bridge_status(),
		"session_count": _sessions.size(),
		"sessions": get_sessions(),
		"recent_events": get_recent(10)
	}


static func get_bridge_status() -> Dictionary:
	return _bridge_status.duplicate(true)


static func set_bridge_status(installed: bool, autoload_name: String, autoload_path: String, message: String) -> void:
	_bridge_status = {
		"installed": installed,
		"autoload_name": autoload_name,
		"autoload_path": autoload_path,
		"message": message
	}


static func clear() -> void:
	_events.clear()
	_sessions.clear()
	_clear_fallback_events()


static func _get_merged_events() -> Array[Dictionary]:
	var merged: Array[Dictionary] = []
	var seen: Dictionary = {}
	for source_events in [_events, _read_fallback_events()]:
		for event in source_events:
			if not (event is Dictionary):
				continue
			var copied := (event as Dictionary).duplicate(true)
			var key := JSON.stringify(copied)
			if seen.has(key):
				continue
			seen[key] = true
			merged.append(copied)
	merged.sort_custom(Callable(MCPRuntimeDebugStore, "_sort_event_chronologically"))
	if merged.size() > MAX_EVENTS:
		merged = merged.slice(merged.size() - MAX_EVENTS)
	return merged


static func _sort_event_chronologically(a: Dictionary, b: Dictionary) -> bool:
	var a_time = int(a.get("timestamp_unix", 0))
	var b_time = int(b.get("timestamp_unix", 0))
	if a_time == b_time:
		return str(a.get("timestamp_text", "")) < str(b.get("timestamp_text", ""))
	return a_time < b_time


static func _read_fallback_events() -> Array[Dictionary]:
	if not FileAccess.file_exists(FALLBACK_FILE_PATH):
		return []
	var file := FileAccess.open(FALLBACK_FILE_PATH, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	var events: Array[Dictionary] = []
	if parsed is Array:
		for item in parsed:
			if item is Dictionary:
				events.append((item as Dictionary).duplicate(true))
	elif parsed is Dictionary:
		var data = parsed.get("events", [])
		if data is Array:
			for item in data:
				if item is Dictionary:
					events.append((item as Dictionary).duplicate(true))
	return events


static func _clear_fallback_events() -> void:
	if not FileAccess.file_exists(FALLBACK_FILE_PATH):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FALLBACK_FILE_PATH))
