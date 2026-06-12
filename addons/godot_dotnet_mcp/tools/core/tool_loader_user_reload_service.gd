@tool
extends RefCounted
class_name ToolLoaderUserReloadService


func request_reload_by_script(script_path: String, reason: String, context: Dictionary) -> Dictionary:
	var normalized_path := script_path.strip_edges()
	if normalized_path.is_empty():
		return {"success": false, "error": "Missing script path"}
	var entries: Dictionary = _entries_by_category(context)
	if not entries.has("user"):
		return {"success": false, "error": "User domain is not registered"}
	if not _call_bool(context.get("category_has_enabled_tools", Callable()), ["user"], false):
		_call_dictionary(context.get("ensure_runtime_loaded", Callable()), ["user", "request_reload_by_script"])
	var runtime_by_category: Dictionary = _runtime_by_category(context)
	var runtime: Dictionary = _dictionary(runtime_by_category.get("user", {}))
	var executor = runtime.get("instance", null)
	if executor == null or not executor.has_method("request_reload_by_script"):
		return {"success": false, "error": "User runtime is unavailable"}
	executor.request_reload_by_script(normalized_path, reason)
	var tick_result: Dictionary = _call_dictionary(context.get("tick_loaded_runtimes", Callable()), [{
		"user": runtime
	}, _tool_definitions_by_category(context), 0.0])
	_call_void(context.get("apply_tick_result", Callable()), [tick_result])
	runtime_by_category = _runtime_by_category(context)
	if runtime_by_category.has("user"):
		_call_void(context.get("refresh_runtime_context", Callable()))
	return {
		"success": true,
		"script_path": normalized_path,
		"reason": reason,
		"runtime_state": _runtime_state_snapshot(executor)
	}


func get_user_tool_runtime_snapshot(context: Dictionary) -> Array:
	var runtime: Dictionary = _dictionary(_runtime_by_category(context).get("user", {}))
	return _runtime_state_snapshot(runtime.get("instance", null))


func _runtime_state_snapshot(executor) -> Array:
	if executor != null and executor.has_method("get_runtime_state_snapshot"):
		var snapshot = executor.get_runtime_state_snapshot()
		if snapshot is Array:
			return (snapshot as Array).duplicate(true)
	return []


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


func _call_bool(callable: Callable, args: Array, default_value: bool) -> bool:
	if not callable.is_valid():
		return default_value
	return _as_bool(callable.callv(args))


func _dictionary(value) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _dictionary_ref(value) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


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
