@tool
extends RefCounted
class_name MCPToolDiagnosticService

const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")

var _load_errors: Array[Dictionary] = []
var _get_entry: Callable = Callable()


func configure(options: Dictionary = {}) -> void:
	_get_entry = options.get("get_entry", Callable())


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
		PluginSelfDiagnosticStore.record_incident(
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
	PluginSelfDiagnosticStore.record_incident(
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
