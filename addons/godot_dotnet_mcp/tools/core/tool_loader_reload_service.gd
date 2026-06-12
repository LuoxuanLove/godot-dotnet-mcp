@tool
extends RefCounted
class_name ToolLoaderReloadService

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")


func reload_domain(category: String, context: Dictionary) -> Dictionary:
	MCPDebugBuffer.record("info", "tool_loader", "Reloading domain: %s" % category)
	if category == "user":
		_call_void(context.get("refresh_entries", Callable()))

	var entries: Dictionary = _entries_by_category(context)
	if not entries.has(category):
		if category == "user":
			return _call_status(context, _make_reload_status(context, "reload_domain", [], [category], []))
		MCPDebugBuffer.record("warning", "tool_loader", "Unknown domain: %s" % category)
		return _call_status(context, _make_reload_status(context, "reload_domain", [], [], [{
			"domain": category,
			"error": "Unknown tool domain"
		}]))

	var entry: Dictionary = _dictionary(entries.get(category, {}))
	if not _as_bool(entry.get("hot_reloadable", true)):
		return _call_status(context, _make_reload_status(context, "reload_domain", [], [category], []))

	var runtime_by_category: Dictionary = _runtime_by_category(context)
	var definitions_by_category: Dictionary = _tool_definitions_by_category(context)
	var old_runtime: Dictionary = _dictionary(runtime_by_category.get(category, {}))
	var definitions_before := _array(definitions_by_category.get(category, []))
	var reload_started := Time.get_ticks_usec()

	var instantiate_result: Dictionary = _call_dictionary(context.get("instantiate_executor", Callable()), [category, true, "reload"])
	if not _as_bool(instantiate_result.get("success", false)):
		var reload_err := str(instantiate_result.get("error", "Failed to reload tool domain"))
		MCPDebugBuffer.record("error", "tool_loader",
			"Domain %s reload failed: %s" % [category, reload_err])
		_call_void(context.get("record_reload_incident", Callable()), [category, reload_err, "reload_domain"])
		_restore_previous_state(category, old_runtime, definitions_before, runtime_by_category, definitions_by_category)
		return _call_status(context, _make_reload_status(context, "reload_domain", [], [], [{
			"domain": category,
			"error": reload_err
		}], _elapsed_ms(reload_started)))

	var executor = instantiate_result.get("executor")
	var version := int(old_runtime.get("version", 0)) + 1
	var allow_empty_definitions := _as_bool(entry.get("allow_empty_definitions", false))
	runtime_by_category[category] = {
		"instance": executor,
		"state": "loaded",
		"version": version,
		"load_count": int(old_runtime.get("load_count", 0)) + 1,
		"last_loaded_at_unix": int(Time.get_unix_time_from_system()),
		"last_error": null
	}
	var definitions: Array = _call_array(context.get("extract_tool_definitions", Callable()), [category, executor])
	if definitions.is_empty():
		if allow_empty_definitions:
			definitions_by_category[category] = []
			_finalize_successful_reload(category, context, reload_started, "Domain %s reloaded with no tool definitions (allowed) (%.0fms)" % [category, _elapsed_ms(reload_started)])
			return _call_status(context, _make_reload_status(context, "reload_domain", [category], [], [], _elapsed_ms(reload_started)))
		_call_void(context.get("record_reload_incident", Callable()), [category, "Reloaded tool domain did not expose any tool definitions", "reload_domain"])
		_restore_previous_state(category, old_runtime, definitions_before, runtime_by_category, definitions_by_category)
		return _call_status(context, _make_reload_status(context, "reload_domain", [], [], [{
			"domain": category,
			"error": "Reloaded tool domain did not expose any tool definitions"
		}], _elapsed_ms(reload_started)))

	definitions_by_category[category] = definitions
	_finalize_successful_reload(category, context, reload_started, "Domain %s reloaded: %d tools (%.0fms)" % [category, definitions.size(), _elapsed_ms(reload_started)])
	return _call_status(context, _make_reload_status(context, "reload_domain", [category], [], [], _elapsed_ms(reload_started)))


func reload_all_domains(context: Dictionary) -> Dictionary:
	var started_usec := Time.get_ticks_usec()
	var disabled_tools: Array = _call_array(context.get("get_disabled_tools", Callable()))
	_call_void(context.get("refresh_entries", Callable()))
	_call_void(context.get("set_disabled_tools", Callable()), [disabled_tools])

	var reloaded: Array = []
	var skipped: Array = []
	var failed: Array = []
	for category in _ordered_categories(context):
		var entries: Dictionary = _entries_by_category(context)
		var entry: Dictionary = _dictionary(entries.get(category, {}))
		if not _as_bool(entry.get("hot_reloadable", true)):
			skipped.append(category)
			continue
		var status: Dictionary = reload_domain(str(category), context)
		reloaded.append_array(_array(status.get("reloaded_domains", [])))
		skipped.append_array(_array(status.get("skipped_domains", [])))
		failed.append_array(_array(status.get("failed_domains", [])))
	_call_void(context.get("sync_load_error_incidents", Callable()), ["reload_all_domains"])
	_call_void(context.get("refresh_runtime_context", Callable()))
	_call_void(context.get("reset_gdscript_lsp_diagnostics_service", Callable()))
	return _call_status(context, _make_reload_status(context, "reload_all_domains", reloaded, skipped, failed, _elapsed_ms(started_usec)))


