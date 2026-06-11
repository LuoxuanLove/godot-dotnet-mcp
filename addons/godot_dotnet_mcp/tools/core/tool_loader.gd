@tool
extends RefCounted
class_name MCPToolLoader

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const MCPToolRegistry = preload("res://addons/godot_dotnet_mcp/tools/tool_registry.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")
const ToolLspDiagnosticsAdapterScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_lsp_diagnostics_adapter.gd")
const ToolPublicSurfacePolicyScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_public_surface_policy.gd")
const ToolExecutionObserverScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_execution_observer.gd")
const ToolRuntimeManagerScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_runtime_manager.gd")
const ToolLoaderStatusServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_status_service.gd")
const ToolRegistryEntryServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_registry_entry_service.gd")

var _registry := MCPToolRegistry.new()
var _server_context: Object
var _entries_by_category: Dictionary = {}
var _ordered_categories: Array[String] = []
var _runtime_by_category: Dictionary = {}
var _tool_definitions_by_category: Dictionary = {}
var _disabled_tools: Dictionary = {}
var _load_errors: Array[Dictionary] = []
var _reload_status: Dictionary = {}
var _tool_lsp_diagnostics_adapter = null
var _public_surface_policy = ToolPublicSurfacePolicyScript.new()
var _execution_observer = ToolExecutionObserverScript.new()
var _runtime_manager = ToolRuntimeManagerScript.new()
var _status_service = ToolLoaderStatusServiceScript.new()
var _entry_service = ToolRegistryEntryServiceScript.new()
var _force_reload_script_load := false
var _tool_activity_registry = null
var _performance: Dictionary = {
	"startup_ms": 0.0,
	"definition_scan_ms": 0.0,
	"preload_ms": 0.0,
	"reload_total_ms": 0.0,
	"reload_count": 0
}


func _init() -> void:
	_runtime_manager.configure(Callable(self, "_build_executor_runtime_context"))


func configure(server_context: Object) -> void:
	_server_context = server_context
	_runtime_manager.configure(Callable(self, "_build_executor_runtime_context"))
	if Engine.has_singleton("MCPRuntimeBridge"):
		var runtime_bridge = Engine.get_singleton("MCPRuntimeBridge")
		if runtime_bridge != null and runtime_bridge.has_method("set_tool_loader"):
			runtime_bridge.set_tool_loader(self)
	_ensure_lsp_diagnostics_adapter()
	_refresh_runtime_context()


func initialize(disabled_tools: Array = [], force_reload_scripts: bool = false) -> Dictionary:
	var started_usec = Time.get_ticks_usec()
	_force_reload_script_load = force_reload_scripts
	_set_disabled_tools(disabled_tools)
	_reset_state()
	_reset_gdscript_lsp_diagnostics_service()
	_refresh_entries()

	var definition_started = Time.get_ticks_usec()
	for category in _ordered_categories:
		_ensure_tool_definitions(category)
	_performance["definition_scan_ms"] = _elapsed_ms(definition_started)

	var preload_started = Time.get_ticks_usec()
	for category in _ordered_categories:
		if _category_has_enabled_tools(category):
			_ensure_runtime_loaded(category, "preload")
	_performance["preload_ms"] = _elapsed_ms(preload_started)
	_performance["startup_ms"] = _elapsed_ms(started_usec)
	_reload_status = _make_reload_status("initialize")
	_sync_load_error_incidents("initialize")
	_refresh_runtime_context()
	_force_reload_script_load = false

	return {
		"tool_count": get_tool_definitions().size(),
		"exposed_tool_count": get_exposed_tool_definitions().size(),
		"category_count": _ordered_categories.size(),
		"tool_load_error_count": _load_errors.size()
	}


func set_tool_activity_registry(registry) -> void:
	if _tool_activity_registry == registry:
		return
	_tool_activity_registry = registry
	_execution_observer.set_activity_registry(registry)
	_refresh_runtime_context()


func get_tool_activity_registry():
	return _tool_activity_registry


func reload_registry(disabled_tools: Array = []) -> Dictionary:
	return initialize(disabled_tools)


func shutdown() -> void:
	for category in _runtime_by_category.keys():
		_unload_runtime(str(category), "shutdown")
	if _tool_lsp_diagnostics_adapter != null and _tool_lsp_diagnostics_adapter.has_method("dispose"):
		_tool_lsp_diagnostics_adapter.dispose()
	_tool_lsp_diagnostics_adapter = null
	_force_reload_script_load = false
	_reset_state()


