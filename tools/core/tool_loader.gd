@tool
extends RefCounted
class_name MCPToolLoader

const MCPToolRegistry = preload("res://addons/godot_dotnet_mcp/tools/tool_registry.gd")

var _registry := MCPToolRegistry.new()
var _server_context: Object
var _entries_by_category: Dictionary = {}
var _ordered_categories: Array[String] = []
var _runtime_by_category: Dictionary = {}
var _tool_definitions_by_category: Dictionary = {}
var _disabled_tools: Dictionary = {}
var _load_errors: Array[Dictionary] = []
var _reload_status: Dictionary = {}
var _performance: Dictionary = {
	"startup_ms": 0.0,
	"definition_scan_ms": 0.0,
	"preload_ms": 0.0,
	"reload_total_ms": 0.0,
	"reload_count": 0,
	"tool_calls": {}
}


func configure(server_context: Object) -> void:
	_server_context = server_context


func initialize(disabled_tools: Array = []) -> Dictionary:
	var started_usec = Time.get_ticks_usec()
	_set_disabled_tools(disabled_tools)
	_reset_state()
	_refresh_entries()

	var definition_started = Time.get_ticks_usec()
	for category in _ordered_categories:
		_ensure_tool_definitions(category)
	_performance["definition_scan_ms"] = _elapsed_ms(definition_started)

	var preload_started = Time.get_ticks_usec()
	for category in _ordered_categories:
		if _category_has_enabled_tools(category):
			_ensure_runtime_loaded(category, "preload")
	_performance["preload_ms"] = _elapsed_ms(preload_started)
	_performance["startup_ms"] = _elapsed_ms(started_usec)
	_reload_status = _make_reload_status("initialize")

	return {
		"tool_count": get_tool_definitions().size(),
		"category_count": _ordered_categories.size(),
		"tool_load_error_count": _load_errors.size()
	}


func reload_registry(disabled_tools: Array = []) -> Dictionary:
	return initialize(disabled_tools)


func set_disabled_tools(disabled_tools: Array) -> void:
	_set_disabled_tools(disabled_tools)
	for category in _ordered_categories:
		if _category_has_enabled_tools(category):
			_ensure_runtime_loaded(category, "disabled_tools_changed")
		else:
			_unload_runtime(category, "disabled_tools_changed")


func get_tools_by_category() -> Dictionary:
	return _build_tools_by_category(true)


func get_all_tools_by_category() -> Dictionary:
	return _build_tools_by_category(false)


func _build_tools_by_category(visible_only: bool) -> Dictionary:
	var result: Dictionary = {}
	for category in _ordered_categories:
		if visible_only and not _is_category_visible(category):
			continue
		var defs = _ensure_tool_definitions(category)
		if defs.is_empty():
			continue
		var decorated_defs: Array[Dictionary] = []
		for tool_def in defs:
			decorated_defs.append(_decorate_tool_definition(category, tool_def))
		result[category] = decorated_defs
	return result


func get_tool_definitions() -> Array[Dictionary]:
	return _build_tool_definitions(true)


func get_all_tool_definitions() -> Array[Dictionary]:
	return _build_tool_definitions(false)


func _build_tool_definitions(visible_only: bool) -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for category in _ordered_categories:
		if visible_only and not _is_category_visible(category):
			continue
		for tool_def in _ensure_tool_definitions(category):
			var full_def = _decorate_tool_definition(category, tool_def)
			full_def["name"] = "%s_%s" % [category, str(tool_def.get("name", ""))]
			full_def["category"] = category
			definitions.append(full_def)
	return definitions


func get_tool_load_errors() -> Array[Dictionary]:
	return _load_errors.duplicate(true)


func get_domain_states() -> Array[Dictionary]:
	return _build_domain_states(true)


func get_all_domain_states() -> Array[Dictionary]:
	return _build_domain_states(false)


func _build_domain_states(visible_only: bool) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for category in _ordered_categories:
		if visible_only and not _is_category_visible(category):
			continue
		var entry: Dictionary = _entries_by_category.get(category, {})
		var runtime: Dictionary = _runtime_by_category.get(category, {})
		var defs = _tool_definitions_by_category.get(category, [])
		states.append({
			"domain": category,
			"category": category,
			"domain_key": str(entry.get("domain_key", "other")),
			"source": str(entry.get("source", "builtin")),
			"script_path": str(entry.get("path", "")),
			"hot_reloadable": bool(entry.get("hot_reloadable", true)),
			"loaded": runtime.get("instance", null) != null,
			"load_state": _current_load_state(category),
			"tool_count": defs.size(),
			"enabled_tool_count": _count_enabled_tools_in_category(category),
			"version": int(runtime.get("version", 0)),
			"load_count": int(runtime.get("load_count", 0)),
			"last_loaded_at_unix": int(runtime.get("last_loaded_at_unix", 0)),
			"last_error": runtime.get("last_error", null)
		})
	return states


