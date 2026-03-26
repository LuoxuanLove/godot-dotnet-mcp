extends RefCounted

const ToolsTabSearchService = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_search_service.gd")


class FakeLocalization extends RefCounted:
	var _texts := {
		"cat_system": "System"
	}

	func get_text(key: String) -> String:
		return str(_texts.get(key, key))


func run_case(_tree: SceneTree) -> Dictionary:
	var model := {
		"localization": FakeLocalization.new(),
		"tools_by_category": {
			"system": [
				{
					"name": "project_state",
					"description": "Summarize the project state"
				},
				{
					"name": "runtime_capture",
					"description": "Capture runtime output"
				}
			],
			"project": [
				{
					"name": "info",
					"description": "Inspect project metadata",
					"inputSchema": {
						"properties": {
							"action": {
								"enum": ["status"]
							}
						}
					}
				}
			],
			"user": []
		}
	}

	var filtered = ToolsTabSearchService.build_filtered_tools_by_category(model, "info")
	var system_tools: Array = filtered.get("system", [])
	if system_tools.size() != 1:
		return _failure("Search service should preserve exactly one system tool for the recursive atomic search query.")
	if str((system_tools[0] as Dictionary).get("name", "")) != "project_state":
		return _failure("Search service should keep system_project_state when project_info matches recursively.")
	if not ToolsTabSearchService.category_matches_search(model, "system", filtered, "info"):
		return _failure("Search service should report system category as matched when a recursive atomic tool matches.")

	var direct_filtered = ToolsTabSearchService.build_filtered_tools_by_category(model, "runtime")
	var direct_tools: Array = direct_filtered.get("system", [])
	if direct_tools.size() != 1 or str((direct_tools[0] as Dictionary).get("name", "")) != "runtime_capture":
		return _failure("Search service did not preserve the direct tool match for runtime_capture.")

	return {
		"name": "tools_tab_search_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"recursive_match_tool": str((system_tools[0] as Dictionary).get("name", "")),
			"direct_match_tool": str((direct_tools[0] as Dictionary).get("name", ""))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tools_tab_search_service_contracts",
		"success": false,
		"error": message
	}
