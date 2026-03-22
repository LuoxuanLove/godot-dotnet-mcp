@tool
extends RefCounted
class_name MCPToolLoader

const MCPToolManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_manifest.gd")
const MCPToolDiagnosticService = preload("res://addons/godot_dotnet_mcp/tools/core/tool_diagnostic_service.gd")
const MCPToolExposureService = preload("res://addons/godot_dotnet_mcp/tools/core/tool_exposure_service.gd")
const MCPToolMetricsService = preload("res://addons/godot_dotnet_mcp/tools/core/tool_metrics_service.gd")
const MCPToolRuntimeService = preload("res://addons/godot_dotnet_mcp/tools/core/tool_runtime_service.gd")
const MCPToolReloadService = preload("res://addons/godot_dotnet_mcp/tools/core/tool_reload_service.gd")
const GDScriptLspDiagnosticsServicePath = "res://addons/godot_dotnet_mcp/plugin/runtime/gdscript_lsp_diagnostics_service.gd"

var _diagnostic_service := MCPToolDiagnosticService.new()
var _exposure_service := MCPToolExposureService.new()
var _metrics_service := MCPToolMetricsService.new()
var _runtime_service := MCPToolRuntimeService.new()
var _reload_service := MCPToolReloadService.new()
var _server_context: Object
var _entries_by_category: Dictionary = {}
var _ordered_categories: Array[String] = []
var _runtime_by_category: Dictionary = {}
var _tool_definitions_by_category: Dictionary = {}
var _disabled_tools: Dictionary = {}
var _reload_status: Dictionary = {}
var _gdscript_lsp_diagnostics_service
var _gdscript_lsp_diagnostics_generation := 0
var _force_reload_script_load := false


func configure(server_context: Object) -> void:
	_server_context = server_context
	if _diagnostic_service == null:
		_diagnostic_service = MCPToolDiagnosticService.new()
	_diagnostic_service.configure({
		"get_entry": Callable(self, "_get_entry_by_category")
	})
	if _metrics_service == null:
		_metrics_service = MCPToolMetricsService.new()
	_metrics_service.reset()
	if _exposure_service == null:
		_exposure_service = MCPToolExposureService.new()
	_exposure_service.configure({
		"ensure_tool_definitions": Callable(self, "_ensure_tool_definitions"),
		"get_cached_tool_definitions": Callable(self, "_get_cached_tool_definitions"),
		"get_entry": Callable(self, "_get_entry_by_category"),
		"get_runtime": Callable(self, "_get_runtime_by_category"),
		"is_category_visible": Callable(self, "_is_category_visible"),
		"is_tool_enabled": Callable(self, "is_tool_enabled"),
		"current_load_state": Callable(self, "_current_load_state"),
		"exposed_categories": MCPToolManifest.get_exposed_categories()
	})
	if _runtime_service == null:
		_runtime_service = MCPToolRuntimeService.new()
	_runtime_service.configure(self, _server_context, {
		"get_entry": Callable(self, "_get_entry_by_category"),
		"get_runtime": Callable(self, "_get_runtime_by_category"),
		"set_runtime": Callable(self, "_set_runtime_by_category"),
		"has_tool_definitions_cache": Callable(self, "_has_tool_definitions_cache"),
		"get_tool_definitions": Callable(self, "_get_cached_tool_definitions"),
		"set_tool_definitions": Callable(self, "_set_tool_definitions_by_category"),
		"get_force_reload_script_load": Callable(self, "_get_force_reload_script_load"),
		"record_load_error": Callable(self, "_record_load_error")
	})
	if _reload_service == null:
		_reload_service = MCPToolReloadService.new()
	_reload_service.configure({
		"refresh_entries": Callable(self, "_refresh_entries"),
		"get_entry": Callable(self, "_get_entry_by_category"),
		"get_ordered_categories": Callable(self, "_get_ordered_categories"),
		"get_disabled_tools": Callable(self, "get_disabled_tools"),
		"set_disabled_tools": Callable(self, "_set_disabled_tools"),
		"get_runtime": Callable(self, "_get_runtime_by_category"),
		"set_runtime": Callable(self, "_set_runtime_by_category"),
		"erase_runtime": Callable(self, "_erase_runtime_by_category"),
		"get_tool_definitions": Callable(self, "_get_cached_tool_definitions"),
		"set_tool_definitions": Callable(self, "_set_tool_definitions_by_category"),
		"erase_tool_definitions": Callable(self, "_erase_tool_definitions_by_category"),
		"instantiate_executor": Callable(self, "_instantiate_executor"),
		"extract_tool_definitions": Callable(self, "_extract_tool_definitions"),
		"sync_load_error_incidents": Callable(_diagnostic_service, "sync_load_error_incidents"),
		"refresh_runtime_context": Callable(self, "_refresh_runtime_context"),
		"reset_lsp_diagnostics": Callable(self, "_reset_gdscript_lsp_diagnostics_service"),
		"category_has_enabled_tools": Callable(self, "_category_has_enabled_tools"),
		"unload_runtime": Callable(self, "_unload_runtime"),
		"record_reload_incident": Callable(_diagnostic_service, "record_reload_incident"),
		"as_bool": Callable(self, "_as_bool")
	})
	if Engine.has_singleton("MCPRuntimeBridge"):
		var runtime_bridge = Engine.get_singleton("MCPRuntimeBridge")
		if runtime_bridge != null and runtime_bridge.has_method("set_tool_loader"):
			runtime_bridge.set_tool_loader(self)
	_refresh_runtime_context()


