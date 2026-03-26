@tool
extends RefCounted
class_name MCPToolReloadService

var _refresh_entries: Callable = Callable()
var _get_entry: Callable = Callable()
var _get_ordered_categories: Callable = Callable()
var _get_disabled_tools: Callable = Callable()
var _set_disabled_tools: Callable = Callable()
var _get_runtime: Callable = Callable()
var _set_runtime: Callable = Callable()
var _erase_runtime: Callable = Callable()
var _get_tool_definitions: Callable = Callable()
var _set_tool_definitions: Callable = Callable()
var _erase_tool_definitions: Callable = Callable()
var _instantiate_executor: Callable = Callable()
var _extract_tool_definitions: Callable = Callable()
var _sync_load_error_incidents: Callable = Callable()
var _refresh_runtime_context: Callable = Callable()
var _reset_lsp_diagnostics: Callable = Callable()
var _category_has_enabled_tools: Callable = Callable()
var _unload_runtime: Callable = Callable()
var _record_reload_incident: Callable = Callable()
var _as_bool: Callable = Callable()


func configure(options: Dictionary = {}) -> void:
	_refresh_entries = options.get("refresh_entries", Callable())
	_get_entry = options.get("get_entry", Callable())
	_get_ordered_categories = options.get("get_ordered_categories", Callable())
	_get_disabled_tools = options.get("get_disabled_tools", Callable())
	_set_disabled_tools = options.get("set_disabled_tools", Callable())
	_get_runtime = options.get("get_runtime", Callable())
	_set_runtime = options.get("set_runtime", Callable())
	_erase_runtime = options.get("erase_runtime", Callable())
	_get_tool_definitions = options.get("get_tool_definitions", Callable())
	_set_tool_definitions = options.get("set_tool_definitions", Callable())
	_erase_tool_definitions = options.get("erase_tool_definitions", Callable())
	_instantiate_executor = options.get("instantiate_executor", Callable())
	_extract_tool_definitions = options.get("extract_tool_definitions", Callable())
	_sync_load_error_incidents = options.get("sync_load_error_incidents", Callable())
	_refresh_runtime_context = options.get("refresh_runtime_context", Callable())
	_reset_lsp_diagnostics = options.get("reset_lsp_diagnostics", Callable())
	_category_has_enabled_tools = options.get("category_has_enabled_tools", Callable())
	_unload_runtime = options.get("unload_runtime", Callable())
	_record_reload_incident = options.get("record_reload_incident", Callable())
	_as_bool = options.get("as_bool", Callable())


func dispose() -> void:
	_refresh_entries = Callable()
	_get_entry = Callable()
	_get_ordered_categories = Callable()
	_get_disabled_tools = Callable()
	_set_disabled_tools = Callable()
	_get_runtime = Callable()
	_set_runtime = Callable()
	_erase_runtime = Callable()
	_get_tool_definitions = Callable()
	_set_tool_definitions = Callable()
	_erase_tool_definitions = Callable()
	_instantiate_executor = Callable()
	_extract_tool_definitions = Callable()
	_sync_load_error_incidents = Callable()
	_refresh_runtime_context = Callable()
	_reset_lsp_diagnostics = Callable()
	_category_has_enabled_tools = Callable()
	_unload_runtime = Callable()
	_record_reload_incident = Callable()
	_as_bool = Callable()


func reload_domain(category: String) -> Dictionary:
	return _reload_domain_internal(category, true)


func reload_all_domains() -> Dictionary:
	var started_usec = Time.get_ticks_usec()
	var disabled_tools = _call_get_disabled_tools()
	_call_refresh_entries()
	_call_set_disabled_tools(disabled_tools)

	var reloaded: Array = []
	var skipped: Array = []
	var failed: Array = []
	var reload_total_ms_delta := 0.0
	var reload_count_delta := 0
	for category in _call_get_ordered_categories():
		var entry = _call_get_entry(category)
		if not _call_as_bool(entry.get("hot_reloadable", true)):
			skipped.append(category)
			continue
		var status = _reload_domain_internal(category, true)
		reloaded.append_array(status.get("reloaded_domains", []))
		skipped.append_array(status.get("skipped_domains", []))
		failed.append_array(status.get("failed_domains", []))
		reload_total_ms_delta += float(status.get("reload_total_ms_delta", 0.0))
		reload_count_delta += int(status.get("reload_count_delta", 0))

	_call_sync_load_error_incidents("reload_all_domains")
	_call_refresh_runtime_context()
	_call_reset_lsp_diagnostics()

	return {
		"reloaded_domains": reloaded,
		"skipped_domains": skipped,
		"failed_domains": failed,
		"elapsed_ms": _elapsed_ms(started_usec),
		"reload_total_ms_delta": reload_total_ms_delta,
		"reload_count_delta": reload_count_delta
	}


