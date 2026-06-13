extends RefCounted

const ContextServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_context_service.gd")
const StateStoreScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_state_store.gd")


class FakeLoader extends RefCounted:
	var called: Array[String] = []

	func _ensure_tool_definitions(_category: String) -> Array:
		called.append("_ensure_tool_definitions")
		return []

	func _is_category_visible(_category: String) -> bool:
		called.append("_is_category_visible")
		return true

	func is_tool_enabled(_tool_name: String) -> bool:
		called.append("is_tool_enabled")
		return true

	func _is_exposed_tool_definition(_tool_def: Dictionary) -> bool:
		called.append("_is_exposed_tool_definition")
		return true

	func _is_public_removed_tool_definition(_tool_def: Dictionary) -> bool:
		called.append("_is_public_removed_tool_definition")
		return false

	func _refresh_entries() -> void:
		called.append("_refresh_entries")

	func _instantiate_executor(_category: String, _force_reload: bool, _reason: String) -> Dictionary:
		called.append("_instantiate_executor")
		return {"success": true, "executor": null}

	func _extract_tool_definitions(_category: String, _executor) -> Array:
		called.append("_extract_tool_definitions")
		return []

	func _record_reload_incident(_category: String, _message: String, _phase: String) -> void:
		called.append("_record_reload_incident")

	func _sync_load_error_incidents(_phase: String) -> void:
		called.append("_sync_load_error_incidents")

	func _refresh_runtime_context() -> void:
		called.append("_refresh_runtime_context")

	func _reset_gdscript_lsp_diagnostics_service() -> void:
		called.append("_reset_gdscript_lsp_diagnostics_service")

	func _category_has_enabled_tools(_category: String) -> bool:
		called.append("_category_has_enabled_tools")
		return true

	func _unload_runtime(_category: String, _reason: String) -> void:
		called.append("_unload_runtime")

	func _make_reload_status(_action: String, _reloaded_domains: Array = [], _skipped_domains: Array = [], _failed_domains: Array = [], _elapsed_ms: float = 0.0) -> Dictionary:
		called.append("_make_reload_status")
		return {"action": _action}

	func _update_reload_status(status: Dictionary) -> Dictionary:
		called.append("_update_reload_status")
		return status

	func get_disabled_tools() -> Array:
		called.append("get_disabled_tools")
		return []

	func _set_disabled_tools(_disabled_tools: Array) -> void:
		called.append("_set_disabled_tools")

	func _ensure_runtime_loaded(_category: String, _reason: String) -> Dictionary:
		called.append("_ensure_runtime_loaded")
		return {"success": true}

	func _tick_loaded_runtimes_for_user_reload(_runtime_by_category: Dictionary, _definitions_by_category: Dictionary, _delta: float) -> Dictionary:
		called.append("_tick_loaded_runtimes_for_user_reload")
		return {}

	func _apply_tick_result(_tick_result: Dictionary) -> bool:
		called.append("_apply_tick_result")
		return false

	func _record_load_error(_category: String, _path: String, _message: String) -> void:
		called.append("_record_load_error")

	func _dispose_executor_instance(_executor) -> void:
		called.append("_dispose_executor_instance")

	func _reset_state() -> void:
		called.append("_reset_state")

	func _dispose_gdscript_lsp_diagnostics_adapter() -> void:
		called.append("_dispose_gdscript_lsp_diagnostics_adapter")

	func _tick_gdscript_lsp_diagnostics(_delta: float) -> void:
		called.append("_tick_gdscript_lsp_diagnostics")

	func _tick_loaded_runtimes_for_lifecycle(_delta: float) -> Dictionary:
		called.append("_tick_loaded_runtimes_for_lifecycle")
		return {}

	func get_tool_definitions() -> Array:
		called.append("get_tool_definitions")
		return []

	func get_exposed_tool_definitions() -> Array:
		called.append("get_exposed_tool_definitions")
		return []

	func _get_tool_load_error_count() -> int:
		called.append("_get_tool_load_error_count")
		return 0


class FakeExecutionContextService extends RefCounted:
	func failure(error_type: String, category: String, tool_name: String, message: String) -> Dictionary:
		return {
			"success": false,
			"error": message,
			"data": {
				"error_type": error_type,
				"domain": category,
				"tool_name": tool_name
			}
		}