func initialize(disabled_tools: Array = [], force_reload_scripts: bool = false) -> Dictionary:
	var started_usec = Time.get_ticks_usec()
	_force_reload_script_load = force_reload_scripts
	_set_disabled_tools(disabled_tools)
	_reset_state()
	_metrics_service.reset()
	_reset_gdscript_lsp_diagnostics_service()
	_refresh_entries()

	var definition_started = Time.get_ticks_usec()
	for category in _ordered_categories:
		_ensure_tool_definitions(category)
	_metrics_service.set_definition_scan_ms(_elapsed_ms(definition_started))

	var preload_started = Time.get_ticks_usec()
	for category in _ordered_categories:
		if _category_has_enabled_tools(category):
			_ensure_runtime_loaded(category, "preload")
	_metrics_service.set_preload_ms(_elapsed_ms(preload_started))
	_metrics_service.set_startup_ms(_elapsed_ms(started_usec))
	_reload_status = _make_reload_status("initialize")
	_diagnostic_service.sync_load_error_incidents("initialize")
	_refresh_runtime_context()
	_force_reload_script_load = false

	return {
		"tool_count": get_tool_definitions().size(),
		"exposed_tool_count": get_exposed_tool_definitions().size(),
		"category_count": _ordered_categories.size(),
		"tool_load_error_count": _diagnostic_service.get_tool_load_error_count()
	}


func reload_registry(disabled_tools: Array = []) -> Dictionary:
	return initialize(disabled_tools)


func set_disabled_tools(disabled_tools: Array) -> void:
	_set_disabled_tools(disabled_tools)
	for category in _ordered_categories:
		if _category_has_enabled_tools(category):
			_ensure_runtime_loaded(category, "disabled_tools_changed")
		else:
			_unload_runtime(category, "disabled_tools_changed")
	_refresh_runtime_context()


func get_tools_by_category() -> Dictionary:
	var visible := _exposure_service.build_tools_by_category(_ordered_categories, true)
	if visible.is_empty() and not _entries_by_category.is_empty():
		MCPDebugBuffer.record("warning", "tool_loader",
			"Visible tools by category resolved to empty; returning fail-closed visible set")
	return visible


func get_all_tools_by_category() -> Dictionary:
	return _exposure_service.build_tools_by_category(_ordered_categories, false)


