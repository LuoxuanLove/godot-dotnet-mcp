extends RefCounted

# {"name": "system_help_contracts"}

const SystemHelpImplScript = preload("res://addons/godot_dotnet_mcp/tools/system/impl_help.gd")


class FakeToolLoader extends RefCounted:
	func get_exposed_tool_definitions() -> Array[Dictionary]:
		return [
			{"name": "system_editor_control"},
			{"name": "system_editor_evidence"},
			{"name": "system_project_state"}
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
	if bool(result.get("success", true)):
		return _failure("system help legacy call should return a removal error payload.")
	var data = result.get("data", {})
	if not (data is Dictionary):
		return _failure("system help removal error should include a data dictionary.")
	var removal_data := data as Dictionary
	if str(removal_data.get("error_type", "")) != "removed_public_tool":
		return _failure("system help removal error should include removed_public_tool error_type.")
	if str(removal_data.get("removed_tool", "")) != "system_help":
		return _failure("system help removal error should name system_help.")
	var replacement_resources = removal_data.get("replacement_resources", [])
	if not (replacement_resources is Array):
		return _failure("system help removal error should include replacement resource URIs.")
	for expected_resource in ["godot-dotnet-mcp://guides/index", "godot-dotnet-mcp://guides/capabilities", "godot-dotnet-mcp://guides/ui-automation"]:
		if not (replacement_resources as Array).has(expected_resource):
			return _failure("system help removal error should include replacement resource: %s" % expected_resource)
	var replacement_methods = removal_data.get("replacement_methods", [])
	for expected_method in ["resources/list", "resources/read", "prompts/list", "prompts/get"]:
		if not (replacement_methods is Array) or not (replacement_methods as Array).has(expected_method):
			return _failure("system help removal error should include replacement method: %s" % expected_method)

	return {
		"name": "system_help_contracts",
		"success": true,
		"error": "",
		"details": {
			"removed_tool": "system_help",
			"replacement_resource_count": (replacement_resources as Array).size()
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "system_help_contracts",
		"success": false,
		"error": message
	}
