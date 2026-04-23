extends RefCounted

# {"name": "tools_tab_rendering_contracts"}

const ToolsTabScene = preload("res://addons/godot_dotnet_mcp/ui/tools_tab.tscn")

var _instance: VBoxContainer = null


class FakeLocalization extends RefCounted:
	var _texts := {
		"tools_enabled": "Enabled %d/%d",
		"tool_search_placeholder": "Search tools",
		"tool_preview_title": "Preview",
		"tool_preview_empty": "Nothing selected",
		"tools_partial_suffix": "(partial)",
		"cat_system": "System",
		"cat_project": "Project",
		"cat_user": "User",
		"domain_core": "Core",
		"domain_user": "User Tools",
		"tool_system_project_state_name": "Project State",
		"tool_project_info_name": "Project Info",
		"tool_user_sample_tool_name": "Sample Tool"
	}

	func get_text(key: String) -> String:
		return str(_texts.get(key, key))


func run_case(tree: SceneTree) -> Dictionary:
	_instance = ToolsTabScene.instantiate() as VBoxContainer
	if _instance == null:
		return _failure("Tools tab rendering test could not instantiate the tools tab scene.")
	tree.root.add_child(_instance)
	await tree.process_frame

	_instance.apply_model({
		"localization": FakeLocalization.new(),
		"editor_scale": 1.0,
		"settings": {
			"disabled_tools": [],
			"collapsed_nodes": {}
		},
		"tools_by_category": {
			"system": [
				{
					"name": "editor_state",
					"description": "Summarize the current editor session"
				},
				{
					"name": "project_state",
					"description": "Summarize the project state"
				},
				{
					"name": "runtime_control",
					"description": "Inspect runtime control status"
				},
				{
					"name": "runtime_capture",
					"description": "Capture runtime frames"
				},
				{
					"name": "runtime_input",
					"description": "Send runtime inputs"
				},
				{
					"name": "runtime_step",
					"description": "Run input-wait-capture step"
				}
			],
			"project": [
				{
					"name": "info",
					"description": "Inspect project metadata"
				}
			],
			"user": [
				{
					"name": "sample_tool",
					"description": "Sample user tool",
					"source": "user_tool",
					"script_path": "res://addons/godot_dotnet_mcp/custom_tools/sample_tool.gd"
				}
			]
		},
		"tool_load_errors": []
	})
	await tree.process_frame

	var tool_count_label = _instance.get_node("HeaderMargin/HeaderContent/ToolCountLabel") as Label
	if tool_count_label == null or tool_count_label.text != "Enabled 7/7":
		return _failure("Tools tab should count the current system and user roots exactly once.")

	var tool_tree = _instance.get_node("ContentSplit/TopPane/ToolListOuterMargin/ToolListPanel/ToolListOverlay/ToolListMargin/ToolTree") as Tree
	if tool_tree == null:
		return _failure("Tools tab rendering test could not resolve the tree control.")
	var root = tool_tree.get_root()
	if root == null:
		return _failure("Tools tab should create a root tree item when applying the model.")

	var system_category = _find_child_by_metadata(root, "root", "system")
	var user_category = _find_child_by_metadata(root, "root", "user")
	if system_category == null or user_category == null:
		return _failure("Tools tab should render the current system and user root groups.")

	var editor_state_tool = _find_child_by_metadata(system_category, "tool", "system_editor_state")
	var system_tool = _find_child_by_metadata(system_category, "tool", "system_project_state")
	var runtime_control_tool = _find_child_by_metadata(system_category, "tool", "system_runtime_control")
	var runtime_capture_tool = _find_child_by_metadata(system_category, "tool", "system_runtime_capture")
	var runtime_input_tool = _find_child_by_metadata(system_category, "tool", "system_runtime_input")
	var runtime_step_tool = _find_child_by_metadata(system_category, "tool", "system_runtime_step")
	var user_tool = _find_child_by_metadata(user_category, "tool", "user_sample_tool")
	if editor_state_tool == null or system_tool == null or runtime_control_tool == null or runtime_capture_tool == null or runtime_input_tool == null or runtime_step_tool == null or user_tool == null:
		return _failure("Tools tab should render tool rows for every visible category.")

	if editor_state_tool.get_child_count() != 0:
		return _failure("Tools tab should only render atomic children that are present in the current model payload.")

	var atomic_tool = _find_child_by_metadata(system_tool, "atomic", "project_info")
	if atomic_tool == null:
		return _failure("Tools tab should keep the atomic child chain for system tools after tree rendering refactor.")

	return {
		"name": "tools_tab_rendering_contracts",
		"success": true,
		"error": "",
		"details": {
			"top_level_domain_count": root.get_child_count(),
			"system_tool_count": system_category.get_child_count(),
			"user_tool_count": user_category.get_child_count()
		}
	}


func cleanup_case(tree: SceneTree) -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance.queue_free()
	_instance = null
	await tree.process_frame
	await tree.process_frame


func _find_child_by_metadata(parent: TreeItem, kind: String, key: String) -> TreeItem:
	if parent == null:
		return null
	var child = parent.get_first_child()
	while child != null:
		var metadata = child.get_metadata(0)
		if metadata is Dictionary:
			var meta := metadata as Dictionary
			if str(meta.get("kind", "")) == kind and str(meta.get("key", "")) == key:
				return child
		child = child.get_next()
	return null


func _failure(message: String) -> Dictionary:
	return {
		"name": "tools_tab_rendering_contracts",
		"success": false,
		"error": message
	}
