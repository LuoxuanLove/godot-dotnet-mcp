@tool
extends RefCounted

## Owns the execution-context callbacks shared by loader runtime and execution services.
## This keeps MCPToolLoader focused on service wiring instead of activity/failure glue.

var _observer


func configure(observer) -> void:
	_observer = observer


func build_execution_context(
	is_category_executable: Callable,
	get_tool_access_error: Callable,
	ensure_runtime_loaded: Callable
) -> Dictionary:
	return {
		"extract_agent_context": Callable(self, "extract_agent_context"),
		"is_category_executable": is_category_executable,
		"get_tool_access_error": get_tool_access_error,
		"ensure_runtime_loaded": ensure_runtime_loaded,
		"begin_tool_activity": Callable(self, "begin_tool_activity"),
		"finalize_tool_execution": Callable(self, "finalize_tool_execution"),
		"finish_tool_activity": Callable(self, "finish_tool_activity"),
		"failure": Callable(self, "failure")
	}


func extract_agent_context(args: Dictionary) -> Dictionary:
	var context := {}
	if args.get("_mcp_context", null) is Dictionary:
		context = (args.get("_mcp_context", {}) as Dictionary).duplicate(true)
	args.erase("_mcp_context")
	return context


func begin_tool_activity(category: String, tool_name: String, args: Dictionary, agent_context: Dictionary) -> Dictionary:
	if _observer != null and _observer.has_method("begin_tool_activity"):
		return _observer.begin_tool_activity(category, tool_name, args, agent_context)
	return {}


func finalize_tool_execution(category: String, tool_name: String, args: Dictionary, started_usec: int, result) -> Dictionary:
	if _observer != null and _observer.has_method("finalize_tool_execution"):
		return _observer.finalize_tool_execution(category, tool_name, args, started_usec, result)
	if result is Dictionary:
		return result
	return failure("tool_execution_failed", category, tool_name, "Tool execution returned an invalid result")


func finish_tool_activity(result: Dictionary, activity_record: Dictionary) -> Dictionary:
	if _observer != null and _observer.has_method("finish_tool_activity"):
		return _observer.finish_tool_activity(result, activity_record)
	return result


func failure(error_type: String, category: String, tool_name: String, message: String, data: Dictionary = {}) -> Dictionary:
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