func set_disabled_tools(disabled_tools: Array) -> void:
	_set_disabled_tools(disabled_tools)
	for category in _ordered_categories:
		if _category_has_enabled_tools(category):
			_ensure_runtime_loaded(category, "disabled_tools_changed")
		else:
			_unload_runtime(category, "disabled_tools_changed")
	_refresh_runtime_context()


func get_tools_by_category() -> Dictionary:
	var visible := _build_tools_by_category_internal(true)
	if visible.is_empty() and not _entries_by_category.is_empty():
		MCPDebugBuffer.record("warning", "tool_loader",
			"Visible tools by category resolved to empty; returning fail-closed visible set")
	return visible


func get_all_tools_by_category() -> Dictionary:
	return _build_tools_by_category_internal(false)


func _build_tools_by_category_internal(visible_only: bool) -> Dictionary:
	var result: Dictionary = {}
	for category in _ordered_categories:
		if visible_only and not _is_category_visible(category):
			continue
		var defs = _ensure_tool_definitions(category)
		if defs.is_empty():
			continue
		var decorated_defs: Array[Dictionary] = []
		for tool_def in defs:
			var decorated_def := _decorate_tool_definition(category, tool_def)
			if _is_public_removed_tool_definition(decorated_def):
				continue
			decorated_defs.append(decorated_def)
		if decorated_defs.is_empty():
			continue
		result[category] = decorated_defs
	return result


func get_tool_definitions() -> Array[Dictionary]:
	var visible := _build_tool_definitions_internal(true)
	if visible.is_empty() and not _entries_by_category.is_empty():
		MCPDebugBuffer.record("warning", "tool_loader",
			"Visible tool definitions resolved to empty; returning fail-closed visible set")
	return visible


func get_all_tool_definitions() -> Array[Dictionary]:
	return _build_tool_definitions_internal(false)


func get_exposed_tool_definitions() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for tool_def in get_tool_definitions():
		if not _is_exposed_tool_definition(tool_def):
			continue
		if not _as_bool(tool_def.get("enabled", true)):
			continue
		definitions.append((tool_def as Dictionary).duplicate(true))
	return definitions


func is_tool_exposed(tool_name: String) -> bool:
	if _is_callable_removed_public_tool(tool_name):
		return true
	for tool_def in get_exposed_tool_definitions():
		if str(tool_def.get("name", "")) == tool_name:
			return true
	if _is_callable_removed_public_tool(tool_name):
		return true
	return _is_callable_compatibility_alias(tool_name)


func is_public_removed_tool(tool_name: String) -> bool:
	return _public_surface_policy.is_public_removed_tool(tool_name)


func build_removed_public_tool_result(tool_name: String, arguments: Dictionary = {}) -> Dictionary:
	return _public_surface_policy.build_removed_public_tool_result(tool_name, arguments)


func _build_tool_definitions_internal(visible_only: bool) -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for category in _ordered_categories:
		if visible_only and not _is_category_visible(category):
			continue
		for tool_def in _ensure_tool_definitions(category):
			var full_def = _decorate_tool_definition(category, tool_def)
			full_def["name"] = "%s_%s" % [category, str(tool_def.get("name", ""))]
			full_def["category"] = category
			definitions.append(full_def)
	return definitions


func get_tool_load_errors() -> Array[Dictionary]:
	return _load_errors.duplicate(true)


func get_domain_states() -> Array[Dictionary]:
	var visible := _build_domain_states_internal(true)
	if visible.is_empty() and not _entries_by_category.is_empty():
		MCPDebugBuffer.record("warning", "tool_loader",
			"Visible domain states resolved to empty; returning fail-closed visible set")
	return visible


func get_all_domain_states() -> Array[Dictionary]:
	return _build_domain_states_internal(false)


