extends RefCounted

# {"name": "system_help_contracts"}

const SystemHelpImplScript = preload("res://addons/godot_dotnet_mcp/tools/system/impl_help.gd")
const MCPProtocolFacts = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd")


class FakeToolLoader extends RefCounted:
	func get_exposed_tool_definitions() -> Array[Dictionary]:
		return [
			{"name": "system_editor_control"},
			{"name": "system_project_state"},
			{"name": "system_help"}
		]


func run_case(_tree: SceneTree) -> Dictionary:
	var impl = SystemHelpImplScript.new()
	impl.configure_runtime({"tool_loader": FakeToolLoader.new()})

	var tool_defs: Array[Dictionary] = impl.get_tools()
	if tool_defs.size() != 1:
		return _failure("system help implementation should expose exactly one tool definition.")
	if str(tool_defs[0].get("name", "")) != "help":
		return _failure("system help implementation should expose help as the local tool name.")

	var result: Dictionary = impl.execute("help", {})
	if not bool(result.get("success", false)):
		return _failure("system help should return a success payload.")
	var data = result.get("data", {})
	if not (data is Dictionary):
		return _failure("system help should return a dictionary payload.")
	var help_data: Dictionary = data
	var visual_guidance = help_data.get("visual_guidance", {})
	if not (visual_guidance is Dictionary):
		return _failure("system help should include visual guidance.")
	if not bool((visual_guidance as Dictionary).get("prefer_editor_screenshot", false)):
		return _failure("system help should explicitly recommend editor screenshots for UI judgment.")
	if not bool((visual_guidance as Dictionary).get("hidden_controls_supported", false)):
		return _failure("system help should explicitly state hidden controls can be enumerated.")

	var schema = help_data.get("schema", {})
	if not (schema is Dictionary):
		return _failure("system help should include schema facts.")
	if str((schema as Dictionary).get("tool_schema_version", "")) != MCPProtocolFacts.get_tool_schema_version():
		return _failure("system help should expose the unified tool schema version.")

	var exposed_tools: Array = help_data.get("exposed_system_tools", [])
	if not exposed_tools.has("system_help") or not exposed_tools.has("system_editor_control"):
		return _failure("system help should include exposed system tool names when requested.")

	var compact_result: Dictionary = impl.execute("help", {"include_tools": false})
	if not bool(compact_result.get("success", false)):
		return _failure("system help include_tools=false should still succeed.")
	if (compact_result.get("data", {}) as Dictionary).has("exposed_system_tools"):
		return _failure("system help include_tools=false should omit exposed_system_tools.")

	return {
		"name": "system_help_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_schema_version": MCPProtocolFacts.get_tool_schema_version(),
			"tool_count": exposed_tools.size()
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "system_help_contracts",
		"success": false,
		"error": message
	}
