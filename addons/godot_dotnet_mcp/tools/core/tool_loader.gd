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
const ToolLoaderReloadServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_reload_service.gd")
const ToolLoaderUserReloadServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_user_reload_service.gd")
const ToolLoaderRuntimeStateServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_runtime_state_service.gd")
const ToolLoaderLifecycleServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_lifecycle_service.gd")

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
var _reload_service = ToolLoaderReloadServiceScript.new()
var _user_reload_service = ToolLoaderUserReloadServiceScript.new()
var _runtime_state_service = ToolLoaderRuntimeStateServiceScript.new()
var _lifecycle_service = ToolLoaderLifecycleServiceScript.new()
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
	return _lifecycle_service.initialize(disabled_tools, force_reload_scripts, _build_lifecycle_context())


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
	_lifecycle_service.shutdown(_build_lifecycle_context())


func set_disabled_tools(disabled_tools: Array) -> void:
	_lifecycle_service.set_disabled_tools(disabled_tools, _build_lifecycle_context())


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
	_lifecycle_service.tick(delta, _build_lifecycle_context())


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
	return _reload_service.reload_domain(category, _build_reload_context())


func reload_all_domains() -> Dictionary:
	return _reload_service.reload_all_domains(_build_reload_context())


func request_reload_by_script(script_path: String, reason: String = "manual") -> Dictionary:
	return _user_reload_service.request_reload_by_script(script_path, reason, _build_user_reload_context())


func get_user_tool_runtime_snapshot() -> Array[Dictionary]:
	var snapshot: Array = _user_reload_service.get_user_tool_runtime_snapshot(_build_user_reload_context())
	var typed_snapshot: Array[Dictionary] = []
	for entry in snapshot:
		if entry is Dictionary:
			typed_snapshot.append((entry as Dictionary).duplicate(true))
	return typed_snapshot


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
	return _runtime_state_service.ensure_tool_definitions(category, _build_runtime_state_context())


func _ensure_runtime_loaded(category: String, reason: String) -> Dictionary:
	return _runtime_state_service.ensure_runtime_loaded(category, reason, _build_runtime_state_context())


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
	_runtime_state_service.unload_runtime(category, reason, _build_runtime_state_context())


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


func _build_reload_context() -> Dictionary:
	return {
		"ordered_categories": _ordered_categories,
		"entries_by_category": _entries_by_category,
		"runtime_by_category": _runtime_by_category,
		"tool_definitions_by_category": _tool_definitions_by_category,
		"performance": _performance,
		"get_ordered_categories": Callable(self, "_get_ordered_categories_for_reload"),
		"get_entries_by_category": Callable(self, "_get_entries_by_category_for_reload"),
		"get_runtime_by_category": Callable(self, "_get_runtime_by_category_for_reload"),
		"get_tool_definitions_by_category": Callable(self, "_get_tool_definitions_by_category_for_reload"),
		"get_performance": Callable(self, "_get_performance_for_reload"),
		"refresh_entries": Callable(self, "_refresh_entries"),
		"instantiate_executor": Callable(self, "_instantiate_executor"),
		"extract_tool_definitions": Callable(self, "_extract_tool_definitions"),
		"record_reload_incident": Callable(self, "_record_reload_incident"),
		"sync_load_error_incidents": Callable(self, "_sync_load_error_incidents"),
		"refresh_runtime_context": Callable(self, "_refresh_runtime_context"),
		"reset_gdscript_lsp_diagnostics_service": Callable(self, "_reset_gdscript_lsp_diagnostics_service"),
		"category_has_enabled_tools": Callable(self, "_category_has_enabled_tools"),
		"unload_runtime": Callable(self, "_unload_runtime"),
		"make_reload_status": Callable(self, "_make_reload_status"),
		"update_reload_status": Callable(self, "_update_reload_status"),
		"get_disabled_tools": Callable(self, "get_disabled_tools"),
		"set_disabled_tools": Callable(self, "_set_disabled_tools")
	}


func _build_user_reload_context() -> Dictionary:
	return {
		"entries_by_category": _entries_by_category,
		"runtime_by_category": _runtime_by_category,
		"tool_definitions_by_category": _tool_definitions_by_category,
		"get_entries_by_category": Callable(self, "_get_entries_by_category_for_reload"),
		"get_runtime_by_category": Callable(self, "_get_runtime_by_category_for_reload"),
		"get_tool_definitions_by_category": Callable(self, "_get_tool_definitions_by_category_for_reload"),
		"category_has_enabled_tools": Callable(self, "_category_has_enabled_tools"),
		"ensure_runtime_loaded": Callable(self, "_ensure_runtime_loaded"),
		"tick_loaded_runtimes": Callable(self, "_tick_loaded_runtimes_for_user_reload"),
		"apply_tick_result": Callable(self, "_apply_tick_result"),
		"refresh_runtime_context": Callable(self, "_refresh_runtime_context")
	}


