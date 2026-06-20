@tool
extends RefCounted
class_name MCPToolLoader

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const ToolLoaderServiceFactoryScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_service_factory.gd")

var _service_factory := ToolLoaderServiceFactoryScript.new()
var _registry = null
var _server_context: Object
var _state_store = null
var _entries_by_category: Dictionary = {}
var _ordered_categories: Array[String] = []
var _runtime_by_category: Dictionary = {}
var _tool_definitions_by_category: Dictionary = {}
var _public_surface_policy = null
var _execution_observer = null
var _runtime_manager = null
var _status_service = null
var _diagnostics_service = null
var _entry_service = null
var _runtime_context_service = null
var _catalog_projection_service = null
var _execution_service = null
var _tick_service = null
var _enablement_service = null
var _reload_service = null
var _user_reload_service = null
var _runtime_state_service = null
var _lifecycle_service = null
var _access_service = null
var _lsp_diagnostics_service = null
var _execution_context_service = null
var _context_service = null
var _query_service = null
var _lifecycle_tick_budget_service = null
var _tool_activity_registry = null
var _performance: Dictionary = {}
var _preload_runtimes_on_initialize := false
var _catalog_revision := 0


func _init() -> void:
	_ensure_services_ready()


func _bind_state_refs() -> void:
	_entries_by_category = _state_store.entries_by_category
	_ordered_categories = _state_store.ordered_categories
	_runtime_by_category = _state_store.runtime_by_category
	_tool_definitions_by_category = _state_store.tool_definitions_by_category
	_performance = _state_store.performance


func _ensure_services_ready() -> void:
	var services: Dictionary = _service_factory.ensure_services(_build_service_factory_context())
	_registry = services.get("registry", _registry)
	_state_store = services.get("state_store", _state_store)
	_public_surface_policy = services.get("public_surface_policy", _public_surface_policy)
	_execution_observer = services.get("execution_observer", _execution_observer)
	_runtime_manager = services.get("runtime_manager", _runtime_manager)
	_status_service = services.get("status_service", _status_service)
	_diagnostics_service = services.get("diagnostics_service", _diagnostics_service)
	_entry_service = services.get("entry_service", _entry_service)
	_runtime_context_service = services.get("runtime_context_service", _runtime_context_service)
	_catalog_projection_service = services.get("catalog_projection_service", _catalog_projection_service)
	_execution_service = services.get("execution_service", _execution_service)
	_tick_service = services.get("tick_service", _tick_service)
	_enablement_service = services.get("enablement_service", _enablement_service)
	_reload_service = services.get("reload_service", _reload_service)
	_user_reload_service = services.get("user_reload_service", _user_reload_service)
	_runtime_state_service = services.get("runtime_state_service", _runtime_state_service)
	_lifecycle_service = services.get("lifecycle_service", _lifecycle_service)
	_access_service = services.get("access_service", _access_service)
	_lsp_diagnostics_service = services.get("lsp_diagnostics_service", _lsp_diagnostics_service)
	_execution_context_service = services.get("execution_context_service", _execution_context_service)
	_context_service = services.get("context_service", _context_service)
	_query_service = services.get("query_service", _query_service)
	_lifecycle_tick_budget_service = services.get("lifecycle_tick_budget_service", _lifecycle_tick_budget_service)
	_bind_state_refs()
	_runtime_manager.configure(Callable(self, "_build_executor_runtime_context"))
	_execution_observer.set_activity_registry(_tool_activity_registry)
	_lsp_diagnostics_service.configure(self)
	_execution_context_service.configure(_execution_observer)
	_context_service.configure(_state_store)


