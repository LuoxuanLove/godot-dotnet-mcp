extends RefCounted

const ToolLoaderEnablementServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_enablement_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var service = ToolLoaderEnablementServiceScript.new()
	var first_changed := service.configure_disabled_tools([
		"system_project_state",
		&"debug_log_write",
		42
	])
	if not first_changed:
		return _failure("Enablement service should report a change when disabled tools are first configured.")
	if service.configure_disabled_tools([42, "debug_log_write", "system_project_state"]):
		return _failure("Enablement service should treat equivalent disabled tool sets as a no-op.")

	var disabled := service.get_disabled_tools()
	if not disabled.has("system_project_state") or not disabled.has("debug_log_write") or not disabled.has("42"):
		return _failure("Enablement service should normalize disabled tool names to strings.")
	if service.is_tool_enabled("system_project_state"):
		return _failure("Enablement service should report configured disabled tools as disabled.")
	if not service.is_tool_enabled("system_editor_state"):
		return _failure("Enablement service should keep unknown tools enabled by default.")

	disabled.append("system_editor_state")
	if not service.is_tool_enabled("system_editor_state"):
		return _failure("Enablement service should isolate disabled tool snapshots from callers.")

	var definitions_by_category := {
		"system": [
			{"name": "project_state"},
			{"name": "editor_state"},
			"invalid"
		],
		"debug": [
			{"name": "log_write"}
		],
		"empty": []
	}
	if service.count_enabled_tools_in_category("system", definitions_by_category) != 1:
		return _failure("Enablement service should count only enabled definitions in a category.")
	if service.category_has_enabled_tools("debug", definitions_by_category):
		return _failure("Enablement service should report categories with only disabled definitions as unavailable.")
	if service.category_has_enabled_tools("empty", definitions_by_category):
		return _failure("Enablement service should report empty categories as unavailable.")
	if not service.configure_disabled_tools([]):
		return _failure("Enablement service should report a change when disabled tools are cleared.")
	if service.count_enabled_tools_in_category("debug", definitions_by_category) != 1:
		return _failure("Enablement service should clear previous disabled tools when reconfigured.")

	return {
		"name": "tool_loader_enablement_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"disabled_count": disabled.size(),
			"system_enabled_count": 1
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_loader_enablement_service_contracts",
		"success": false,
		"error": message
	}