func _build_domain_states_internal(visible_only: bool) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for category in _ordered_categories:
		if visible_only and not _is_category_visible(category):
			continue
		var entry: Dictionary = _entries_by_category.get(category, {})
		var runtime: Dictionary = _runtime_by_category.get(category, {})
		var defs = _tool_definitions_by_category.get(category, [])
		states.append({
			"domain": category,
			"category": category,
			"domain_key": str(entry.get("domain_key", "other")),
			"source": str(entry.get("source", "builtin")),
			"script_path": str(entry.get("path", "")),
			"hot_reloadable": _as_bool(entry.get("hot_reloadable", true)),
			"loaded": runtime.get("instance", null) != null,
			"load_state": _current_load_state(category),
			"tool_count": defs.size(),
			"enabled_tool_count": _count_enabled_tools_in_category(category),
			"version": int(runtime.get("version", 0)),
			"load_count": int(runtime.get("load_count", 0)),
			"last_loaded_at_unix": int(runtime.get("last_loaded_at_unix", 0)),
			"last_error": runtime.get("last_error", null)
		})
	return states


func get_reload_status() -> Dictionary:
	return _reload_status.duplicate(true)


func get_tool_loader_status() -> Dictionary:
	var tool_count := get_tool_definitions().size()
	var exposed_tool_count := get_exposed_tool_definitions().size()
	var category_count := _ordered_categories.size()
	var tool_load_error_count := _load_errors.size()
	return _status_service.build_tool_loader_status(tool_count, exposed_tool_count, category_count, tool_load_error_count)


func get_performance_summary() -> Dictionary:
	return _status_service.build_performance_summary(_performance, _execution_observer.get_tool_call_metrics())


func get_tool_usage_stats() -> Array[Dictionary]:
	return _execution_observer.get_tool_usage_stats()


func execute_tool(category: String, tool_name: String, args: Dictionary) -> Dictionary:
	var execution_args := args.duplicate(true)
	var agent_context := _extract_agent_context(execution_args)
	if not _is_category_executable(category):
		MCPDebugBuffer.record("warning", "tool_loader",
			"%s_%s denied: %s" % [category, tool_name, _get_tool_access_error(category)],
			"%s_%s" % [category, tool_name])
		return _failure("tool_access_denied", category, tool_name, _get_tool_access_error(category))

	MCPDebugBuffer.record("debug", "tool_loader",
		"Calling %s_%s (action: %s)" % [category, tool_name, str(execution_args.get("action", ""))],
		"%s_%s" % [category, tool_name])

	var runtime_result = _ensure_runtime_loaded(category, "tool_call")
	if not runtime_result.get("success", false):
		return runtime_result

	var runtime: Dictionary = runtime_result.get("runtime", {})
	var executor = runtime.get("instance")
	if executor == null:
		return _failure("tool_runtime_missing", category, tool_name, "Tool runtime is unavailable")

	var started_usec = Time.get_ticks_usec()
	var activity_record := _begin_tool_activity(category, tool_name, execution_args, agent_context)
	var result = executor.execute(tool_name, execution_args)
	result = _finalize_tool_execution(category, tool_name, execution_args, started_usec, result)
	return _finish_tool_activity(result, activity_record)


func execute_tool_async(category: String, tool_name: String, args: Dictionary) -> Dictionary:
	var execution_args := args.duplicate(true)
	var agent_context := _extract_agent_context(execution_args)
	if not _is_category_executable(category):
		MCPDebugBuffer.record("warning", "tool_loader",
			"%s_%s denied: %s" % [category, tool_name, _get_tool_access_error(category)],
			"%s_%s" % [category, tool_name])
		return _failure("tool_access_denied", category, tool_name, _get_tool_access_error(category))

	MCPDebugBuffer.record("debug", "tool_loader",
		"Calling %s_%s (action: %s)" % [category, tool_name, str(execution_args.get("action", ""))],
		"%s_%s" % [category, tool_name])

	var runtime_result = _ensure_runtime_loaded(category, "tool_call")
	if not runtime_result.get("success", false):
		return runtime_result

	var runtime: Dictionary = runtime_result.get("runtime", {})
	var executor = runtime.get("instance")
	if executor == null:
		return _failure("tool_runtime_missing", category, tool_name, "Tool runtime is unavailable")

	var started_usec = Time.get_ticks_usec()
	var activity_record := _begin_tool_activity(category, tool_name, execution_args, agent_context)
	var result
	if executor.has_method("execute_async"):
		result = await executor.execute_async(tool_name, execution_args)
	else:
		result = executor.execute(tool_name, execution_args)
	result = _finalize_tool_execution(category, tool_name, execution_args, started_usec, result)
	return _finish_tool_activity(result, activity_record)