func _build_service_factory_context() -> Dictionary:
	return {
		"registry": _registry,
		"state_store": _state_store,
		"public_surface_policy": _public_surface_policy,
		"execution_observer": _execution_observer,
		"runtime_manager": _runtime_manager,
		"status_service": _status_service,
		"diagnostics_service": _diagnostics_service,
		"entry_service": _entry_service,
		"runtime_context_service": _runtime_context_service,
		"catalog_projection_service": _catalog_projection_service,
		"execution_service": _execution_service,
		"tick_service": _tick_service,
		"enablement_service": _enablement_service,
		"reload_service": _reload_service,
		"user_reload_service": _user_reload_service,
		"runtime_state_service": _runtime_state_service,
		"lifecycle_service": _lifecycle_service,
		"access_service": _access_service,
		"lsp_diagnostics_service": _lsp_diagnostics_service,
		"execution_context_service": _execution_context_service,
		"context_service": _context_service,
		"query_service": _query_service,
		"lifecycle_tick_budget_service": _lifecycle_tick_budget_service
	}


func configure(server_context: Object) -> void:
	_ensure_services_ready()
	_server_context = server_context
	_runtime_manager.configure(Callable(self, "_build_executor_runtime_context"))
	if Engine.has_singleton("MCPRuntimeBridge"):
		var runtime_bridge = Engine.get_singleton("MCPRuntimeBridge")
		if runtime_bridge != null and runtime_bridge.has_method("set_tool_loader"):
			runtime_bridge.set_tool_loader(self)
	_lsp_diagnostics_service.configure(self)
	_refresh_runtime_context()


func initialize(disabled_tools: Array = [], force_reload_scripts: bool = false) -> Dictionary:
	_ensure_services_ready()
	_tick_service.invalidate_user_definitions()
	var summary: Dictionary = _lifecycle_service.initialize(disabled_tools, force_reload_scripts, _build_lifecycle_context())
	_bump_catalog_revision()
	summary["catalog_revision"] = _catalog_revision
	return summary


func set_preload_runtimes_on_initialize(enabled: bool) -> void:
	_preload_runtimes_on_initialize = enabled


func set_tool_activity_registry(registry) -> void:
	_ensure_services_ready()
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
	_ensure_services_ready()
	_lifecycle_service.shutdown(_build_lifecycle_context())
	_execution_observer.set_activity_registry(null)
	_tool_activity_registry = null
	_refresh_runtime_context()
	_bump_catalog_revision()


func set_disabled_tools(disabled_tools: Array) -> void:
	_ensure_services_ready()
	_lifecycle_service.set_disabled_tools(disabled_tools, _build_lifecycle_context())
	_bump_catalog_revision()


func get_tools_by_category() -> Dictionary:
	_ensure_services_ready()
	return _build_tools_by_category_internal(true)


func get_all_tools_by_category() -> Dictionary:
	_ensure_services_ready()
	return _build_tools_by_category_internal(false)


func _build_tools_by_category_internal(visible_only: bool) -> Dictionary:
	return _query_service.build_tools_by_category(
		_catalog_projection_service,
		_build_catalog_projection_context(),
		visible_only,
		_entries_by_category,
		Callable(self, "_record_empty_visible_warning")
	)


func get_tool_definitions() -> Array[Dictionary]:
	_ensure_services_ready()
	return _build_tool_definitions_internal(true)


func get_all_tool_definitions() -> Array[Dictionary]:
	_ensure_services_ready()
	return _build_tool_definitions_internal(false)


func get_exposed_tool_definitions() -> Array[Dictionary]:
	_ensure_services_ready()
	return _query_service.build_exposed_tool_definitions(_catalog_projection_service, _build_catalog_projection_context(), get_tool_definitions())


func is_tool_exposed(tool_name: String) -> bool:
	_ensure_services_ready()
	return _query_service.is_tool_exposed(
		tool_name,
		get_exposed_tool_definitions(),
		_public_surface_policy,
		get_tool_definitions(),
		Callable(self, "is_tool_enabled")
	)


func is_public_removed_tool(tool_name: String) -> bool:
	_ensure_services_ready()
	return _public_surface_policy.is_public_removed_tool(tool_name)


