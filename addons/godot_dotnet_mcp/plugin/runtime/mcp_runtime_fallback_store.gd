@tool
extends RefCounted
class_name MCPRuntimeFallbackStore

const MCPUserDataPaths = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_user_data_paths.gd")

var _fallback_file_path := MCPUserDataPaths.RUNTIME_EVENTS_PATH
var _max_stored_events := 300
var _pending_events: Array[Dictionary] = []
var _fallback_cache: Array[Dictionary] = []
var _fallback_cache_loaded := false
var _next_event_id: int = 1
var _next_event_id_initialized := false


func configure(options: Dictionary = {}) -> void:
	_fallback_file_path = str(options.get("fallback_file_path", _fallback_file_path))
	_max_stored_events = maxi(int(options.get("max_stored_events", _max_stored_events)), 1)


func append_event(kind: String, payload: Dictionary, session_id: int = -1) -> void:
	_ensure_next_event_id_initialized()
	var event := {
		"event_id": _next_event_id,
		"timestamp_unix": int(Time.get_unix_time_from_system()),
		"timestamp_text": Time.get_datetime_string_from_system(true, true),
		"kind": kind,
		"session_id": session_id,
		"payload": payload.duplicate(true)
	}
	_next_event_id += 1
	_pending_events.append(event)
	_trim_cached_events()


func has_pending_events() -> bool:
	return not _pending_events.is_empty()


func flush() -> void:
	if _pending_events.is_empty():
		return
	_ensure_fallback_cache_loaded()
	var next_cache: Array[Dictionary] = _fallback_cache.duplicate(true)
	next_cache.append_array(_pending_events)
	if next_cache.size() > _max_stored_events:
		next_cache = next_cache.slice(next_cache.size() - _max_stored_events)
	if _write_fallback_events(next_cache):
		_fallback_cache = next_cache
		_fallback_cache_loaded = true
		_pending_events.clear()
	else:
		push_warning("[MCP] Failed to persist fallback runtime events; pending events remain in memory.")


func read_events() -> Array[Dictionary]:
	_ensure_fallback_cache_loaded()
	var events: Array[Dictionary] = _fallback_cache.duplicate(true)
	for event in _pending_events:
		events.append(event.duplicate(true))
	return events


func clear_memory() -> void:
	_pending_events.clear()
	_fallback_cache.clear()
	_fallback_cache_loaded = false
	_next_event_id = 1
	_next_event_id_initialized = false


func dispose() -> void:
	clear_memory()


func _ensure_next_event_id_initialized() -> void:
	if _next_event_id_initialized:
		return
	_sync_next_event_id(_read_fallback_events())


func _ensure_fallback_cache_loaded() -> void:
	if _fallback_cache_loaded:
		return
	_fallback_cache = _read_fallback_events()
	_fallback_cache_loaded = true
	_sync_next_event_id(_fallback_cache)


func _sync_next_event_id(events: Array[Dictionary]) -> void:
	var max_event_id := 0
	for event in events:
		max_event_id = maxi(max_event_id, int(event.get("event_id", 0)))
	_next_event_id = max(_next_event_id, max_event_id + 1)
	_next_event_id_initialized = true


func _read_fallback_events() -> Array[Dictionary]:
	if not FileAccess.file_exists(_fallback_file_path):
		return []
	var file := FileAccess.open(_fallback_file_path, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		var events: Array[Dictionary] = []
		for item in parsed:
			if item is Dictionary:
				events.append((item as Dictionary).duplicate(true))
		return events
	if parsed is Dictionary:
		var data = parsed.get("events", [])
		if data is Array:
			var wrapped_events: Array[Dictionary] = []
			for item in data:
				if item is Dictionary:
					wrapped_events.append((item as Dictionary).duplicate(true))
			return wrapped_events
	return []


func _write_fallback_events(events: Array[Dictionary]) -> bool:
	return _write_text_atomically(_fallback_file_path, JSON.stringify(events))


func _write_text_atomically(file_path: String, text: String) -> bool:
	var dir_path := file_path.get_base_dir()
	if not dir_path.is_empty() and dir_path != ".":
		var dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
		if dir_error != OK:
			return false
	var temp_path := _build_sidecar_path(file_path, "tmp")
	var backup_path := _build_sidecar_path(file_path, "bak")
	var temp_file := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp_file == null:
		return false
	temp_file.store_string(text)
	temp_file.close()
	if FileAccess.get_file_as_string(temp_path) != text:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		return false
	var absolute_path := ProjectSettings.globalize_path(file_path)
	var absolute_temp_path := ProjectSettings.globalize_path(temp_path)
	var absolute_backup_path := ProjectSettings.globalize_path(backup_path)
	var had_existing := FileAccess.file_exists(file_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup_path)
	if had_existing:
		var backup_error := DirAccess.rename_absolute(absolute_path, absolute_backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(absolute_temp_path)
			return false
	var replace_error := DirAccess.rename_absolute(absolute_temp_path, absolute_path)
	if replace_error != OK:
		if had_existing and FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup_path, absolute_path)
		DirAccess.remove_absolute(absolute_temp_path)
		return false
	if had_existing and FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup_path)
	return true


func _build_sidecar_path(file_path: String, extension: String) -> String:
	var dir_path := file_path.get_base_dir()
	var file_name := file_path.get_file()
	var suffix := "%s-%s" % [str(Time.get_ticks_usec()), str(randi())]
	return "%s/.%s.%s.%s" % [dir_path, file_name, suffix, extension]


func _trim_cached_events() -> void:
	var projected_size := _pending_events.size()
	if _fallback_cache_loaded:
		projected_size += _fallback_cache.size()
	if projected_size <= _max_stored_events:
		return
	var overflow := projected_size - _max_stored_events
	while overflow > 0 and not _fallback_cache.is_empty():
		_fallback_cache.remove_at(0)
		overflow -= 1
	while overflow > 0 and not _pending_events.is_empty():
		_pending_events.remove_at(0)
		overflow -= 1