func run_case(_tree: SceneTree) -> Dictionary:
	var store = StateStoreScript.new()
	var service = ContextServiceScript.new()
	service.configure(store)

	store.ordered_categories.append("system")
	store.entries_by_category["system"] = {"path": "res://system.gd"}
	store.runtime_by_category["system"] = {"loaded": true}
	store.tool_definitions_by_category["system"] = [{"name": "system_project_state"}]
	store.performance["startup_ms"] = 12.5
	store.set_force_reload_script_load(true)

	var catalog_context := service.build_catalog_projection_context({"marker": "catalog"})
	if catalog_context.get("entries_by_category", {}) != store.entries_by_category:
		return _failure("Context service should preserve catalog state references.")
	if str(catalog_context.get("marker", "")) != "catalog":
		return _failure("Context service should merge catalog callbacks.")

	var reload_context := service.build_reload_context({"marker": "reload"})
	if reload_context.get("performance", {}) != store.performance:
		return _failure("Context service should include reload performance state.")
	if not (reload_context.get("get_ordered_categories", Callable()) is Callable):
		return _failure("Context service should expose reload state accessors.")
	if str(reload_context.get("marker", "")) != "reload":
		return _failure("Context service should merge reload callbacks.")

	var user_reload_context := service.build_user_reload_context({"marker": "user"})
	if user_reload_context.get("performance", {}) != store.performance:
		return _failure("User reload context should reuse reload state projection.")
	if str(user_reload_context.get("marker", "")) != "user":
		return _failure("Context service should merge user reload callbacks.")

	var runtime_context := service.build_runtime_state_context({"marker": "runtime"})
	if not bool(runtime_context.get("force_reload_script_load", false)):
		return _failure("Context service should expose runtime force-reload state.")
	if not (runtime_context.get("get_force_reload_script_load", Callable()) is Callable):
		return _failure("Context service should expose runtime-state accessors.")
	if str(runtime_context.get("marker", "")) != "runtime":
		return _failure("Context service should merge runtime-state callbacks.")

	var lifecycle_context := service.build_lifecycle_context({"marker": "lifecycle"})
	if lifecycle_context.get("runtime_by_category", {}) != store.runtime_by_category:
		return _failure("Context service should preserve lifecycle runtime state references.")
	if not (lifecycle_context.get("set_force_reload_script_load", Callable()) is Callable):
		return _failure("Context service should expose lifecycle mutators.")
	if str(lifecycle_context.get("marker", "")) != "lifecycle":
		return _failure("Context service should merge lifecycle callbacks.")

	var fallback = ContextServiceScript.new()
	var fallback_context := fallback.build_reload_context({"marker": "fallback"})
	if str(fallback_context.get("marker", "")) != "fallback":
		return _failure("Context service should fail open to callback-only contexts when no store is configured.")

	var loader_context_result := _verify_loader_wiring_contexts(store)
	if not bool(loader_context_result.get("success", false)):
		return loader_context_result
	var source_guard_result := _verify_loader_source_uses_context_service()
	if not bool(source_guard_result.get("success", false)):
		return source_guard_result

	return {
		"success": true,
		"name": "tool_loader_context_service_contracts",
		"contexts": 6
	}


