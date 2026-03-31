extends RefCounted

const ToolsTabSearchService = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_search_service.gd")
const ToolsTabSelectionSupport = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_selection_support.gd")
const ToolsTabViewStateService = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_view_state_service.gd")


class FakeLocalization extends RefCounted:
	var _texts := {
		"tools_enabled": "Enabled %d/%d",
		"tool_search_placeholder": "Search tools",
		"tool_preview_title": "Preview",
		"tool_preview_empty": "Nothing selected",
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
		"tool_preview_required": "Required",
		"tool_system_project_state_name": "Project State",
		"tool_system_project_state_desc": "Summarize the current project state."
	}

	func get_text(key: String) -> String:
		return str(_texts.get(key, key))


func run_case(_tree: SceneTree) -> Dictionary:
	var service = ToolsTabViewStateService.new()
	var localization = FakeLocalization.new()
	var model := {
		"settings": {
			"disabled_tools": [],
			"collapsed_nodes": {}
		},
		"domain_defs": [
			{
				"key": "core",
				"label": "domain_core",
				"categories": ["system"]
			}
		],
		"tool_load_errors": [],
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
			]
		}
	}
	var filtered = ToolsTabSearchService.build_filtered_tools_by_category(model, "")
	var header_state: Dictionary = service.build_header_state(localization, model, filtered)
	if str(header_state.get("tool_count_text", "")) != "Enabled 1/1":
		return _failure("View state service should derive the enabled tool count label.")
	if str(header_state.get("search_placeholder_text", "")) != "Search tools":
		return _failure("View state service should derive the search placeholder text.")

	var selection_state = ToolsTabSelectionSupport.build_state_from_metadata({
		"kind": "tool",
		"key": "system_project_state",
		"category": "system",
		"tool_name": "project_state"
	})
	var preview_state: Dictionary = service.build_preview_state(localization, model, filtered, selection_state, "")
	if not bool(preview_state.get("selection_changed", false)):
		return _failure("View state service should report a changed selection when the preview key changes.")
	if str(preview_state.get("title", "")) != "Preview":
		return _failure("View state service should derive the preview title.")
	if str(preview_state.get("text", "")).find("Tool: Project State") == -1:
		return _failure("View state service should build preview text for the selected tool.")

	var preview_key = str(preview_state.get("preview_key", ""))
	var repeated_preview_state: Dictionary = service.build_preview_state(localization, model, filtered, selection_state, preview_key)
	if bool(repeated_preview_state.get("selection_changed", true)):
		return _failure("View state service should keep selection_changed false when the preview key is stable.")

	var initial_signature = service.build_tree_signature(model, "")
	var changed_model = model.duplicate(true)
	changed_model["tool_load_errors"] = [{"tool": "project_state", "error": "load_failed"}]
	var changed_signature = service.build_tree_signature(changed_model, "")
	if initial_signature == changed_signature:
		return _failure("View state service should include tool load errors in the tree signature.")

	return {
		"name": "tools_tab_view_state_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"preview_key": preview_key,
			"signature_length": initial_signature.length()
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tools_tab_view_state_service_contracts",
		"success": false,
		"error": message
	}
