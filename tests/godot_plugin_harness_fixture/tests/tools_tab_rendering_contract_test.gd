extends RefCounted

# {"name": "tools_tab_rendering_contracts"}

const ToolsTabScene = preload("res://addons/godot_dotnet_mcp/ui/tools_tab.tscn")
const SystemTreeCatalog = preload("res://addons/godot_dotnet_mcp/plugin/runtime/system_tree_catalog.gd")
const ToolPresentationService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_presentation_service.gd")

var _instance: VBoxContainer = null


class FakeLocalization extends RefCounted:
	var _texts := {
		"tools_enabled": "Enabled %d/%d",
		"tool_search_placeholder": "Search tools",
		"tool_preview_title": "Preview",
		"tool_preview_empty": "Nothing selected",
		"tool_preview_tool": "工具",
		"tool_preview_tool_id": "工具 ID",
		"tool_preview_category": "分类",
		"tool_preview_description": "描述",
		"tools_partial_suffix": "(partial)",
		"cat_system": "System",
		"cat_runtime": "运行时",
		"cat_project": "Project",
		"cat_user": "User",
		"domain_core": "Core",
		"domain_user": "User Tools",
		"tool_action_get_output_name": "读取输出",
		"tool_action_get_errors_name": "读取错误",
		"tool_action_clear_name": "清空",
		"tool_action_ensure_layout_name": "确保目录结构",
		"tool_action_list_capture_cache_name": "列出截图缓存",
		"tool_action_cleanup_capture_cache_name": "清理截图缓存",
		"tool_action_cleanup_legacy_cache_name": "清理旧缓存",
		"tool_system_project_state_name": "Project State",
		"tool_system_editor_state_name": "编辑器状态",
		"tool_system_editor_log_name": "编辑器日志",
		"tool_system_userdata_maintenance_name": "用户数据维护",
		"tool_system_runtime_capture_name": "运行时捕获",
		"tool_runtime_capture_name": "捕获",
		"tool_runtime_capture_desc": "内部运行时捕获：通过已启用的运行时会话，将正在运行游戏的视口捕获为 PNG。",
		"tool_project_info_name": "Project Info",
		"tool_user_sample_tool_name": "Sample Tool"
	}

	func get_text(key: String) -> String:
		return str(_texts.get(key, key))


class RefreshLocalization extends FakeLocalization:
	func _init() -> void:
		_texts = _texts.duplicate(true)
		_texts["tools_enabled"] = "已启用 %d/%d"
		_texts["tool_system_editor_log_name"] = "编辑器日志（刷新）"