func _tick_loaded_runtimes_for_user_reload(runtime_by_category: Dictionary, definitions_by_category: Dictionary, delta: float) -> Dictionary:
	return _tick_service.tick_loaded_runtimes(
		runtime_by_category,
		definitions_by_category,
		delta,
		Callable(self, "_extract_tool_definitions")
	)


func _tick_loaded_runtimes_for_lifecycle(delta: float) -> Dictionary:
	return _tick_service.tick_loaded_runtimes(
		_runtime_by_category,
		_tool_definitions_by_category,
		delta,
		Callable(self, "_extract_tool_definitions")
	)


func _build_runtime_state_context() -> Dictionary:
	return {
		"entries_by_category": _entries_by_category,
		"runtime_by_category": _runtime_by_category,
		"tool_definitions_by_category": _tool_definitions_by_category,
		"force_reload_script_load": _force_reload_script_load,
		"get_entries_by_category": Callable(self, "_get_entries_by_category_for_reload"),
		"get_runtime_by_category": Callable(self, "_get_runtime_by_category_for_reload"),
		"get_tool_definitions_by_category": Callable(self, "_get_tool_definitions_by_category_for_reload"),
		"get_force_reload_script_load": Callable(self, "_get_force_reload_script_load"),
		"instantiate_executor": Callable(self, "_instantiate_executor"),
		"extract_tool_definitions": Callable(self, "_extract_tool_definitions"),
		"record_load_error": Callable(self, "_record_load_error"),
		"dispose_executor": Callable(self, "_dispose_executor_instance"),
		"failure": Callable(self, "_failure")
	}


func _build_lifecycle_context() -> Dictionary:
	return {
		"ordered_categories": _ordered_categories,
		"runtime_by_category": _runtime_by_category,
		"tool_definitions_by_category": _tool_definitions_by_category,
		"performance": _performance,
		"set_force_reload_script_load": Callable(self, "_set_force_reload_script_load"),
		"get_runtime_by_category": Callable(self, "_get_runtime_by_category_for_reload"),
		"get_tool_definitions_by_category": Callable(self, "_get_tool_definitions_by_category_for_reload"),
		"get_ordered_categories": Callable(self, "_get_ordered_categories_for_reload"),
		"reset_state": Callable(self, "_reset_state"),
		"set_disabled_tools": Callable(self, "_set_disabled_tools"),
		"reset_gdscript_lsp_diagnostics_service": Callable(self, "_reset_gdscript_lsp_diagnostics_service"),
		"dispose_gdscript_lsp_diagnostics_adapter": Callable(self, "_dispose_gdscript_lsp_diagnostics_adapter"),
		"tick_gdscript_lsp_diagnostics": Callable(self, "_tick_gdscript_lsp_diagnostics"),
		"refresh_entries": Callable(self, "_refresh_entries"),
		"ensure_tool_definitions": Callable(self, "_ensure_tool_definitions"),
		"category_has_enabled_tools": Callable(self, "_category_has_enabled_tools"),
		"ensure_runtime_loaded": Callable(self, "_ensure_runtime_loaded"),
		"unload_runtime": Callable(self, "_unload_runtime"),
		"tick_loaded_runtimes": Callable(self, "_tick_loaded_runtimes_for_lifecycle"),
		"make_reload_status": Callable(self, "_make_reload_status"),
		"update_reload_status": Callable(self, "_update_reload_status"),
		"sync_load_error_incidents": Callable(self, "_sync_load_error_incidents"),
		"refresh_runtime_context": Callable(self, "_refresh_runtime_context"),
		"get_tool_definitions": Callable(self, "get_tool_definitions"),
		"get_exposed_tool_definitions": Callable(self, "get_exposed_tool_definitions"),
		"get_tool_load_error_count": Callable(self, "_get_tool_load_error_count")
	}


func _set_force_reload_script_load(enabled: bool) -> void:
	_force_reload_script_load = enabled


func _get_force_reload_script_load() -> bool:
	return _force_reload_script_load


func _get_tool_load_error_count() -> int:
	return _diagnostics_service.get_tool_load_error_count()


func _dispose_gdscript_lsp_diagnostics_adapter() -> void:
	if _tool_lsp_diagnostics_adapter != null and _tool_lsp_diagnostics_adapter.has_method("dispose"):
		_tool_lsp_diagnostics_adapter.dispose()
	_tool_lsp_diagnostics_adapter = null


func _tick_gdscript_lsp_diagnostics(delta: float) -> void:
	var diagnostics_adapter = _ensure_lsp_diagnostics_adapter()
	if diagnostics_adapter != null and diagnostics_adapter.has_method("tick"):
		diagnostics_adapter.tick(delta)


func _get_ordered_categories_for_reload() -> Array:
	return _ordered_categories


func _get_entries_by_category_for_reload() -> Dictionary:
	return _entries_by_category


func _get_runtime_by_category_for_reload() -> Dictionary:
	return _runtime_by_category


func _get_tool_definitions_by_category_for_reload() -> Dictionary:
	return _tool_definitions_by_category


func _get_performance_for_reload() -> Dictionary:
	return _performance


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