func get_tool_definitions() -> Array[Dictionary]:
	var visible := _exposure_service.build_tool_definitions(_ordered_categories, true)
	if visible.is_empty() and not _entries_by_category.is_empty():
		MCPDebugBuffer.record("warning", "tool_loader",
			"Visible tool definitions resolved to empty; returning fail-closed visible set")
	return visible


func get_all_tool_definitions() -> Array[Dictionary]:
	return _exposure_service.build_tool_definitions(_ordered_categories, false)


func get_exposed_tool_definitions() -> Array[Dictionary]:
	return _exposure_service.build_exposed_tool_definitions(_ordered_categories, true)


func is_tool_exposed(tool_name: String) -> bool:
	return _exposure_service.is_tool_exposed(tool_name, _ordered_categories, true)


func get_tool_load_errors() -> Array[Dictionary]:
	return _diagnostic_service.get_tool_load_errors()


func get_domain_states() -> Array[Dictionary]:
	var visible := _exposure_service.build_domain_states(_ordered_categories, true)
	if visible.is_empty() and not _entries_by_category.is_empty():
		MCPDebugBuffer.record("warning", "tool_loader",
			"Visible domain states resolved to empty; returning fail-closed visible set")
	return visible


func get_all_domain_states() -> Array[Dictionary]:
	return _exposure_service.build_domain_states(_ordered_categories, false)


func get_reload_status() -> Dictionary:
	return _reload_status.duplicate(true)


func get_tool_loader_status() -> Dictionary:
	return _exposure_service.build_tool_loader_status(_ordered_categories, _diagnostic_service.get_tool_load_error_count())


func get_performance_summary() -> Dictionary:
	return _metrics_service.build_performance_summary()


func get_tool_usage_stats() -> Array[Dictionary]:
	return _metrics_service.build_tool_usage_stats()


func execute_tool(category: String, tool_name: String, args: Dictionary) -> Dictionary:
	if not _is_category_executable(category):
		MCPDebugBuffer.record("warning", "tool_loader",
			"%s_%s denied: %s" % [category, tool_name, _get_permission_error(category)],
			"%s_%s" % [category, tool_name])
		return _failure("permission_denied", category, tool_name, _get_permission_error(category))

	MCPDebugBuffer.record("debug", "tool_loader",
		"Calling %s_%s (action: %s)" % [category, tool_name, str(args.get("action", ""))],
		"%s_%s" % [category, tool_name])

	var runtime_result = _ensure_runtime_loaded(category, "tool_call")
	if not runtime_result.get("success", false):
		return _failure("tool_load_failed", category, "", str(runtime_result.get("error", "Failed to load tool runtime")))

	var runtime: Dictionary = runtime_result.get("runtime", {})
	var executor = runtime.get("instance")
	if executor == null:
		return _failure("tool_runtime_missing", category, tool_name, "Tool runtime is unavailable")

	var started_usec = Time.get_ticks_usec()
	var result = executor.execute(tool_name, args)
	var elapsed_ms = _elapsed_ms(started_usec)
	_metrics_service.record_tool_call("%s_%s" % [category, tool_name], category, elapsed_ms)

	if result is Dictionary and _as_bool(result.get("success", true)):
		MCPDebugBuffer.record("info", "tool_loader",
			"%s_%s ok (%.0fms)" % [category, tool_name, elapsed_ms],
			"%s_%s" % [category, tool_name])
		return result

	var error_message = "Tool execution failed"
	if result is Dictionary:
		error_message = str(result.get("error", error_message))
		MCPDebugBuffer.record("warning", "tool_loader",
			"%s_%s failed (%.0fms): %s" % [category, tool_name, elapsed_ms, error_message],
			"%s_%s" % [category, tool_name])
		var failure_result: Dictionary = result.duplicate(true)
		var failure_data = failure_result.get("data", {})
		if not (failure_data is Dictionary):
			failure_data = {"details": failure_data}
		failure_data["tool_name"] = "%s_%s" % [category, tool_name]
		failure_data["action"] = str(args.get("action", ""))
		failure_data["error_type"] = str(failure_data.get("error_type", "tool_execution_failed"))
		failure_data["domain"] = category
		failure_data["elapsed_ms"] = elapsed_ms
		failure_data["timestamp_unix"] = int(Time.get_unix_time_from_system())
		failure_result["data"] = failure_data
		return failure_result

	MCPDebugBuffer.record("warning", "tool_loader",
		"%s_%s failed (%.0fms): %s" % [category, tool_name, elapsed_ms, error_message],
		"%s_%s" % [category, tool_name])
	return _failure("tool_execution_failed", category, tool_name, error_message, {
		"action": str(args.get("action", "")),
		"elapsed_ms": elapsed_ms
	})