func build_removed_public_tool_result(tool_name: String, arguments: Dictionary = {}) -> Dictionary:
	_ensure_services_ready()
	return _public_surface_policy.build_removed_public_tool_result(tool_name, arguments)


func _build_tool_definitions_internal(visible_only: bool) -> Array[Dictionary]:
	return _query_service.build_tool_definitions(
		_catalog_projection_service,
		_build_catalog_projection_context(),
		visible_only,
		_entries_by_category,
		Callable(self, "_record_empty_visible_warning")
	)


func get_tool_load_errors() -> Array[Dictionary]:
	_ensure_services_ready()
	return _diagnostics_service.get_tool_load_errors()


func get_domain_states() -> Array[Dictionary]:
	_ensure_services_ready()
	return _build_domain_states_internal(true)


func get_all_domain_states() -> Array[Dictionary]:
	_ensure_services_ready()
	return _build_domain_states_internal(false)


func _build_domain_states_internal(visible_only: bool) -> Array[Dictionary]:
	return _query_service.build_domain_states(
		_catalog_projection_service,
		_build_catalog_projection_context(),
		visible_only,
		_entries_by_category,
		Callable(self, "_record_empty_visible_warning")
	)


func get_reload_status() -> Dictionary:
	_ensure_services_ready()
	return _diagnostics_service.get_reload_status()


func get_tool_loader_status() -> Dictionary:
	_ensure_services_ready()
	var status: Dictionary = _query_service.build_tool_loader_status(
		_status_service,
		get_tool_definitions(),
		get_exposed_tool_definitions(),
		_ordered_categories,
		_diagnostics_service.get_tool_load_error_count()
	)
	status["catalog_revision"] = _catalog_revision
	return status


func get_catalog_revision() -> int:
	return _catalog_revision


func get_performance_summary() -> Dictionary:
	_ensure_services_ready()
	return _status_service.build_performance_summary(_performance, _execution_observer.get_tool_call_metrics())


func get_tool_usage_stats() -> Array[Dictionary]:
	_ensure_services_ready()
	return _execution_observer.get_tool_usage_stats()


func execute_tool(category: String, tool_name: String, args: Dictionary) -> Dictionary:
	_ensure_services_ready()
	return _execution_service.execute_tool(category, tool_name, args, _build_execution_context())


func execute_tool_async(category: String, tool_name: String, args: Dictionary) -> Dictionary:
	_ensure_services_ready()
	return await _execution_service.execute_tool_async(category, tool_name, args, _build_execution_context())


func tick(delta: float) -> void:
	_ensure_services_ready()
	if _tool_activity_registry != null and _tool_activity_registry.has_method("sweep_stale"):
		_tool_activity_registry.sweep_stale()
	var tick_budget: Dictionary = _lifecycle_tick_budget_service.accumulate(delta, _has_active_gdscript_lsp_diagnostics_request())
	if not bool(tick_budget.get("should_tick", false)):
		return
	var tick_delta := float(tick_budget.get("tick_delta_seconds", 0.0))
	var started_usec := Time.get_ticks_usec()
	_lifecycle_service.tick(tick_delta, _build_lifecycle_context())
	var elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	_lifecycle_tick_budget_service.record_performance(
		_performance,
		elapsed_ms,
		float(tick_budget.get("interval_seconds", 0.0)),
		tick_delta
	)


func get_gdscript_lsp_diagnostics_service():
	_ensure_services_ready()
	return _lsp_diagnostics_service.get_service()


func get_lsp_diagnostics_debug_snapshot() -> Dictionary:
	_ensure_services_ready()
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
	_ensure_services_ready()
	_tick_service.invalidate_user_definitions()
	var status: Dictionary = _reload_service.reload_domain(category, _build_reload_context())
	if not (status.get("reloaded_domains", []) as Array).is_empty():
		_bump_catalog_revision()
		status["catalog_revision"] = _catalog_revision
	return status


