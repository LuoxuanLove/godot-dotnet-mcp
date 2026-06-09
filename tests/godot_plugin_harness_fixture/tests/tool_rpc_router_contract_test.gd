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
		definitions.append({
			"name": "system_tool_catalog",
			"description": "Removed public tool catalog",
			"category": "system",
			"domain_key": "system",
			"load_state": "ready",
			"source": "builtin",
			"enabled": true,
			"inputSchema": {
				"type": "object",
				"properties": {
					"query": {"type": "string"}
				}
			}
		})
		definitions.append({
			"name": "system_tool_activity",
			"description": "Removed public activity tool",
			"category": "system",
			"domain_key": "system",
			"load_state": "ready",
			"source": "builtin",
			"enabled": true,
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["status", "recent", "get"]}
				}
			}
		})
		definitions.append({
			"name": "system_plugin_reload",
			"description": "Removed public plugin reload tool",
			"category": "system",
			"domain_key": "system",
			"load_state": "ready",
			"source": "builtin",
			"enabled": true,
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["get_freshness", "full_reload_plugin"]}
				}
			}
		})
		definitions.append({
			"name": "system_plugin_update",
			"description": "Removed public plugin update tool",
			"category": "system",
			"domain_key": "system",
			"load_state": "ready",
			"source": "builtin",
			"enabled": true,
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["get_current", "get_status", "set_source", "discover_refs", "start_sync"]}
				}
			}
		})
		definitions.append({
			"name": "system_scene_validate",
			"description": "Removed public scene validation tool",
			"category": "system",
			"domain_key": "system",
			"load_state": "ready",
			"source": "builtin",
			"enabled": true,
			"inputSchema": {
				"type": "object",
				"properties": {
					"scene": {"type": "string"}
				}
			}
		})
		definitions.append({
			"name": "system_scene_analyze",
			"description": "Removed public scene analysis tool",
			"category": "system",
			"domain_key": "system",
			"load_state": "ready",
			"source": "builtin",
			"enabled": true,
			"inputSchema": {
				"type": "object",
				"properties": {
					"scene": {"type": "string"}
				}
			}
		})
		return definitions

	func get_domain_states() -> Array:
		return [{
			"category": "system",
			"status": "ready"
		}]

	func is_public_removed_tool(tool_name: String) -> bool:
		return [
			"system_help",
			"system_plugin_reload",
			"system_plugin_update",
			"system_scene_analyze",
			"system_scene_validate",
			"system_tool_catalog",
			"system_tool_activity"
		].has(tool_name)

	func build_removed_public_tool_result(tool_name: String, arguments: Dictionary = {}) -> Dictionary:
		if tool_name == "system_plugin_reload":
			return _removed_plugin_maintenance_tool(
				tool_name,
				{"action": "reload"} if str(arguments.get("action", "")) == "full_reload_plugin" else {"action": "status"}
			)
		if tool_name == "system_plugin_update":
			return _removed_plugin_maintenance_tool(
				tool_name,
				_plugin_update_replacement_arguments(str(arguments.get("action", "")), arguments)
			)
		return {}

	func _removed_plugin_maintenance_tool(tool_name: String, replacement_arguments: Dictionary) -> Dictionary:
		return {
			"success": false,
			"error": "%s has been removed from the public tool surface. Call system_plugin_maintenance instead." % tool_name,
			"data": {
				"error_type": "removed_public_tool",
				"removed_tool": tool_name,
				"replacement_tools": [{
					"name": "system_plugin_maintenance",
					"arguments": replacement_arguments
				}],
				"replacement_methods": ["tools/call", "resources/read", "resources/list"],
				"replacement_resources": ["godot-dotnet-mcp://guides/capabilities", "godot-dotnet-mcp://tools/catalog/visible"]
			}
		}

	func _plugin_update_replacement_arguments(action: String, arguments: Dictionary) -> Dictionary:
		match action:
			"get_current":
				return {"action": "status"}
			"get_status":
				return {"action": "update_status"}
			"discover_refs":
				return {
					"action": "refresh_update_refs",
					"force_refresh": arguments.get("force_refresh", true)
				}
			"set_source":
				return {
					"action": "set_update_source",
					"source": arguments.get("source", arguments.get("update_source", "")),
					"custom_branch": arguments.get("custom_branch", arguments.get("branch", "")),
					"release_tag": arguments.get("release_tag", arguments.get("tag", ""))
				}
			"start_sync":
				return {"action": "start_update"}
			_:
				return {"action": "status"}

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
			}, {
				"name": "tool_catalog",
				"full_name": "system_tool_catalog",
				"category": "system",
				"enabled": true,
				"inputSchema": {"type": "object", "properties": {"query": {"type": "string"}}}
			}, {
				"name": "tool_activity",
				"full_name": "system_tool_activity",
				"category": "system",
				"enabled": true,
				"inputSchema": {"type": "object", "properties": {"action": {"type": "string", "enum": ["status", "recent", "get"]}}}
			}, {
				"name": "scene_validate",
				"full_name": "system_scene_validate",
				"category": "system",
				"enabled": true,
				"inputSchema": {"type": "object", "properties": {"scene": {"type": "string"}}}
			}, {
				"name": "scene_analyze",
				"full_name": "system_scene_analyze",
				"category": "system",
				"enabled": true,
				"inputSchema": {"type": "object", "properties": {"scene": {"type": "string"}}}
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
		if category == "system" and tool_name == "tool_catalog":
			return {
				"success": false,
				"error": "system_tool_catalog has been removed from the public tool surface. Read the catalog resources instead.",
				"data": {
					"error_type": "removed_public_tool",
					"removed_tool": "system_tool_catalog",
					"replacement_methods": ["resources/read", "resources/list"],
					"replacement_resources": ["godot-dotnet-mcp://tools/catalog/visible", "godot-dotnet-mcp://tools/catalog/exposed"]
				}
			}
		if category == "system" and tool_name == "tool_activity":
			return {
				"success": false,
				"error": "system_tool_activity has been removed from the public tool surface. Read the activity resources instead.",
				"data": {
					"error_type": "removed_public_tool",
					"removed_tool": "system_tool_activity",
					"replacement_methods": ["resources/read", "resources/list", "resources/templates/list"],
					"replacement_resources": ["godot-dotnet-mcp://activity/status"]
				}
			}
		if category == "system" and (tool_name == "scene_validate" or tool_name == "scene_analyze"):
			var removed_tool := "system_scene_validate" if tool_name == "scene_validate" else "system_scene_analyze"
			var replacement_action := "validate" if tool_name == "scene_validate" else "analyze"
			return {
				"success": false,
				"error": "%s has been removed from the public tool surface. Call system_scene_inspect with action=%s instead." % [removed_tool, replacement_action],
				"data": {
					"error_type": "removed_public_tool",
					"removed_tool": removed_tool,
					"replacement_tools": [{
						"name": "system_scene_inspect",
						"arguments": {"action": replacement_action, "scene": str(arguments.get("scene", ""))}
					}],
					"replacement_methods": ["tools/call", "resources/read", "resources/templates/list"],
					"replacement_resources": ["godot-dotnet-mcp://scene/{path}", "godot-dotnet-mcp://guides/capabilities"]
				}
			}
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
		return (
			tool_name == "system_project_state"
			or tool_name == "system_project_lifecycle"
			or tool_name == "system_help"
			or tool_name == "system_plugin_reload"
			or tool_name == "system_plugin_update"
			or tool_name == "system_tool_catalog"
			or tool_name == "system_tool_activity"
			or tool_name == "system_scene_validate"
			or tool_name == "system_scene_analyze"
		)

	func is_tool_exposed(tool_name: String) -> bool:
		return is_tool_enabled(tool_name) and (
			tool_name == "system_project_state"
			or tool_name == "system_project_lifecycle"
			or tool_name == "system_help"
			or tool_name == "system_plugin_reload"
			or tool_name == "system_plugin_update"
			or tool_name == "system_tool_catalog"
			or tool_name == "system_tool_activity"
			or tool_name == "system_scene_validate"
			or tool_name == "system_scene_analyze"
		)

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
	for removed_tool_name in ["system_help", "system_plugin_reload", "system_plugin_update", "system_tool_catalog", "system_tool_activity", "system_scene_validate", "system_scene_analyze"]:
		if _contains_tool_name_recursive(tools_list, removed_tool_name):
			return _failure("Tool RPC router tools/list should not expose removed public tool %s." % removed_tool_name)
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

	var removed_catalog_result: Dictionary = await router.build_tool_call_result_async({
		"name": "system_tool_catalog",
		"arguments": {"query": "runtime"}
	})
	if not bool(removed_catalog_result.get("isError", false)):
		return _failure("Tool RPC router should return isError=true for removed system_tool_catalog.")
	var removed_catalog_structured = removed_catalog_result.get("structuredContent", {})
	if not (removed_catalog_structured is Dictionary) or bool((removed_catalog_structured as Dictionary).get("success", true)):
		return _failure("Tool RPC router removed system_tool_catalog should expose failing structuredContent.")
	var removed_catalog_data = (removed_catalog_structured as Dictionary).get("data", {})
	if not (removed_catalog_data is Dictionary) or str((removed_catalog_data as Dictionary).get("error_type", "")) != "removed_public_tool":
		return _failure("Tool RPC router removed system_tool_catalog should expose removed_public_tool guidance.")
	if not (((removed_catalog_data as Dictionary).get("replacement_resources", []) as Array).has("godot-dotnet-mcp://tools/catalog/visible")):
		return _failure("Tool RPC router removed system_tool_catalog should point to catalog resources.")

	var removed_activity_result: Dictionary = await router.build_tool_call_result_async({
		"name": "system_tool_activity",
		"arguments": {"action": "status"}
	})
	if not bool(removed_activity_result.get("isError", false)):
		return _failure("Tool RPC router should return isError=true for removed system_tool_activity.")
	var removed_activity_structured = removed_activity_result.get("structuredContent", {})
	if not (removed_activity_structured is Dictionary) or bool((removed_activity_structured as Dictionary).get("success", true)):
		return _failure("Tool RPC router removed system_tool_activity should expose failing structuredContent.")
	var removed_activity_data = (removed_activity_structured as Dictionary).get("data", {})
	if not (removed_activity_data is Dictionary) or str((removed_activity_data as Dictionary).get("error_type", "")) != "removed_public_tool":
		return _failure("Tool RPC router removed system_tool_activity should expose removed_public_tool guidance.")
	if not (((removed_activity_data as Dictionary).get("replacement_resources", []) as Array).has("godot-dotnet-mcp://activity/status")):
		return _failure("Tool RPC router removed system_tool_activity should point to activity/status.")
	for removed_plugin_case in [
		{"tool": "system_plugin_reload", "arguments": {"action": "full_reload_plugin"}, "replacement_action": "reload"},
		{"tool": "system_plugin_update", "arguments": {"action": "get_current"}, "replacement_action": "status"},
		{"tool": "system_plugin_update", "arguments": {"action": "start_sync"}, "replacement_action": "start_update"},
		{"tool": "system_plugin_update", "arguments": {"action": "discover_refs", "force_refresh": false}, "replacement_action": "refresh_update_refs"}
	]:
		var removed_plugin_result: Dictionary = await router.build_tool_call_result_async({
			"name": str(removed_plugin_case.get("tool", "")),
			"arguments": removed_plugin_case.get("arguments", {})
		})
		if not bool(removed_plugin_result.get("isError", false)):
			return _failure("Tool RPC router should return isError=true for removed %s." % str(removed_plugin_case.get("tool", "")))
		var removed_plugin_structured = removed_plugin_result.get("structuredContent", {})
		if not _is_removed_plugin_maintenance_tool(removed_plugin_structured, str(removed_plugin_case.get("tool", "")), str(removed_plugin_case.get("replacement_action", ""))):
			return _failure("Tool RPC router removed %s should point to system_plugin_maintenance." % str(removed_plugin_case.get("tool", "")))
		if str(removed_plugin_case.get("replacement_action", "")) == "refresh_update_refs":
			var removed_plugin_data = (removed_plugin_structured as Dictionary).get("data", {})
			var replacement_args := _first_replacement_arguments(removed_plugin_data)
			if bool(replacement_args.get("force_refresh", true)):
				return _failure("Tool RPC router removed system_plugin_update discover_refs should preserve force_refresh=false.")
	for removed_scene_case in [
		{"tool": "system_scene_validate", "action": "validate"},
		{"tool": "system_scene_analyze", "action": "analyze"}
	]:
		var removed_scene_result: Dictionary = await router.build_tool_call_result_async({
			"name": str(removed_scene_case.get("tool", "")),
			"arguments": {"scene": "res://Main.tscn"}
		})
		if not bool(removed_scene_result.get("isError", false)):
			return _failure("Tool RPC router should return isError=true for removed %s." % str(removed_scene_case.get("tool", "")))
		var removed_scene_structured = removed_scene_result.get("structuredContent", {})
		if not _is_removed_scene_tool(removed_scene_structured, str(removed_scene_case.get("tool", "")), str(removed_scene_case.get("action", ""))):
			return _failure("Tool RPC router removed %s should point to system_scene_inspect." % str(removed_scene_case.get("tool", "")))

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
	if value is String:
		return str(value) == tool_name
	if value is Array:
		for item in value:
			if _contains_tool_name_recursive(item, tool_name):
				return true
		return false
	if value is Dictionary:
		var dict := value as Dictionary
		for key in ["name", "fullName", "full_name"]:
			if str(dict.get(key, "")) == tool_name:
				return true
		for nested in dict.values():
			if _contains_tool_name_recursive(nested, tool_name):
				return true
	return false


func _is_removed_scene_tool(structured, removed_tool: String, replacement_action: String) -> bool:
	if not (structured is Dictionary) or bool((structured as Dictionary).get("success", true)):
		return false
	var data = (structured as Dictionary).get("data", {})
	if not (data is Dictionary):
		return false
	var data_dict := data as Dictionary
	if str(data_dict.get("error_type", "")) != "removed_public_tool":
		return false
	if str(data_dict.get("removed_tool", "")) != removed_tool:
		return false
	if not ((data_dict.get("replacement_resources", []) as Array).has("godot-dotnet-mcp://scene/{path}")):
		return false
	var replacement_tools = data_dict.get("replacement_tools", [])
	if not (replacement_tools is Array) or (replacement_tools as Array).is_empty():
		return false
	var replacement = (replacement_tools as Array)[0]
	if not (replacement is Dictionary):
		return false
	var replacement_arguments = (replacement as Dictionary).get("arguments", {})
	return str((replacement as Dictionary).get("name", "")) == "system_scene_inspect" and replacement_arguments is Dictionary and str((replacement_arguments as Dictionary).get("action", "")) == replacement_action


func _is_removed_plugin_maintenance_tool(structured, removed_tool: String, replacement_action: String) -> bool:
	if not (structured is Dictionary) or bool((structured as Dictionary).get("success", true)):
		return false
	var data = (structured as Dictionary).get("data", {})
	if not (data is Dictionary):
		return false
	var data_dict := data as Dictionary
	if str(data_dict.get("error_type", "")) != "removed_public_tool":
		return false
	if str(data_dict.get("removed_tool", "")) != removed_tool:
		return false
	var replacement_tools = data_dict.get("replacement_tools", [])
	if not (replacement_tools is Array) or (replacement_tools as Array).is_empty():
		return false
	var replacement = (replacement_tools as Array)[0]
	if not (replacement is Dictionary):
		return false
	var replacement_arguments = (replacement as Dictionary).get("arguments", {})
	return str((replacement as Dictionary).get("name", "")) == "system_plugin_maintenance" and replacement_arguments is Dictionary and str((replacement_arguments as Dictionary).get("action", "")) == replacement_action


func _first_replacement_arguments(data) -> Dictionary:
	if not (data is Dictionary):
		return {}
	var replacement_tools = (data as Dictionary).get("replacement_tools", [])
	if not (replacement_tools is Array) or (replacement_tools as Array).is_empty():
		return {}
	var replacement = (replacement_tools as Array)[0]
	if not (replacement is Dictionary):
		return {}
	var replacement_arguments = (replacement as Dictionary).get("arguments", {})
	if replacement_arguments is Dictionary:
		return replacement_arguments
	return {}