func tick(delta: float) -> void:
	for category in _runtime_by_category.keys():
		var runtime: Dictionary = _runtime_by_category.get(category, {})
		var executor = runtime.get("instance", null)
		if executor != null and executor.has_method("tick"):
			executor.tick(delta)
		if category == "user":
			_sync_user_tool_runtime_definitions(executor)
			_maybe_unload_idle_user_runtime(executor)
	var diagnostics_adapter = _ensure_lsp_diagnostics_adapter()
	if diagnostics_adapter != null and diagnostics_adapter.has_method("tick"):
		diagnostics_adapter.tick(delta)


func get_gdscript_lsp_diagnostics_service():
	var diagnostics_adapter = _ensure_lsp_diagnostics_adapter()
	if diagnostics_adapter != null and diagnostics_adapter.has_method("get_service"):
		return diagnostics_adapter.get_service()
	return null


func get_lsp_diagnostics_debug_snapshot() -> Dictionary:
	var diagnostics_adapter = _ensure_lsp_diagnostics_adapter()
	if diagnostics_adapter != null and diagnostics_adapter.has_method("get_debug_snapshot"):
		return diagnostics_adapter.get_debug_snapshot(get_tool_loader_status())
	return {
		"has_tool_loader": true,
		"service_available": false,
		"service_generation": 0,
		"tool_loader_status": get_tool_loader_status()
	}


func _reset_gdscript_lsp_diagnostics_service() -> void:
	var diagnostics_adapter = _ensure_lsp_diagnostics_adapter()
	if diagnostics_adapter != null and diagnostics_adapter.has_method("reset"):
		diagnostics_adapter.reset()


func _ensure_lsp_diagnostics_adapter():
	if _tool_lsp_diagnostics_adapter == null:
		_tool_lsp_diagnostics_adapter = ToolLspDiagnosticsAdapterScript.new()
	if _tool_lsp_diagnostics_adapter != null and _tool_lsp_diagnostics_adapter.has_method("configure"):
		_tool_lsp_diagnostics_adapter.configure(self, {
			"runtime_bridge": _get_runtime_bridge()
		})
	return _tool_lsp_diagnostics_adapter


func _get_runtime_bridge():
	if Engine.has_singleton("MCPRuntimeBridge"):
		return Engine.get_singleton("MCPRuntimeBridge")
	return null


func _refresh_runtime_context() -> void:
	var context: Dictionary = {
		"tool_loader": self,
		"server": _server_context,
		"plugin_host": _get_plugin_host(),
		"tool_activity_registry": _tool_activity_registry
	}
	for category in _runtime_by_category.keys():
		var runtime: Dictionary = _runtime_by_category.get(category, {})
		var executor = runtime.get("instance", null)
		if executor != null and executor.has_method("configure_runtime"):
			executor.configure_runtime(context.duplicate())


