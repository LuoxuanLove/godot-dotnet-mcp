@tool
extends RefCounted
class_name MCPToolBootstrapCoordinator

const MCPToolManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_manifest.gd")
const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")

var _tool_loader: Object
var _store
var _diagnostic_service
var _exposure_service
var _metrics_service
var _runtime_service
var _reload_service
var _execution_gateway
var _lsp_adapter


func configure(tool_loader: Object, store, diagnostic_service, exposure_service, metrics_service, runtime_service, reload_service, execution_gateway, lsp_adapter) -> void:
	_tool_loader = tool_loader
	_store = store
	_diagnostic_service = diagnostic_service
	_exposure_service = exposure_service
	_metrics_service = metrics_service
	_runtime_service = runtime_service
	_reload_service = reload_service
	_execution_gateway = execution_gateway
	_lsp_adapter = lsp_adapter


func configure_services(server_context: Object) -> void:
	_store.configure(server_context)
	_diagnostic_service.configure({
		"get_entry": Callable(_store, "get_entry")
	})
	_metrics_service.reset()
	_exposure_service.configure({
		"ensure_tool_definitions": Callable(_runtime_service, "ensure_tool_definitions"),
		"get_cached_tool_definitions": Callable(_store, "get_cached_tool_definitions"),
		"get_entry": Callable(_store, "get_entry"),
		"get_runtime": Callable(_store, "get_runtime"),
		"is_category_visible": Callable(_store, "is_category_visible"),
		"is_tool_enabled": Callable(_store, "is_tool_enabled"),
		"current_load_state": Callable(_store, "current_load_state"),
		"exposed_categories": MCPToolManifest.get_exposed_categories()
	})
	_runtime_service.configure(_tool_loader, server_context, {
		"get_entry": Callable(_store, "get_entry"),
		"get_runtime": Callable(_store, "get_runtime"),
		"set_runtime": Callable(_store, "set_runtime"),
		"has_tool_definitions_cache": Callable(_store, "has_tool_definitions_cache"),
		"get_tool_definitions": Callable(_store, "get_cached_tool_definitions"),
		"set_tool_definitions": Callable(_store, "set_tool_definitions"),
		"get_force_reload_script_load": Callable(_store, "get_force_reload_script_load"),
		"record_load_error": Callable(self, "record_load_error")
	})
	_reload_service.configure({
		"refresh_entries": Callable(self, "refresh_entries"),
		"get_entry": Callable(_store, "get_entry"),
		"get_ordered_categories": Callable(_store, "get_ordered_categories"),
		"get_disabled_tools": Callable(_store, "get_disabled_tools"),
		"set_disabled_tools": Callable(_store, "set_disabled_tools"),
		"get_runtime": Callable(_store, "get_runtime"),
		"set_runtime": Callable(_store, "set_runtime"),
		"erase_runtime": Callable(_store, "erase_runtime"),
		"get_tool_definitions": Callable(_store, "get_cached_tool_definitions"),
		"set_tool_definitions": Callable(_store, "set_tool_definitions"),
		"erase_tool_definitions": Callable(_store, "erase_tool_definitions"),
		"instantiate_executor": Callable(_runtime_service, "instantiate_executor"),
		"extract_tool_definitions": Callable(_runtime_service, "extract_tool_definitions"),
		"sync_load_error_incidents": Callable(_diagnostic_service, "sync_load_error_incidents"),
		"refresh_runtime_context": Callable(self, "refresh_runtime_context"),
		"reset_lsp_diagnostics": Callable(_lsp_adapter, "reset"),
		"category_has_enabled_tools": Callable(_store, "category_has_enabled_tools"),
		"unload_runtime": Callable(_runtime_service, "unload_runtime"),
		"record_reload_incident": Callable(_diagnostic_service, "record_reload_incident"),
		"as_bool": Callable(_store, "_as_bool")
	})
	_lsp_adapter.configure(_tool_loader)
	_execution_gateway.configure(_store, _runtime_service, _metrics_service, _lsp_adapter, {
		"refresh_runtime_context": Callable(self, "refresh_runtime_context")
	})
	_refresh_runtime_context_bridge()


