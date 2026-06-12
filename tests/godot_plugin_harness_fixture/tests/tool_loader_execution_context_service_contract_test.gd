extends RefCounted

const ExecutionContextServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_execution_context_service.gd")
const ToolExecutionServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_execution_service.gd")

var _events: Array[String] = []
var _runtime_by_category: Dictionary = {}
var _last_agent_context: Dictionary = {}


class FakeObserver:
	extends RefCounted

	var owner

	func _init(new_owner) -> void:
		owner = new_owner

	func begin_tool_activity(category: String, tool_name: String, args: Dictionary, agent_context: Dictionary) -> Dictionary:
		owner._events.append("begin")
		owner._last_agent_context = agent_context.duplicate(true)
		return {
			"category": category,
			"tool_name": tool_name,
			"action": str(args.get("action", ""))
		}

	func finalize_tool_execution(_category: String, _tool_name: String, _args: Dictionary, _started_usec: int, result) -> Dictionary:
		owner._events.append("finalize")
		var finalized: Dictionary = result.duplicate(true) if result is Dictionary else {
			"success": false,
			"error": "invalid result"
		}
		finalized["finalized_by_observer"] = true
		return finalized

	func finish_tool_activity(result: Dictionary, activity_record: Dictionary) -> Dictionary:
		owner._events.append("finish")
		var finished := result.duplicate(true)
		finished["activity_finished"] = not activity_record.is_empty()
		return finished


class FakeExecutor:
	extends RefCounted

	func execute(tool_name: String, args: Dictionary) -> Dictionary:
		return {
			"success": true,
			"data": {
				"tool_name": tool_name,
				"has_context": args.has("_mcp_context"),
				"action": str(args.get("action", ""))
			}
		}


func run_case(_tree: SceneTree) -> Dictionary:
	var context_service = ExecutionContextServiceScript.new()
	context_service.configure(FakeObserver.new(self))

	var args := {
		"action": "inspect",
		"_mcp_context": {
			"agent_id": "execution-context-service-contract",
			"trace_id": "ctx-1"
		}
	}
	var agent_context: Dictionary = context_service.extract_agent_context(args)
	if args.has("_mcp_context"):
		return _failure("Execution context service should sanitize private MCP context from tool arguments.")
	if str(agent_context.get("agent_id", "")) != "execution-context-service-contract":
		return _failure("Execution context service should preserve extracted agent context.")

	var category_failure: Dictionary = context_service.failure("tool_runtime_missing", "runtime", "", "Runtime unavailable.", {"reason": "contract"})
	if bool(category_failure.get("success", true)):
		return _failure("Execution context service failure helper should fail closed.")
	var category_failure_data: Dictionary = category_failure.get("data", {})
	if str(category_failure_data.get("tool_name", "")) != "runtime" or str(category_failure_data.get("reason", "")) != "contract":
		return _failure("Category-level failures should keep category tool names and extra data.", category_failure_data)
	if int(category_failure_data.get("timestamp_unix", 0)) <= 0:
		return _failure("Execution context service failures should include timestamps.", category_failure_data)

	var tool_failure: Dictionary = context_service.failure("tool_access_denied", "system", "probe", "Denied.")
	if str((tool_failure.get("data", {}) as Dictionary).get("tool_name", "")) != "system_probe":
		return _failure("Tool-level failures should include full MCP tool names.", tool_failure)

	_runtime_by_category = {
		"system": {"success": true, "runtime": {"instance": FakeExecutor.new()}}
	}
	_events.clear()
	var execution_service = ToolExecutionServiceScript.new()
	var result: Dictionary = execution_service.execute_tool("system", "probe", {
		"action": "status",
		"_mcp_context": {"agent_id": "execution-context-service-contract"}
	}, context_service.build_execution_context(
		Callable(self, "_is_category_executable"),
		Callable(self, "_get_tool_access_error"),
		Callable(self, "_ensure_runtime_loaded")
	))
	if not bool(result.get("success", false)):
		return _failure("Execution context service should integrate with tool execution service.", result)
	if _events != ["begin", "finalize", "finish"]:
		return _failure("Execution context service should route observer callbacks in order.", {"events": _events})
	if bool((result.get("data", {}) as Dictionary).get("has_context", true)):
		return _failure("Execution context service should execute tools with sanitized arguments.", result)
	if str(_last_agent_context.get("agent_id", "")) != "execution-context-service-contract":
		return _failure("Execution context service should pass agent context into activity tracking.", _last_agent_context)
	if not bool(result.get("finalized_by_observer", false)) or not bool(result.get("activity_finished", false)):
		return _failure("Execution context service should preserve observer finalization and activity finishing.", result)

	var denied: Dictionary = execution_service.execute_tool("disabled", "probe", {}, context_service.build_execution_context(
		Callable(self, "_is_category_executable"),
		Callable(self, "_get_tool_access_error"),
		Callable(self, "_ensure_runtime_loaded")
	))
	if bool(denied.get("success", true)):
		return _failure("Execution context service should expose the shared failure callback to execution service.")
	var denied_data: Dictionary = denied.get("data", {})
	if str(denied_data.get("error_type", "")) != "tool_access_denied" or str(denied_data.get("tool_name", "")) != "disabled_probe":
		return _failure("Execution service denied failures should use the execution context envelope.", denied_data)

	return {
		"success": true,
		"name": "tool_loader_execution_context_service_contracts",
		"callback_events": _events.size()
	}


func _is_category_executable(category: String) -> bool:
	return category != "disabled"


func _get_tool_access_error(_category: String) -> String:
	return "Contract disabled."


func _ensure_runtime_loaded(category: String, reason: String):
	if reason != "tool_call":
		return {
			"success": false,
			"error": "Unexpected runtime reason."
		}
	return _runtime_by_category.get(category, {"success": false, "error": "missing"})


func _failure(message: String, extra: Dictionary = {}) -> Dictionary:
	var data := extra.duplicate(true)
	data["message"] = message
	return {
		"success": false,
		"name": "tool_loader_execution_context_service_contracts",
		"error": message,
		"data": data
	}