func tick(delta: float) -> void:
	for category in _runtime_by_category.keys():
		var runtime: Dictionary = _runtime_by_category.get(category, {})
		var executor = runtime.get("instance", null)
		if executor != null and executor.has_method("tick"):
			executor.tick(delta)
		if category == "user":
			_sync_user_tool_runtime_definitions(executor)
			_maybe_unload_idle_user_runtime(executor)
	var diagnostics_service = get_gdscript_lsp_diagnostics_service()
	if diagnostics_service != null and diagnostics_service.has_method("tick"):
		diagnostics_service.tick(delta)


func get_gdscript_lsp_diagnostics_service():
	if _gdscript_lsp_diagnostics_service != null and is_instance_valid(_gdscript_lsp_diagnostics_service):
		return _gdscript_lsp_diagnostics_service
	if Engine.has_singleton("MCPRuntimeBridge"):
		var runtime_bridge = Engine.get_singleton("MCPRuntimeBridge")
		if runtime_bridge != null and runtime_bridge.has_method("get_gdscript_lsp_diagnostics_service"):
			var runtime_service = runtime_bridge.get_gdscript_lsp_diagnostics_service()
			if runtime_service != null and is_instance_valid(runtime_service):
				_gdscript_lsp_diagnostics_service = runtime_service
				return _gdscript_lsp_diagnostics_service
	if _gdscript_lsp_diagnostics_service == null or not is_instance_valid(_gdscript_lsp_diagnostics_service):
		_reset_gdscript_lsp_diagnostics_service()
	return _gdscript_lsp_diagnostics_service


func get_lsp_diagnostics_debug_snapshot() -> Dictionary:
	var service = get_gdscript_lsp_diagnostics_service()
	var snapshot: Dictionary = {
		"has_tool_loader": true,
		"service_available": service != null,
		"service_generation": _gdscript_lsp_diagnostics_generation,
		"tool_loader_status": get_tool_loader_status()
	}
	if service != null and service.has_method("get_debug_snapshot"):
		snapshot["service"] = service.get_debug_snapshot()
	return snapshot


func _reset_gdscript_lsp_diagnostics_service() -> void:
	if _gdscript_lsp_diagnostics_service != null and is_instance_valid(_gdscript_lsp_diagnostics_service):
		if _gdscript_lsp_diagnostics_service.has_method("clear"):
			_gdscript_lsp_diagnostics_service.clear()
	var diagnostics_script = ResourceLoader.load(
		GDScriptLspDiagnosticsServicePath,
		"",
		ResourceLoader.CACHE_MODE_REPLACE
	)
	if diagnostics_script == null:
		_gdscript_lsp_diagnostics_service = null
		return
	_gdscript_lsp_diagnostics_service = diagnostics_script.new()
	_gdscript_lsp_diagnostics_generation += 1
	if Engine.has_singleton("MCPRuntimeBridge"):
		var runtime_bridge = Engine.get_singleton("MCPRuntimeBridge")
		if runtime_bridge != null and runtime_bridge.has_method("set_gdscript_lsp_diagnostics_service"):
			runtime_bridge.set_gdscript_lsp_diagnostics_service(_gdscript_lsp_diagnostics_service)


