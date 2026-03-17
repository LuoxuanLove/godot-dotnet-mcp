@tool
extends RefCounted
class_name MCPRuntimeDebugStore

const MAX_EVENTS := 300
const FALLBACK_FILE_PATH := "user://godot_mcp_runtime_bridge_events.json"

static var _events: Array[Dictionary] = []
static var _sessions: Dictionary = {}
static var _fallback_cache: Array[Dictionary] = []
static var _fallback_dirty := true
static var _fallback_modified_unix := -1
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
	_fallback_dirty = true
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
			filtered.append(_decorate_runtime_error_event(event))

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
	_fallback_cache.clear()
	_fallback_dirty = true
	_fallback_modified_unix = -1
	_clear_fallback_events()


static func _decorate_runtime_error_event(event: Dictionary) -> Dictionary:
	var decorated := event.duplicate(true)
	var payload = decorated.get("payload", {})
	var context := _extract_runtime_error_context(payload if payload is Dictionary else {})
	decorated["source_file"] = str(context.get("source_file", ""))
	decorated["source_line"] = context.get("source_line", "")
	decorated["error_category"] = str(context.get("error_category", "unknown"))
	return decorated


static func _extract_runtime_error_context(payload: Dictionary) -> Dictionary:
	var metadata := payload.get("metadata", {})
	var metadata_dict := metadata if metadata is Dictionary else {}
	var source_file = _normalize_runtime_source_file(str(
		metadata_dict.get("source_file", metadata_dict.get("source_path", metadata_dict.get("path", metadata_dict.get("script", ""))))
	))
	var source_line = _parse_source_line(metadata_dict.get("source_line", metadata_dict.get("line", "")))
	var combined_text = _build_runtime_error_text(payload, metadata_dict)

	if source_file.is_empty() or source_line <= 0:
		var stack_context = _extract_runtime_error_from_stack(payload.get("stack", []))
		if source_file.is_empty():
			source_file = str(stack_context.get("source_file", ""))
		if source_line <= 0:
			source_line = _parse_source_line(stack_context.get("source_line", ""))

	if source_file.is_empty() or source_line <= 0:
		var text_context = _extract_runtime_error_from_text(combined_text)
		if source_file.is_empty():
			source_file = str(text_context.get("source_file", ""))
		if source_line <= 0:
			source_line = _parse_source_line(text_context.get("source_line", ""))

	return {
		"source_file": source_file,
		"source_line": source_line if source_line > 0 else "",
		"error_category": _classify_runtime_error(combined_text)
	}


static func _build_runtime_error_text(payload: Dictionary, metadata: Dictionary) -> String:
	var parts: Array[String] = [str(payload.get("message", ""))]
	for key in ["error", "exception", "exception_text", "details", "trace", "stack_trace"]:
		if metadata.has(key):
			parts.append(str(metadata.get(key, "")))
	var stack_value = payload.get("stack", [])
	if stack_value is String:
		parts.append(str(stack_value))
	return "\n".join(parts).strip_edges()


static func _extract_runtime_error_from_stack(stack_data) -> Dictionary:
	if stack_data is Array:
		for frame in stack_data:
			if not (frame is Dictionary):
				continue
			var frame_dict := frame as Dictionary
			var source_file = _normalize_runtime_source_file(str(
				frame_dict.get("source", frame_dict.get("source_file", frame_dict.get("path", frame_dict.get("file", ""))))
			))
			var source_line = _parse_source_line(frame_dict.get("line", frame_dict.get("source_line", "")))
			if not source_file.is_empty() or source_line > 0:
				return {
					"source_file": source_file,
					"source_line": source_line if source_line > 0 else ""
				}
	return {
		"source_file": "",
		"source_line": ""
	}


