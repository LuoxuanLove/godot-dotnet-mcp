extends RefCounted

const ToolRpcRouterScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_rpc_router.gd")
const ToolRpcRouterContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_rpc_router_context.gd")


class FakeToolLoader:
	extends RefCounted

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
		}]

	func get_tool_definitions() -> Array:
		return get_exposed_tool_definitions()

	func get_domain_states() -> Array:
		return [{
			"category": "system",
			"status": "ready"
		}]

	func execute_tool_async(category: String, tool_name: String, arguments: Dictionary) -> Dictionary:
		return {
			"success": true,
			"data": {
				"category": category,
				"tool": tool_name,
				"arguments": arguments.duplicate(true)
			},
			"message": "ok"
		}


class FakeCallbacks:
	extends RefCounted

	var loader = FakeToolLoader.new()
	var last_log: Dictionary = {}

	func get_tool_loader():
		return loader

	func is_tool_enabled(tool_name: String) -> bool:
		return tool_name == "system_project_state"

	func is_tool_exposed(tool_name: String) -> bool:
		return tool_name == "system_project_state"

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
	router.configure(context)

	var tools_list: Dictionary = router.build_tools_list_result()
	var tools = tools_list.get("tools", [])
	if not (tools is Array) or (tools as Array).is_empty():
		return _failure("Tool RPC router did not surface exposed tool definitions.")

	var success_result: Dictionary = await router.build_tool_call_result_async({
		"name": "system_project_state",
		"arguments": {
			"scope": "full"
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
	var parsed_data = parsed_dict.get("data", {})
	if not (parsed_data is Dictionary) or str((parsed_data as Dictionary).get("tool", "")) != "project_state":
		return _failure("Tool RPC router did not preserve the resolved tool name in the serialized payload.")

	var error_result: Dictionary = await router.build_tool_call_result_async({})
	if not bool(error_result.get("isError", false)):
		return _failure("Tool RPC router should return isError=true when the tool name is missing.")

	return {
		"name": "tool_rpc_router_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": (tools as Array).size(),
			"serialized_tool": str((parsed_data as Dictionary).get("tool", "")),
			"log_level": str(callbacks.last_log.get("level", ""))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_rpc_router_contracts",
		"success": false,
		"error": message
	}
