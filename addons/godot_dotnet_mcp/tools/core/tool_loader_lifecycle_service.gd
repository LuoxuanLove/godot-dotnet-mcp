@tool
extends RefCounted
class_name ToolLoaderLifecycleService


func initialize(disabled_tools: Array, force_reload_scripts: bool, context: Dictionary) -> Dictionary:
	var started_usec := Time.get_ticks_usec()
	var preload_enabled := _call_bool(context.get("should_preload_runtimes", Callable()), [], false)
	_call_void(context.get("set_force_reload_script_load", Callable()), [force_reload_scripts])
	_call_void(context.get("set_disabled_tools", Callable()), [disabled_tools])
	_call_void(context.get("reset_state", Callable()))
	_call_void(context.get("reset_gdscript_lsp_diagnostics_service", Callable()))
	_call_void(context.get("refresh_entries", Callable()))

	var definition_started := Time.get_ticks_usec()
	for category in _ordered_categories(context):
		_call_array(context.get("ensure_tool_definitions", Callable()), [str(category)])
	_performance(context)["definition_scan_ms"] = _elapsed_ms(definition_started)

	var preload_started := Time.get_ticks_usec()
	if preload_enabled:
		for category in _ordered_categories(context):
			var category_name := str(category)
			if _call_bool(context.get("category_has_enabled_tools", Callable()), [category_name], false):
				_call_dictionary(context.get("ensure_runtime_loaded", Callable()), [category_name, "preload"])
	_performance(context)["preload_ms"] = _elapsed_ms(preload_started) if preload_enabled else 0.0
	_performance(context)["preload_skipped"] = not preload_enabled
	_performance(context)["startup_ms"] = _elapsed_ms(started_usec)
	_call_status(context, _make_reload_status(context, "initialize"))
	_call_void(context.get("sync_load_error_incidents", Callable()), ["initialize"])
	_call_void(context.get("refresh_runtime_context", Callable()))
	_call_void(context.get("set_force_reload_script_load", Callable()), [false])

	return {
		"tool_count": _call_array(context.get("get_tool_definitions", Callable())).size(),
		"exposed_tool_count": _call_array(context.get("get_exposed_tool_definitions", Callable())).size(),
		"category_count": _ordered_categories(context).size(),
		"tool_load_error_count": _call_int(context.get("get_tool_load_error_count", Callable()), 0)
	}


func shutdown(context: Dictionary) -> void:
	var categories := _runtime_by_category(context).keys()
	for category in categories:
		_call_void(context.get("unload_runtime", Callable()), [str(category), "shutdown"])
	_call_void(context.get("dispose_gdscript_lsp_diagnostics_adapter", Callable()))
	_call_void(context.get("set_force_reload_script_load", Callable()), [false])
	_call_void(context.get("reset_state", Callable()))


func set_disabled_tools(disabled_tools: Array, context: Dictionary) -> void:
	var changed := _call_bool(context.get("set_disabled_tools", Callable()), [disabled_tools], true)
	if not changed:
		return
	for category in _ordered_categories(context):
		var category_name := str(category)
		if _call_bool(context.get("category_has_enabled_tools", Callable()), [category_name], false):
			_call_dictionary(context.get("ensure_runtime_loaded", Callable()), [category_name, "disabled_tools_changed"])
		else:
			_call_void(context.get("unload_runtime", Callable()), [category_name, "disabled_tools_changed"])
	_call_void(context.get("refresh_runtime_context", Callable()))


func tick(delta: float, context: Dictionary) -> void:
	var tick_result: Dictionary = _call_dictionary(context.get("tick_loaded_runtimes", Callable()), [delta])
	var refresh_context := _apply_tick_result(tick_result, context)
	if refresh_context:
		_call_void(context.get("bump_catalog_revision", Callable()))
		_call_void(context.get("refresh_runtime_context", Callable()))
	_call_void(context.get("tick_gdscript_lsp_diagnostics", Callable()), [delta])


func _apply_tick_result(tick_result: Dictionary, context: Dictionary) -> bool:
	var refresh_context := false
	var definitions_by_category: Dictionary = _tool_definitions_by_category(context)
	var runtime_by_category: Dictionary = _runtime_by_category(context)
	if _as_bool(tick_result.get("user_definitions_changed", false)):
		definitions_by_category["user"] = _array(tick_result.get("user_definitions", []))
		refresh_context = true
	if _as_bool(tick_result.get("user_should_unload", false)) and runtime_by_category.has("user"):
		runtime_by_category.erase("user")
		definitions_by_category.erase("user")
		refresh_context = true
	return refresh_context


func _make_reload_status(context: Dictionary, action: String) -> Dictionary:
	var callback: Callable = context.get("make_reload_status", Callable())
	if callback.is_valid():
		var result = callback.call(action)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
	return {"action": action}


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


func _call_int(callable: Callable, default_value: int) -> int:
	if not callable.is_valid():
		return default_value
	var result = callable.call()
	if result is int:
		return int(result)
	if result is float:
		return int(result)
	return default_value


func _ordered_categories(context: Dictionary) -> Array:
	var callback: Callable = context.get("get_ordered_categories", Callable())
	if callback.is_valid():
		return _array(callback.call())
	return _array(context.get("ordered_categories", []))


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
	return _dictionary_ref(context.get("performance", {}))


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
