@tool
extends RefCounted
class_name MCPToolLoaderSupervisor

const MCPToolLoader = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader.gd")

var _server_context
var _tool_loader: MCPToolLoader
var _tool_loader_initialized := false
var _tool_loader_healthy := false
var _tool_loader_status: String = "uninitialized"
var _tool_loader_last_summary: Dictionary = {}
var _disabled_tools: Dictionary = {}
var _log := Callable()
var _record_registration_issue := Callable()


func configure(server_context, callbacks: Dictionary = {}) -> void:
	_server_context = server_context
	_log = callbacks.get("log", Callable())
	_record_registration_issue = callbacks.get("record_registration_issue", Callable())
	if _tool_loader == null:
		_replace_tool_loader()


func ensure_initialized() -> void:
	if _tool_loader == null:
		_replace_tool_loader()
	if not _tool_loader_initialized:
		register_tools()


func register_tools(reason: String = "initialize", force_reload_scripts: bool = false) -> Dictionary:
	if _tool_loader == null:
		_replace_tool_loader()
	var summary = _rebuild_tool_loader(reason, force_reload_scripts)
	if _should_recover_tool_loader(summary):
		_log_message("Tool loader came back empty during %s; retrying with a fresh force-reload pass" % reason, "warning")
		summary = _rebuild_tool_loader("%s_recover" % reason, true)
	var status := _classify_tool_loader_health(summary)
	_apply_status(status, summary)
	_log_message("Registered %d tools across %d categories (%s)" % [
		int(summary.get("tool_count", 0)),
		int(summary.get("category_count", 0)),
		reason
	], "info")
	_maybe_record_registration_issue(reason, status, summary)
	return summary


func set_disabled_tools(disabled: Array) -> void:
	_disabled_tools.clear()
	for name in disabled:
		_disabled_tools[str(name)] = true
	if _tool_loader != null:
		_tool_loader.set_disabled_tools(disabled)
		refresh_status_from_loader()


func get_disabled_tools() -> Array:
	return _disabled_tools.keys()


func is_tool_enabled(tool_name: String) -> bool:
	return not _disabled_tools.has(tool_name)


func get_tool_loader() -> MCPToolLoader:
	return _tool_loader


func get_status() -> Dictionary:
	return {
		"initialized": _tool_loader_initialized,
		"healthy": _tool_loader_healthy,
		"status": _tool_loader_status,
		"tool_count": int(_tool_loader_last_summary.get("tool_count", 0)),
		"exposed_tool_count": int(_tool_loader_last_summary.get("exposed_tool_count", 0)),
		"category_count": int(_tool_loader_last_summary.get("category_count", 0)),
		"tool_load_error_count": int(_tool_loader_last_summary.get("tool_load_error_count", 0)),
		"last_summary": _tool_loader_last_summary.duplicate(true)
	}


func refresh_status_from_loader() -> void:
	if _tool_loader == null:
		return
	var summary := {
		"tool_count": _tool_loader.get_tool_definitions().size(),
		"exposed_tool_count": _tool_loader.get_exposed_tool_definitions().size(),
		"category_count": _tool_loader.get_domain_states().size(),
		"tool_load_error_count": _tool_loader.get_tool_load_errors().size()
	}
	var status := _classify_tool_loader_health(summary)
	_apply_status(status, summary)


func dispose() -> void:
	if _tool_loader != null and _tool_loader.has_method("shutdown"):
		_tool_loader.shutdown()
	_tool_loader = null
	_server_context = null
	_tool_loader_initialized = false
	_tool_loader_healthy = false
	_tool_loader_status = "disposed"
	_tool_loader_last_summary = {}
	_disabled_tools.clear()
	_log = Callable()
	_record_registration_issue = Callable()


func _rebuild_tool_loader(reason: String, force_reload_scripts: bool) -> Dictionary:
	_replace_tool_loader()
	var summary = _tool_loader.initialize(get_disabled_tools(), force_reload_scripts)
	var category_count = int(summary.get("category_count", 0))
	var tool_count = int(summary.get("tool_count", 0))
	_log_message("Tool loader summary after %s: %d tools / %d categories" % [reason, tool_count, category_count], "debug")
	return summary


func _replace_tool_loader() -> void:
	if _tool_loader != null and _tool_loader.has_method("shutdown"):
		_tool_loader.shutdown()
	_tool_loader = MCPToolLoader.new()
	if _server_context != null:
		_tool_loader.configure(_server_context)
	if not _disabled_tools.is_empty():
		_tool_loader.set_disabled_tools(get_disabled_tools())


func _should_recover_tool_loader(summary: Dictionary) -> bool:
	return int(summary.get("category_count", 0)) <= 0 and int(summary.get("tool_load_error_count", 0)) <= 0


func _classify_tool_loader_health(summary: Dictionary) -> Dictionary:
	var category_count := int(summary.get("category_count", 0))
	var tool_count := int(summary.get("tool_count", 0))
	var exposed_tool_count := int(summary.get("exposed_tool_count", 0))
	var tool_load_error_count := int(summary.get("tool_load_error_count", 0))
	var status := "ready"
	var healthy := true
	if category_count <= 0 and tool_load_error_count <= 0:
		status = "empty_registry"
		healthy = false
	elif tool_count <= 0 or exposed_tool_count <= 0:
		status = "no_visible_tools"
		healthy = false
	elif tool_load_error_count > 0:
		status = "degraded"
	return {
		"initialized": category_count > 0 or tool_count > 0 or tool_load_error_count > 0,
		"healthy": healthy,
		"status": status
	}


func _apply_status(status: Dictionary, summary: Dictionary) -> void:
	_tool_loader_initialized = bool(status.get("initialized", false))
	_tool_loader_healthy = bool(status.get("healthy", false))
	_tool_loader_status = str(status.get("status", "unknown"))
	_tool_loader_last_summary = summary.duplicate(true)


func _maybe_record_registration_issue(reason: String, status: Dictionary, summary: Dictionary) -> void:
	if not _record_registration_issue.is_valid():
		return
	if not bool(status.get("healthy", false)):
		_record_registration_issue.call("error", reason, status.duplicate(true), summary.duplicate(true))
	elif int(summary.get("tool_load_error_count", 0)) > 0:
		_record_registration_issue.call("warning", reason, status.duplicate(true), summary.duplicate(true))


func _log_message(message: String, level: String) -> void:
	if _log.is_valid():
		_log.call(message, level)
