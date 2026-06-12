extends RefCounted

# {"name": "stdio_tool_activity_contracts"}

const StdioServerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_stdio_server.gd")
const StdioContextBuilderScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_stdio_service_context_builder.gd")
const ToolActivityRegistryScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_activity_registry.gd")


class FakeToolLoader:
	extends RefCounted

	var activity_registry = ToolActivityRegistryScript.new()
	var executed_arguments: Dictionary = {}
	var disabled_tools: Dictionary = {}

	func get_tool_definitions() -> Array:
		return [{
			"name": "system_project_state",
			"category": "system",
			"inputSchema": {"type": "object", "properties": {}}
		}, {
			"name": "system_project_lifecycle",
			"category": "system",
			"inputSchema": {"type": "object", "properties": {"action": {"type": "string", "enum": ["start", "stop"]}}}
		}]

	func get_exposed_tool_definitions() -> Array:
		return [{
			"name": "system_project_state",
			"category": "system",
			"inputSchema": {"type": "object", "properties": {}}
		}, {
			"name": "system_project_lifecycle",
			"category": "system",
			"inputSchema": {"type": "object", "properties": {"action": {"type": "string", "enum": ["start", "stop"]}}}
		}]

	func get_domain_states() -> Array:
		return [{"category": "system", "status": "ready"}]

	func is_tool_enabled(tool_name: String) -> bool:
		return not disabled_tools.has(tool_name)

	func is_tool_exposed(tool_name: String) -> bool:
		if disabled_tools.has(tool_name):
			return false
		return tool_name == "system_project_state" or tool_name == "system_project_lifecycle"

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
	var structured = (result as Dictionary).get("structuredContent", {})
	if not (structured is Dictionary):
		return _failure("Stdio tools/call should expose structuredContent for successful tool responses.")
	var structured_dict: Dictionary = structured
	if bool(structured_dict.get("success", false)) != bool(parsed_dict.get("success", false)):
		return _failure("Stdio structuredContent should match the compatibility text JSON success flag.")
	if JSON.stringify(structured_dict.get("data", {})) != JSON.stringify(parsed_dict.get("data", {})):
		return _failure("Stdio structuredContent should match the compatibility text JSON data payload.")
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

	var lifecycle_response: Dictionary = await stdio_server.call("_handle_tools_call", {
		"name": "system_project_lifecycle",
		"arguments": {"action": "stop"}
	}, 43)
	var lifecycle_result = lifecycle_response.get("result", {})
	if not (lifecycle_result is Dictionary) or bool((lifecycle_result as Dictionary).get("isError", true)):
		return _failure("Stdio tools/call should allow system_project_lifecycle(action=stop).")
	var lifecycle_content = (lifecycle_result as Dictionary).get("content", [])
	if not (lifecycle_content is Array) or (lifecycle_content as Array).is_empty():
		return _failure("Stdio lifecycle call should include text content.")
	var lifecycle_payload = JSON.parse_string(str(((lifecycle_content as Array)[0] as Dictionary).get("text", "")))
	if not (lifecycle_payload is Dictionary):
		return _failure("Stdio lifecycle call should serialize a JSON object payload.")
	var lifecycle_structured = (lifecycle_result as Dictionary).get("structuredContent", {})
	if not (lifecycle_structured is Dictionary):
		return _failure("Stdio lifecycle call should expose structuredContent.")
	var lifecycle_data = (lifecycle_payload as Dictionary).get("data", {})
	if not (lifecycle_data is Dictionary) or str((lifecycle_data as Dictionary).get("tool", "")) != "project_lifecycle":
		return _failure("Stdio lifecycle call should resolve system_project_lifecycle to project_lifecycle.")
	var lifecycle_structured_data = (lifecycle_structured as Dictionary).get("data", {})
	if not (lifecycle_structured_data is Dictionary) or str((lifecycle_structured_data as Dictionary).get("tool", "")) != "project_lifecycle":
		return _failure("Stdio lifecycle structuredContent should preserve the resolved tool name.")

	for removed_tool_name in ["system_project_run", "system_project_stop"]:
		var removed_response: Dictionary = await stdio_server.call("_handle_tools_call", {
			"name": removed_tool_name,
			"arguments": {}
		}, 44)
		var removed_result = removed_response.get("result", {})
		if not (removed_result is Dictionary) or not bool((removed_result as Dictionary).get("isError", false)):
			return _failure("Stdio tools/call should reject removed project lifecycle entry '%s'." % removed_tool_name)
		var removed_structured = (removed_result as Dictionary).get("structuredContent", {})
		if not (removed_structured is Dictionary) or bool((removed_structured as Dictionary).get("success", true)):
			return _failure("Stdio removed tool errors should expose failing structuredContent for '%s'." % removed_tool_name)

	loader.disabled_tools["system_project_lifecycle"] = true
	var disabled_lifecycle_response: Dictionary = await stdio_server.call("_handle_tools_call", {
		"name": "system_project_lifecycle",
		"arguments": {}
	}, 44)
	var disabled_lifecycle_result = disabled_lifecycle_response.get("result", {})
	if not (disabled_lifecycle_result is Dictionary) or not bool((disabled_lifecycle_result as Dictionary).get("isError", false)):
		return _failure("Stdio tools/call should reject system_project_lifecycle when disabled.")
	var disabled_lifecycle_structured = (disabled_lifecycle_result as Dictionary).get("structuredContent", {})
	if not (disabled_lifecycle_structured is Dictionary) or bool((disabled_lifecycle_structured as Dictionary).get("success", true)):
		return _failure("Stdio disabled tool errors should expose failing structuredContent.")
	if str((disabled_lifecycle_structured as Dictionary).get("error", "")).find("disabled") == -1:
		return _failure("Stdio disabled tool errors should use loader enabled-state semantics before exposure checks.")
	loader.disabled_tools.clear()

	stdio_server.start()
	stdio_server.set("_last_written_response", {})
	await stdio_server._handle_request(JSON.stringify({
		"jsonrpc": "2.0",
		"id": 45,
		"method": "tools/call",
		"params": {
			"name": "system_project_state",
			"arguments": []
		}
	}))
	var invalid_arguments_request_response = stdio_server.get("_last_written_response")
	stdio_server.stop()
	if not (invalid_arguments_request_response is Dictionary):
		return _failure("Stdio full request path should record non-object tool arguments response.")
	var invalid_arguments_request_result = (invalid_arguments_request_response as Dictionary).get("result", {})
	if not (invalid_arguments_request_result is Dictionary):
		return _failure("Stdio full request path should return a tool result for non-object tool arguments.")
	var invalid_arguments_request_structured = (invalid_arguments_request_result as Dictionary).get("structuredContent", {})
	if not (invalid_arguments_request_structured is Dictionary) or bool((invalid_arguments_request_structured as Dictionary).get("success", true)):
		return _failure("Stdio full request path should expose failing structuredContent for non-object tool arguments.")

	var plain_activity_result: Dictionary = stdio_server.call("_normalize_tool_result", {
		"success": true,
		"activity": {
			"user_supplied": true
		},
		"plain": "value"
	})
	if plain_activity_result.has("activity"):
		return _failure("Stdio normalizer should reserve top-level activity only for protocol activity summaries.")
	var plain_activity_data = plain_activity_result.get("data", {})
	if not (plain_activity_data is Dictionary) or not (((plain_activity_data as Dictionary).get("activity", {}) as Dictionary).get("user_supplied", false)):
		return _failure("Stdio normalizer should move non-protocol tool activity fields into data.")

	var context_guard := _verify_stdio_context_builder_guard(stdio_server)
	stdio_server.free()
	if not bool(context_guard.get("success", false)):
		return context_guard

	return {
		"name": "stdio_tool_activity_contracts",
		"success": true,
		"error": "",
		"details": {
			"activity_call_id": str((parsed_dict.get("activity", {}) as Dictionary).get("call_id", "")),
			"recent_count": int(status.get("recent_count", 0))
		}
	}