func reload_domain(category: String) -> Dictionary:
	MCPDebugBuffer.record("info", "tool_loader", "Reloading domain: %s" % category)
	if category == "user":
		_refresh_entries()

	if not _entries_by_category.has(category):
		if category == "user":
			return _update_reload_status(_make_reload_status("reload_domain", [], [category], []))
		MCPDebugBuffer.record("warning", "tool_loader", "Unknown domain: %s" % category)
		return _update_reload_status(_make_reload_status("reload_domain", [], [], [{
			"domain": category,
			"error": "Unknown tool domain"
		}]))

	var entry: Dictionary = _entries_by_category.get(category, {})
	if not (true if entry.get("hot_reloadable", true) else false):
		return _update_reload_status(_make_reload_status("reload_domain", [], [category], []))

	var old_runtime: Dictionary = _runtime_by_category.get(category, {}).duplicate(true)
	var definitions_before = _tool_definitions_by_category.get(category, []).duplicate(true)
	var reload_started = Time.get_ticks_usec()

	var instantiate_result = _instantiate_executor(category, true, "reload")
	if not instantiate_result.get("success", false):
		var reload_err := str(instantiate_result.get("error", "Failed to reload tool domain"))
		MCPDebugBuffer.record("error", "tool_loader",
			"Domain %s reload failed: %s" % [category, reload_err])
		_record_reload_incident(category, reload_err, "reload_domain")
		if not old_runtime.is_empty():
			_runtime_by_category[category] = old_runtime
		if not definitions_before.is_empty():
			_tool_definitions_by_category[category] = definitions_before
		return _update_reload_status(_make_reload_status("reload_domain", [], [], [{
			"domain": category,
			"error": reload_err
		}], _elapsed_ms(reload_started)))

	var executor = instantiate_result.get("executor")
	var version = int(old_runtime.get("version", 0)) + 1
	var allow_empty_definitions = true if entry.get("allow_empty_definitions", false) else false
	_runtime_by_category[category] = {
		"instance": executor,
		"state": "loaded",
		"version": version,
		"load_count": int(old_runtime.get("load_count", 0)) + 1,
		"last_loaded_at_unix": int(Time.get_unix_time_from_system()),
		"last_error": null
	}
	var definitions = _extract_tool_definitions(category, executor)
	if definitions.is_empty():
		if allow_empty_definitions:
			_tool_definitions_by_category[category] = []
			_sync_load_error_incidents("reload_domain")
			_performance["reload_total_ms"] = float(_performance.get("reload_total_ms", 0.0)) + _elapsed_ms(reload_started)
			_performance["reload_count"] = int(_performance.get("reload_count", 0)) + 1
			MCPDebugBuffer.record("info", "tool_loader",
				"Domain %s reloaded with no tool definitions (allowed) (%.0fms)" % [category, _elapsed_ms(reload_started)])
			_refresh_runtime_context()
			_reset_gdscript_lsp_diagnostics_service()
			if not _category_has_enabled_tools(category):
				_unload_runtime(category, "reload_completed_disabled")
			return _update_reload_status(_make_reload_status("reload_domain", [category], [], [], _elapsed_ms(reload_started)))
		_record_reload_incident(category, "Reloaded tool domain did not expose any tool definitions", "reload_domain")
		if not old_runtime.is_empty():
			_runtime_by_category[category] = old_runtime
		if not definitions_before.is_empty():
			_tool_definitions_by_category[category] = definitions_before
		return _update_reload_status(_make_reload_status("reload_domain", [], [], [{
			"domain": category,
			"error": "Reloaded tool domain did not expose any tool definitions"
		}], _elapsed_ms(reload_started)))

	_tool_definitions_by_category[category] = definitions
	_sync_load_error_incidents("reload_domain")
	_performance["reload_total_ms"] = float(_performance.get("reload_total_ms", 0.0)) + _elapsed_ms(reload_started)
	_performance["reload_count"] = int(_performance.get("reload_count", 0)) + 1

	MCPDebugBuffer.record("info", "tool_loader",
		"Domain %s reloaded: %d tools (%.0fms)" % [category, definitions.size(), _elapsed_ms(reload_started)])

	_refresh_runtime_context()
	_reset_gdscript_lsp_diagnostics_service()
	if not _category_has_enabled_tools(category):
		_unload_runtime(category, "reload_completed_disabled")

	return _update_reload_status(_make_reload_status("reload_domain", [category], [], [], _elapsed_ms(reload_started)))


func reload_all_domains() -> Dictionary:
	var started_usec = Time.get_ticks_usec()
	var disabled_tools = get_disabled_tools()
	_refresh_entries()
	_set_disabled_tools(disabled_tools)

	var reloaded: Array = []
	var skipped: Array = []
	var failed: Array = []
	for category in _ordered_categories:
		var entry: Dictionary = _entries_by_category.get(category, {})
		if not _as_bool(entry.get("hot_reloadable", true)):
			skipped.append(category)
			continue
		var status = reload_domain(category)
		reloaded.append_array(status.get("reloaded_domains", []))
		skipped.append_array(status.get("skipped_domains", []))
		failed.append_array(status.get("failed_domains", []))
	_sync_load_error_incidents("reload_all_domains")
	_refresh_runtime_context()
	_reset_gdscript_lsp_diagnostics_service()

	return _update_reload_status(_make_reload_status("reload_all_domains", reloaded, skipped, failed, _elapsed_ms(started_usec)))


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
	_load_errors.clear()


func _refresh_entries() -> void:
	var index: Dictionary = _entry_service.build_index(_registry.collect_entries())
	var new_entries: Dictionary = index.get("entries_by_category", {})
	var new_order: Array[String] = []
	new_order.assign(index.get("ordered_categories", []))
	_load_errors.clear()
	_load_errors.assign(index.get("load_errors", []))

	for existing_category in _runtime_by_category.keys():
		if not new_entries.has(existing_category):
			_runtime_by_category.erase(existing_category)
			_tool_definitions_by_category.erase(existing_category)

	_entries_by_category = new_entries
	_ordered_categories = new_order
	_sync_load_error_incidents("refresh_entries")


