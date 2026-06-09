extends RefCounted

# {"name": "tool_rpc_router_contracts"}

const ToolRpcRouterScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_rpc_router.gd")
const ToolRpcRouterContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_rpc_router_context.gd")
const ToolActivityRegistryScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_activity_registry.gd")
const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")


class FakeToolLoader:
	extends RefCounted

	var activity_registry = null

	func get_exposed_tool_definitions() -> Array:
		return [{
			"name": "system_project_state",
			"description": "Inspect project state",
			"category": "system",
			"domain_key": "system",
			"load_state": "ready",
			"source": "builtin",
			"enabled": true,
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		}, {
			"name": "system_project_lifecycle",
			"description": "Start or stop a project runtime session",
			"category": "system",
			"domain_key": "system",
			"load_state": "ready",
			"source": "builtin",
			"enabled": true,
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["start", "stop"]}
				}
			}
		}]

	func get_tool_definitions() -> Array:
		var definitions := get_exposed_tool_definitions()
		definitions.append({
			"name": "system_help",
			"description": "Removed help tool",
			"category": "system",
			"domain_key": "system",
			"load_state": "ready",
			"source": "builtin",
			"enabled": true,
			"inputSchema": {"type": "object", "properties": {}}
		})
		return definitions

	func get_domain_states() -> Array:
		return [{
			"category": "system",
			"status": "ready"
		}]

	func get_all_tools_by_category() -> Dictionary:
		return {
			"system": [{
				"name": "project_state",
				"full_name": "system_project_state",
				"category": "system",
				"enabled": true,
				"inputSchema": {"type": "object", "properties": {}}
			}, {
				"name": "project_lifecycle",
				"full_name": "system_project_lifecycle",
				"category": "system",
				"enabled": true,
				"inputSchema": {"type": "object", "properties": {"action": {"type": "string", "enum": ["start", "stop"]}}}
			}, {
				"name": "help",
				"full_name": "system_help",
				"category": "system",
				"enabled": true,
				"inputSchema": {"type": "object", "properties": {}}
			}],
			"project": [{
				"name": "info",
				"full_name": "project_info",
				"category": "project",
				"enabled": true,
				"inputSchema": {"type": "object", "properties": {}}
			}],
			"filesystem": [{
				"name": "directory",
				"full_name": "filesystem_directory",
				"category": "filesystem",
				"enabled": true,
				"inputSchema": {"type": "object", "properties": {}}
			}]
		}

	func execute_tool_async(category: String, tool_name: String, arguments: Dictionary) -> Dictionary:
		var execution_args := arguments.duplicate(true)
		var agent_context := {}
		if execution_args.get("_mcp_context", null) is Dictionary:
			agent_context = (execution_args.get("_mcp_context", {}) as Dictionary).duplicate(true)
		execution_args.erase("_mcp_context")
		var record := {}
		if activity_registry != null:
			record = activity_registry.begin_call("%s_%s" % [category, tool_name], category, tool_name, execution_args, agent_context, {})
		var result := {
			"success": true,
			"data": {
				"category": category,
				"tool": tool_name,
				"arguments": execution_args
			},
			"message": "ok"
		}
		if activity_registry != null and not record.is_empty():
			var finished: Dictionary = activity_registry.finish_call(str(record.get("call_id", "")), true)
			result["activity"] = activity_registry.summarize_record(finished)
		if category == "system" and tool_name == "help":
			result = {
				"success": false,
				"error": "system_help has been removed from the public MCP tool surface.",
				"data": {
					"error_type": "removed_public_tool",
					"removed_tool": "system_help",
					"replacement_resources": ["godot-dotnet-mcp://guides/index"]
				}
			}
		return result


class FailingToolLoader:
	extends FakeToolLoader

	func execute_tool_async(category: String, tool_name: String, arguments: Dictionary) -> Dictionary:
		return {
			"success": false,
			"error": "contract failure",
			"data": {
				"category": category,
				"tool": tool_name,
				"arguments_seen": arguments
			}
		}


class PlainActivityToolLoader:
	extends FakeToolLoader

	func execute_tool_async(category: String, tool_name: String, arguments: Dictionary) -> Dictionary:
		return {
			"success": true,
			"activity": {
				"user_supplied": true
			},
			"category": category,
			"tool": tool_name,
			"arguments": arguments
		}