func run_case(tree: SceneTree) -> Dictionary:
	_instance = ToolsTabScene.instantiate() as VBoxContainer
	if _instance == null:
		return _failure("Tools tab rendering test could not instantiate the tools tab scene.")
	tree.root.add_child(_instance)
	await tree.process_frame

	var tools_by_category := _build_tools_by_category()
	var presentation := ToolPresentationService.build_tool_presentation(_build_exposed_tools(tools_by_category), tools_by_category)
	var base_model := {
		"localization": FakeLocalization.new(),
		"current_language": "en",
		"editor_scale": 1.0,
		"settings": {
			"disabled_tools": [],
			"collapsed_nodes": {}
		},
		"tools_by_category": tools_by_category,
		"toolTree": presentation.get("toolTree", []),
		"toolGroups": presentation.get("toolGroups", []),
		"tool_presentation": presentation,
		"tool_load_errors": []
	}
	_instance.apply_model(base_model)
	await tree.process_frame

	var tool_count_label = _instance.get_node("HeaderCard/HeaderMargin/HeaderContent/ToolCountLabel") as Label
	var expected_visible_tool_count := SystemTreeCatalog.SYSTEM_TOOL_ATOMIC_CHILDREN.size() + 1
	if tool_count_label == null or tool_count_label.text != "Enabled %d/%d" % [expected_visible_tool_count, expected_visible_tool_count]:
		return _failure("Tools tab should count the current system and user roots exactly once.")

	var tool_tree = _instance.get_node("ContentSplit/TopPane/ToolListOuterMargin/ToolListPanel/ToolListOverlay/ToolListMargin/ToolTree") as Tree
	if tool_tree == null:
		return _failure("Tools tab rendering test could not resolve the tree control.")
	var root = tool_tree.get_root()
	if root == null:
		return _failure("Tools tab should create a root tree item when applying the model.")

	var core_domain = _find_child_by_metadata(root, "domain", "core")
	var user_domain = _find_child_by_metadata(root, "domain", "user")
	if core_domain == null or user_domain == null:
		return _failure("Tools tab should render presentation domain roots.")
	var context_local_position_value: Variant = _get_item_local_center(tool_tree, core_domain)
	if context_local_position_value == null:
		return _failure("Tools tab rendering test could not resolve a local right-click position for the context menu contract.")
	var context_local_position := context_local_position_value as Vector2
	var expected_context_position := tool_tree.get_screen_transform() * context_local_position
	var actual_context_position: Variant = _instance.call("_get_tree_context_menu_screen_position", context_local_position)
	if not (actual_context_position is Vector2) or (actual_context_position as Vector2).distance_to(expected_context_position) > 2.0:
		return _failure("Tools tab context menu position should be transformed through ToolTree.get_screen_transform().")
	var popup_rect: Variant = _instance.call("_show_tree_context_menu", user_domain, expected_context_position)
	if not (popup_rect is Rect2i) or (popup_rect as Rect2i).position != Vector2i(int(expected_context_position.x), int(expected_context_position.y)):
		return _failure("Tools tab context PopupMenu should pass the tested screen coordinate helper result into popup(Rect2i).")
	var initial_popup_menu := _find_context_popup(_instance)
	if initial_popup_menu == null:
		return _failure("Tools tab should create a context popup for right-clicked tree items.")
	initial_popup_menu.hide()
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	right_click.position = context_local_position
	_instance.call("_on_tree_gui_input", right_click)
	await tree.process_frame
	var event_popup_menu := _find_context_popup(_instance)
	if event_popup_menu == null or str(_instance.call("_get_context_menu_english_id")) != "core":
		return _failure("Tools tab real right-click path should open the context PopupMenu for the hit TreeItem.")
	await tree.process_frame
	var popup_nodes := _collect_context_popups(_instance)
	if popup_nodes.size() != 1:
		return _failure("Tools tab should keep every Dock-created PopupMenu/PopupPanel covered by this coordinate contract.")
	var popup_menu := _find_context_popup(_instance)
	if popup_menu == null:
		return _failure("Tools tab should create a context popup for right-clicked tree items.")
	popup_menu.hide()
	var system_category = _find_child_by_metadata(core_domain, "category", "system")
	var user_category = _find_child_by_metadata(user_domain, "category", "user")
	if system_category == null or user_category == null:
		return _failure("Tools tab should render presentation category nodes.")

	var editor_state_tool = _find_child_by_metadata(system_category, "tool", "system_editor_state")
	var system_tool = _find_child_by_metadata(system_category, "tool", "system_project_state")
	var runtime_control_tool = _find_child_by_metadata(system_category, "tool", "system_runtime_control")
	var runtime_capture_tool = _find_child_by_metadata(system_category, "tool", "system_runtime_capture")
	var runtime_input_tool = _find_child_by_metadata(system_category, "tool", "system_runtime_input")
	var runtime_step_tool = _find_child_by_metadata(system_category, "tool", "system_runtime_step")
	var editor_log_tool = _find_child_by_metadata(system_category, "tool", "system_editor_log")
	var userdata_tool = _find_child_by_metadata(system_category, "tool", "system_userdata_maintenance")
	var user_tool = _find_child_by_metadata(user_category, "tool", "user_sample_tool")
	if editor_state_tool == null or system_tool == null or runtime_control_tool == null or runtime_capture_tool == null or runtime_input_tool == null or runtime_step_tool == null or editor_log_tool == null or userdata_tool == null or user_tool == null:
		return _failure("Tools tab should render tool rows for every visible category.")
	var user_metadata = user_tool.get_metadata(0)
	if not (user_metadata is Dictionary) or str((user_metadata as Dictionary).get("script_path", "")) != "res://addons/godot_dotnet_mcp/custom_tools/sample_tool.gd":
		return _failure("Tools tab should preserve user tool script_path metadata when rendering presentation nodes.")
	if editor_state_tool.get_text(0) != "编辑器状态" or editor_log_tool.get_text(0) != "编辑器日志" or userdata_tool.get_text(0) != "用户数据维护":
		return _failure("Tools tab should localize newly added system tool rows.")
	var runtime_capture_atomic = _find_child_by_metadata(runtime_capture_tool, "atomic", "runtime_capture")
	if runtime_capture_tool.get_text(0) != "运行时捕获" or runtime_capture_atomic == null or runtime_capture_atomic.get_text(0) != "捕获":
		return _failure("Tools tab should localize runtime atomic tool rows.")
	_instance.call("_apply_selection_metadata", runtime_capture_atomic.get_metadata(0))
	await tree.process_frame
	var preview_text = _instance.get_node("ContentSplit/BottomPane/PreviewOuterMargin/ToolPreviewPanel/ToolPreviewMargin/ToolPreviewContent/ToolPreviewText") as TextEdit
	if preview_text == null:
		return _failure("Tools tab rendering test could not resolve the preview text control.")
	if not preview_text.text.contains("工具: 捕获") or not preview_text.text.contains("分类: 运行时") or not preview_text.text.contains("内部运行时捕获"):
		return _failure("Tools tab should localize runtime atomic preview text.")
	if preview_text.text.contains("RUNTIME CAPTURE ATOMIC"):
		return _failure("Tools tab should not fall back to the runtime atomic English description.")

	var atomic_tool = _find_child_by_metadata(system_tool, "atomic", "project_info")
	if atomic_tool == null:
		return _failure("Tools tab should keep the atomic child chain for system tools after tree rendering refactor.")
	var editor_log_action = _find_child_by_metadata(editor_log_tool, "action", "system_editor_log.get_output")
	var userdata_action = _find_child_by_metadata(userdata_tool, "action", "system_userdata_maintenance.ensure_layout")
	if editor_log_action == null or userdata_action == null:
		return _failure("Tools tab should render high-level system tool action children.")
	if editor_log_action.get_text(0) != "读取输出" or userdata_action.get_text(0) != "确保目录结构":
		return _failure("Tools tab should localize high-level system tool action children.")
	var catalog_error := _assert_system_catalog_rendered(system_category)
	if not catalog_error.is_empty():
		return _failure(catalog_error)
	var refreshed_model := base_model.duplicate(true)
	refreshed_model["localization"] = RefreshLocalization.new()
	refreshed_model["current_language"] = "zh_CN"
	_instance.apply_model(refreshed_model)
	await tree.process_frame
	await tree.process_frame
	if tool_count_label.text != "已启用 %d/%d" % [expected_visible_tool_count, expected_visible_tool_count]:
		return _failure("Tools tab should refresh localized header copy when language changes.")
	var refreshed_root = tool_tree.get_root()
	var refreshed_core_domain = _find_child_by_metadata(refreshed_root, "domain", "core")
	var refreshed_system_category = _find_child_by_metadata(refreshed_core_domain, "category", "system")
	var refreshed_editor_log_tool = _find_child_by_metadata(refreshed_system_category, "tool", "system_editor_log")
	if refreshed_editor_log_tool == null or refreshed_editor_log_tool.get_text(0) != "编辑器日志（刷新）":
		return _failure("Tools tab should rebuild tree item text when the active language changes.")

	return {
		"name": "tools_tab_rendering_contracts",
		"success": true,
		"error": "",
		"details": {
			"top_level_domain_count": root.get_child_count(),
			"system_tool_count": system_category.get_child_count(),
			"user_tool_count": user_category.get_child_count(),
			"catalog_tool_count": SystemTreeCatalog.SYSTEM_TOOL_ATOMIC_CHILDREN.size()
		}
	}