func _refresh_runtime_context() -> void:
	var context: Dictionary = {
		"tool_loader": self,
		"server": _server_context
	}
	for category in _runtime_by_category.keys():
		var runtime: Dictionary = _runtime_by_category.get(category, {})
		var executor = runtime.get("instance", null)
		if executor != null and executor.has_method("configure_runtime"):
			executor.configure_runtime(context.duplicate(true))


func reload_domain(category: String) -> Dictionary:
	MCPDebugBuffer.record("info", "tool_loader", "Reloading domain: %s" % category)
	var status = _reload_service.reload_domain(category)
	_metrics_service.apply_reload_metrics(status)
	var failed_domains: Array = status.get("failed_domains", [])
	var reloaded_domains: Array = status.get("reloaded_domains", [])
	var skipped_domains: Array = status.get("skipped_domains", [])
	var elapsed_ms = float(status.get("elapsed_ms", 0.0))
	if not failed_domains.is_empty():
		var failure = failed_domains[0] if failed_domains[0] is Dictionary else {}
		MCPDebugBuffer.record("error", "tool_loader",
			"Domain %s reload failed: %s" % [category, str((failure as Dictionary).get("error", "Failed to reload tool domain"))])
	elif not reloaded_domains.is_empty():
		var definition_count = int(status.get("definition_count", 0))
		if bool(status.get("allow_empty_definitions", false)):
			MCPDebugBuffer.record("info", "tool_loader",
				"Domain %s reloaded with no tool definitions (allowed) (%.0fms)" % [category, elapsed_ms])
		else:
			MCPDebugBuffer.record("info", "tool_loader",
				"Domain %s reloaded: %d tools (%.0fms)" % [category, definition_count, elapsed_ms])
	elif not skipped_domains.is_empty() and category != "user":
		MCPDebugBuffer.record("warning", "tool_loader", "Reload skipped for domain: %s" % category)
	return _update_reload_status(_make_reload_status(
		"reload_domain",
		reloaded_domains,
		skipped_domains,
		failed_domains,
		elapsed_ms
	))


func reload_all_domains() -> Dictionary:
	var status = _reload_service.reload_all_domains()
	_metrics_service.apply_reload_metrics(status)
	return _update_reload_status(_make_reload_status(
		"reload_all_domains",
		status.get("reloaded_domains", []),
		status.get("skipped_domains", []),
		status.get("failed_domains", []),
		float(status.get("elapsed_ms", 0.0))
	))


func request_reload_by_script(script_path: String, reason: String = "manual") -> Dictionary:
	var normalized_path = script_path.strip_edges()
	if normalized_path.is_empty():
		return {"success": false, "error": "Missing script path"}
	if not _entries_by_category.has("user"):
		return {"success": false, "error": "User domain is not registered"}
	if not _category_has_enabled_tools("user"):
		_ensure_runtime_loaded("user", "request_reload_by_script")
	var runtime: Dictionary = _runtime_by_category.get("user", {})
	var executor = runtime.get("instance", null)
	if executor == null or not executor.has_method("request_reload_by_script"):
		return {"success": false, "error": "User runtime is unavailable"}
	executor.request_reload_by_script(normalized_path, reason)
	if executor.has_method("tick"):
		executor.tick(0.0)
	_sync_user_tool_runtime_definitions(executor)
	_refresh_runtime_context()
	return {
		"success": true,
		"script_path": normalized_path,
		"reason": reason,
		"runtime_state": executor.get_runtime_state_snapshot() if executor.has_method("get_runtime_state_snapshot") else []
	}


func get_user_tool_runtime_snapshot() -> Array[Dictionary]:
	var runtime: Dictionary = _runtime_by_category.get("user", {})
	var executor = runtime.get("instance", null)
	if executor != null and executor.has_method("get_runtime_state_snapshot"):
		return executor.get_runtime_state_snapshot()
	return []


func get_disabled_tools() -> Array:
	return _disabled_tools.keys()


func is_tool_enabled(tool_name: String) -> bool:
	return not _disabled_tools.has(tool_name)