func _reload_domain_internal(category: String, refresh_user_entries: bool) -> Dictionary:
	if refresh_user_entries and category == "user":
		_call_refresh_entries()

	var entry = _call_get_entry(category)
	if entry.is_empty():
		if category == "user":
			return {
				"reloaded_domains": [],
				"skipped_domains": [category],
				"failed_domains": [],
				"elapsed_ms": 0.0,
				"reload_total_ms_delta": 0.0,
				"reload_count_delta": 0
			}
		return {
			"reloaded_domains": [],
			"skipped_domains": [],
			"failed_domains": [{
				"domain": category,
				"error": "Unknown tool domain"
			}],
			"elapsed_ms": 0.0,
			"reload_total_ms_delta": 0.0,
			"reload_count_delta": 0
		}

	if not _call_as_bool(entry.get("hot_reloadable", true)):
		return {
			"reloaded_domains": [],
			"skipped_domains": [category],
			"failed_domains": [],
			"elapsed_ms": 0.0,
			"reload_total_ms_delta": 0.0,
			"reload_count_delta": 0
		}

	var old_runtime = _call_get_runtime(category).duplicate(true)
	var definitions_before = _call_get_tool_definitions(category).duplicate(true)
	var reload_started = Time.get_ticks_usec()

	var instantiate_result = _call_instantiate_executor(category, true, "reload")
	if not bool(instantiate_result.get("success", false)):
		var reload_err = str(instantiate_result.get("error", "Failed to reload tool domain"))
		_call_record_reload_incident(category, reload_err, "reload_domain")
		_restore_snapshot(category, old_runtime, definitions_before)
		return {
			"reloaded_domains": [],
			"skipped_domains": [],
			"failed_domains": [{
				"domain": category,
				"error": reload_err
			}],
			"elapsed_ms": _elapsed_ms(reload_started),
			"reload_total_ms_delta": 0.0,
			"reload_count_delta": 0
		}

	var executor = instantiate_result.get("executor", null)
	var version = int(old_runtime.get("version", 0)) + 1
	var allow_empty_definitions = true if entry.get("allow_empty_definitions", false) else false
	_call_set_runtime(category, {
		"instance": executor,
		"state": "loaded",
		"version": version,
		"load_count": int(old_runtime.get("load_count", 0)) + 1,
		"last_loaded_at_unix": int(Time.get_unix_time_from_system()),
		"last_error": null
	})

	var definitions = _call_extract_tool_definitions(category, executor)
	if definitions.is_empty():
		if allow_empty_definitions:
			_call_set_tool_definitions(category, [])
			_call_sync_load_error_incidents("reload_domain")
			_call_refresh_runtime_context()
			_call_reset_lsp_diagnostics()
			if not _call_category_has_enabled_tools(category):
				_call_unload_runtime(category, "reload_completed_disabled")
			return {
				"reloaded_domains": [category],
				"skipped_domains": [],
				"failed_domains": [],
				"elapsed_ms": _elapsed_ms(reload_started),
				"reload_total_ms_delta": _elapsed_ms(reload_started),
				"reload_count_delta": 1,
				"definition_count": 0,
				"allow_empty_definitions": true
			}

		_call_record_reload_incident(category, "Reloaded tool domain did not expose any tool definitions", "reload_domain")
		_restore_snapshot(category, old_runtime, definitions_before)
		return {
			"reloaded_domains": [],
			"skipped_domains": [],
			"failed_domains": [{
				"domain": category,
				"error": "Reloaded tool domain did not expose any tool definitions"
			}],
			"elapsed_ms": _elapsed_ms(reload_started),
			"reload_total_ms_delta": 0.0,
			"reload_count_delta": 0
		}

	_call_set_tool_definitions(category, definitions)
	_call_sync_load_error_incidents("reload_domain")
	_call_refresh_runtime_context()
	_call_reset_lsp_diagnostics()
	if not _call_category_has_enabled_tools(category):
		_call_unload_runtime(category, "reload_completed_disabled")

	return {
		"reloaded_domains": [category],
		"skipped_domains": [],
		"failed_domains": [],
		"elapsed_ms": _elapsed_ms(reload_started),
		"reload_total_ms_delta": _elapsed_ms(reload_started),
		"reload_count_delta": 1,
		"definition_count": definitions.size(),
		"allow_empty_definitions": false
	}


