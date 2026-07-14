@tool
extends RefCounted

## Coordinates tool execution flow for MCPToolLoader.
## Keeps access checks, runtime lookup, activity tracking, and result finalization
## out of the loader facade while preserving the existing public loader API.

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")


func execute_tool(category: String, tool_name: String, args: Dictionary, context: Dictionary) -> Dictionary:
	var prepared := _prepare_execution(category, tool_name, args, context)
	if not bool(prepared.get("success", false)):
		return prepared

	var executor = prepared.get("executor")
	var execution_args: Dictionary = prepared.get("args", {})
	var result = executor.execute(tool_name, execution_args)
	return _finish_execution(category, tool_name, execution_args, prepared, result)


func execute_tool_async(category: String, tool_name: String, args: Dictionary, context: Dictionary) -> Dictionary:
	var prepared := _prepare_execution(category, tool_name, args, context)
	if not bool(prepared.get("success", false)):
		return prepared

	var executor = prepared.get("executor")
	var execution_args: Dictionary = prepared.get("args", {})
	var result
	if executor.has_method("execute_async"):
		result = await executor.execute_async(tool_name, execution_args)
	else:
		result = executor.execute(tool_name, execution_args)
	return _finish_execution(category, tool_name, execution_args, prepared, result)


func _prepare_execution(category: String, tool_name: String, args: Dictionary, context: Dictionary) -> Dictionary:
	var execution_args := args.duplicate(true)
	var extract_agent_context: Callable = context.get("extract_agent_context", Callable())
	var agent_context := {}
	if extract_agent_context.is_valid():
		agent_context = extract_agent_context.call(execution_args)

	var is_category_executable: Callable = context.get("is_category_executable", Callable())
	var get_tool_access_error: Callable = context.get("get_tool_access_error", Callable())
	if is_category_executable.is_valid() and not bool(is_category_executable.call(category)):
		var access_error := "Tool category is disabled."
		if get_tool_access_error.is_valid():
			access_error = str(get_tool_access_error.call(category))
		MCPDebugBuffer.record("warning", "tool_loader",
			"%s_%s denied: %s" % [category, tool_name, access_error],
			"%s_%s" % [category, tool_name])
		return _call_failure(context, "tool_access_denied", category, tool_name, access_error)

	MCPDebugBuffer.record("debug", "tool_loader",
		"Calling %s_%s (action: %s)" % [category, tool_name, str(execution_args.get("action", ""))],
		"%s_%s" % [category, tool_name])

	var ensure_runtime_loaded: Callable = context.get("ensure_runtime_loaded", Callable())
	if not ensure_runtime_loaded.is_valid():
		return _call_failure(context, "tool_runtime_missing", category, tool_name, "Tool runtime loader is unavailable")
	var runtime_result = ensure_runtime_loaded.call(category, "tool_call")
	if not (runtime_result is Dictionary):
		return _call_failure(context, "tool_runtime_missing", category, tool_name, "Tool runtime loader returned an invalid result")
	if not bool((runtime_result as Dictionary).get("success", false)):
		return runtime_result

	var runtime: Dictionary = (runtime_result as Dictionary).get("runtime", {})
	var executor = runtime.get("instance")
	if executor == null:
		return _call_failure(context, "tool_runtime_missing", category, tool_name, "Tool runtime is unavailable")

	var begin_activity: Callable = context.get("begin_tool_activity", Callable())
	var activity_record := {}
	if begin_activity.is_valid():
		activity_record = begin_activity.call(category, tool_name, execution_args, agent_context)

	return {
		"success": true,
		"args": execution_args,
		"context": context,
		"executor": executor,
		"activity_record": activity_record,
		"started_usec": Time.get_ticks_usec()
	}


func _finish_execution(category: String, tool_name: String, execution_args: Dictionary, prepared: Dictionary, result) -> Dictionary:
	var context: Dictionary = prepared.get("context", {})
	var finalize_tool_execution: Callable = context.get("finalize_tool_execution", Callable())
	var finish_tool_activity: Callable = context.get("finish_tool_activity", Callable())

	if not finalize_tool_execution.is_valid() or not finish_tool_activity.is_valid():
		return result if result is Dictionary else {
			"success": false,
			"error": "Tool execution service missing finalization callbacks"
		}
	var finalized = finalize_tool_execution.call(category, tool_name, execution_args, int(prepared.get("started_usec", Time.get_ticks_usec())), result)
	return finish_tool_activity.call(finalized, prepared.get("activity_record", {}))


func _call_failure(context: Dictionary, error_type: String, category: String, tool_name: String, message: String) -> Dictionary:
	var failure: Callable = context.get("failure", Callable())
	if failure.is_valid():
		return failure.call(error_type, category, tool_name, message)
	return {
		"success": false,
		"error": message,
		"data": {
			"error_type": error_type,
			"domain": category,
			"tool_name": "%s_%s" % [category, tool_name]
		}
	}