func _finalize_successful_reload(category: String, context: Dictionary, reload_started: int, message: String) -> void:
	_call_void(context.get("sync_load_error_incidents", Callable()), ["reload_domain"])
	var performance: Dictionary = _performance(context)
	var elapsed := _elapsed_ms(reload_started)
	performance["reload_total_ms"] = float(performance.get("reload_total_ms", 0.0)) + elapsed
	performance["reload_count"] = int(performance.get("reload_count", 0)) + 1
	MCPDebugBuffer.record("info", "tool_loader", message)
	_call_void(context.get("refresh_runtime_context", Callable()))
	_call_void(context.get("reset_gdscript_lsp_diagnostics_service", Callable()))
	var has_enabled := _call_bool(context.get("category_has_enabled_tools", Callable()), [category], true)
	if not has_enabled:
		_call_void(context.get("unload_runtime", Callable()), [category, "reload_completed_disabled"])


func _restore_previous_state(category: String, old_runtime: Dictionary, definitions_before: Array, runtime_by_category: Dictionary, definitions_by_category: Dictionary) -> void:
	if not old_runtime.is_empty():
		runtime_by_category[category] = old_runtime.duplicate(true)
	if not definitions_before.is_empty():
		definitions_by_category[category] = definitions_before.duplicate(true)


func _make_reload_status(context: Dictionary, action: String, reloaded_domains: Array = [], skipped_domains: Array = [], failed_domains: Array = [], elapsed_ms: float = 0.0) -> Dictionary:
	var callback: Callable = context.get("make_reload_status", Callable())
	if callback.is_valid():
		var result = callback.call(action, reloaded_domains, skipped_domains, failed_domains, elapsed_ms)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
	return {
		"action": action,
		"reloaded_domains": reloaded_domains.duplicate(),
		"skipped_domains": skipped_domains.duplicate(),
		"failed_domains": failed_domains.duplicate(true),
		"elapsed_ms": elapsed_ms
	}


func _call_status(context: Dictionary, status: Dictionary) -> Dictionary:
	var callback: Callable = context.get("update_reload_status", Callable())
	if callback.is_valid():
		var result = callback.call(status)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
	return status.duplicate(true)


func _call_void(callable: Callable, args: Array = []) -> void:
	if callable.is_valid():
		callable.callv(args)


func _call_dictionary(callable: Callable, args: Array = []) -> Dictionary:
	if not callable.is_valid():
		return {}
	var result = callable.callv(args)
	if result is Dictionary:
		return (result as Dictionary).duplicate(true)
	return {}


func _call_array(callable: Callable, args: Array = []) -> Array:
	if not callable.is_valid():
		return []
	var result = callable.callv(args)
	return _array(result)


func _call_bool(callable: Callable, args: Array, default_value: bool) -> bool:
	if not callable.is_valid():
		return default_value
	return _as_bool(callable.callv(args))


func _ordered_categories(context: Dictionary) -> Array:
	var callback: Callable = context.get("get_ordered_categories", Callable())
	if callback.is_valid():
		return _array(callback.call())
	return _array(context.get("ordered_categories", []))


func _entries_by_category(context: Dictionary) -> Dictionary:
	var callback: Callable = context.get("get_entries_by_category", Callable())
	if callback.is_valid():
		return _dictionary_ref(callback.call())
	return _dictionary_ref(context.get("entries_by_category", {}))


func _runtime_by_category(context: Dictionary) -> Dictionary:
	var callback: Callable = context.get("get_runtime_by_category", Callable())
	if callback.is_valid():
		return _dictionary_ref(callback.call())
	return _dictionary_ref(context.get("runtime_by_category", {}))


func _tool_definitions_by_category(context: Dictionary) -> Dictionary:
	var callback: Callable = context.get("get_tool_definitions_by_category", Callable())
	if callback.is_valid():
		return _dictionary_ref(callback.call())
	return _dictionary_ref(context.get("tool_definitions_by_category", {}))


func _performance(context: Dictionary) -> Dictionary:
	var callback: Callable = context.get("get_performance", Callable())
	if callback.is_valid():
		return _dictionary_ref(callback.call())
	return _dictionary_ref(context.get("performance", {}))


func _dictionary(value) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _dictionary_ref(value) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _array(value) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []


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


func _elapsed_ms(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0
