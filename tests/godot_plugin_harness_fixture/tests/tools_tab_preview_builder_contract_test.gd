extends RefCounted

const ToolsTabPreviewBuilder = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_preview_builder.gd")
const ToolsTabSearchService = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_search_service.gd")
const ToolsTabScript = preload("res://addons/godot_dotnet_mcp/ui/tools_tab.gd")


class FakeLocalization extends RefCounted:
	var _texts := {
		"cat_system": "System",
		"tool_preview_tool": "Tool",
		"tool_preview_tool_id": "Tool ID",
		"tool_preview_category": "Category",
		"tool_preview_description": "Description",
		"tool_preview_no_description": "No description",
		"tool_preview_actions": "Actions",
		"tool_preview_params": "Parameters",
		"tool_preview_no_params": "No parameters",
		"tool_preview_atomic_tools": "Atomic tools",
		"tool_preview_no_atomic_tools": "No atomic tools",
		"tool_preview_system_tool_hint": "Expand this tool to inspect its atomic chain.",
		"tool_preview_empty": "Nothing selected",
		"tool_preview_required": "Required",
		"tool_system_project_state_name": "Project State",
		"tool_system_project_state_desc": "Summarize the current project state.",
		"tool_project_info_name": "Project Info",
		"tool_project_info_desc": "Inspect the project metadata."
	}

	func get_text(key: String) -> String:
		return str(_texts.get(key, key))


func run_case(_tree: SceneTree) -> Dictionary:
	var localization = FakeLocalization.new()
	var model := {
		"localization": localization,
		"tools_by_category": {
			"system": [
				{
					"name": "project_state",
					"description": "Summarize the project state",
					"inputSchema": {
						"properties": {
							"scope": {
								"type": "string",
								"description": "State scope"
							}
						},
						"required": ["scope"]
					}
				}
			],
			"project": [
				{
					"name": "info",
					"description": "Inspect project metadata"
				}
			]
		}
	}
	var filtered = ToolsTabSearchService.build_filtered_tools_by_category(model, "")
	var preview_text = ToolsTabPreviewBuilder.build_preview_text({
		"localization": localization,
		"current_model": model,
		"filtered_tools_by_category": filtered,
		"selected_tree_kind": "tool",
		"selected_tree_key": "system_project_state",
		"selected_tool_category": "system",
		"selected_tool_name": "project_state"
	})
	for fragment in [
		"Tool: Project State",
		"Tool ID: system_project_state",
		"Category: System",
		"Summarize the current project state.",
		"Parameters",
		"- scope | string | Required | State scope",
		"Atomic tools",
		"Project Info",
		"Expand this tool to inspect its atomic chain."
	]:
		if not preview_text.contains(fragment):
			return _failure("Preview builder output is missing expected fragment: %s" % fragment)

	return {
		"name": "tools_tab_preview_builder_contracts",
		"success": true,
		"error": "",
		"details": {
			"preview_length": preview_text.length()
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tools_tab_preview_builder_contracts",
		"success": false,
		"error": message
	}
