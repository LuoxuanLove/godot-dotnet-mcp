extends RefCounted

const ToolsTabScene = preload("res://addons/godot_dotnet_mcp/ui/tools_tab.tscn")
const ToolsTabViewBindingService = preload("res://addons/godot_dotnet_mcp/ui/tools_tab_view_binding_service.gd")

var _instance: VBoxContainer = null


func run_case(tree: SceneTree) -> Dictionary:
	var service = ToolsTabViewBindingService.new()
	_instance = ToolsTabScene.instantiate() as VBoxContainer
	if _instance == null:
		return _failure("Tools tab view binding test could not instantiate the tools tab scene.")
	tree.root.add_child(_instance)
	await tree.process_frame

	var tool_count_label = _instance.find_child("ToolCountLabel", true, false) as Label
	var search_edit = _instance.find_child("ToolSearchEdit", true, false) as LineEdit
	var tool_preview_panel = _instance.find_child("ToolPreviewPanel", true, false) as PanelContainer
	var tool_preview_title = _instance.find_child("ToolPreviewTitle", true, false) as Label
	var tool_preview_text = _instance.find_child("ToolPreviewText", true, false) as TextEdit
	var tool_tree = _instance.find_child("ToolTree", true, false) as Tree
	var top_shadow = _instance.find_child("TopShadow", true, false) as ColorRect
	var bottom_shadow = _instance.find_child("BottomShadow", true, false) as ColorRect
	if tool_count_label == null or search_edit == null or tool_preview_panel == null or tool_preview_title == null:
		return _failure("Tools tab view binding test could not resolve the preview/header controls from the scene.")
	if tool_preview_text == null or tool_tree == null or top_shadow == null or bottom_shadow == null:
		return _failure("Tools tab view binding test could not resolve the tree and shadow controls from the scene.")

	service.configure_preview_text(tool_preview_text)
	if tool_preview_text.editable:
		return _failure("View binding service should keep the preview text read-only.")
	if not tool_preview_text.selecting_enabled or not tool_preview_text.context_menu_enabled:
		return _failure("View binding service should enable selection and context menu on the preview text.")

	service.apply_header_state(tool_count_label, search_edit, {
		"tool_count_text": "Enabled 2/3",
		"search_placeholder_text": "Search tools"
	})
	if tool_count_label.text != "Enabled 2/3":
		return _failure("View binding service should apply the tool count text.")
	if search_edit.placeholder_text != "Search tools":
		return _failure("View binding service should apply the search placeholder text.")

	service.configure_tree_shadow(top_shadow, false)
	service.configure_tree_shadow(bottom_shadow, true)
	if top_shadow.material == null or bottom_shadow.material == null:
		return _failure("View binding service should attach a shader material to both tree shadows.")
	if top_shadow.anchor_top != 0.0 or bottom_shadow.anchor_top != 1.0:
		return _failure("View binding service should configure top and bottom shadows differently.")

	var long_preview_text := ""
	for index in range(0, 40):
		long_preview_text += "Line %d\n" % index
	tool_preview_text.custom_minimum_size = Vector2(320, 160)
	tool_preview_text.set_text(long_preview_text)
	await tree.process_frame
	tool_preview_text.set_v_scroll(6)
	service.apply_preview_state(tool_preview_title, tool_preview_text, {
		"title": "Preview",
		"text": long_preview_text,
		"selection_changed": false
	})
	if tool_preview_title.text != "Preview":
		return _failure("View binding service should apply the preview title.")
	if tool_preview_text.get_v_scroll() != 6:
		return _failure("View binding service should preserve preview scroll position when the selection is stable.")

	service.apply_preview_state(tool_preview_title, tool_preview_text, {
		"title": "Preview Changed",
		"text": long_preview_text,
		"selection_changed": true
	})
	if tool_preview_text.get_v_scroll() != 0:
		return _failure("View binding service should reset preview scroll position when the selection changes.")

	service.apply_editor_scale(
		tool_tree,
		tool_preview_panel,
		top_shadow,
		bottom_shadow,
		search_edit,
		1.5,
		0,
		1
	)
	if not is_equal_approx(tool_tree.custom_minimum_size.y, 144.0):
		return _failure("View binding service should scale the tree minimum height.")
	if not is_equal_approx(tool_preview_panel.custom_minimum_size.y, 132.0):
		return _failure("View binding service should scale the preview panel minimum height.")
	if not is_equal_approx(search_edit.custom_minimum_size.y, 45.0):
		return _failure("View binding service should scale the search box minimum height.")
	if not is_equal_approx(bottom_shadow.offset_top, -21.0):
		return _failure("View binding service should scale the bottom shadow offset.")

	return {
		"name": "tools_tab_view_binding_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_tree_min_height": tool_tree.custom_minimum_size.y,
			"preview_panel_min_height": tool_preview_panel.custom_minimum_size.y,
			"search_min_height": search_edit.custom_minimum_size.y,
			"preview_scroll": tool_preview_text.get_v_scroll()
		}
	}


func cleanup_case(tree: SceneTree) -> void:
	if _instance != null and is_instance_valid(_instance):
		var top_shadow = _instance.find_child("TopShadow", true, false) as ColorRect
		var bottom_shadow = _instance.find_child("BottomShadow", true, false) as ColorRect
		if top_shadow != null:
			top_shadow.material = null
		if bottom_shadow != null:
			bottom_shadow.material = null
		_instance.queue_free()
	_instance = null
	await tree.process_frame
	await tree.process_frame


func _failure(message: String) -> Dictionary:
	return {
		"name": "tools_tab_view_binding_service_contracts",
		"success": false,
		"error": message
	}