func _set_disabled_tools(disabled_tools: Array) -> void:
	_disabled_tools.clear()
	for tool_name in disabled_tools:
		_disabled_tools[str(tool_name)] = true


func _ensure_tool_definitions(category: String) -> Array:
	if _tool_definitions_by_category.has(category):
		return _tool_definitions_by_category[category]

	var runtime: Dictionary = _runtime_by_category.get(category, {})
	var executor = runtime.get("instance", null)
	if executor == null:
		var instantiate_result = _instantiate_executor(category, _force_reload_script_load, "definitions")
		if not instantiate_result.get("success", false):
			_record_load_error(category, str(_entries_by_category.get(category, {}).get("path", "")), str(instantiate_result.get("error", "Failed to load tool definitions")))
			_tool_definitions_by_category[category] = []
			return []
		executor = instantiate_result.get("executor")

	var definitions = _extract_tool_definitions(category, executor)
	_tool_definitions_by_category[category] = definitions
	return definitions


func _ensure_runtime_loaded(category: String, reason: String) -> Dictionary:
	var runtime: Dictionary = _runtime_by_category.get(category, {})
	if runtime.get("instance", null) != null:
		return {"success": true, "runtime": runtime}

	var instantiate_result = _instantiate_executor(category, false, reason)
	if _force_reload_script_load:
		instantiate_result = _instantiate_executor(category, true, reason)
	if not instantiate_result.get("success", false):
		return _failure("tool_load_failed", category, "", str(instantiate_result.get("error", "Failed to load tool runtime")))

	var executor = instantiate_result.get("executor")
	var version = int(runtime.get("version", 0))
	if version <= 0:
		version = 1
	else:
		version += 1

	var runtime_state := "loaded"
	if reason == "tool_call":
		runtime_state = "loaded_on_demand"

	runtime = {
		"instance": executor,
		"state": runtime_state,
		"version": version,
		"load_count": int(runtime.get("load_count", 0)) + 1,
		"last_loaded_at_unix": int(Time.get_unix_time_from_system()),
		"last_error": null
	}
	_runtime_by_category[category] = runtime
	_tool_definitions_by_category[category] = _extract_tool_definitions(category, executor)
	return {"success": true, "runtime": runtime}


func _instantiate_executor(category: String, force_reload: bool, reason: String) -> Dictionary:
	var entry: Dictionary = _entries_by_category.get(category, {})
	return _runtime_manager.instantiate_executor(category, entry, force_reload, reason)


func _build_executor_runtime_context(category: String, entry: Dictionary, reason: String) -> Dictionary:
	return {
		"tool_loader": self,
		"server": _server_context,
		"plugin_host": _get_plugin_host(),
		"tool_activity_registry": _tool_activity_registry,
		"category": category,
		"reason": reason,
		"entry": entry.duplicate(true)
	}


func _get_plugin_host():
	if _server_context != null and is_instance_valid(_server_context) and _server_context.has_method("get_parent"):
		var plugin = _server_context.get_parent()
		if plugin != null and is_instance_valid(plugin):
			return plugin
	return null


func _finalize_tool_execution(category: String, tool_name: String, args: Dictionary, started_usec: int, result) -> Dictionary:
	return _execution_observer.finalize_tool_execution(category, tool_name, args, started_usec, result)


func _extract_agent_context(args: Dictionary) -> Dictionary:
	var context := {}
	if args.get("_mcp_context", null) is Dictionary:
		context = (args.get("_mcp_context", {}) as Dictionary).duplicate(true)
	args.erase("_mcp_context")
	return context


func _begin_tool_activity(category: String, tool_name: String, args: Dictionary, agent_context: Dictionary) -> Dictionary:
	return _execution_observer.begin_tool_activity(category, tool_name, args, agent_context)


func _finish_tool_activity(result: Dictionary, activity_record: Dictionary) -> Dictionary:
	return _execution_observer.finish_tool_activity(result, activity_record)


func _reload_script_dependency_chain(_script_resource: Script, _visited: Dictionary) -> void:
	pass

	# Only reload this script if it has GDScript dependencies (parent class or Script
	# constants) that were themselves reloaded and whose class IDs may have changed.
	# Scripts with only built-in base classes and no Script constants are already fresh
	# from CACHE_MODE_IGNORE and do not need reload() — calling it would corrupt them.


