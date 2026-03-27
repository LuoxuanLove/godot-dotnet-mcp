@tool
extends RefCounted
class_name MCPToolExecutionGateway

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")

var _store
var _runtime_service
var _metrics_service
var _lsp_adapter
var _refresh_runtime_context: Callable = Callable()


func configure(store, runtime_service, metrics_service, lsp_adapter, options: Dictionary = {}) -> void:
	_store = store
	_runtime_service = runtime_service
	_metrics_service = metrics_service
	_lsp_adapter = lsp_adapter
	_refresh_runtime_context = options.get("refresh_runtime_context", Callable())


func dispose() -> void:
	_store = null
	_runtime_service = null
	_metrics_service = null
	_lsp_adapter = null
	_refresh_runtime_context = Callable()


func execute_tool_async(category: String, tool_name: String, args: Dictionary) -> Dictionary:
	if not _store.is_category_executable(category):
		MCPDebugBuffer.record("warning", "tool_loader",
			"%s_%s denied: %s" % [category, tool_name, _store.get_permission_error(category)],
			"%s_%s" % [category, tool_name])
		return _failure("permission_denied", category, tool_name, _store.get_permission_error(category))

	MCPDebugBuffer.record("debug", "tool_loader",
		"Calling %s_%s (action: %s)" % [category, tool_name, str(args.get("action", ""))],
		"%s_%s" % [category, tool_name])

	var runtime_result = _runtime_service.ensure_runtime_loaded(category, "tool_call")
	if not runtime_result.get("success", false):
		return _failure("tool_load_failed", category, "", str(runtime_result.get("error", "Failed to load tool runtime")))

	var runtime: Dictionary = runtime_result.get("runtime", {})
	var executor = runtime.get("instance")
	if executor == null:
		return _failure("tool_runtime_missing", category, tool_name, "Tool runtime is unavailable")

	var started_usec = Time.get_ticks_usec()
	var result
	if executor.has_method("execute_async"):
		result = await executor.execute_async(tool_name, args)
	else:
		result = executor.execute(tool_name, args)
	var elapsed_ms = _elapsed_ms(started_usec)
	_metrics_service.record_tool_call("%s_%s" % [category, tool_name], category, elapsed_ms)

	if result is Dictionary and _as_bool(result.get("success", true)):
		MCPDebugBuffer.record("info", "tool_loader",
			"%s_%s ok (%.0fms)" % [category, tool_name, elapsed_ms],
			"%s_%s" % [category, tool_name])
		return result

	var error_message := "Tool execution failed"
	if result is Dictionary:
		error_message = str(result.get("error", error_message))
		MCPDebugBuffer.record("warning", "tool_loader",
			"%s_%s failed (%.0fms): %s" % [category, tool_name, elapsed_ms, error_message],
			"%s_%s" % [category, tool_name])
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

	MCPDebugBuffer.record("warning", "tool_loader",
		"%s_%s failed (%.0fms): %s" % [category, tool_name, elapsed_ms, error_message],
		"%s_%s" % [category, tool_name])
	return _failure("tool_execution_failed", category, tool_name, error_message, {
		"action": str(args.get("action", "")),
		"elapsed_ms": elapsed_ms
	})


func tick(delta: float) -> void:
	for category in _store.runtime_categories():
		var runtime: Dictionary = _store.get_runtime(str(category))
		var executor = runtime.get("instance", null)
		if executor != null and executor.has_method("tick"):
			executor.tick(delta)
		if category == "user":
			_sync_user_tool_runtime_definitions(executor)
			_maybe_unload_idle_user_runtime(executor)
	if _lsp_adapter != null:
		_lsp_adapter.tick(delta)


func request_reload_by_script(script_path: String, reason: String = "manual") -> Dictionary:
	var normalized_path = script_path.strip_edges()
	if normalized_path.is_empty():
		return {"success": false, "error": "Missing script path"}
	if not _store.has_entry("user"):
		return {"success": false, "error": "User domain is not registered"}
	if not _store.category_has_enabled_tools("user"):
		_runtime_service.ensure_runtime_loaded("user", "request_reload_by_script")
	var runtime: Dictionary = _store.get_runtime("user")
	var executor = runtime.get("instance", null)
	if executor == null or not executor.has_method("request_reload_by_script"):
		return {"success": false, "error": "User runtime is unavailable"}
	executor.request_reload_by_script(normalized_path, reason)
	if executor.has_method("tick"):
		executor.tick(0.0)
	_sync_user_tool_runtime_definitions(executor)
	_call_refresh_runtime_context()
	return {
		"success": true,
		"script_path": normalized_path,
		"reason": reason,
		"runtime_state": executor.get_runtime_state_snapshot() if executor.has_method("get_runtime_state_snapshot") else []
	}


func get_user_tool_runtime_snapshot() -> Array[Dictionary]:
	var runtime: Dictionary = _store.get_runtime("user")
	var executor = runtime.get("instance", null)
	if executor != null and executor.has_method("get_runtime_state_snapshot"):
		return executor.get_runtime_state_snapshot()
	return []


func release_all_runtimes(reason: String) -> void:
	if _runtime_service == null:
		return
	for category in _store.runtime_categories():
		_runtime_service.unload_runtime(str(category), reason)


func _sync_user_tool_runtime_definitions(executor) -> void:
	if executor == null or not executor.has_method("get_tools"):
		return
	var previous_defs = _store.get_cached_tool_definitions("user")
	var next_defs = _runtime_service.extract_tool_definitions("user", executor)
	if JSON.stringify(previous_defs) == JSON.stringify(next_defs):
		return
	_store.set_tool_definitions("user", next_defs)
	_call_refresh_runtime_context()


func _maybe_unload_idle_user_runtime(executor) -> void:
	var runtime: Dictionary = _store.get_runtime("user")
	var defs: Array = _store.get_cached_tool_definitions("user")
	if executor == null:
		if defs.is_empty() and not runtime.is_empty():
			_runtime_service.unload_runtime("user", "idle_runtime_missing_executor")
			_store.erase_runtime("user")
			_store.erase_tool_definitions("user")
			_call_refresh_runtime_context()
		return
	if not executor.has_method("should_unload_runtime"):
		return
	if not _as_bool(executor.should_unload_runtime()):
		return
	_runtime_service.unload_runtime("user", "idle_runtime")
	_store.erase_runtime("user")
	_store.erase_tool_definitions("user")
	_call_refresh_runtime_context()


func _call_refresh_runtime_context() -> void:
	if _refresh_runtime_context.is_valid():
		_refresh_runtime_context.call()


func _failure(error_type: String, category: String, tool_name: String, message: String, data: Dictionary = {}) -> Dictionary:
	var failure_data = data.duplicate(true)
	failure_data["error_type"] = error_type
	failure_data["domain"] = category
	failure_data["tool_name"] = category if tool_name.is_empty() else "%s_%s" % [category, tool_name]
	failure_data["timestamp_unix"] = int(Time.get_unix_time_from_system())
	return {
		"success": false,
		"error": message,
		"data": failure_data
	}


func _elapsed_ms(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0


func _as_bool(value) -> bool:
	if value is bool:
		return value
	if value is int:
		return value != 0
	if value is float:
		return !is_zero_approx(value)
	if value is String:
		var normalized: String = value.strip_edges().to_lower()
		return normalized == "true" or normalized == "1" or normalized == "yes" or normalized == "on"
	return value != null