func _reset_state() -> void:
	_entries_by_category.clear()
	_ordered_categories.clear()
	_runtime_by_category.clear()
	_tool_definitions_by_category.clear()
	_diagnostic_service.clear_load_errors()


func _refresh_entries() -> void:
	_diagnostic_service.clear_load_errors()
	var collected = MCPToolManifest.collect_entries()
	var new_entries: Dictionary = {}
	var new_order: Array[String] = []
	_diagnostic_service.append_load_errors(collected.get("errors", []))
	for entry in collected.get("entries", []):
		var category = str(entry.get("category", ""))
		if category.is_empty():
			continue
		if new_entries.has(category):
			_diagnostic_service.append_duplicate_category_error(
				category,
				str(entry.get("path", "")),
				str(entry.get("source", "builtin"))
			)
			continue
		new_entries[category] = entry.duplicate(true)
		new_order.append(category)

	for existing_category in _runtime_by_category.keys():
		if not new_entries.has(existing_category):
			_runtime_by_category.erase(existing_category)
			_tool_definitions_by_category.erase(existing_category)

	_entries_by_category = new_entries
	_ordered_categories = new_order
	_diagnostic_service.sync_load_error_incidents("refresh_entries")


func _set_disabled_tools(disabled_tools: Array) -> void:
	_disabled_tools.clear()
	for tool_name in disabled_tools:
		_disabled_tools[str(tool_name)] = true


func _get_cached_tool_definitions(category: String) -> Array:
	return _tool_definitions_by_category.get(category, [])


func _get_ordered_categories() -> Array[String]:
	return _ordered_categories.duplicate()


func _has_tool_definitions_cache(category: String) -> bool:
	return _tool_definitions_by_category.has(category)


func _get_entry_by_category(category: String) -> Dictionary:
	return _entries_by_category.get(category, {})


func _get_runtime_by_category(category: String) -> Dictionary:
	return _runtime_by_category.get(category, {})


func _set_runtime_by_category(category: String, runtime: Dictionary) -> void:
	_runtime_by_category[category] = runtime


func _erase_runtime_by_category(category: String) -> void:
	_runtime_by_category.erase(category)


func _set_tool_definitions_by_category(category: String, definitions: Array) -> void:
	_tool_definitions_by_category[category] = definitions


func _erase_tool_definitions_by_category(category: String) -> void:
	_tool_definitions_by_category.erase(category)


func _get_force_reload_script_load() -> bool:
	return _force_reload_script_load


func _ensure_tool_definitions(category: String) -> Array:
	return _runtime_service.ensure_tool_definitions(category)


func _ensure_runtime_loaded(category: String, reason: String) -> Dictionary:
	return _runtime_service.ensure_runtime_loaded(category, reason)


func _instantiate_executor(category: String, force_reload: bool, reason: String) -> Dictionary:
	return _runtime_service.instantiate_executor(category, force_reload, reason)


func _extract_tool_definitions(category: String, executor) -> Array:
	return _runtime_service.extract_tool_definitions(category, executor)


func _record_load_error(category: String, path: String, message: String) -> void:
	var error_info = _diagnostic_service.record_load_error(category, path, message)
	var runtime: Dictionary = _runtime_by_category.get(category, {})
	runtime["last_error"] = error_info
	_runtime_by_category[category] = runtime
	_diagnostic_service.sync_load_error_incidents("record_load_error")


func _count_enabled_tools_in_category(category: String) -> int:
	var count = 0
	for tool_def in _tool_definitions_by_category.get(category, []):
		var full_name = "%s_%s" % [category, str(tool_def.get("name", ""))]
		if is_tool_enabled(full_name):
			count += 1
	return count


func _category_has_enabled_tools(category: String) -> bool:
	return _count_enabled_tools_in_category(category) > 0


func _unload_runtime(category: String, reason: String) -> void:
	_runtime_service.unload_runtime(category, reason)