func _extract_tool_definitions(category: String, executor) -> Array:
	return _runtime_manager.extract_tool_definitions(executor)


func _record_load_error(category: String, path: String, message: String) -> void:
	var error_info = {
		"category": category,
		"path": path,
		"message": message
	}
	_load_errors.append(error_info)
	var runtime: Dictionary = _runtime_by_category.get(category, {})
	runtime["last_error"] = error_info
	_runtime_by_category[category] = runtime
	_sync_load_error_incidents("record_load_error")


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
	if not _runtime_by_category.has(category):
		return
	var runtime: Dictionary = _runtime_by_category.get(category, {})
	var executor = runtime.get("instance", null)
	_dispose_executor_instance(executor)
	runtime["instance"] = null
	runtime["state"] = "definitions_only"
	runtime["last_unloaded_reason"] = reason
	_runtime_by_category[category] = runtime


func _dispose_executor_instance(executor) -> void:
	_runtime_manager.dispose_executor(executor)


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
	return _status_service.make_reload_status(action, get_performance_summary(), reloaded_domains, skipped_domains, failed_domains, elapsed_ms)


func _update_reload_status(status: Dictionary) -> Dictionary:
	_reload_status = status.duplicate(true)
	return _reload_status.duplicate(true)


func _elapsed_ms(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0


func _decorate_tool_definition(category: String, tool_def: Dictionary) -> Dictionary:
	var decorated = tool_def.duplicate(true)
	var entry: Dictionary = _entries_by_category.get(category, {})
	var full_name = "%s_%s" % [category, str(tool_def.get("name", ""))]
	decorated["category"] = category
	decorated["full_name"] = full_name
	decorated["enabled"] = is_tool_enabled(full_name)
	decorated["load_state"] = _current_load_state(category)
	decorated["source"] = str(decorated.get("source", str(entry.get("source", "builtin"))))
	decorated["domain_script_path"] = str(entry.get("path", ""))
	decorated["script_path"] = str(decorated.get("script_path", str(entry.get("path", ""))))
	decorated["domain_key"] = str(entry.get("domain_key", "other"))
	return decorated


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


func _is_exposed_tool_definition(tool_def: Dictionary) -> bool:
	return _public_surface_policy.is_exposed_tool_definition(tool_def)


func _is_public_removed_tool_definition(tool_def: Dictionary) -> bool:
	return _public_surface_policy.is_public_removed_tool_definition(tool_def)


func _is_callable_removed_public_tool(tool_name: String) -> bool:
	return _public_surface_policy.is_callable_removed_public_tool(tool_name, get_tool_definitions(), Callable(self, "is_tool_enabled"))


func _is_callable_compatibility_alias(tool_name: String) -> bool:
	return _public_surface_policy.is_callable_compatibility_alias(tool_name, get_tool_definitions(), Callable(self, "is_tool_enabled"))


func _is_exposed_tool_category(category: String) -> bool:
	return _public_surface_policy.is_exposed_tool_category(category)


func _get_tool_access_provider():
	if _server_context == null:
		return null
	if _server_context.has_method("get_tool_access_provider"):
		return _server_context.get_tool_access_provider()
	if _server_context.has_method("get_parent"):
		return _server_context.get_parent()
	return null


func _is_category_visible(category: String) -> bool:
	var provider = _get_tool_access_provider()
	if provider != null and provider.has_method("is_tool_category_visible"):
		return _as_bool(provider.is_tool_category_visible(category))
	return true


func _is_category_executable(category: String) -> bool:
	var provider = _get_tool_access_provider()
	if provider != null and provider.has_method("is_tool_category_executable"):
		return _as_bool(provider.is_tool_category_executable(category))
	return true


func _get_tool_access_error(category: String) -> String:
	var provider = _get_tool_access_provider()
	if provider != null and provider.has_method("get_tool_access_denied_message"):
		return str(provider.get_tool_access_denied_message(category))
	return "Tool category is disabled."


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


func _sync_load_error_incidents(phase: String) -> void:
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


func _record_reload_incident(category: String, message: String, phase: String) -> void:
	PluginSelfDiagnosticStore.record_incident(
		"error",
		"reload_conflict",
		"tool_reload_failed",
		message,
		"tool_loader",
		phase,
		str(_entries_by_category.get(category, {}).get("path", "")),
		"",
		"",
		true,
		"Inspect the last reload status and the failing tool domain script.",
		{
			"category": category
		}
	)
