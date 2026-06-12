@tool
extends RefCounted
class_name ToolLoaderDiagnosticsService

const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")

var _load_errors: Array[Dictionary] = []
var _reload_status: Dictionary = {}


func clear_load_errors() -> void:
	_load_errors.clear()


func replace_load_errors(load_errors: Array) -> void:
	_load_errors.clear()
	for error_info in load_errors:
		if error_info is Dictionary:
			_load_errors.append((error_info as Dictionary).duplicate(true))


func get_tool_load_errors() -> Array[Dictionary]:
	return _load_errors.duplicate(true)


func get_tool_load_error_count() -> int:
	return _load_errors.size()


func get_reload_status() -> Dictionary:
	return _reload_status.duplicate(true)


func record_load_error(category: String, path: String, message: String, phase: String = "record_load_error") -> Dictionary:
	var error_info := {
		"category": category,
		"path": path,
		"message": message
	}
	_load_errors.append(error_info.duplicate(true))
	sync_load_error_incidents(phase)
	return error_info.duplicate(true)


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


func record_reload_incident(category: String, path: String, message: String, phase: String) -> void:
	PluginSelfDiagnosticStore.record_incident(
		"error",
		"reload_conflict",
		"tool_reload_failed",
		message,
		"tool_loader",
		phase,
		path,
		"",
		"",
		true,
		"Inspect the last reload status and the failing tool domain script.",
		{
			"category": category
		}
	)


func update_reload_status(status: Dictionary) -> Dictionary:
	_reload_status = status.duplicate(true)
	return _reload_status.duplicate(true)