func get_reload_status() -> Dictionary:
	return _reload_status.duplicate(true)


func get_performance_summary() -> Dictionary:
	var per_tool: Array[Dictionary] = []
	for tool_name in _performance.get("tool_calls", {}).keys():
		per_tool.append(_performance["tool_calls"][tool_name].duplicate(true))
	per_tool.sort_custom(Callable(self, "_sort_tool_metric"))
	return {
		"startup_ms": _performance.get("startup_ms", 0.0),
		"definition_scan_ms": _performance.get("definition_scan_ms", 0.0),
		"preload_ms": _performance.get("preload_ms", 0.0),
		"reload_total_ms": _performance.get("reload_total_ms", 0.0),
		"reload_count": _performance.get("reload_count", 0),
		"tool_calls": per_tool
	}


func get_tool_usage_stats() -> Array[Dictionary]:
	var stats: Array[Dictionary] = []
	for tool_name in _performance.get("tool_calls", {}).keys():
		var metric: Dictionary = _performance["tool_calls"][tool_name]
		stats.append({
			"tool_name": str(metric.get("tool_name", tool_name)),
			"category": str(metric.get("category", "")),
			"call_count": int(metric.get("count", 0)),
			"last_called_at_unix": int(metric.get("last_called_at_unix", 0)),
			"total_ms": float(metric.get("total_ms", 0.0)),
			"avg_ms": float(metric.get("avg_ms", 0.0)),
			"last_ms": float(metric.get("last_ms", 0.0))
		})
	stats.sort_custom(Callable(self, "_sort_tool_usage_stats"))
	return stats


func execute_tool(category: String, tool_name: String, args: Dictionary) -> Dictionary:
	if not _is_category_executable(category):
		return _failure("permission_denied", category, tool_name, _get_permission_error(category))

	var runtime_result = _ensure_runtime_loaded(category, "tool_call")
	if not runtime_result.get("success", false):
		return runtime_result

	var runtime: Dictionary = runtime_result.get("runtime", {})
	var executor = runtime.get("instance")
	if executor == null:
		return _failure("tool_runtime_missing", category, tool_name, "Tool runtime is unavailable")

	var started_usec = Time.get_ticks_usec()
	var result = executor.execute(tool_name, args)
	var elapsed_ms = _elapsed_ms(started_usec)
	_record_tool_call_metric("%s_%s" % [category, tool_name], category, elapsed_ms)

	if result is Dictionary and bool(result.get("success", true)):
		return result

	var error_message = "Tool execution failed"
	if result is Dictionary:
		error_message = str(result.get("error", error_message))
		var failure_result: Dictionary = result.duplicate(true)
		var failure_data = failure_result.get("data", {})
		if not (failure_data is Dictionary):
			failure_data = {"details": failure_data}
		failure_data["tool_name"] = "%s_%s" % [category, tool_name]
		failure_data["action"] = str(args.get("action", ""))
		failure_data["error_type"] = str(failure_data.get("error_type", "tool_execution_failed"))
		failure_data["domain"] = category
		failure_data["elapsed_ms"] = elapsed_ms
		failure_data["timestamp_unix"] = int(Time.get_unix_time_from_system())
		failure_result["data"] = failure_data
		return failure_result

	return _failure("tool_execution_failed", category, tool_name, error_message, {
		"action": str(args.get("action", "")),
		"elapsed_ms": elapsed_ms
	})