func _verify_loader_wiring_contexts(store) -> Dictionary:
	var loader = FakeLoader.new()
	var execution_context_service = FakeExecutionContextService.new()
	var service = ContextServiceScript.new()
	service.configure(store)

	var catalog_context := service.build_loader_catalog_projection_context(loader)
	for key in [
		"ensure_tool_definitions",
		"is_category_visible",
		"is_tool_enabled",
		"is_exposed_tool_definition",
		"is_public_removed_tool_definition"
	]:
		if not (catalog_context.get(key, Callable()) is Callable) or not (catalog_context[key] as Callable).is_valid():
			return _failure("Loader catalog context should expose callable: %s" % key)

	var reload_context := service.build_loader_reload_context(loader)
	for key in [
		"refresh_entries",
		"instantiate_executor",
		"extract_tool_definitions",
		"record_reload_incident",
		"sync_load_error_incidents",
		"refresh_runtime_context",
		"reset_gdscript_lsp_diagnostics_service",
		"category_has_enabled_tools",
		"unload_runtime",
		"make_reload_status",
		"update_reload_status",
		"get_disabled_tools",
		"set_disabled_tools"
	]:
		if not (reload_context.get(key, Callable()) is Callable) or not (reload_context[key] as Callable).is_valid():
			return _failure("Loader reload context should expose callable: %s" % key)

	var user_reload_context := service.build_loader_user_reload_context(loader)
	for key in [
		"category_has_enabled_tools",
		"ensure_runtime_loaded",
		"tick_loaded_runtimes",
		"apply_tick_result",
		"refresh_runtime_context"
	]:
		if not (user_reload_context.get(key, Callable()) is Callable) or not (user_reload_context[key] as Callable).is_valid():
			return _failure("Loader user reload context should expose callable: %s" % key)

	var runtime_state_context := service.build_loader_runtime_state_context(loader, execution_context_service)
	for key in [
		"instantiate_executor",
		"extract_tool_definitions",
		"record_load_error",
		"dispose_executor",
		"failure"
	]:
		if not (runtime_state_context.get(key, Callable()) is Callable) or not (runtime_state_context[key] as Callable).is_valid():
			return _failure("Loader runtime-state context should expose callable: %s" % key)

	var lifecycle_context := service.build_loader_lifecycle_context(loader)
	for key in [
		"reset_state",
		"set_disabled_tools",
		"reset_gdscript_lsp_diagnostics_service",
		"dispose_gdscript_lsp_diagnostics_adapter",
		"tick_gdscript_lsp_diagnostics",
		"refresh_entries",
		"ensure_tool_definitions",
		"category_has_enabled_tools",
		"ensure_runtime_loaded",
		"unload_runtime",
		"tick_loaded_runtimes",
		"make_reload_status",
		"update_reload_status",
		"sync_load_error_incidents",
		"refresh_runtime_context",
		"get_tool_definitions",
		"get_exposed_tool_definitions",
		"get_tool_load_error_count"
	]:
		if not (lifecycle_context.get(key, Callable()) is Callable) or not (lifecycle_context[key] as Callable).is_valid():
			return _failure("Loader lifecycle context should expose callable: %s" % key)

	if lifecycle_context.get("runtime_by_category", {}) != store.runtime_by_category:
		return _failure("Loader lifecycle context should retain shared runtime state references.")
	var failure_result: Dictionary = (runtime_state_context["failure"] as Callable).call("probe", "system", "probe", "boom")
	if str(failure_result.get("data", {}).get("error_type", "")) != "probe":
		return _failure("Loader runtime-state context should route failure envelope through execution context service.")
	return {"success": true}


func _verify_loader_source_uses_context_service() -> Dictionary:
	var source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/tools/core/tool_loader.gd")
	if source.is_empty():
		return _failure("Tool loader source should be readable for service-convergence guards.")
	for forbidden in [
		"build_catalog_projection_context({",
		"build_reload_context({",
		"build_user_reload_context({",
		"build_runtime_state_context({",
		"build_lifecycle_context({"
	]:
		if source.find(forbidden) != -1:
			return _failure("MCPToolLoader should delegate loader context wiring to ToolLoaderContextService, not rebuild callback maps: %s" % forbidden)
	for required in [
		"build_loader_catalog_projection_context(self)",
		"build_loader_reload_context(self)",
		"build_loader_user_reload_context(self)",
		"build_loader_runtime_state_context(self, _execution_context_service)",
		"build_loader_lifecycle_context(self)"
	]:
		if source.find(required) == -1:
			return _failure("MCPToolLoader should call the loader-specific context service method: %s" % required)
	var context_service_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/tools/core/tool_loader_context_service.gd")
	if context_service_source.is_empty():
		return _failure("ToolLoaderContextService source should be readable for ownership guards.")
	for forbidden in [
		"var _loader",
		"var _execution_context_service",
		"configure_loader(",
		"= loader",
		"= execution_context_service"
	]:
		if context_service_source.find(forbidden) != -1:
			return _failure("ToolLoaderContextService must not retain loader-owned objects: %s" % forbidden)
	return {"success": true}


func _failure(message: String, extra: Dictionary = {}) -> Dictionary:
	var data := extra.duplicate(true)
	data["message"] = message
	return {
		"success": false,
		"name": "tool_loader_context_service_contracts",
		"error": message,
		"data": data
	}