class FakeCallbacks:
	extends RefCounted

	var loader = FakeToolLoader.new()
	var activity_registry = ToolActivityRegistryScript.new()
	var last_log: Dictionary = {}
	var disabled_tools: Dictionary = {}

	func _init() -> void:
		loader.activity_registry = activity_registry

	func get_tool_loader():
		return loader

	func is_tool_enabled(tool_name: String) -> bool:
		if disabled_tools.has(tool_name):
			return false
		return tool_name == "system_project_state" or tool_name == "system_project_lifecycle" or tool_name == "system_help"

	func is_tool_exposed(tool_name: String) -> bool:
		return is_tool_enabled(tool_name) and (tool_name == "system_project_state" or tool_name == "system_project_lifecycle" or tool_name == "system_help")

	func log(message: String, level: String) -> void:
		last_log = {
			"message": message,
			"level": level
		}

	func sanitize_for_json(value):
		return value


func run_case(_tree: SceneTree) -> Dictionary:
	var router = ToolRpcRouterScript.new()
	var callbacks = FakeCallbacks.new()
	var context = ToolRpcRouterContextScript.new()
	context.get_tool_loader = Callable(callbacks, "get_tool_loader")
	context.is_tool_enabled = Callable(callbacks, "is_tool_enabled")
	context.is_tool_exposed = Callable(callbacks, "is_tool_exposed")
	context.log = Callable(callbacks, "log")
	context.sanitize_for_json = Callable(callbacks, "sanitize_for_json")
	context.tool_activity_registry = callbacks.activity_registry
	router.configure(context)

	var tools_list: Dictionary = router.build_tools_list_result()
	var tools = tools_list.get("tools", [])
	if not (tools is Array) or (tools as Array).is_empty():
		return _failure("Tool RPC router did not surface exposed tool definitions.")
	if not (tools_list.get("toolTree", []) is Array) or (tools_list.get("toolTree", []) as Array).is_empty():
		return _failure("Tool RPC router did not expose the unified tool tree.")
	if _contains_tool_name_recursive(tools_list.get("toolTree", []), "system_help") or _contains_tool_name_recursive(tools_list.get("toolGroups", []), "system_help"):
		return _failure("Tool RPC router tree and group metadata should omit removed system_help from tools/list.")
	if not (((tools as Array)[0] as Dictionary).has("groupPath")):
		return _failure("Tool RPC router should preserve flat tools while adding groupPath metadata.")
	for tool_entry in tools:
		if not (tool_entry is Dictionary):
			continue
		if str((tool_entry as Dictionary).get("name", "")) == "system_project_stop":
			return _failure("Tool RPC router should omit removed project lifecycle entries from tools/list.")
		if str((tool_entry as Dictionary).get("name", "")) == "system_project_run":
			return _failure("Tool RPC router should not expose removed system_project_run.")
		if str((tool_entry as Dictionary).get("name", "")) == "system_help":
			return _failure("Tool RPC router should omit removed system_help from tools/list.")

	var success_result: Dictionary = await router.build_tool_call_result_async({
		"name": "system_project_state",
		"arguments": {
			"scope": "full",
			"_mcp_context": {
				"agent_id": "router-contract-agent",
				"purpose": "verify context stripping",
				"notes": "This note should stay in activity only."
			}
		}
	})
	if bool(success_result.get("isError", true)):
		return _failure("Tool RPC router should return isError=false for a successful tool execution.")
	var content = success_result.get("content", [])
	if not (content is Array) or (content as Array).is_empty():
		return _failure("Tool RPC router did not include text content for a successful tool execution.")
	var text_payload := str(((content as Array)[0] as Dictionary).get("text", ""))
	var parsed = JSON.parse_string(text_payload)
	if not (parsed is Dictionary):
		return _failure("Tool RPC router did not serialize the tool result as a JSON object.")
	var parsed_dict: Dictionary = parsed
	if not bool(parsed_dict.get("success", false)):
		return _failure("Tool RPC router did not preserve the success flag in the serialized payload.")
	var structured = success_result.get("structuredContent", {})
	if not (structured is Dictionary):
		return _failure("Tool RPC router should expose structuredContent for successful tool responses.")
	var structured_dict: Dictionary = structured
	if bool(structured_dict.get("success", false)) != bool(parsed_dict.get("success", false)):
		return _failure("Tool RPC router structuredContent should match the compatibility text JSON success flag.")
	if JSON.stringify(structured_dict.get("data", {})) != JSON.stringify(parsed_dict.get("data", {})):
		return _failure("Tool RPC router structuredContent should match the compatibility text JSON data payload.")
	var parsed_data = parsed_dict.get("data", {})
	if not (parsed_data is Dictionary) or str((parsed_data as Dictionary).get("tool", "")) != "project_state":
		return _failure("Tool RPC router did not preserve the resolved tool name in the serialized payload.")
	var executed_arguments = (parsed_data as Dictionary).get("arguments", {})
	if not (executed_arguments is Dictionary) or (executed_arguments as Dictionary).has("_mcp_context"):
		return _failure("Tool RPC router should strip _mcp_context before executing the concrete tool.")
	var activity = parsed_dict.get("activity", {})
	if not (activity is Dictionary) or str((activity as Dictionary).get("call_id", "")).is_empty():
		return _failure("Tool RPC router should attach an activity summary to normal tool responses.")
	var activity_status: Dictionary = callbacks.activity_registry.get_status()
	var recent = activity_status.get("recent", [])
	if not (recent is Array) or (recent as Array).is_empty():
		return _failure("Tool activity registry should retain recent completed tool calls.")
	var recent_context = (((recent as Array)[0] as Dictionary).get("agent_context", {}) as Dictionary)
	if str(recent_context.get("agent_id", "")) != "router-contract-agent":
		return _failure("Tool activity registry should retain sanitized self-reported agent context.")

	var lifecycle_result: Dictionary = await router.build_tool_call_result_async({
		"name": "system_project_lifecycle",
		"arguments": {"action": "stop"}
	})
	if bool(lifecycle_result.get("isError", true)):
		return _failure("Tool RPC router should allow system_project_lifecycle(action=stop) through tools/call.")
	var lifecycle_payload = JSON.parse_string(str(((lifecycle_result.get("content", []) as Array)[0] as Dictionary).get("text", "")))
	if not (lifecycle_payload is Dictionary):
		return _failure("Tool RPC router should serialize lifecycle calls.")
	var lifecycle_data = (lifecycle_payload as Dictionary).get("data", {})
	if not (lifecycle_data is Dictionary) or str((lifecycle_data as Dictionary).get("tool", "")) != "project_lifecycle":
		return _failure("Tool RPC router should resolve system_project_lifecycle to the project_lifecycle implementation.")

	for removed_tool_name in ["system_project_run", "system_project_stop"]:
		var removed_result: Dictionary = await router.build_tool_call_result_async({
			"name": removed_tool_name,
			"arguments": {}
		})
		if not bool(removed_result.get("isError", false)):
			return _failure("Tool RPC router should reject removed project lifecycle entry '%s'." % removed_tool_name)

	var removed_help_result: Dictionary = await router.build_tool_call_result_async({
		"name": "system_help",
		"arguments": {}
	})
	if not bool(removed_help_result.get("isError", false)):
		return _failure("Tool RPC router should return an error result for removed system_help legacy calls.")
	var removed_help_structured = removed_help_result.get("structuredContent", {})
	if not (removed_help_structured is Dictionary):
		return _failure("Tool RPC router should expose structuredContent for removed system_help calls.")
	var removed_help_data = (removed_help_structured as Dictionary).get("data", {})
	if not (removed_help_data is Dictionary) or not (((removed_help_data as Dictionary).get("replacement_resources", []) as Array).has("godot-dotnet-mcp://guides/index")):
		return _failure("Tool RPC router should preserve system_help replacement resource URIs.")

	callbacks.disabled_tools["system_project_lifecycle"] = true
	var disabled_lifecycle_result: Dictionary = await router.build_tool_call_result_async({
		"name": "system_project_lifecycle",
		"arguments": {}
	})
	if not bool(disabled_lifecycle_result.get("isError", false)):
		return _failure("Tool RPC router should reject system_project_lifecycle when disabled.")
	callbacks.disabled_tools.clear()

	var error_result: Dictionary = await router.build_tool_call_result_async({})
	if not bool(error_result.get("isError", false)):
		return _failure("Tool RPC router should return isError=true when the tool name is missing.")
	var invalid_arguments_result: Dictionary = await router.build_tool_call_result_async({
		"name": "system_project_state",
		"arguments": []
	})
	if not bool(invalid_arguments_result.get("isError", false)):
		return _failure("Tool RPC router should return isError=true when arguments are not an object.")
	var invalid_arguments_content = invalid_arguments_result.get("content", [])
	if not (invalid_arguments_content is Array) or (invalid_arguments_content as Array).is_empty():
		return _failure("Tool RPC router non-object arguments error should include text content.")
	if str(((invalid_arguments_content as Array)[0] as Dictionary).get("text", "")).find("Tool arguments must be an object") == -1:
		return _failure("Tool RPC router non-object arguments error should preserve the validation message.")

	MCPDebugBuffer.clear()
	var failing_callbacks = FakeCallbacks.new()
	failing_callbacks.loader = FailingToolLoader.new()
	var failing_context = ToolRpcRouterContextScript.new()
	failing_context.get_tool_loader = Callable(failing_callbacks, "get_tool_loader")
	failing_context.is_tool_enabled = Callable(failing_callbacks, "is_tool_enabled")
	failing_context.is_tool_exposed = Callable(failing_callbacks, "is_tool_exposed")
	failing_context.log = Callable(failing_callbacks, "log")
	failing_context.sanitize_for_json = Callable(failing_callbacks, "sanitize_for_json")
	failing_context.tool_activity_registry = failing_callbacks.activity_registry
	var failing_router = ToolRpcRouterScript.new()
	failing_router.configure(failing_context)
	var failing_result: Dictionary = await failing_router.build_tool_call_result_async({
		"name": "system_project_state",
		"arguments": {
			"scope": "full",
			"_mcp_context": {
				"agent_id": "debug-leak-agent",
				"notes": "do not log this note"
			}
		}
	})
	if not bool(failing_result.get("isError", false)):
		return _failure("Tool RPC router should mark failing tool execution as an error.")
	var failing_structured = failing_result.get("structuredContent", {})
	if not (failing_structured is Dictionary) or bool((failing_structured as Dictionary).get("success", true)):
		return _failure("Tool RPC router should expose structuredContent for failing tool responses.")
	var debug_events := MCPDebugBuffer.get_recent(1)
	if debug_events.is_empty():
		return _failure("Tool RPC router should record failing tool calls in the debug buffer.")
	var debug_json := JSON.stringify(debug_events[0])
	if debug_json.find("_mcp_context") != -1 or debug_json.find("debug-leak-agent") != -1 or debug_json.find("do not log this note") != -1:
		return _failure("Tool RPC router should remove _mcp_context before recording failed-call arguments.")

	var plain_callbacks = FakeCallbacks.new()
	plain_callbacks.loader = PlainActivityToolLoader.new()
	var plain_context = ToolRpcRouterContextScript.new()
	plain_context.get_tool_loader = Callable(plain_callbacks, "get_tool_loader")
	plain_context.is_tool_enabled = Callable(plain_callbacks, "is_tool_enabled")
	plain_context.is_tool_exposed = Callable(plain_callbacks, "is_tool_exposed")
	plain_context.log = Callable(plain_callbacks, "log")
	plain_context.sanitize_for_json = Callable(plain_callbacks, "sanitize_for_json")
	plain_context.tool_activity_registry = plain_callbacks.activity_registry
	var plain_router = ToolRpcRouterScript.new()
	plain_router.configure(plain_context)
	var plain_result: Dictionary = await plain_router.build_tool_call_result_async({
		"name": "system_project_state",
		"arguments": {"scope": "plain"}
	})
	var plain_payload = JSON.parse_string(str(((plain_result.get("content", []) as Array)[0] as Dictionary).get("text", "")))
	if not (plain_payload is Dictionary):
		return _failure("Tool RPC router should serialize plain activity test payload.")
	var plain_structured = plain_result.get("structuredContent", {})
	if not (plain_structured is Dictionary):
		return _failure("Tool RPC router should expose structuredContent for normalized non-protocol activity payloads.")
	if JSON.stringify((plain_structured as Dictionary).get("data", {})) != JSON.stringify((plain_payload as Dictionary).get("data", {})):
		return _failure("Tool RPC router structuredContent should preserve normalized non-protocol activity data.")
	if (plain_payload as Dictionary).has("activity"):
		return _failure("Tool RPC router should reserve top-level activity only for protocol activity summaries.")
	var plain_data = (plain_payload as Dictionary).get("data", {})
	if not (plain_data is Dictionary) or not (((plain_data as Dictionary).get("activity", {}) as Dictionary).get("user_supplied", false)):
		return _failure("Tool RPC router should move non-protocol tool activity fields into data.")

	return {
		"name": "tool_rpc_router_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": (tools as Array).size(),
			"serialized_tool": str((parsed_data as Dictionary).get("tool", "")),
			"activity_call_id": str((activity as Dictionary).get("call_id", "")),
			"log_level": str(callbacks.last_log.get("level", ""))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_rpc_router_contracts",
		"success": false,
		"error": message
	}


func _contains_tool_name_recursive(value, tool_name: String) -> bool:
	if value is Dictionary:
		var value_dict := value as Dictionary
		for key in ["name", "full_name", "toolName", "tool_name"]:
			if str(value_dict.get(key, "")) == tool_name:
				return true
		for nested_value in value_dict.values():
			if _contains_tool_name_recursive(nested_value, tool_name):
				return true
	elif value is Array:
		for nested_item in value as Array:
			if _contains_tool_name_recursive(nested_item, tool_name):
				return true
	elif str(value) == tool_name:
		return true
	return false