func reload_domain(category: String) -> Dictionary:
	if not _entries_by_category.has(category):
		return _update_reload_status(_make_reload_status("reload_domain", [], [], [{
			"domain": category,
			"error": "Unknown tool domain"
		}]))

	var entry: Dictionary = _entries_by_category.get(category, {})
	if not bool(entry.get("hot_reloadable", true)):
		return _update_reload_status(_make_reload_status("reload_domain", [], [category], []))

	var old_runtime: Dictionary = _runtime_by_category.get(category, {}).duplicate(true)
	var definitions_before = _tool_definitions_by_category.get(category, []).duplicate(true)
	var reload_started = Time.get_ticks_usec()

	var instantiate_result = _instantiate_executor(category, true, "reload")
	if not instantiate_result.get("success", false):
		if not old_runtime.is_empty():
			_runtime_by_category[category] = old_runtime
		if not definitions_before.is_empty():
			_tool_definitions_by_category[category] = definitions_before
		return _update_reload_status(_make_reload_status("reload_domain", [], [], [{
			"domain": category,
			"error": str(instantiate_result.get("error", "Failed to reload tool domain"))
		}], _elapsed_ms(reload_started)))

	var executor = instantiate_result.get("executor")
	var version = int(old_runtime.get("version", 0)) + 1
	_runtime_by_category[category] = {
		"instance": executor,
		"state": "loaded",
		"version": version,
		"load_count": int(old_runtime.get("load_count", 0)) + 1,
		"last_loaded_at_unix": int(Time.get_unix_time_from_system()),
		"last_error": null
	}
	var definitions = _extract_tool_definitions(category, executor)
	if definitions.is_empty():
		if not old_runtime.is_empty():
			_runtime_by_category[category] = old_runtime
		if not definitions_before.is_empty():
			_tool_definitions_by_category[category] = definitions_before
		return _update_reload_status(_make_reload_status("reload_domain", [], [], [{
			"domain": category,
			"error": "Reloaded tool domain did not expose any tool definitions"
		}], _elapsed_ms(reload_started)))

	_tool_definitions_by_category[category] = definitions
	_performance["reload_total_ms"] = float(_performance.get("reload_total_ms", 0.0)) + _elapsed_ms(reload_started)
	_performance["reload_count"] = int(_performance.get("reload_count", 0)) + 1

	if not _category_has_enabled_tools(category):
		_unload_runtime(category, "reload_completed_disabled")

	return _update_reload_status(_make_reload_status("reload_domain", [category], [], [], _elapsed_ms(reload_started)))


func reload_all_domains() -> Dictionary:
	var started_usec = Time.get_ticks_usec()
	var disabled_tools = get_disabled_tools()
	_refresh_entries()
	_set_disabled_tools(disabled_tools)

	var reloaded: Array = []
	var skipped: Array = []
	var failed: Array = []
	for category in _ordered_categories:
		var entry: Dictionary = _entries_by_category.get(category, {})
		if not bool(entry.get("hot_reloadable", true)):
			skipped.append(category)
			continue
		var status = reload_domain(category)
		reloaded.append_array(status.get("reloaded_domains", []))
		skipped.append_array(status.get("skipped_domains", []))
		failed.append_array(status.get("failed_domains", []))

	return _update_reload_status(_make_reload_status("reload_all_domains", reloaded, skipped, failed, _elapsed_ms(started_usec)))


func get_disabled_tools() -> Array:
	return _disabled_tools.keys()


func is_tool_enabled(tool_name: String) -> bool:
	return not _disabled_tools.has(tool_name)


func _reset_state() -> void:
	_entries_by_category.clear()
	_ordered_categories.clear()
	_runtime_by_category.clear()
	_tool_definitions_by_category.clear()
	_load_errors.clear()


func _refresh_entries() -> void:
	_load_errors.clear()
	var collected = _registry.collect_entries()
	var new_entries: Dictionary = {}
	var new_order: Array[String] = []
	for error_info in collected.get("errors", []):
		_load_errors.append(error_info.duplicate(true))
	for entry in collected.get("entries", []):
		var category = str(entry.get("category", ""))
		if category.is_empty():
			continue
		if new_entries.has(category):
			_load_errors.append({
				"category": category,
				"path": str(entry.get("path", "")),
				"message": "Duplicate tool category registered",
				"source": str(entry.get("source", "builtin"))
			})
			continue
		new_entries[category] = entry.duplicate(true)
		new_order.append(category)

	for existing_category in _runtime_by_category.keys():
		if not new_entries.has(existing_category):
			_runtime_by_category.erase(existing_category)
			_tool_definitions_by_category.erase(existing_category)

	_entries_by_category = new_entries
	_ordered_categories = new_order


func _set_disabled_tools(disabled_tools: Array) -> void:
	_disabled_tools.clear()
	for tool_name in disabled_tools:
		_disabled_tools[str(tool_name)] = true


func _ensure_tool_definitions(category: String) -> Array:
	if _tool_definitions_by_category.has(category):
		return _tool_definitions_by_category[category]

	var runtime: Dictionary = _runtime_by_category.get(category, {})
	var executor = runtime.get("instance", null)
	if executor == null:
		var instantiate_result = _instantiate_executor(category, false, "definitions")
		if not instantiate_result.get("success", false):
			_record_load_error(category, str(_entries_by_category.get(category, {}).get("path", "")), str(instantiate_result.get("error", "Failed to load tool definitions")))
			_tool_definitions_by_category[category] = []
			return []
		executor = instantiate_result.get("executor")

	var definitions = _extract_tool_definitions(category, executor)
	_tool_definitions_by_category[category] = definitions
	return definitions


