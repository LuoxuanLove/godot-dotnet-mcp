@tool
extends RefCounted
class_name MCPToolDiagnosticService

var _load_errors: Array[Dictionary] = []
var _get_entry: Callable = Callable()
var _record_incident: Callable = Callable(self, "_noop_record_incident")


func configure(options: Dictionary = {}) -> void:
	_get_entry = options.get("get_entry", Callable())
	_record_incident = options.get("record_incident", Callable(self, "_noop_record_incident"))
	if not _record_incident.is_valid():
		_record_incident = Callable(self, "_noop_record_incident")


func dispose() -> void:
	_load_errors.clear()
	_get_entry = Callable()
	_record_incident = Callable(self, "_noop_record_incident")


func clear_load_errors() -> void:
	_load_errors.clear()


func append_load_errors(errors: Array) -> void:
	for error_info in errors:
		if error_info is Dictionary:
			_load_errors.append((error_info as Dictionary).duplicate(true))


func append_duplicate_category_error(category: String, path: String, source: String) -> void:
	_load_errors.append({
		"category": category,
		"path": path,
		"message": "Duplicate tool category registered",
		"source": source
	})


func record_load_error(category: String, path: String, message: String) -> Dictionary:
	var error_info := {
		"category": category,
		"path": path,
		"message": message
	}
	_load_errors.append(error_info)
	return error_info.duplicate(true)


func get_tool_load_errors() -> Array[Dictionary]:
	return _load_errors.duplicate(true)


func get_tool_load_error_count() -> int:
	return _load_errors.size()


func sync_load_error_incidents(phase: String) -> void:
	for error_info in _load_errors:
		if not (error_info is Dictionary):
			continue
		var info := error_info as Dictionary
		_record_incident.call(
			"error",
			"tool_load_error",
			"tool_domain_load_failed",
			str(info.get("message", "Tool domain load failed")),
			"tool_loader",
			phase,
			str(info.get("path", "")),
			"",
			"",
			true,
			"Inspect the tool domain script and the editor output for the failing category.",
			{
				"category": str(info.get("category", "")),
				"source": str(info.get("source", "builtin"))
			}
		)


func record_reload_incident(category: String, message: String, phase: String) -> void:
	_record_incident.call(
		"error",
		"reload_conflict",
		"tool_reload_failed",
		message,
		"tool_loader",
		phase,
		str(_get_entry_by_category(category).get("path", "")),
		"",
		"",
		true,
		"Inspect the last reload status and the failing tool domain script.",
		{
			"category": category
		}
	)


func _get_entry_by_category(category: String) -> Dictionary:
	if not _get_entry.is_valid():
		return {}
	var entry = _get_entry.call(category)
	return entry if entry is Dictionary else {}


func _noop_record_incident(
	_severity: String,
	_category: String,
	_code: String,
	_message: String,
	_component: String,
	_phase: String = "",
	_file_path: String = "",
	_line = "",
	_operation_id: String = "",
	_recoverable: bool = true,
	_suggested_action: String = "",
	_context: Dictionary = {}
) -> Dictionary:
	return {}
