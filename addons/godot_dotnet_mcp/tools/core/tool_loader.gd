@tool
extends RefCounted
class_name MCPToolLoader

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const MCPToolRegistry = preload("res://addons/godot_dotnet_mcp/tools/tool_registry.gd")
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
const ToolLoaderStateStoreScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_state_store.gd")
const ToolLoaderAccessServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_access_service.gd")
const ToolLoaderLspDiagnosticsServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_lsp_diagnostics_service.gd")
const ToolLoaderExecutionContextServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_execution_context_service.gd")
const ToolLoaderContextServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_context_service.gd")

var _registry := MCPToolRegistry.new()
var _server_context: Object
var _state_store = ToolLoaderStateStoreScript.new()
var _entries_by_category: Dictionary = {}
var _ordered_categories: Array[String] = []
var _runtime_by_category: Dictionary = {}
var _tool_definitions_by_category: Dictionary = {}
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
var _access_service = ToolLoaderAccessServiceScript.new()
var _lsp_diagnostics_service = ToolLoaderLspDiagnosticsServiceScript.new()
var _execution_context_service = ToolLoaderExecutionContextServiceScript.new()
var _context_service = ToolLoaderContextServiceScript.new()
var _tool_activity_registry = null
var _performance: Dictionary = {}


func _init() -> void:
	_bind_state_refs()
	_runtime_manager.configure(Callable(self, "_build_executor_runtime_context"))
	_lsp_diagnostics_service.configure(self)
	_execution_context_service.configure(_execution_observer)
	_context_service.configure(_state_store)
	_context_service.configure_loader(self, _execution_context_service)


func _bind_state_refs() -> void:
	_entries_by_category = _state_store.entries_by_category
	_ordered_categories = _state_store.ordered_categories
	_runtime_by_category = _state_store.runtime_by_category
	_tool_definitions_by_category = _state_store.tool_definitions_by_category
	_performance = _state_store.performance


func configure(server_context: Object) -> void:
	_server_context = server_context
	_runtime_manager.configure(Callable(self, "_build_executor_runtime_context"))
	if Engine.has_singleton("MCPRuntimeBridge"):
		var runtime_bridge = Engine.get_singleton("MCPRuntimeBridge")
		if runtime_bridge != null and runtime_bridge.has_method("set_tool_loader"):
			runtime_bridge.set_tool_loader(self)
	_lsp_diagnostics_service.configure(self)
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
	return _lsp_diagnostics_service.get_service()


func get_lsp_diagnostics_debug_snapshot() -> Dictionary:
	return _lsp_diagnostics_service.get_debug_snapshot(get_tool_loader_status())


func _reset_gdscript_lsp_diagnostics_service() -> void:
	_lsp_diagnostics_service.reset()


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
	_state_store.reset(_diagnostics_service)


func _refresh_entries() -> void:
	_state_store.refresh_entries(_registry, _entry_service, _diagnostics_service, Callable(self, "_sync_load_error_incidents"))


func _set_disabled_tools(disabled_tools: Array) -> void:
	_enablement_service.configure_disabled_tools(disabled_tools)


func _ensure_tool_definitions(category: String) -> Array:
	return _runtime_state_service.ensure_tool_definitions(category, _build_runtime_state_context())


func _ensure_runtime_loaded(category: String, reason: String) -> Dictionary:
	return _runtime_state_service.ensure_runtime_loaded(category, reason, _build_runtime_state_context())


func _instantiate_executor(category: String, force_reload: bool, reason: String) -> Dictionary:
	var entry: Dictionary = _state_store.entry_for(category)
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


func _reload_script_dependency_chain(_script_resource: Script, _visited: Dictionary) -> void:
	pass

	# Only reload this script if it has GDScript dependencies (parent class or Script
	# constants) that were themselves reloaded and whose class IDs may have changed.
	# Scripts with only built-in base classes and no Script constants are already fresh
	# from CACHE_MODE_IGNORE and do not need reload() — calling it would corrupt them.


func _extract_tool_definitions(category: String, executor) -> Array:
	return _runtime_manager.extract_tool_definitions(executor)


func _record_load_error(category: String, path: String, message: String) -> void:
	_state_store.record_load_error(category, path, message, _diagnostics_service)


func _count_enabled_tools_in_category(category: String) -> int:
	return _enablement_service.count_enabled_tools_in_category(category, _tool_definitions_by_category)


func _category_has_enabled_tools(category: String) -> bool:
	return _enablement_service.category_has_enabled_tools(category, _tool_definitions_by_category)


func _unload_runtime(category: String, reason: String) -> void:
	_runtime_state_service.unload_runtime(category, reason, _build_runtime_state_context())


func _dispose_executor_instance(executor) -> void:
	_runtime_manager.dispose_executor(executor)


func _make_reload_status(action: String, reloaded_domains: Array = [], skipped_domains: Array = [], failed_domains: Array = [], elapsed_ms: float = 0.0) -> Dictionary:
	return _status_service.make_reload_status(action, get_performance_summary(), reloaded_domains, skipped_domains, failed_domains, elapsed_ms)


func _update_reload_status(status: Dictionary) -> Dictionary:
	return _diagnostics_service.update_reload_status(status)


func _elapsed_ms(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0


func _build_catalog_projection_context() -> Dictionary:
	return _context_service.build_loader_catalog_projection_context()


func _build_execution_context() -> Dictionary:
	return _execution_context_service.build_execution_context(
		Callable(self, "_is_category_executable"),
		Callable(self, "_get_tool_access_error"),
		Callable(self, "_ensure_runtime_loaded")
	)


func _build_reload_context() -> Dictionary:
	return _context_service.build_loader_reload_context()


func _build_user_reload_context() -> Dictionary:
	return _context_service.build_loader_user_reload_context()


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
	return _context_service.build_loader_runtime_state_context()


func _build_lifecycle_context() -> Dictionary:
	return _context_service.build_loader_lifecycle_context()


func _set_force_reload_script_load(enabled: bool) -> void:
	_state_store.set_force_reload_script_load(enabled)


func _get_force_reload_script_load() -> bool:
	return _state_store.get_force_reload_script_load()


func _get_tool_load_error_count() -> int:
	return _diagnostics_service.get_tool_load_error_count()


func _dispose_gdscript_lsp_diagnostics_adapter() -> void:
	_lsp_diagnostics_service.release_loader()


func _tick_gdscript_lsp_diagnostics(delta: float) -> void:
	_lsp_diagnostics_service.tick(delta)


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
	return _access_service.get_tool_access_provider(_server_context)


func _is_category_visible(category: String) -> bool:
	return _access_service.is_category_visible(category, _server_context)


func _is_category_executable(category: String) -> bool:
	return _access_service.is_category_executable(category, _server_context)


func _get_tool_access_error(category: String) -> String:
	return _access_service.get_tool_access_error(category, _server_context)


func _sync_load_error_incidents(phase: String) -> void:
	_diagnostics_service.sync_load_error_incidents(phase)


func _record_reload_incident(category: String, message: String, phase: String) -> void:
	_diagnostics_service.record_reload_incident(
		category,
		str(_entries_by_category.get(category, {}).get("path", "")),
		message,
		phase
	)