func _ensure_runtime_loaded(category: String, reason: String) -> Dictionary:
	var runtime: Dictionary = _runtime_by_category.get(category, {})
	if runtime.get("instance", null) != null:
		return {"success": true, "runtime": runtime}

	var instantiate_result = _instantiate_executor(category, false, reason)
	if not instantiate_result.get("success", false):
		return _failure("tool_load_failed", category, "", str(instantiate_result.get("error", "Failed to load tool runtime")))

	var executor = instantiate_result.get("executor")
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
	_runtime_by_category[category] = runtime
	_tool_definitions_by_category[category] = _extract_tool_definitions(category, executor)
	return {"success": true, "runtime": runtime}


func _instantiate_executor(category: String, force_reload: bool, reason: String) -> Dictionary:
	var entry: Dictionary = _entries_by_category.get(category, {})
	if entry.is_empty():
		return {"success": false, "error": "Tool domain is not registered"}

	var path = str(entry.get("path", ""))
	if path.is_empty():
		return {"success": false, "error": "Tool domain path is empty"}

	var script_resource = _load_script_resource(path, force_reload)
	if script_resource == null:
		return {"success": false, "error": "Failed to load tool script"}
	if script_resource is Script and not script_resource.can_instantiate():
		return {"success": false, "error": "Tool script could not be instantiated"}
	if not script_resource.has_method("new"):
		return {"success": false, "error": "Loaded tool resource is not instantiable"}

	var executor = script_resource.new()
	if executor == null:
		return {"success": false, "error": "Tool executor instance creation returned null"}
	if not executor.has_method("get_tools") or not executor.has_method("execute"):
		return {"success": false, "error": "Tool executor does not expose get_tools/execute"}
	if executor.has_method("configure_runtime"):
		executor.configure_runtime({
			"tool_loader": self,
			"server": _server_context,
			"category": category,
			"reason": reason,
			"entry": entry.duplicate(true)
		})

	return {
		"success": true,
		"executor": executor
	}


func _load_script_resource(path: String, force_reload: bool) -> Resource:
	var cache_mode = ResourceLoader.CACHE_MODE_REUSE
	if force_reload:
		cache_mode = ResourceLoader.CACHE_MODE_IGNORE
	var script_resource = ResourceLoader.load(path, "", cache_mode)
	if script_resource is Script and force_reload:
		_reload_script_dependency_chain(script_resource as Script, {})
	return script_resource


func _reload_script_dependency_chain(script_resource: Script, visited: Dictionary) -> void:
	if script_resource == null:
		return

	var script_path = str(script_resource.resource_path)
	if not script_path.is_empty():
		if visited.has(script_path):
			return
		visited[script_path] = true

	var base_script = script_resource.get_base_script()
	if base_script is Script:
		_reload_script_dependency_chain(base_script as Script, visited)

	for constant_value in script_resource.get_script_constant_map().values():
		if constant_value is Script:
			_reload_script_dependency_chain(constant_value as Script, visited)

	script_resource.reload()


func _extract_tool_definitions(category: String, executor) -> Array:
	var definitions: Array[Dictionary] = []
	for tool_def in executor.get_tools():
		if not (tool_def is Dictionary):
			continue
		definitions.append(tool_def.duplicate(true))
	return definitions


func _record_load_error(category: String, path: String, message: String) -> void:
	var error_info = {
		"category": category,
		"path": path,
		"message": message
	}
	_load_errors.append(error_info)
	var runtime: Dictionary = _runtime_by_category.get(category, {})
	runtime["last_error"] = error_info
	_runtime_by_category[category] = runtime


func _count_enabled_tools_in_category(category: String) -> int:
	var count = 0
	for tool_def in _tool_definitions_by_category.get(category, []):
		var full_name = "%s_%s" % [category, str(tool_def.get("name", ""))]
		if is_tool_enabled(full_name):
			count += 1
	return count


func _category_has_enabled_tools(category: String) -> bool:
	return _count_enabled_tools_in_category(category) > 0


func _unload_runtime(category: String, reason: String) -> void:
	if not _runtime_by_category.has(category):
		return
	var runtime: Dictionary = _runtime_by_category.get(category, {})
	runtime["instance"] = null
	runtime["state"] = "definitions_only"
	runtime["last_unloaded_reason"] = reason
	_runtime_by_category[category] = runtime