func _build_exposed_tools(tools_by_category: Dictionary) -> Array:
	var exposed: Array = []
	for tool_def in tools_by_category.get("system", []):
		if not (tool_def is Dictionary):
			continue
		var tool := (tool_def as Dictionary).duplicate(true)
		tool["name"] = "system_%s" % str(tool.get("name", ""))
		tool["category"] = "system"
		exposed.append(tool)
	return exposed


func _build_tools_by_category() -> Dictionary:
	var tools_by_category := {
		"system": [],
		"user": [
			{
				"name": "sample_tool",
				"description": "Sample user tool",
				"source": "user_tool",
				"script_path": "res://addons/godot_dotnet_mcp/custom_tools/sample_tool.gd"
			}
		]
	}
	var system_tools := SystemTreeCatalog.SYSTEM_TOOL_ATOMIC_CHILDREN.keys()
	system_tools.sort()
	for full_name in system_tools:
		_add_tool_def(tools_by_category, str(full_name), _system_actions_for(str(full_name)))
		for entry in SystemTreeCatalog.SYSTEM_TOOL_ATOMIC_CHILDREN.get(full_name, []):
			var atomic_full_name := ""
			if entry is Dictionary:
				atomic_full_name = str(entry.get("tool", ""))
			else:
				atomic_full_name = str(entry)
			_add_tool_def(tools_by_category, atomic_full_name)
	return tools_by_category


