@tool
extends RefCounted
class_name ToolLoaderRuntimeStateService


func ensure_tool_definitions(category: String, context: Dictionary) -> Array:
	var definitions_by_category: Dictionary = _tool_definitions_by_category(context)
	if definitions_by_category.has(category):
		return _array(definitions_by_category[category])

	var runtime: Dictionary = _dictionary(_runtime_by_category(context).get(category, {}))
	var executor = runtime.get("instance", null)
	var created_for_definitions := false
	if executor == null:
		var instantiate_result: Dictionary = _call_dictionary(context.get("instantiate_executor", Callable()), [category, _force_reload_script_load(context), "definitions"])
		if not _as_bool(instantiate_result.get("success", false)):
			var entries: Dictionary = _entries_by_category(context)
			_call_void(context.get("record_load_error", Callable()), [
				category,
				str(_dictionary(entries.get(category, {})).get("path", "")),
				str(instantiate_result.get("error", "Failed to load tool definitions"))
			])
			definitions_by_category[category] = []
			return []
		executor = instantiate_result.get("executor")
		created_for_definitions = true

	var definitions: Array = _call_array(context.get("extract_tool_definitions", Callable()), [category, executor])
	definitions_by_category[category] = definitions
	if created_for_definitions:
		_call_void(context.get("dispose_executor", Callable()), [executor])
		var runtime_by_category: Dictionary = _runtime_by_category(context)
		if not runtime_by_category.has(category):
			runtime_by_category[category] = {
				"instance": null,
				"state": "definitions_only",
				"version": 0,
				"load_count": 0,
				"last_loaded_at_unix": 0,
				"last_error": null
			}
	return definitions


func ensure_runtime_loaded(category: String, reason: String, context: Dictionary) -> Dictionary:
	var runtime_by_category: Dictionary = _runtime_by_category(context)
	var definitions_by_category: Dictionary = _tool_definitions_by_category(context)
	var runtime: Dictionary = _dictionary(runtime_by_category.get(category, {}))
	if runtime.get("instance", null) != null:
		return {"success": true, "runtime": runtime}

	var instantiate_result: Dictionary = _call_dictionary(context.get("instantiate_executor", Callable()), [category, false, reason])
	if _force_reload_script_load(context):
		instantiate_result = _call_dictionary(context.get("instantiate_executor", Callable()), [category, true, reason])
	if not _as_bool(instantiate_result.get("success", false)):
		return _call_failure(context, "tool_load_failed", category, "", str(instantiate_result.get("error", "Failed to load tool runtime")))

	var executor = instantiate_result.get("executor")
	var version := int(runtime.get("version", 0))
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
	runtime_by_category[category] = runtime
	definitions_by_category[category] = _call_array(context.get("extract_tool_definitions", Callable()), [category, executor])
	return {"success": true, "runtime": runtime}


func unload_runtime(category: String, reason: String, context: Dictionary) -> void:
	var runtime_by_category: Dictionary = _runtime_by_category(context)
	if not runtime_by_category.has(category):
		return
	var runtime: Dictionary = _dictionary(runtime_by_category.get(category, {}))
	_call_void(context.get("dispose_executor", Callable()), [runtime.get("instance", null)])
	if reason == "shutdown":
		runtime_by_category.erase(category)
		return
	runtime["instance"] = null
	runtime["state"] = "definitions_only"
	runtime["last_unloaded_reason"] = reason
	runtime_by_category[category] = runtime


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


func _force_reload_script_load(context: Dictionary) -> bool:
	var callback: Callable = context.get("get_force_reload_script_load", Callable())
	if callback.is_valid():
		return _as_bool(callback.call())
	return _as_bool(context.get("force_reload_script_load", false))


func _call_failure(context: Dictionary, error_type: String, category: String, tool_name: String, message: String) -> Dictionary:
	var callback: Callable = context.get("failure", Callable())
	if callback.is_valid():
		var result = callback.call(error_type, category, tool_name, message)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
	return {
		"success": false,
		"error": message,
		"data": {
			"error_type": error_type,
			"domain": category,
			"tool_name": category if tool_name.is_empty() else "%s_%s" % [category, tool_name]
		}
	}


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
