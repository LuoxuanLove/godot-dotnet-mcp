extends RefCounted

const ToolExecutionServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_execution_service.gd")

var _runtime_by_category: Dictionary = {}
var _events: Array[String] = []
var _last_agent_context: Dictionary = {}


class SyncExecutor:
	extends RefCounted

	func execute(tool_name: String, args: Dictionary) -> Dictionary:
		return {
			"success": true,
			"data": {
				"tool_name": tool_name,
				"action": str(args.get("action", "")),
				"has_context": args.has("_mcp_context")
			}
		}


class AsyncExecutor:
	extends RefCounted

	func execute_async(tool_name: String, args: Dictionary) -> Dictionary:
		await Engine.get_main_loop().process_frame
		return {
			"success": true,
			"data": {
				"tool_name": tool_name,
				"action": str(args.get("action", "")),
				"async": true
			}
		}


func run_case(_tree: SceneTree) -> Dictionary:
	var service = ToolExecutionServiceScript.new()
	_runtime_by_category = {
		"sync": {"success": true, "runtime": {"instance": SyncExecutor.new()}},
		"async": {"success": true, "runtime": {"instance": AsyncExecutor.new()}},
		"missing": {"success": true, "runtime": {}},
		"bad": "not-a-dictionary"
	}

	var denied: Dictionary = service.execute_tool("disabled", "probe", {}, _build_context())
	if bool(denied.get("success", true)):
		return _failure("Tool execution service should reject non-executable categories.")
	if str((denied.get("data", {}) as Dictionary).get("error_type", "")) != "tool_access_denied":
		return _failure("Denied executions should use the loader failure callback.")

	_events.clear()
	var sync_result: Dictionary = service.execute_tool("sync", "probe", {
		"action": "status",
		"_mcp_context": {"agent_id": "execution-service-contract"}
	}, _build_context())
	if not bool(sync_result.get("success", false)):
		return _failure("Tool execution service should execute synchronous tool runtimes.", sync_result)
	if _events != ["extract", "runtime", "begin", "finalize", "finish"]:
		return _failure("Synchronous execution should preserve loader callback order.", {"events": _events})
	var sync_data: Dictionary = sync_result.get("data", {})
	if bool(sync_data.get("has_context", true)):
		return _failure("Tool execution service should execute with sanitized arguments.")
	if str(_last_agent_context.get("agent_id", "")) != "execution-service-contract":
		return _failure("Tool execution service should pass extracted agent context into activity tracking.")
	if not bool(sync_result.get("activity_finished", false)):
		return _failure("Tool execution service should finish activity records after finalization.")

	_events.clear()
	var async_result: Dictionary = await service.execute_tool_async("async", "probe", {
		"action": "capture"
	}, _build_context())
	if not bool(async_result.get("success", false)):
		return _failure("Tool execution service should execute asynchronous tool runtimes.", async_result)
	if not bool((async_result.get("data", {}) as Dictionary).get("async", false)):
		return _failure("Async execution should prefer execute_async when available.")
	if _events != ["extract", "runtime", "begin", "finalize", "finish"]:
		return _failure("Asynchronous execution should preserve loader callback order.", {"events": _events})

	var bad_runtime: Dictionary = service.execute_tool("bad", "probe", {}, _build_context())
	if bool(bad_runtime.get("success", true)) or str((bad_runtime.get("data", {}) as Dictionary).get("error_type", "")) != "tool_runtime_missing":
		return _failure("Tool execution service should reject invalid runtime loader results.")

	var missing_executor: Dictionary = service.execute_tool("missing", "probe", {}, _build_context())
	if bool(missing_executor.get("success", true)) or str((missing_executor.get("data", {}) as Dictionary).get("error_type", "")) != "tool_runtime_missing":
		return _failure("Tool execution service should reject runtimes without executor instances.")

	return {
		"success": true,
		"name": "tool_execution_service_contracts",
		"event_count": _events.size()
	}


func _build_context() -> Dictionary:
	return {
		"extract_agent_context": Callable(self, "_extract_agent_context"),
		"is_category_executable": Callable(self, "_is_category_executable"),
		"get_tool_access_error": Callable(self, "_get_tool_access_error"),
		"ensure_runtime_loaded": Callable(self, "_ensure_runtime_loaded"),
		"begin_tool_activity": Callable(self, "_begin_tool_activity"),
		"finalize_tool_execution": Callable(self, "_finalize_tool_execution"),
		"finish_tool_activity": Callable(self, "_finish_tool_activity"),
		"failure": Callable(self, "_loader_failure")
	}


func _extract_agent_context(args: Dictionary) -> Dictionary:
	_events.append("extract")
	var agent_context: Dictionary = args.get("_mcp_context", {})
	args.erase("_mcp_context")
	return agent_context


func _is_category_executable(category: String) -> bool:
	return category != "disabled"


func _get_tool_access_error(_category: String) -> String:
	return "contract disabled"


func _ensure_runtime_loaded(category: String, reason: String):
	_events.append("runtime")
	if reason != "tool_call":
		return _loader_failure("tool_runtime_missing", category, "", "Unexpected runtime reason.")
	return _runtime_by_category.get(category, {"success": false, "error": "missing"})


func _begin_tool_activity(category: String, tool_name: String, args: Dictionary, agent_context: Dictionary) -> Dictionary:
	_events.append("begin")
	_last_agent_context = agent_context.duplicate(true)
	return {
		"category": category,
		"tool_name": tool_name,
		"action": str(args.get("action", ""))
	}


func _finalize_tool_execution(_category: String, _tool_name: String, _args: Dictionary, _started_usec: int, result) -> Dictionary:
	_events.append("finalize")
	if not (result is Dictionary):
		return {"success": false, "error": "invalid result"}
	var finalized: Dictionary = result
	finalized["finalized"] = true
	return finalized


func _finish_tool_activity(result: Dictionary, activity_record: Dictionary) -> Dictionary:
	_events.append("finish")
	var finished := result.duplicate(true)
	finished["activity_finished"] = not activity_record.is_empty()
	return finished


func _loader_failure(error_type: String, category: String, tool_name: String, message: String, data: Dictionary = {}) -> Dictionary:
	var failure_data := data.duplicate(true)
	failure_data["error_type"] = error_type
	failure_data["domain"] = category
	failure_data["tool_name"] = "%s_%s" % [category, tool_name]
	return {
		"success": false,
		"error": message,
		"data": failure_data
	}


func _failure(message: String, extra: Dictionary = {}) -> Dictionary:
	var data := extra.duplicate(true)
	data["message"] = message
	return {
		"success": false,
		"name": "tool_execution_service_contracts",
		"error": message,
		"data": data
	}