func initialize(disabled_tools: Array = [], force_reload_scripts: bool = false) -> Dictionary:
	var started_usec = Time.get_ticks_usec()
	_store.set_force_reload_script_load(force_reload_scripts)
	_store.reset_registry_state()
	_metrics_service.reset()
	_diagnostic_service.clear_load_errors()
	_lsp_adapter.reset()
	refresh_entries()
	_store.set_disabled_tools(disabled_tools)

	var definition_started = Time.get_ticks_usec()
	for category in _store.get_ordered_categories():
		_runtime_service.ensure_tool_definitions(category)
	_metrics_service.set_definition_scan_ms(_elapsed_ms(definition_started))

	var preload_started = Time.get_ticks_usec()
	for category in _store.get_ordered_categories():
		if _store.category_has_enabled_tools(category):
			_runtime_service.ensure_runtime_loaded(category, "preload")
	_metrics_service.set_preload_ms(_elapsed_ms(preload_started))
	_metrics_service.set_startup_ms(_elapsed_ms(started_usec))
	_store.set_reload_status(_make_reload_status("initialize"))
	_diagnostic_service.sync_load_error_incidents("initialize")
	refresh_runtime_context()
	_store.set_force_reload_script_load(false)

	return {
		"tool_count": _exposure_service.build_tool_definitions(_store.get_ordered_categories(), true).size(),
		"exposed_tool_count": _exposure_service.build_exposed_tool_definitions(_store.get_ordered_categories(), true).size(),
		"category_count": _store.get_ordered_categories().size(),
		"tool_load_error_count": _diagnostic_service.get_tool_load_error_count()
	}


func set_disabled_tools(disabled_tools: Array) -> void:
	_store.set_disabled_tools(disabled_tools)
	for category in _store.get_ordered_categories():
		if _store.category_has_enabled_tools(category):
			_runtime_service.ensure_runtime_loaded(category, "disabled_tools_changed")
		else:
			_runtime_service.unload_runtime(category, "disabled_tools_changed")
	refresh_runtime_context()


func shutdown() -> void:
	if _execution_gateway != null and _execution_gateway.has_method("release_all_runtimes"):
		_execution_gateway.release_all_runtimes("shutdown")
	if _reload_service != null and _reload_service.has_method("dispose"):
		_reload_service.dispose()
	if _runtime_service != null and _runtime_service.has_method("dispose"):
		_runtime_service.dispose()
	if _exposure_service != null and _exposure_service.has_method("dispose"):
		_exposure_service.dispose()
	if _diagnostic_service != null and _diagnostic_service.has_method("dispose"):
		_diagnostic_service.dispose()
	if _execution_gateway != null and _execution_gateway.has_method("dispose"):
		_execution_gateway.dispose()
	if _lsp_adapter != null and _lsp_adapter.has_method("dispose"):
		_lsp_adapter.dispose()
	elif _lsp_adapter != null and _lsp_adapter.has_method("release"):
		_lsp_adapter.release()
	if _metrics_service != null:
		_metrics_service.reset()
	if _store != null and _store.has_method("clear_all"):
		_store.clear_all()
	_tool_loader = null
	_store = null
	_diagnostic_service = null
	_exposure_service = null
	_metrics_service = null
	_runtime_service = null
	_reload_service = null
	_execution_gateway = null
	_lsp_adapter = null


func refresh_entries() -> void:
	_diagnostic_service.clear_load_errors()
	var collected = MCPToolManifest.collect_entries()
	var new_entries: Dictionary = {}
	var new_order: Array[String] = []
	_diagnostic_service.append_load_errors(collected.get("errors", []))
	for entry in collected.get("entries", []):
		var category := str(entry.get("category", ""))
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

	for existing_category in _store.runtime_categories():
		if not new_entries.has(existing_category):
			_runtime_service.unload_runtime(str(existing_category), "refresh_entries_removed")
			_store.erase_runtime(str(existing_category))
			_store.erase_tool_definitions(str(existing_category))

	_store.set_entries(new_entries, new_order)
	_diagnostic_service.sync_load_error_incidents("refresh_entries")