func _record_tool_call_metric(full_name: String, category: String, elapsed_ms: float) -> void:
	var per_tool: Dictionary = _performance.get("tool_calls", {})
	var metric: Dictionary = per_tool.get(full_name, {
		"tool_name": full_name,
		"category": category,
		"count": 0,
		"total_ms": 0.0,
		"avg_ms": 0.0,
		"last_ms": 0.0,
		"last_called_at_unix": 0
	})
	metric["count"] = int(metric.get("count", 0)) + 1
	metric["total_ms"] = float(metric.get("total_ms", 0.0)) + elapsed_ms
	metric["last_ms"] = elapsed_ms
	metric["last_called_at_unix"] = int(Time.get_unix_time_from_system())
	metric["avg_ms"] = metric["total_ms"] / float(metric["count"])
	per_tool[full_name] = metric
	_performance["tool_calls"] = per_tool


func _failure(error_type: String, category: String, tool_name: String, message: String, data: Dictionary = {}) -> Dictionary:
	var failure_data = data.duplicate(true)
	failure_data["error_type"] = error_type
	failure_data["domain"] = category
	if tool_name.is_empty():
		failure_data["tool_name"] = category
	else:
		failure_data["tool_name"] = "%s_%s" % [category, tool_name]
	failure_data["timestamp_unix"] = int(Time.get_unix_time_from_system())
	return {
		"success": false,
		"error": message,
		"data": failure_data
	}


func _make_reload_status(action: String, reloaded_domains: Array = [], skipped_domains: Array = [], failed_domains: Array = [], elapsed_ms: float = 0.0) -> Dictionary:
	return {
		"action": action,
		"reloaded_domains": reloaded_domains.duplicate(),
		"skipped_domains": skipped_domains.duplicate(),
		"failed_domains": failed_domains.duplicate(true),
		"elapsed_ms": elapsed_ms,
		"timestamp_unix": int(Time.get_unix_time_from_system()),
		"performance": get_performance_summary()
	}


func _update_reload_status(status: Dictionary) -> Dictionary:
	_reload_status = status.duplicate(true)
	return _reload_status.duplicate(true)


func _elapsed_ms(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0


func _sort_tool_metric(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("tool_name", "")) < str(b.get("tool_name", ""))


func _sort_tool_usage_stats(a: Dictionary, b: Dictionary) -> bool:
	var left_count = int(a.get("call_count", 0))
	var right_count = int(b.get("call_count", 0))
	if left_count != right_count:
		return left_count > right_count

	var left_time = int(a.get("last_called_at_unix", 0))
	var right_time = int(b.get("last_called_at_unix", 0))
	if left_time != right_time:
		return left_time > right_time

	return str(a.get("tool_name", "")) < str(b.get("tool_name", ""))


func _decorate_tool_definition(category: String, tool_def: Dictionary) -> Dictionary:
	var decorated = tool_def.duplicate(true)
	var entry: Dictionary = _entries_by_category.get(category, {})
	decorated["category"] = category
	decorated["load_state"] = _current_load_state(category)
	decorated["source"] = str(entry.get("source", "builtin"))
	decorated["script_path"] = str(entry.get("path", ""))
	decorated["domain_key"] = str(entry.get("domain_key", "other"))
	return decorated


func _get_permission_provider():
	if _server_context == null:
		return null
	if _server_context.has_method("get_plugin_permission_provider"):
		return _server_context.get_plugin_permission_provider()
	if _server_context.has_method("get_parent"):
		return _server_context.get_parent()
	return null


func _is_category_visible(category: String) -> bool:
	var provider = _get_permission_provider()
	if provider != null and provider.has_method("is_tool_category_visible_for_permission"):
		return bool(provider.is_tool_category_visible_for_permission(category))
	return true


func _is_category_executable(category: String) -> bool:
	var provider = _get_permission_provider()
	if provider != null and provider.has_method("is_tool_category_executable_for_permission"):
		return bool(provider.is_tool_category_executable_for_permission(category))
	return true


func _get_permission_error(category: String) -> String:
	var provider = _get_permission_provider()
	if provider != null and provider.has_method("get_permission_denied_message_for_category"):
		return str(provider.get_permission_denied_message_for_category(category))
	return "Current permission level does not allow this tool category"


func _current_load_state(category: String) -> String:
	var runtime: Dictionary = _runtime_by_category.get(category, {})
	var defs = _tool_definitions_by_category.get(category, [])
	if runtime.has("state"):
		return str(runtime.get("state", "definitions_only"))
	if defs.is_empty():
		return "uninitialized"
	return "definitions_only"