func _verify_stdio_context_builder_guard(stdio_server) -> Dictionary:
	var builder = StdioContextBuilderScript.new()
	var router_context = builder.build_tool_rpc_router_context(stdio_server, stdio_server.call("_get_stdio_tool_activity_registry"))
	if router_context == null or not router_context.get_tool_loader.is_valid():
		return _failure("Stdio context builder should produce a tool router context with a loader callable.")
	if router_context.tool_activity_registry == null:
		return _failure("Stdio context builder should preserve the shared tool activity registry.")
	var resources_context = builder.build_resources_service_context(stdio_server)
	if resources_context == null or not resources_context.get_tool_loader_status.is_valid() or not resources_context.sanitize_for_json.is_valid():
		return _failure("Stdio context builder should produce resource service status and sanitization callables.")
	var prompts_context = builder.build_prompts_service_context(stdio_server)
	if prompts_context == null or not prompts_context.get_tool_loader_status.is_valid():
		return _failure("Stdio context builder should produce prompt service status callables.")
	var stdio_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_stdio_server.gd")
	for forbidden in [
		"MCPResourcesServiceContextScript",
		"MCPPromptsServiceContextScript",
		"MCPToolRpcRouterContextScript",
		".new()\n\tresources_context",
		".new()\n\tprompts_context",
		".new()\n\trouter_context"
	]:
		if stdio_source.find(forbidden) != -1:
			return _failure("mcp_stdio_server.gd should delegate context construction to MCPStdioServiceContextBuilder, but still contains '%s'." % forbidden)
	var builder_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_stdio_service_context_builder.gd")
	for required in [
		"MCPResourcesServiceContextScript",
		"MCPPromptsServiceContextScript",
		"MCPToolRpcRouterContextScript",
		"func build_tool_rpc_router_context",
		"func build_resources_service_context",
		"func build_prompts_service_context"
	]:
		if builder_source.find(required) == -1:
			return _failure("MCPStdioServiceContextBuilder should own stdio context construction: missing '%s'." % required)
	return {"success": true, "error": ""}


func _failure(message: String) -> Dictionary:
	return {
		"name": "stdio_tool_activity_contracts",
		"success": false,
		"error": message
	}