func refresh_runtime_context() -> void:
	var context: Dictionary = {
		"tool_loader": _tool_loader,
		"server": _store.get_server_context()
	}
	for category in _store.runtime_categories():
		var runtime: Dictionary = _store.get_runtime(str(category))
		var executor = runtime.get("instance", null)
		if executor != null and executor.has_method("configure_runtime"):
			executor.configure_runtime(context.duplicate(true))
	_refresh_runtime_context_bridge()


func reload_domain(category: String) -> Dictionary:
	MCPDebugBuffer.record("info", "tool_loader", "Reloading domain: %s" % category)
	var status = _reload_service.reload_domain(category)
	_metrics_service.apply_reload_metrics(status)
	var failed_domains: Array = status.get("failed_domains", [])
	var reloaded_domains: Array = status.get("reloaded_domains", [])
	var skipped_domains: Array = status.get("skipped_domains", [])
	var elapsed_ms := float(status.get("elapsed_ms", 0.0))
	if not failed_domains.is_empty():
		var failure = failed_domains[0] if failed_domains[0] is Dictionary else {}
		MCPDebugBuffer.record("error", "tool_loader",
			"Domain %s reload failed: %s" % [category, str((failure as Dictionary).get("error", "Failed to reload tool domain"))])
	elif not reloaded_domains.is_empty():
		var definition_count := int(status.get("definition_count", 0))
		if bool(status.get("allow_empty_definitions", false)):
			MCPDebugBuffer.record("info", "tool_loader",
				"Domain %s reloaded with no tool definitions (allowed) (%.0fms)" % [category, elapsed_ms])
		else:
			MCPDebugBuffer.record("info", "tool_loader",
				"Domain %s reloaded: %d tools (%.0fms)" % [category, definition_count, elapsed_ms])
	elif not skipped_domains.is_empty() and category != "user":
		MCPDebugBuffer.record("warning", "tool_loader", "Reload skipped for domain: %s" % category)
	return _store.set_reload_status(_make_reload_status(
		"reload_domain",
		reloaded_domains,
		skipped_domains,
		failed_domains,
		elapsed_ms
	))


func reload_all_domains() -> Dictionary:
	var status = _reload_service.reload_all_domains()
	_metrics_service.apply_reload_metrics(status)
	return _store.set_reload_status(_make_reload_status(
		"reload_all_domains",
		status.get("reloaded_domains", []),
		status.get("skipped_domains", []),
		status.get("failed_domains", []),
		float(status.get("elapsed_ms", 0.0))
	))


func record_load_error(category: String, path: String, message: String) -> void:
	var error_info = _diagnostic_service.record_load_error(category, path, message)
	var runtime: Dictionary = _store.get_runtime(category)
	runtime["last_error"] = error_info
	_store.set_runtime(category, runtime)
	_diagnostic_service.sync_load_error_incidents("record_load_error")


func _refresh_runtime_context_bridge() -> void:
	if Engine.has_singleton("MCPRuntimeBridge"):
		var runtime_bridge = Engine.get_singleton("MCPRuntimeBridge")
		if runtime_bridge != null and runtime_bridge.has_method("set_tool_loader"):
			runtime_bridge.set_tool_loader(_tool_loader)


func _make_reload_status(action: String, reloaded_domains: Array = [], skipped_domains: Array = [], failed_domains: Array = [], elapsed_ms: float = 0.0) -> Dictionary:
	return {
		"action": action,
		"reloaded_domains": reloaded_domains.duplicate(),
		"skipped_domains": skipped_domains.duplicate(),
		"failed_domains": failed_domains.duplicate(true),
		"elapsed_ms": elapsed_ms,
		"timestamp_unix": int(Time.get_unix_time_from_system()),
		"performance": _metrics_service.build_performance_summary()
	}


func _elapsed_ms(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0