func reload_all_domains() -> Dictionary:
	_ensure_services_ready()
	_tick_service.invalidate_user_definitions()
	var status: Dictionary = _reload_service.reload_all_domains(_build_reload_context())
	if not (status.get("reloaded_domains", []) as Array).is_empty():
		_bump_catalog_revision()
		status["catalog_revision"] = _catalog_revision
	return status


func request_reload_by_script(script_path: String, reason: String = "manual") -> Dictionary:
	_ensure_services_ready()
	_tick_service.invalidate_user_definitions()
	var status: Dictionary = _user_reload_service.request_reload_by_script(script_path, reason, _build_user_reload_context())
	status["catalog_revision"] = _catalog_revision
	return status


func get_user_tool_runtime_snapshot() -> Array[Dictionary]:
	_ensure_services_ready()
	var snapshot: Array = _user_reload_service.get_user_tool_runtime_snapshot(_build_user_reload_context())
	var typed_snapshot: Array[Dictionary] = []
	for entry in snapshot:
		if entry is Dictionary:
			typed_snapshot.append((entry as Dictionary).duplicate(true))
	return typed_snapshot


func get_disabled_tools() -> Array:
	_ensure_services_ready()
	return _enablement_service.get_disabled_tools()


func is_tool_enabled(tool_name: String) -> bool:
	_ensure_services_ready()
	return _enablement_service.is_tool_enabled(tool_name)


func _reset_state() -> void:
	_state_store.reset(_diagnostics_service)


func _refresh_entries() -> void:
	_state_store.refresh_entries(_registry, _entry_service, _diagnostics_service, Callable(self, "_sync_load_error_incidents"))


func _set_disabled_tools(disabled_tools: Array) -> bool:
	return _enablement_service.configure_disabled_tools(disabled_tools)


func _ensure_tool_definitions(category: String) -> Array:
	return _runtime_state_service.ensure_tool_definitions(category, _build_runtime_state_context())


func _should_preload_runtimes() -> bool:
	return _preload_runtimes_on_initialize


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
	return _context_service.build_loader_catalog_projection_context(self)


func _build_execution_context() -> Dictionary:
	return _execution_context_service.build_execution_context(
		Callable(self, "_is_category_executable"),
		Callable(self, "_get_tool_access_error"),
		Callable(self, "_ensure_runtime_loaded")
	)


func _build_reload_context() -> Dictionary:
	return _context_service.build_loader_reload_context(self)


func _build_user_reload_context() -> Dictionary:
	return _context_service.build_loader_user_reload_context(self)


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


func _apply_tick_result(tick_result: Dictionary) -> bool:
	var refresh_context := false
	if bool(tick_result.get("user_definitions_changed", false)):
		_tool_definitions_by_category["user"] = tick_result.get("user_definitions", [])
		refresh_context = true
	if bool(tick_result.get("user_should_unload", false)) and _runtime_by_category.has("user"):
		_runtime_by_category.erase("user")
		_tool_definitions_by_category.erase("user")
		refresh_context = true
	if refresh_context:
		_bump_catalog_revision()
	return refresh_context


func _bump_catalog_revision() -> void:
	_catalog_revision += 1


func _build_runtime_state_context() -> Dictionary:
	return _context_service.build_loader_runtime_state_context(self, _execution_context_service)


func _build_lifecycle_context() -> Dictionary:
	return _context_service.build_loader_lifecycle_context(self)


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


func _has_active_gdscript_lsp_diagnostics_request() -> bool:
	return _lsp_diagnostics_service != null \
		and _lsp_diagnostics_service.has_method("has_active_request") \
		and _lsp_diagnostics_service.has_active_request()


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


func _record_empty_visible_warning(message: String) -> void:
	MCPDebugBuffer.record("warning", "tool_loader", message)
