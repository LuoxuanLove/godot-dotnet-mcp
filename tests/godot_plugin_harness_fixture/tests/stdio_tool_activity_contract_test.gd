extends RefCounted

# {"name": "stdio_tool_activity_contracts"}

const StdioServerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_stdio_server.gd")
const ToolActivityRegistryScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_activity_registry.gd")


class FakeToolLoader:
	extends RefCounted

	var activity_registry = ToolActivityRegistryScript.new()
	var executed_arguments: Dictionary = {}

	func get_tool_definitions() -> Array:
		return [{
			"name": "system_project_state",
			"category": "system",
			"inputSchema": {"type": "object", "properties": {}}
		}]

	func get_exposed_tool_definitions() -> Array:
		return get_tool_definitions()

	func get_domain_states() -> Array:
		return [{"category": "system", "status": "ready"}]

	func is_tool_exposed(tool_name: String) -> bool:
		return tool_name == "system_project_state"

	func execute_tool_async(category: String, tool_name: String, arguments: Dictionary) -> Dictionary:
		var execution_args := arguments.duplicate(true)
		var agent_context := {}
		if execution_args.get("_mcp_context", null) is Dictionary:
			agent_context = (execution_args.get("_mcp_context", {}) as Dictionary).duplicate(true)
		execution_args.erase("_mcp_context")
		executed_arguments = execution_args.duplicate(true)
		var record: Dictionary = activity_registry.begin_call("%s_%s" % [category, tool_name], category, tool_name, execution_args, agent_context, {"transport": "stdio"})
		var finished: Dictionary = activity_registry.finish_call(str(record.get("call_id", "")), true)
		return {
			"success": true,
			"data": {
				"category": category,
				"tool": tool_name,
				"arguments": execution_args
			},
			"activity": activity_registry.summarize_record(finished),
			"message": "ok"
		}


func run_case(_tree: SceneTree) -> Dictionary:
	var loader = FakeToolLoader.new()
	var stdio_server = StdioServerScript.new()
	stdio_server.initialize(loader, false)

	var response: Dictionary = await stdio_server.call("_handle_tools_call", {
		"name": "system_project_state",
		"arguments": {
			"summary": true
		},
		"_mcp_context": {
			"agent_id": "stdio-contract-agent",
			"purpose": "verify stdio activity"
		}
	}, 42)

	var result = response.get("result", {})
	if not (result is Dictionary) or bool((result as Dictionary).get("isError", true)):
		return _failure("Stdio tools/call should return a successful result.")
	var content = (result as Dictionary).get("content", [])
	if not (content is Array) or (content as Array).is_empty():
		return _failure("Stdio tools/call should include text content.")
	var payload_text := str(((content as Array)[0] as Dictionary).get("text", ""))
	var parsed = JSON.parse_string(payload_text)
	if not (parsed is Dictionary):
		return _failure("Stdio tools/call should serialize a JSON object payload.")
	var parsed_dict: Dictionary = parsed
	if not bool(parsed_dict.get("success", false)):
		return _failure("Stdio tools/call should preserve successful tool results.")
	if not (parsed_dict.get("activity", {}) is Dictionary) or str((parsed_dict.get("activity", {}) as Dictionary).get("call_id", "")).is_empty():
		return _failure("Stdio tools/call should preserve loader activity summaries.")
	if loader.executed_arguments.has("_mcp_context"):
		return _failure("Stdio tools/call should not pass _mcp_context to concrete tool execution.")
	var status: Dictionary = loader.activity_registry.get_status()
	var recent = status.get("recent", [])
	if not (recent is Array) or (recent as Array).is_empty():
		return _failure("Stdio tools/call should write completed calls into the activity registry.")
	var agent_context = (((recent as Array)[0] as Dictionary).get("agent_context", {}) as Dictionary)
	if str(agent_context.get("agent_id", "")) != "stdio-contract-agent":
		return _failure("Stdio tools/call should retain top-level _mcp_context in activity.")

	var plain_activity_result: Dictionary = stdio_server.call("_normalize_tool_result", {
		"success": true,
		"activity": {
			"user_supplied": true
		},
		"plain": "value"
	})
	stdio_server.free()
	if plain_activity_result.has("activity"):
		return _failure("Stdio normalizer should reserve top-level activity only for protocol activity summaries.")
	var plain_activity_data = plain_activity_result.get("data", {})
	if not (plain_activity_data is Dictionary) or not (((plain_activity_data as Dictionary).get("activity", {}) as Dictionary).get("user_supplied", false)):
		return _failure("Stdio normalizer should move non-protocol tool activity fields into data.")

	return {
		"name": "stdio_tool_activity_contracts",
		"success": true,
		"error": "",
		"details": {
			"activity_call_id": str((parsed_dict.get("activity", {}) as Dictionary).get("call_id", "")),
			"recent_count": int(status.get("recent_count", 0))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "stdio_tool_activity_contracts",
		"success": false,
		"error": message
	}
