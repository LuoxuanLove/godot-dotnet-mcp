@tool
extends RefCounted

## Builds MCPToolLoader service context dictionaries from shared state and callables.
## The loader still owns the concrete operations; this service owns the wiring maps.

var _state_store
var _loader
var _execution_context_service


func configure(state_store) -> void:
	_state_store = state_store


func configure_loader(loader, execution_context_service = null) -> void:
	_loader = loader
	_execution_context_service = execution_context_service


func build_catalog_projection_context(callbacks: Dictionary) -> Dictionary:
	if _state_store != null and _state_store.has_method("build_catalog_projection_context"):
		return _state_store.build_catalog_projection_context(callbacks)
	return callbacks.duplicate(true)


func build_reload_context(callbacks: Dictionary) -> Dictionary:
	if _state_store != null and _state_store.has_method("build_reload_context"):
		return _state_store.build_reload_context(callbacks)
	return callbacks.duplicate(true)


func build_user_reload_context(callbacks: Dictionary) -> Dictionary:
	return build_reload_context(callbacks)


func build_runtime_state_context(callbacks: Dictionary) -> Dictionary:
	if _state_store != null and _state_store.has_method("build_runtime_state_context"):
		return _state_store.build_runtime_state_context(callbacks)
	return callbacks.duplicate(true)


func build_lifecycle_context(callbacks: Dictionary) -> Dictionary:
	if _state_store != null and _state_store.has_method("build_lifecycle_context"):
		return _state_store.build_lifecycle_context(callbacks)
	return callbacks.duplicate(true)


func build_loader_catalog_projection_context() -> Dictionary:
	return build_catalog_projection_context({
		"ensure_tool_definitions": _loader_callable("_ensure_tool_definitions"),
		"is_category_visible": _loader_callable("_is_category_visible"),
		"is_tool_enabled": _loader_callable("is_tool_enabled"),
		"is_exposed_tool_definition": _loader_callable("_is_exposed_tool_definition"),
		"is_public_removed_tool_definition": _loader_callable("_is_public_removed_tool_definition")
	})


func build_loader_reload_context() -> Dictionary:
	return build_reload_context({
		"refresh_entries": _loader_callable("_refresh_entries"),
		"instantiate_executor": _loader_callable("_instantiate_executor"),
		"extract_tool_definitions": _loader_callable("_extract_tool_definitions"),
		"record_reload_incident": _loader_callable("_record_reload_incident"),
		"sync_load_error_incidents": _loader_callable("_sync_load_error_incidents"),
		"refresh_runtime_context": _loader_callable("_refresh_runtime_context"),
		"reset_gdscript_lsp_diagnostics_service": _loader_callable("_reset_gdscript_lsp_diagnostics_service"),
		"category_has_enabled_tools": _loader_callable("_category_has_enabled_tools"),
		"unload_runtime": _loader_callable("_unload_runtime"),
		"make_reload_status": _loader_callable("_make_reload_status"),
		"update_reload_status": _loader_callable("_update_reload_status"),
		"get_disabled_tools": _loader_callable("get_disabled_tools"),
		"set_disabled_tools": _loader_callable("_set_disabled_tools")
	})


func build_loader_user_reload_context() -> Dictionary:
	return build_user_reload_context({
		"category_has_enabled_tools": _loader_callable("_category_has_enabled_tools"),
		"ensure_runtime_loaded": _loader_callable("_ensure_runtime_loaded"),
		"tick_loaded_runtimes": _loader_callable("_tick_loaded_runtimes_for_user_reload"),
		"apply_tick_result": _loader_callable("_apply_tick_result"),
		"refresh_runtime_context": _loader_callable("_refresh_runtime_context")
	})


func build_loader_runtime_state_context() -> Dictionary:
	return build_runtime_state_context({
		"instantiate_executor": _loader_callable("_instantiate_executor"),
		"extract_tool_definitions": _loader_callable("_extract_tool_definitions"),
		"record_load_error": _loader_callable("_record_load_error"),
		"dispose_executor": _loader_callable("_dispose_executor_instance"),
		"failure": _execution_context_callable("failure")
	})


func build_loader_lifecycle_context() -> Dictionary:
	return build_lifecycle_context({
		"reset_state": _loader_callable("_reset_state"),
		"set_disabled_tools": _loader_callable("_set_disabled_tools"),
		"reset_gdscript_lsp_diagnostics_service": _loader_callable("_reset_gdscript_lsp_diagnostics_service"),
		"dispose_gdscript_lsp_diagnostics_adapter": _loader_callable("_dispose_gdscript_lsp_diagnostics_adapter"),
		"tick_gdscript_lsp_diagnostics": _loader_callable("_tick_gdscript_lsp_diagnostics"),
		"refresh_entries": _loader_callable("_refresh_entries"),
		"ensure_tool_definitions": _loader_callable("_ensure_tool_definitions"),
		"category_has_enabled_tools": _loader_callable("_category_has_enabled_tools"),
		"ensure_runtime_loaded": _loader_callable("_ensure_runtime_loaded"),
		"unload_runtime": _loader_callable("_unload_runtime"),
		"tick_loaded_runtimes": _loader_callable("_tick_loaded_runtimes_for_lifecycle"),
		"make_reload_status": _loader_callable("_make_reload_status"),
		"update_reload_status": _loader_callable("_update_reload_status"),
		"sync_load_error_incidents": _loader_callable("_sync_load_error_incidents"),
		"refresh_runtime_context": _loader_callable("_refresh_runtime_context"),
		"get_tool_definitions": _loader_callable("get_tool_definitions"),
		"get_exposed_tool_definitions": _loader_callable("get_exposed_tool_definitions"),
		"get_tool_load_error_count": _loader_callable("_get_tool_load_error_count")
	})


func _loader_callable(method_name: String) -> Callable:
	if _loader == null:
		return Callable()
	return Callable(_loader, method_name)


func _execution_context_callable(method_name: String) -> Callable:
	if _execution_context_service == null:
		return Callable()
	return Callable(_execution_context_service, method_name)