func _restore_snapshot(category: String, runtime_snapshot: Dictionary, definitions_snapshot: Array) -> void:
	if runtime_snapshot.is_empty():
		_call_erase_runtime(category)
	else:
		_call_set_runtime(category, runtime_snapshot.duplicate(true))

	if definitions_snapshot.is_empty():
		_call_erase_tool_definitions(category)
	else:
		_call_set_tool_definitions(category, definitions_snapshot.duplicate(true))


func _elapsed_ms(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0


func _call_refresh_entries() -> void:
	if _refresh_entries.is_valid():
		_refresh_entries.call()


func _call_get_entry(category: String) -> Dictionary:
	if not _get_entry.is_valid():
		return {}
	var entry = _get_entry.call(category)
	return entry if entry is Dictionary else {}


func _call_get_ordered_categories() -> Array[String]:
	if not _get_ordered_categories.is_valid():
		return []
	var ordered = _get_ordered_categories.call()
	return ordered if ordered is Array else []


func _call_get_disabled_tools() -> Array:
	if not _get_disabled_tools.is_valid():
		return []
	var disabled = _get_disabled_tools.call()
	return disabled if disabled is Array else []


func _call_set_disabled_tools(disabled_tools: Array) -> void:
	if _set_disabled_tools.is_valid():
		_set_disabled_tools.call(disabled_tools)


func _call_get_runtime(category: String) -> Dictionary:
	if not _get_runtime.is_valid():
		return {}
	var runtime = _get_runtime.call(category)
	return runtime if runtime is Dictionary else {}


func _call_set_runtime(category: String, runtime: Dictionary) -> void:
	if _set_runtime.is_valid():
		_set_runtime.call(category, runtime)


func _call_erase_runtime(category: String) -> void:
	if _erase_runtime.is_valid():
		_erase_runtime.call(category)


func _call_get_tool_definitions(category: String) -> Array:
	if not _get_tool_definitions.is_valid():
		return []
	var definitions = _get_tool_definitions.call(category)
	return definitions if definitions is Array else []


func _call_set_tool_definitions(category: String, definitions: Array) -> void:
	if _set_tool_definitions.is_valid():
		_set_tool_definitions.call(category, definitions)


func _call_erase_tool_definitions(category: String) -> void:
	if _erase_tool_definitions.is_valid():
		_erase_tool_definitions.call(category)


func _call_instantiate_executor(category: String, force_reload: bool, reason: String) -> Dictionary:
	if not _instantiate_executor.is_valid():
		return {
			"success": false,
			"error": "Tool runtime instantiate callback is unavailable"
		}
	var result = _instantiate_executor.call(category, force_reload, reason)
	return result if result is Dictionary else {
		"success": false,
		"error": "Tool runtime instantiate callback returned an invalid result"
	}


func _call_extract_tool_definitions(category: String, executor) -> Array:
	if not _extract_tool_definitions.is_valid():
		return []
	var definitions = _extract_tool_definitions.call(category, executor)
	return definitions if definitions is Array else []


func _call_sync_load_error_incidents(phase: String) -> void:
	if _sync_load_error_incidents.is_valid():
		_sync_load_error_incidents.call(phase)


func _call_refresh_runtime_context() -> void:
	if _refresh_runtime_context.is_valid():
		_refresh_runtime_context.call()


func _call_reset_lsp_diagnostics() -> void:
	if _reset_lsp_diagnostics.is_valid():
		_reset_lsp_diagnostics.call()


func _call_category_has_enabled_tools(category: String) -> bool:
	if not _category_has_enabled_tools.is_valid():
		return false
	return _call_as_bool(_category_has_enabled_tools.call(category))


func _call_unload_runtime(category: String, reason: String) -> void:
	if _unload_runtime.is_valid():
		_unload_runtime.call(category, reason)


func _call_record_reload_incident(category: String, message: String, phase: String) -> void:
	if _record_reload_incident.is_valid():
		_record_reload_incident.call(category, message, phase)


func _call_as_bool(value) -> bool:
	if _as_bool.is_valid():
		return bool(_as_bool.call(value))
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
