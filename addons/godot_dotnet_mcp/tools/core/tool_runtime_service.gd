@tool
extends RefCounted
class_name MCPToolRuntimeService

var _tool_loader: Object
var _server_context: Object
var _get_entry: Callable = Callable()
var _get_runtime: Callable = Callable()
var _set_runtime: Callable = Callable()
var _has_tool_definitions_cache: Callable = Callable()
var _get_tool_definitions: Callable = Callable()
var _set_tool_definitions: Callable = Callable()
var _get_force_reload_script_load: Callable = Callable()
var _record_load_error: Callable = Callable()


func configure(tool_loader: Object, server_context: Object, options: Dictionary = {}) -> void:
	_tool_loader = tool_loader
	_server_context = server_context
	_get_entry = options.get("get_entry", Callable())
	_get_runtime = options.get("get_runtime", Callable())
	_set_runtime = options.get("set_runtime", Callable())
	_has_tool_definitions_cache = options.get("has_tool_definitions_cache", Callable())
	_get_tool_definitions = options.get("get_tool_definitions", Callable())
	_set_tool_definitions = options.get("set_tool_definitions", Callable())
	_get_force_reload_script_load = options.get("get_force_reload_script_load", Callable())
	_record_load_error = options.get("record_load_error", Callable())


func ensure_tool_definitions(category: String) -> Array:
	if _call_has_tool_definitions_cache(category):
		return _call_get_tool_definitions(category)

	var runtime = _call_get_runtime(category)
	var executor = runtime.get("instance", null)
	if executor == null:
		var instantiate_result = instantiate_executor(category, _call_force_reload_script_load(), "definitions")
		if not bool(instantiate_result.get("success", false)):
			_call_record_load_error(
				category,
				str(_call_get_entry(category).get("path", "")),
				str(instantiate_result.get("error", "Failed to load tool definitions"))
			)
			_call_set_tool_definitions(category, [])
			return []
		executor = instantiate_result.get("executor", null)

	var definitions = extract_tool_definitions(category, executor)
	_call_set_tool_definitions(category, definitions)
	return definitions


func ensure_runtime_loaded(category: String, reason: String) -> Dictionary:
	var runtime = _call_get_runtime(category)
	if runtime.get("instance", null) != null:
		return {
			"success": true,
			"runtime": runtime
		}

	var instantiate_result = instantiate_executor(category, false, reason)
	if _call_force_reload_script_load():
		instantiate_result = instantiate_executor(category, true, reason)
	if not bool(instantiate_result.get("success", false)):
		return {
			"success": false,
			"error": str(instantiate_result.get("error", "Failed to load tool runtime"))
		}

	var executor = instantiate_result.get("executor", null)
	var version = int(runtime.get("version", 0))
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
	_call_set_runtime(category, runtime)
	_call_set_tool_definitions(category, extract_tool_definitions(category, executor))
	return {
		"success": true,
		"runtime": runtime
	}


func instantiate_executor(category: String, force_reload: bool, reason: String) -> Dictionary:
	var entry = _call_get_entry(category)
	if entry.is_empty():
		return {
			"success": false,
			"error": "Tool domain is not registered"
		}

	var path = str(entry.get("path", ""))
	if path.is_empty():
		return {
			"success": false,
			"error": "Tool domain path is empty"
		}

	var script_resource = _load_script_resource(path, force_reload)
	if script_resource == null:
		return {
			"success": false,
			"error": "Failed to load tool script"
		}
	if script_resource is Script and not script_resource.can_instantiate():
		script_resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		if script_resource == null:
			return {
				"success": false,
				"error": "Failed to load tool script"
			}
		if script_resource is Script and not script_resource.can_instantiate():
			return {
				"success": false,
				"error": "Tool script could not be instantiated [replace_reload_failed]"
			}
	if not script_resource.has_method("new"):
		return {
			"success": false,
			"error": "Loaded tool resource is not instantiable"
		}

	var executor = script_resource.new()
	if executor == null:
		return {
			"success": false,
			"error": "Tool executor instance creation returned null"
		}
	if not executor.has_method("get_tools") or not executor.has_method("execute"):
		return {
			"success": false,
			"error": "Tool executor does not expose get_tools/execute"
		}
	if executor.has_method("configure_runtime"):
		executor.configure_runtime({
			"tool_loader": _tool_loader,
			"server": _server_context,
			"category": category,
			"reason": reason,
			"entry": entry.duplicate(true)
		})

	return {
		"success": true,
		"executor": executor
	}


func extract_tool_definitions(_category: String, executor) -> Array:
	var definitions: Array[Dictionary] = []
	if executor == null or not executor.has_method("get_tools"):
		return definitions
	for tool_def in executor.get_tools():
		if not (tool_def is Dictionary):
			continue
		definitions.append((tool_def as Dictionary).duplicate(true))
	return definitions


func unload_runtime(category: String, reason: String) -> void:
	var runtime = _call_get_runtime(category)
	if runtime.is_empty():
		return
	runtime["instance"] = null
	runtime["state"] = "definitions_only"
	runtime["last_unloaded_reason"] = reason
	_call_set_runtime(category, runtime)


func _load_script_resource(path: String, force_reload: bool) -> Resource:
	var cache_mode = ResourceLoader.CACHE_MODE_REUSE
	if force_reload:
		cache_mode = ResourceLoader.CACHE_MODE_REPLACE
	return ResourceLoader.load(path, "", cache_mode)


func _call_get_entry(category: String) -> Dictionary:
	if not _get_entry.is_valid():
		return {}
	var entry = _get_entry.call(category)
	return entry if entry is Dictionary else {}


func _call_get_runtime(category: String) -> Dictionary:
	if not _get_runtime.is_valid():
		return {}
	var runtime = _get_runtime.call(category)
	return runtime if runtime is Dictionary else {}


func _call_set_runtime(category: String, runtime: Dictionary) -> void:
	if _set_runtime.is_valid():
		_set_runtime.call(category, runtime)


func _call_has_tool_definitions_cache(category: String) -> bool:
	if not _has_tool_definitions_cache.is_valid():
		return false
	return _as_bool(_has_tool_definitions_cache.call(category))


func _call_get_tool_definitions(category: String) -> Array:
	if not _get_tool_definitions.is_valid():
		return []
	var definitions = _get_tool_definitions.call(category)
	return definitions if definitions is Array else []


func _call_set_tool_definitions(category: String, definitions: Array) -> void:
	if _set_tool_definitions.is_valid():
		_set_tool_definitions.call(category, definitions)


func _call_force_reload_script_load() -> bool:
	if not _get_force_reload_script_load.is_valid():
		return false
	return _as_bool(_get_force_reload_script_load.call())


func _call_record_load_error(category: String, path: String, message: String) -> void:
	if _record_load_error.is_valid():
		_record_load_error.call(category, path, message)


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