func _failure(error_type: String, category: String, tool_name: String, message: String, data: Dictionary = {}) -> Dictionary:
	var failure_data = data.duplicate(true)
	failure_data["error_type"] = error_type
	failure_data["domain"] = category
	if tool_name.is_empty():
		failure_data["tool_name"] = category
	else:
		failure_data["tool_name"] = "%s_%s" % [category, tool_name]
	failure_data["timestamp_unix"] = int(Time.get_unix_time_from_system())
	return {
		"success": false,
		"error": message,
		"data": failure_data
	}


func _make_reload_status(action: String, reloaded_domains: Array = [], skipped_domains: Array = [], failed_domains: Array = [], elapsed_ms: float = 0.0) -> Dictionary:
	return {
		"action": action,
		"reloaded_domains": reloaded_domains.duplicate(),
		"skipped_domains": skipped_domains.duplicate(),
		"failed_domains": failed_domains.duplicate(true),
		"elapsed_ms": elapsed_ms,
		"timestamp_unix": int(Time.get_unix_time_from_system()),
		"performance": get_performance_summary()
	}


func _update_reload_status(status: Dictionary) -> Dictionary:
	_reload_status = status.duplicate(true)
	return _reload_status.duplicate(true)


func _elapsed_ms(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0


func _sync_user_tool_runtime_definitions(executor) -> void:
	if executor == null or not executor.has_method("get_tools"):
		return
	var previous_defs = _tool_definitions_by_category.get("user", [])
	var next_defs = _extract_tool_definitions("user", executor)
	if JSON.stringify(previous_defs) == JSON.stringify(next_defs):
		return
	_tool_definitions_by_category["user"] = next_defs
	_refresh_runtime_context()


func _maybe_unload_idle_user_runtime(executor) -> void:
	var runtime: Dictionary = _runtime_by_category.get("user", {})
	var defs: Array = _tool_definitions_by_category.get("user", [])
	if executor == null:
		if defs.is_empty() and not runtime.is_empty():
			_runtime_by_category.erase("user")
			_tool_definitions_by_category.erase("user")
			_refresh_runtime_context()
		return
	if not executor.has_method("should_unload_runtime"):
		return
	if not _as_bool(executor.should_unload_runtime()):
		return
	_runtime_by_category.erase("user")
	_tool_definitions_by_category.erase("user")
	_refresh_runtime_context()


func _get_permission_provider():
	if _server_context == null:
		return null
	if _server_context.has_method("get_plugin_permission_provider"):
		return _server_context.get_plugin_permission_provider()
	if _server_context.has_method("get_parent"):
		return _server_context.get_parent()
	return null


func _is_category_visible(category: String) -> bool:
	var provider = _get_permission_provider()
	if provider != null and provider.has_method("is_tool_category_visible_for_permission"):
		return _as_bool(provider.is_tool_category_visible_for_permission(category))
	return false


func _is_category_executable(category: String) -> bool:
	var provider = _get_permission_provider()
	if provider != null and provider.has_method("is_tool_category_executable_for_permission"):
		return _as_bool(provider.is_tool_category_executable_for_permission(category))
	return false


func _get_permission_error(category: String) -> String:
	var provider = _get_permission_provider()
	if provider != null and provider.has_method("get_permission_denied_message_for_category"):
		return str(provider.get_permission_denied_message_for_category(category))
	return "Current permission level does not allow this tool category"


func _as_bool(value) -> bool:
	if value is bool:
		return value
	if value is int:
		return value != 0
	if value is float:
		return !is_zero_approx(value)
	if value is String:
		var normalized = value.strip_edges().to_lower()
		return normalized == "true" or normalized == "1" or normalized == "yes" or normalized == "on"
	return value != null


func _current_load_state(category: String) -> String:
	var runtime: Dictionary = _runtime_by_category.get(category, {})
	var defs = _tool_definitions_by_category.get(category, [])
	if runtime.has("state"):
		return str(runtime.get("state", "definitions_only"))
	if defs.is_empty():
		return "uninitialized"
	return "definitions_only"