func _add_tool_def(tools_by_category: Dictionary, full_name: String, actions: Array = []) -> void:
	if full_name.is_empty():
		return
	var parts := _split_full_name(full_name)
	var category := str(parts.get("category", ""))
	var tool_name := str(parts.get("tool", ""))
	if category.is_empty() or tool_name.is_empty():
		return
	if not tools_by_category.has(category):
		tools_by_category[category] = []
	for existing in tools_by_category[category]:
		if str(existing.get("name", "")) == tool_name:
			return
	var tool_def := {
		"name": tool_name,
		"description": "Contract fixture for %s" % full_name
	}
	if not actions.is_empty():
		tool_def["inputSchema"] = {
			"type": "object",
			"properties": {
				"action": {"type": "string", "enum": actions}
			}
		}
	tools_by_category[category].append(tool_def)


func _split_full_name(full_name: String) -> Dictionary:
	var categories := ["plugin_developer", "plugin_evolution", "plugin_runtime", "filesystem", "animation", "navigation", "material", "resource", "particle", "geometry", "lighting", "tilemap", "project", "editor", "runtime", "system", "script", "signal", "shader", "debug", "scene", "group", "audio", "node", "user", "ui"]
	for category in categories:
		if full_name.begins_with("%s_" % category):
			return {"category": category, "tool": full_name.trim_prefix("%s_" % category)}
	return {}


func _system_actions_for(full_name: String) -> Array:
	match full_name:
		"system_editor_log":
			return ["get_output", "get_errors", "clear"]
		"system_userdata_maintenance":
			return ["ensure_layout", "list_capture_cache", "cleanup_capture_cache", "cleanup_legacy_cache"]
		"system_runtime_control":
			return ["status", "enable", "disable"]
		"system_editor_control":
			return ["set_main_screen", "capture_editor", "list_controls", "list_dock_tabs", "activate_dock_tab", "activate_ui", "get_control", "capture_control", "focus_control", "activate_control", "click_control", "right_click_control", "set_control_text", "list_popups", "press_popup_button", "set_popup_text", "close_popup"]
		"system_project_configure":
			return ["get_settings", "set_setting", "list_autoloads", "add_autoload", "remove_autoload", "list_input_actions"]
	return []


func _assert_system_catalog_rendered(system_category: TreeItem) -> String:
	for system_full_name in SystemTreeCatalog.SYSTEM_TOOL_ATOMIC_CHILDREN.keys():
		var system_tool := _find_child_by_metadata(system_category, "tool", str(system_full_name))
		if system_tool == null:
			return "Tools tab should render high-level system tool: %s" % system_full_name
		for action in _system_actions_for(str(system_full_name)):
			if _find_child_by_metadata(system_tool, "action", "%s.%s" % [system_full_name, action]) == null:
				return "Tools tab should render action child %s.%s" % [system_full_name, action]
		for entry in SystemTreeCatalog.SYSTEM_TOOL_ATOMIC_CHILDREN.get(system_full_name, []):
			var atomic_full_name := ""
			var actions: Array = []
			if entry is Dictionary:
				atomic_full_name = str(entry.get("tool", ""))
				actions = entry.get("actions", [])
			else:
				atomic_full_name = str(entry)
			if atomic_full_name.is_empty():
				continue
			var atomic_item := _find_child_by_metadata(system_tool, "atomic", atomic_full_name)
			if atomic_item == null:
				return "Tools tab should render atomic child %s under %s" % [atomic_full_name, system_full_name]
			for action in actions:
				if _find_child_by_metadata(atomic_item, "action", "%s.%s" % [atomic_full_name, action]) == null:
					return "Tools tab should render atomic action %s.%s under %s" % [atomic_full_name, action, system_full_name]
	return ""


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


func _find_context_popup(root: Node) -> PopupMenu:
	if root is PopupMenu:
		return root as PopupMenu
	for child in root.get_children():
		var found := _find_context_popup(child)
		if found != null:
			return found
	return null


func _get_item_local_center(tree: Tree, item: TreeItem) -> Variant:
	var item_rect := tree.get_item_area_rect(item, 0)
	if item_rect.size.x <= 0.0 or item_rect.size.y <= 0.0:
		return null
	return item_rect.position + item_rect.size * 0.5


func _collect_context_popups(root: Node) -> Array:
	var popups: Array = []
	_collect_context_popups_recursive(root, popups)
	return popups


func _collect_context_popups_recursive(root: Node, popups: Array) -> void:
	for child in root.get_children():
		if child is PopupMenu or child is PopupPanel:
			popups.append(child)
			continue
		_collect_context_popups_recursive(child, popups)


func _failure(message: String) -> Dictionary:
	return {
		"name": "tools_tab_rendering_contracts",
		"success": false,
		"error": message
	}