static func _extract_runtime_error_from_text(text: String) -> Dictionary:
	for pattern in [
		"(res://[^:\\)\\s]+):(\\d+)",
		"([A-Za-z]:[/\\\\][^\\r\\n]+?\\.(?:cs|gd|gdshader|tscn)):line\\s+(\\d+)",
		"([A-Za-z]:[/\\\\][^\\r\\n]+?\\.(?:cs|gd|gdshader|tscn))\\((\\d+)(?:,\\d+)?\\)",
		"([A-Za-z]:[/\\\\][^\\r\\n]+?\\.(?:cs|gd|gdshader|tscn)):(\\d+)"
	]:
		var regex := RegEx.new()
		if regex.compile(pattern) != OK:
			continue
		var match_result = regex.search(text)
		if match_result == null:
			continue
		return {
			"source_file": _normalize_runtime_source_file(str(match_result.get_string(1))),
			"source_line": _parse_source_line(match_result.get_string(2))
		}
	return {
		"source_file": "",
		"source_line": ""
	}


static func _classify_runtime_error(text: String) -> String:
	var lowered = text.to_lower()
	if lowered.contains("nullreferenceexception") \
		or lowered.contains("base object of type 'nil'") \
		or lowered.contains("base object of type \"nil\"") \
		or lowered.contains("null instance") \
		or lowered.contains("not set to an instance of an object"):
		return "null_reference"
	if lowered.contains("assertion failed") \
		or lowered.contains("assert failed") \
		or lowered.contains("assert ") \
		or lowered.contains("condition \""):
		return "assertion"
	if lowered.contains("error calling from signal") \
		or lowered.contains("error emitting signal") \
		or (lowered.contains("signal") and lowered.contains("connect")) \
		or (lowered.contains("signal") and lowered.contains("callable")):
		return "signal_error"
	if lowered.contains("script error") \
		or lowered.contains("parser error") \
		or lowered.contains("parse error") \
		or lowered.contains("gdscript") \
		or lowered.contains("res://"):
		return "script_error"
	return "unknown"


static func _normalize_runtime_source_file(source_file: String) -> String:
	var normalized = source_file.strip_edges().replace("\\", "/")
	if normalized.is_empty():
		return ""
	if normalized.begins_with("res://"):
		return normalized

	var project_root = ProjectSettings.globalize_path("res://").replace("\\", "/")
	var comparison_root = project_root
	var comparison_source = normalized
	if OS.get_name() == "Windows":
		comparison_root = comparison_root.to_lower()
		comparison_source = comparison_source.to_lower()

	if comparison_source.begins_with(comparison_root):
		var relative_path = normalized.substr(project_root.length()).trim_prefix("/")
		return "res://%s" % relative_path
	return normalized


static func _parse_source_line(value) -> int:
	if value is int:
		return int(value)
	var text = str(value).strip_edges()
	if text.is_valid_int():
		return int(text)
	return -1


static func _get_merged_events() -> Array[Dictionary]:
	var merged: Array[Dictionary] = []
	var seen: Dictionary = {}
	for source_events in [_events, _read_fallback_events_cached()]:
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


static func _read_fallback_events_cached() -> Array[Dictionary]:
	var global_path := ProjectSettings.globalize_path(FALLBACK_FILE_PATH)
	if not FileAccess.file_exists(FALLBACK_FILE_PATH):
		_fallback_cache.clear()
		_fallback_dirty = false
		_fallback_modified_unix = -1
		return []

	var modified_unix := int(FileAccess.get_modified_time(global_path))
	if not _fallback_dirty and modified_unix == _fallback_modified_unix:
		return _fallback_cache.duplicate(true)

	_fallback_cache = _read_fallback_events()
	_fallback_modified_unix = modified_unix
	_fallback_dirty = false
	return _fallback_cache.duplicate(true)


static func _clear_fallback_events() -> void:
	if not FileAccess.file_exists(FALLBACK_FILE_PATH):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FALLBACK_FILE_PATH))
	_fallback_cache.clear()
	_fallback_dirty = false
	_fallback_modified_unix = -1
