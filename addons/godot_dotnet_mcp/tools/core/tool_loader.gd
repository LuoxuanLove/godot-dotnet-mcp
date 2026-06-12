@tool
extends RefCounted
class_name MCPToolLoader

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const MCPToolRegistry = preload("res://addons/godot_dotnet_mcp/tools/tool_registry.gd")
const ToolLspDiagnosticsAdapterScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_lsp_diagnostics_adapter.gd")
const ToolPublicSurfacePolicyScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_public_surface_policy.gd")
const ToolExecutionObserverScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_execution_observer.gd")
const ToolRuntimeManagerScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_runtime_manager.gd")
const ToolLoaderStatusServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_status_service.gd")
const ToolLoaderDiagnosticsServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_diagnostics_service.gd")
const ToolRegistryEntryServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_registry_entry_service.gd")
const ToolLoaderRuntimeContextServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_runtime_context_service.gd")
const ToolLoaderCatalogProjectionServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_catalog_projection_service.gd")
const ToolExecutionServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_execution_service.gd")
const ToolLoaderTickServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_tick_service.gd")
const ToolLoaderEnablementServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_enablement_service.gd")

var _registry := MCPToolRegistry.new()
var _server_context: Object
var _entries_by_category: Dictionary = {}
var _ordered_categories: Array[String] = []
var _runtime_by_category: Dictionary = {}
var _tool_definitions_by_category: Dictionary = {}
var _tool_lsp_diagnostics_adapter = null
var _public_surface_policy = ToolPublicSurfacePolicyScript.new()
var _execution_observer = ToolExecutionObserverScript.new()
var _runtime_manager = ToolRuntimeManagerScript.new()
var _status_service = ToolLoaderStatusServiceScript.new()
var _diagnostics_service = ToolLoaderDiagnosticsServiceScript.new()
var _entry_service = ToolRegistryEntryServiceScript.new()
var _runtime_context_service = ToolLoaderRuntimeContextServiceScript.new()
var _catalog_projection_service = ToolLoaderCatalogProjectionServiceScript.new()
var _execution_service = ToolExecutionServiceScript.new()
var _tick_service = ToolLoaderTickServiceScript.new()
var _enablement_service = ToolLoaderEnablementServiceScript.new()
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
	_update_reload_status(_make_reload_status("initialize"))
	_sync_load_error_incidents("initialize")
	_refresh_runtime_context()
	_force_reload_script_load = false

	return {
		"tool_count": get_tool_definitions().size(),
		"exposed_tool_count": get_exposed_tool_definitions().size(),
		"category_count": _ordered_categories.size(),
		"tool_load_error_count": _diagnostics_service.get_tool_load_error_count()
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
	return _catalog_projection_service.build_tools_by_category(_build_catalog_projection_context(), visible_only)


func get_tool_definitions() -> Array[Dictionary]:
	var visible := _build_tool_definitions_internal(true)
	if visible.is_empty() and not _entries_by_category.is_empty():
		MCPDebugBuffer.record("warning", "tool_loader",
			"Visible tool definitions resolved to empty; returning fail-closed visible set")
	return visible


func get_all_tool_definitions() -> Array[Dictionary]:
	return _build_tool_definitions_internal(false)


func get_exposed_tool_definitions() -> Array[Dictionary]:
	return _catalog_projection_service.build_exposed_tool_definitions(_build_catalog_projection_context(), get_tool_definitions())


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
	return _catalog_projection_service.build_tool_definitions(_build_catalog_projection_context(), visible_only)


func get_tool_load_errors() -> Array[Dictionary]:
	return _diagnostics_service.get_tool_load_errors()


func get_domain_states() -> Array[Dictionary]:
	var visible := _build_domain_states_internal(true)
	if visible.is_empty() and not _entries_by_category.is_empty():
		MCPDebugBuffer.record("warning", "tool_loader",
			"Visible domain states resolved to empty; returning fail-closed visible set")
	return visible


func get_all_domain_states() -> Array[Dictionary]:
	return _build_domain_states_internal(false)


func _build_domain_states_internal(visible_only: bool) -> Array[Dictionary]:
	return _catalog_projection_service.build_domain_states(_build_catalog_projection_context(), visible_only)


func get_reload_status() -> Dictionary:
	return _diagnostics_service.get_reload_status()


func get_tool_loader_status() -> Dictionary:
	var tool_count := get_tool_definitions().size()
	var exposed_tool_count := get_exposed_tool_definitions().size()
	var category_count := _ordered_categories.size()
	var tool_load_error_count := _diagnostics_service.get_tool_load_error_count()
	return _status_service.build_tool_loader_status(tool_count, exposed_tool_count, category_count, tool_load_error_count)


func get_performance_summary() -> Dictionary:
	return _status_service.build_performance_summary(_performance, _execution_observer.get_tool_call_metrics())


func get_tool_usage_stats() -> Array[Dictionary]:
	return _execution_observer.get_tool_usage_stats()


func execute_tool(category: String, tool_name: String, args: Dictionary) -> Dictionary:
	return _execution_service.execute_tool(category, tool_name, args, _build_execution_context())


func execute_tool_async(category: String, tool_name: String, args: Dictionary) -> Dictionary:
	return await _execution_service.execute_tool_async(category, tool_name, args, _build_execution_context())


func tick(delta: float) -> void:
	var tick_result: Dictionary = _tick_service.tick_loaded_runtimes(
		_runtime_by_category,
		_tool_definitions_by_category,
		delta,
		Callable(self, "_extract_tool_definitions")
	)
	_apply_tick_result(tick_result)
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
	var context: Dictionary = _runtime_context_service.build_runtime_context(
		self,
		_server_context,
		_runtime_context_service.resolve_plugin_host(_server_context),
		_tool_activity_registry
	)
	_runtime_context_service.configure_loaded_runtimes(_runtime_by_category, context)


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
	_apply_tick_result(_tick_service.tick_loaded_runtimes(
		{"user": runtime},
		_tool_definitions_by_category,
		0.0,
		Callable(self, "_extract_tool_definitions")
	))
	if _runtime_by_category.has("user"):
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
	return _enablement_service.get_disabled_tools()


func is_tool_enabled(tool_name: String) -> bool:
	return _enablement_service.is_tool_enabled(tool_name)


func _reset_state() -> void:
	_entries_by_category.clear()
	_ordered_categories.clear()
	_runtime_by_category.clear()
	_tool_definitions_by_category.clear()
	_diagnostics_service.clear_load_errors()


func _refresh_entries() -> void:
	var index: Dictionary = _entry_service.build_index(_registry.collect_entries())
	var new_entries: Dictionary = index.get("entries_by_category", {})
	var new_order: Array[String] = []
	new_order.assign(index.get("ordered_categories", []))
	_diagnostics_service.replace_load_errors(index.get("load_errors", []))

	for existing_category in _runtime_by_category.keys():
		if not new_entries.has(existing_category):
			_runtime_by_category.erase(existing_category)
			_tool_definitions_by_category.erase(existing_category)

	_entries_by_category = new_entries
	_ordered_categories = new_order
	_sync_load_error_incidents("refresh_entries")


func _set_disabled_tools(disabled_tools: Array) -> void:
	_enablement_service.configure_disabled_tools(disabled_tools)


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
	return _runtime_context_service.build_executor_runtime_context(
		self,
		_server_context,
		_runtime_context_service.resolve_plugin_host(_server_context),
		_tool_activity_registry,
		category,
		entry,
		reason
	)


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
	var error_info: Dictionary = _diagnostics_service.record_load_error(category, path, message)
	var runtime: Dictionary = _runtime_by_category.get(category, {})
	runtime["last_error"] = error_info.duplicate(true)
	_runtime_by_category[category] = runtime


func _count_enabled_tools_in_category(category: String) -> int:
	return _enablement_service.count_enabled_tools_in_category(category, _tool_definitions_by_category)


func _category_has_enabled_tools(category: String) -> bool:
	return _enablement_service.category_has_enabled_tools(category, _tool_definitions_by_category)


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
	return _diagnostics_service.update_reload_status(status)


func _elapsed_ms(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0


func _build_catalog_projection_context() -> Dictionary:
	return {
		"ordered_categories": _ordered_categories,
		"entries_by_category": _entries_by_category,
		"runtime_by_category": _runtime_by_category,
		"tool_definitions_by_category": _tool_definitions_by_category,
		"ensure_tool_definitions": Callable(self, "_ensure_tool_definitions"),
		"is_category_visible": Callable(self, "_is_category_visible"),
		"is_tool_enabled": Callable(self, "is_tool_enabled"),
		"is_exposed_tool_definition": Callable(self, "_is_exposed_tool_definition"),
		"is_public_removed_tool_definition": Callable(self, "_is_public_removed_tool_definition")
	}


func _build_execution_context() -> Dictionary:
	return {
		"extract_agent_context": Callable(self, "_extract_agent_context"),
		"is_category_executable": Callable(self, "_is_category_executable"),
		"get_tool_access_error": Callable(self, "_get_tool_access_error"),
		"ensure_runtime_loaded": Callable(self, "_ensure_runtime_loaded"),
		"begin_tool_activity": Callable(self, "_begin_tool_activity"),
		"finalize_tool_execution": Callable(self, "_finalize_tool_execution"),
		"finish_tool_activity": Callable(self, "_finish_tool_activity"),
		"failure": Callable(self, "_failure")
	}


func _apply_tick_result(tick_result: Dictionary) -> void:
	var refresh_context := false
	if bool(tick_result.get("user_definitions_changed", false)):
		_tool_definitions_by_category["user"] = (tick_result.get("user_definitions", []) as Array).duplicate(true)
		refresh_context = true
	if bool(tick_result.get("user_should_unload", false)) and _runtime_by_category.has("user"):
		_runtime_by_category.erase("user")
		_tool_definitions_by_category.erase("user")
		refresh_context = true
	if refresh_context:
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


func _sync_load_error_incidents(phase: String) -> void:
	_diagnostics_service.sync_load_error_incidents(phase)


func _record_reload_incident(category: String, message: String, phase: String) -> void:
	_diagnostics_service.record_reload_incident(
		category,
		str(_entries_by_category.get(category, {}).get("path", "")),
		message,
		phase
	)
