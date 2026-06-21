extends RefCounted

# {"name": "tools_tab_rendering_contracts"}

const ToolsTabScene = preload("res://addons/godot_dotnet_mcp/ui/tools_tab.tscn")
const SystemTreeCatalog = preload("res://addons/godot_dotnet_mcp/plugin/runtime/system_tree_catalog.gd")
const ToolPresentationService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_presentation_service.gd")
const ToolTreePresentationService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_tree_presentation_service.gd")
const TEST_ICON_SRC := "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxNiIgaGVpZ2h0PSIxNiI+PHJlY3Qgd2lkdGg9IjE2IiBoZWlnaHQ9IjE2IiBmaWxsPSIjNGFhM2ZmIi8+PC9zdmc+"

var _instance: VBoxContainer = null


class FakeLocalization extends RefCounted:
	var _texts := {
		"tools_enabled": "Enabled %d/%d",
		"tool_search_placeholder": "Search tools",
		"tool_preview_title": "Preview",
		"tool_preview_empty": "Nothing selected",
		"tool_preview_tool": "工具",
		"tool_preview_tool_id": "工具 ID",
		"tool_preview_domain": "Domain",
		"tool_preview_category": "分类",
		"tool_preview_category_count": "%d categories",
		"tool_preview_tool_count": "%d tools",
		"tool_preview_description": "描述",
		"agent_tools_group_project_context": "项目上下文",
		"agent_tools_group_project_context_desc": "项目状态、文件、配置、生命周期、索引、符号搜索和场景依赖。",
		"agent_tools_group_editor_automation": "编辑器自动化",
		"agent_tools_group_editor_automation_desc": "编辑器状态、界面控制、证据截图、检查器和设置对话框工作流。",
		"agent_tools_group_scene_resource": "场景与资源",
		"agent_tools_group_scene_resource_desc": "场景树、场景检查、场景补丁、资源引用和绑定审计。",
		"agent_tools_group_script_csharp_semantics": "脚本语义",
		"agent_tools_group_script_csharp_semantics_desc": "脚本分析、脚本补丁以及 C# 绑定或语义检查。",
		"agent_tools_group_runtime_debugging": "运行时调试",
		"agent_tools_group_runtime_debugging_desc": "运行时控制、运行时步进、运行时诊断和 DAP 调试。",
		"agent_tools_group_plugin_maintenance": "插件维护",
		"agent_tools_group_plugin_maintenance_desc": "插件启用、更新、维护和用户数据清理工作流。",
		"agent_tools_group_user_tools": "用户工具",
		"agent_tools_group_user_tools_desc": "通过 MCP surface 暴露的项目本地自定义用户工具。",
		"agent_tools_group_other_agent_tools": "其他 Agent 工具",
		"agent_tools_group_other_agent_tools_desc": "尚未归入规范分组的其他公开工具。",
		"tool_architecture_actions": "Actions",
		"tool_architecture_implemented_by": "Implemented by",
		"tool_action": "工具动作",
		"tools_partial_suffix": "(partial)",
		"cat_system": "System",
		"cat_runtime": "运行时",
		"cat_project": "Project",
		"cat_user": "User",
		"cat_plugin_runtime": "插件运行时",
		"domain_core": "Core",
		"domain_plugin": "Plugin",
		"domain_user": "User Tools",
		"tool_action_get_output_name": "读取输出",
		"tool_action_get_errors_name": "读取错误",
		"tool_action_clear_name": "清空",
		"tool_action_clear_output_name": "清空输出",
		"tool_action_status_name": "读取状态",
		"tool_action_capture_name": "截图",
		"tool_action_capture_popup_name": "截图弹窗",
		"tool_action_ensure_layout_name": "确保目录结构",
		"tool_action_list_capture_cache_name": "列出截图缓存",
		"tool_action_cleanup_capture_cache_name": "清理截图缓存",
		"tool_action_cleanup_legacy_cache_name": "清理旧缓存",
		"tool_action_set_settings_name": "写入设置",
		"tool_action_run_task_name": "运行任务",
		"tool_action_run_task_desc": "编排可信的设置行定位、读取、可选写入、验证与截图取证任务。",
		"tool_action_initialize_name": "初始化",
		"tool_action_launch_name": "启动",
		"tool_action_attach_name": "附加",
		"tool_action_configuration_done_name": "配置完成",
		"tool_action_custom_node_label": "节点自带动作名",
		"tool_action_custom_node_desc": "节点自带动作描述。",
		"tool_action_disconnect_name": "断开连接",
		"tool_action_terminate_name": "终止",
		"tool_action_threads_name": "读取线程",
		"tool_action_set_breakpoint_name": "设置断点",
		"tool_action_remove_breakpoint_name": "移除断点",
		"tool_action_list_breakpoints_name": "列出断点",
		"tool_action_pause_name": "暂停",
		"tool_action_continue_name": "继续",
		"tool_action_step_over_name": "单步跳过",
		"tool_action_stack_trace_name": "调用栈",
		"tool_action_output_name": "输出事件",
		"tool_param_system_dap_debugger_adapter_args_desc": "发送给调试适配器的启动或附加参数。",
		"tool_system_project_state_name": "Project State",
		"tool_system_dap_debugger_name": "DAP 调试器",
		"tool_system_editor_state_name": "编辑器状态",
		"tool_system_editor_evidence_name": "编辑器取证",
		"tool_system_editor_evidence_desc": "捕获自描述的编辑器视觉证据。",
		"tool_system_userdata_maintenance_name": "用户数据维护",
		"tool_system_runtime_step_name": "运行时步进",
		"tool_runtime_step_name": "步进",
		"tool_runtime_step_desc": "内部运行时步进：应用可选运行时输入、等待指定帧数，并按需捕获一帧画面。",
		"tool_runtime_capture_name": "捕获",
		"tool_runtime_capture_desc": "内部运行时捕获：通过已启用的运行时会话，将正在运行游戏的视口捕获为 PNG。",
		"tool_plugin_runtime_state_name": "插件状态",
		"tool_project_info_name": "Project Info",
		"tool_user_sample_tool_name": "Sample Tool",
		"tool_ctx_copy_input_schema_json": "Copy Input Schema JSON",
		"tool_ctx_copy_output_schema_json": "Copy Output Schema JSON",
		"tool_preview_output": "Output",
		"tool_preview_no_output": "No output schema"
	}

	func get_text(key: String) -> String:
		return str(_texts.get(key, key))


class RefreshLocalization extends FakeLocalization:
	func _init() -> void:
		_texts = _texts.duplicate(true)
		_texts["tools_enabled"] = "已启用 %d/%d"
		_texts["tool_system_editor_evidence_name"] = "编辑器取证（刷新）"


func run_case(tree: SceneTree) -> Dictionary:
	_instance = ToolsTabScene.instantiate() as VBoxContainer
	if _instance == null:
		return _failure("Tools tab rendering test could not instantiate the tools tab scene.")
	var ui_source_guard := _assert_tools_tab_prefers_shared_presentation_metadata()
	if not ui_source_guard.is_empty():
		return _failure(ui_source_guard)
	var signature_guard := _assert_tools_tab_uses_lightweight_tree_signatures()
	if not signature_guard.is_empty():
		return _failure(signature_guard)
	tree.root.add_child(_instance)
	await tree.process_frame

	var tools_by_category := _build_tools_by_category()
	var presentation := ToolPresentationService.build_tool_presentation(_build_exposed_tools(tools_by_category), tools_by_category)
	var agent_presentation := ToolTreePresentationService.build_agent_tool_tree(_build_exposed_tools(tools_by_category), [], tools_by_category)
	_override_presentation_action_metadata(presentation, "system_dap_debugger.configuration_done", "tool_action_custom_node_label", "tool_action_custom_node_desc")
	_poison_raw_tool_definitions_after_presentation(tools_by_category)
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
	var agent_model := base_model.duplicate(true)
	agent_model["active_tool_presentation"] = agent_presentation
	agent_model["agent_tool_presentation"] = agent_presentation
	agent_model["toolTree"] = agent_presentation.get("toolTree", [])
	agent_model["toolGroups"] = agent_presentation.get("toolGroups", [])
	_instance.apply_model(agent_model)
	await tree.process_frame

	var tool_count_label = _instance.get_node("HeaderCard/HeaderMargin/HeaderContent/ToolCountLabel") as Label
	if tool_count_label == null or tool_count_label.text != "Enabled 26/26":
		return _failure("Tools tab Agent Tools view should count only canonical public tools and user tools.")
	if _instance.has_node("HeaderCard/HeaderMargin/HeaderContent/ViewModeRow"):
		return _failure("Tools tab should remove the obsolete Agent/Internal/Diagnostics view mode row.")
	_instance.size = Vector2(320, 640)
	_instance.call("_apply_responsive_layout")
	await tree.process_frame
	var tool_tree = _instance.get_node("ContentSplit/TopPane/ToolListOuterMargin/ToolListPanel/ToolListOverlay/ToolListMargin/ToolTree") as Tree
	if tool_tree == null:
		return _failure("Tools tab rendering test could not resolve the tree control.")
	var root = tool_tree.get_root()
	if root == null:
		return _failure("Tools tab should create a root tree item when applying the Agent Tools model.")
	var project_group := _find_child_by_metadata(root, "category", "project_context")
	var runtime_group := _find_child_by_metadata(root, "category", "runtime_debugging")
	var plugin_group := _find_child_by_metadata(root, "category", "plugin_maintenance")
	var user_group := _find_child_by_metadata(root, "category", "user_tools")
	if project_group == null or runtime_group == null or plugin_group == null or user_group == null:
		return _failure("Tools tab should default to Agent Tools groups instead of internal domain roots.")
	if str(project_group.get_text(0)).contains("Project Context") or str(runtime_group.get_text(0)).contains("Runtime Debugging"):
		return _failure("Tools tab Agent Tools group labels should render localized text instead of raw English group labels.")
	if not str(project_group.get_text(0)).contains("项目上下文") or not str(runtime_group.get_text(0)).contains("运行时调试"):
		return _failure("Tools tab Agent Tools group labels should use localized group names from labelKey metadata.")
	if _find_child_by_metadata(root, "domain", "core") != null or _find_child_by_metadata(root, "category", "plugin_runtime") != null:
		return _failure("Tools tab Agent Tools view should not mix internal domain/category roots into the default tree.")
	if _find_child_by_metadata(runtime_group, "tool", "system_dap_debugger") == null or _find_child_by_metadata(runtime_group, "tool", "system_runtime_control") == null:
		return _failure("Tools tab Agent Tools view should group canonical runtime/debugging tools.")
	if _find_child_by_metadata(root, "tool", "runtime_step") != null or _find_child_by_metadata(root, "tool", "plugin_runtime_state") != null:
		return _failure("Tools tab Agent Tools view should hide lower-level executor tools from the default call surface.")
	var agent_runtime_control := _find_child_by_metadata(runtime_group, "tool", "system_runtime_control")
	var runtime_architecture := _find_child_by_metadata(agent_runtime_control, "category", "system_runtime_control:implemented_by") if agent_runtime_control != null else null
	var runtime_atomic := _find_child_by_metadata(runtime_architecture, "atomic", "runtime_control") if runtime_architecture != null else null
	if runtime_architecture == null or runtime_atomic == null:
		return _failure("Tools tab Agent Tools view should nest runtime executor architecture under the public tool row.")
	if runtime_atomic.is_editable(1):
		return _failure("Tools tab Agent Tools architecture rows should be read-only.")
	var agent_project_state := _find_child_by_metadata(project_group, "tool", "system_project_state")
	if agent_project_state == null:
		return _failure("Tools tab Agent Tools view should render canonical public project tools.")
	_instance.call("_apply_selection_metadata", agent_project_state.get_metadata(0))
	await tree.process_frame
	var preview_text = _instance.get_node("ContentSplit/BottomPane/PreviewOuterMargin/ToolPreviewPanel/ToolPreviewMargin/ToolPreviewContent/ToolPreviewText") as TextEdit
	if preview_text == null or not preview_text.text.contains("工具 ID: system_project_state"):
		return _failure("Tools tab Agent Tools preview should keep tool metadata and schema preview behavior.")
	_instance.call("_apply_selection_metadata", project_group.get_metadata(0))
	await tree.process_frame
	if preview_text.text.contains("agent_tools_group_project_context"):
		return _failure("Tools tab Agent Tools group labels should fall back to human-readable text when locale keys are not present.")
	if not preview_text.text.contains("7 tools") or not preview_text.text.contains("Project State"):
		return _failure("Tools tab Agent Tools group preview should count and list public_tool children.")

	_instance.apply_model(base_model)
	await tree.process_frame

	var expected_visible_tool_count := SystemTreeCatalog.SYSTEM_TOOL_ATOMIC_CHILDREN.size() + 2
	if tool_count_label == null or tool_count_label.text != "Enabled %d/%d" % [expected_visible_tool_count, expected_visible_tool_count]:
		return _failure("Tools tab should count the current system, plugin, and user presentation tools exactly once.")

	if tool_tree == null:
		return _failure("Tools tab rendering test could not resolve the tree control.")
	root = tool_tree.get_root()
	if root == null:
		return _failure("Tools tab should create a root tree item when applying the model.")

	var core_domain = _find_child_by_metadata(root, "domain", "core")
	var plugin_domain = _find_child_by_metadata(root, "domain", "plugin")
	var user_domain = _find_child_by_metadata(root, "domain", "user")
	if core_domain == null or plugin_domain == null or user_domain == null:
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
	var plugin_runtime_category = _find_child_by_metadata(plugin_domain, "category", "plugin_runtime")
	var user_category = _find_child_by_metadata(user_domain, "category", "user")
	if system_category == null or plugin_runtime_category == null or user_category == null:
		return _failure("Tools tab should render presentation category nodes.")
	var initial_top_level_domain_count := root.get_child_count()
	var initial_system_tool_count := system_category.get_child_count()
	var initial_user_tool_count := user_category.get_child_count()

	var editor_state_tool = _find_child_by_metadata(system_category, "tool", "system_editor_state")
	var system_tool = _find_child_by_metadata(system_category, "tool", "system_project_state")
	var dap_tool = _find_child_by_metadata(system_category, "tool", "system_dap_debugger")
	var runtime_control_tool = _find_child_by_metadata(system_category, "tool", "system_runtime_control")
	var runtime_step_tool = _find_child_by_metadata(system_category, "tool", "system_runtime_step")
	var project_lifecycle_tool = _find_child_by_metadata(system_category, "tool", "system_project_lifecycle")
	var inspector_tool = _find_child_by_metadata(system_category, "tool", "system_inspector")
	var editor_evidence_tool = _find_child_by_metadata(system_category, "tool", "system_editor_evidence")
	var userdata_tool = _find_child_by_metadata(system_category, "tool", "system_userdata_maintenance")
	var plugin_runtime_state_tool = _find_child_by_metadata(plugin_runtime_category, "tool", "plugin_runtime_state")
	var user_tool = _find_child_by_metadata(user_category, "tool", "user_sample_tool")
	if editor_state_tool == null or system_tool == null or dap_tool == null or runtime_control_tool == null or runtime_step_tool == null or project_lifecycle_tool == null or inspector_tool == null or editor_evidence_tool == null or userdata_tool == null or plugin_runtime_state_tool == null or user_tool == null:
		return _failure("Tools tab should render tool rows for every visible category.")
	for removed_tool_name in ["system_project_run", "system_project_stop"]:
		if _find_child_by_metadata(system_category, "tool", removed_tool_name) != null:
			return _failure("Tools tab should not render removed project lifecycle entry '%s'." % removed_tool_name)
	for removed_tool_name in ["system_plugin_reload", "system_plugin_update", "system_tool_activity", "system_scene_validate", "system_scene_analyze", "system_editor_log"]:
		if _find_child_by_metadata(system_category, "tool", removed_tool_name) != null:
			return _failure("Tools tab should not render removed public tool %s." % removed_tool_name)
	if _find_child_by_metadata(project_lifecycle_tool, "action", "system_project_lifecycle.start") == null or _find_child_by_metadata(project_lifecycle_tool, "action", "system_project_lifecycle.stop") == null:
		return _failure("Tools tab should render start and stop actions under system_project_lifecycle.")
	var user_metadata = user_tool.get_metadata(0)
	if not (user_metadata is Dictionary) or str((user_metadata as Dictionary).get("script_path", "")) != "res://addons/godot_dotnet_mcp/custom_tools/sample_tool.gd":
		return _failure("Tools tab should preserve user tool script_path metadata when rendering presentation nodes.")
	if user_tool.get_icon(0) != null:
		return _failure("Tools tab should reject oversized protocol icon metadata before rendering user tool rows.")
	if user_metadata is Dictionary and not str((user_metadata as Dictionary).get("mcp_icon_src", "")).is_empty():
		return _failure("Tools tab should not mark oversized protocol icon metadata as rendered.")
	if editor_state_tool.get_text(0) != "编辑器状态" or editor_evidence_tool.get_text(0) != "编辑器取证" or userdata_tool.get_text(0) != "用户数据维护":
		return _failure("Tools tab should localize newly added system tool rows.")
	if plugin_runtime_state_tool.get_text(0) != "插件状态":
		return _failure("Tools tab should localize plugin runtime tool rows.")
	var runtime_step_atomic = _find_child_by_metadata(runtime_step_tool, "atomic", "runtime_step")
	var runtime_capture_atomic = _find_child_by_metadata(runtime_step_tool, "atomic", "runtime_capture")
	if runtime_step_tool.get_text(0) != "运行时步进" or runtime_step_atomic == null or runtime_step_atomic.get_text(0) != "步进" or runtime_capture_atomic == null or runtime_capture_atomic.get_text(0) != "捕获":
		return _failure("Tools tab should localize runtime atomic tool rows.")
	_instance.call("_apply_selection_metadata", runtime_step_atomic.get_metadata(0))
	await tree.process_frame
	preview_text = _instance.get_node("ContentSplit/BottomPane/PreviewOuterMargin/ToolPreviewPanel/ToolPreviewMargin/ToolPreviewContent/ToolPreviewText") as TextEdit
	if preview_text == null:
		return _failure("Tools tab rendering test could not resolve the preview text control.")
	if not preview_text.text.contains("工具: 步进") or not preview_text.text.contains("分类: 运行时") or not preview_text.text.contains("内部运行时步进"):
		return _failure("Tools tab should localize runtime atomic preview text.")
	if preview_text.text.contains("RUNTIME STEP ATOMIC"):
		return _failure("Tools tab should not fall back to the runtime atomic English description.")

	var bottom_pane = _instance.get_node("ContentSplit/BottomPane") as VBoxContainer
	if bottom_pane == null or bottom_pane.size_flags_vertical != Control.SIZE_EXPAND_FILL:
		return _failure("Tools tab bottom preview pane should expand and fill the available vertical split space.")

	var atomic_tool = _find_child_by_metadata(system_tool, "atomic", "project_info")
	if atomic_tool == null:
		return _failure("Tools tab should keep the atomic child chain for system tools after tree rendering refactor.")
	var editor_control_clear_action = _find_child_by_metadata(_find_child_by_metadata(system_category, "tool", "system_editor_control"), "action", "system_editor_control.clear_output")
	var editor_evidence_status_action = _find_child_by_metadata(editor_evidence_tool, "action", "system_editor_evidence.status")
	var editor_evidence_capture_action = _find_child_by_metadata(editor_evidence_tool, "action", "system_editor_evidence.capture")
	var userdata_action = _find_child_by_metadata(userdata_tool, "action", "system_userdata_maintenance.ensure_layout")
	if editor_control_clear_action == null or editor_evidence_status_action == null or editor_evidence_capture_action == null or userdata_action == null:
		return _failure("Tools tab should render high-level system tool action children.")
	if editor_control_clear_action.get_text(0) != "清空输出" or editor_evidence_status_action.get_text(0) != "读取状态" or editor_evidence_capture_action.get_text(0) != "截图" or userdata_action.get_text(0) != "确保目录结构":
		return _failure("Tools tab should localize high-level system tool action children.")
	var settings_dialog_tool := _find_child_by_metadata(system_category, "tool", "system_settings_dialog")
	var run_task_action := _find_child_by_metadata(settings_dialog_tool, "action", "system_settings_dialog.run_task") if settings_dialog_tool != null else null
	if run_task_action == null or run_task_action.get_text(0) != "运行任务":
		return _failure("Tools tab should render the localized run_task action for system_settings_dialog.")
	var settings_popup_atomic := _find_child_by_metadata(settings_dialog_tool, "atomic", "editor_popup") if settings_dialog_tool != null else null
	var settings_popup_capture_action := _find_child_by_metadata(settings_popup_atomic, "action", "editor_popup.capture_popup") if settings_popup_atomic != null else null
	if settings_popup_capture_action == null:
		return _failure("Tools tab should expose editor_popup.capture_popup under system_settings_dialog for surface evidence workflows.")
	var dap_configuration_done_action = _find_child_by_metadata(dap_tool, "action", "system_dap_debugger.configuration_done")
	if dap_configuration_done_action == null or dap_configuration_done_action.get_text(0) != "节点自带动作名":
		return _failure("Tools tab should render action names from shared presentation node metadata instead of deriving action keys in the UI.")
	_instance.call("_apply_selection_metadata", dap_tool.get_metadata(0))
	await tree.process_frame
	if not preview_text.text.contains("adapter_args | object | 发送给调试适配器的启动或附加参数。"):
		return _failure("Tools tab should localize DAP parameter descriptions in the selected tool preview.")
	if preview_text.text.contains("Launch/attach arguments sent to the adapter"):
		return _failure("Tools tab should not leak raw English DAP schema parameter descriptions in localized previews.")
	if not preview_text.text.contains("fallback_note | string | Fallback-only schema description"):
		return _failure("Tools tab should keep schema descriptions as fallback when no localized parameter description exists.")
	if not preview_text.text.contains("Output") or not preview_text.text.contains("structuredContent | object") or not preview_text.text.contains("Contract structured output"):
		return _failure("Tools tab preview should render outputSchema summaries from shared presentation metadata.")
	if preview_text.text.contains("RAW SHOULD NOT APPEAR") or preview_text.text.contains("raw_only_param"):
		return _failure("Tools tab preview should consume shared presentation metadata instead of poisoned raw tool definitions.")
	var copied_schema_metadata: Dictionary = _instance.call("_get_tool_metadata", "system_dap_debugger", dap_tool.get_metadata(0))
	var copied_schema_json = copied_schema_metadata.get("inputSchema", {})
	if not (copied_schema_json is Dictionary):
		return _failure("Tools tab schema-copy metadata should expose an inputSchema object.")
	var copied_properties = (copied_schema_json as Dictionary).get("properties", {})
	if not (copied_properties is Dictionary) or not (copied_properties as Dictionary).has("adapter_args"):
		return _failure("Tools tab schema-copy metadata should resolve shared presentation inputSchema.")
	if (copied_properties as Dictionary).has("raw_only_param") or str((copied_schema_json as Dictionary).get("$schema", "")) != "https://json-schema.org/draft/2020-12/schema":
		return _failure("Tools tab schema-copy metadata should not use poisoned raw schemas.")
	var copied_output_schema_json = copied_schema_metadata.get("outputSchema", {})
	if not (copied_output_schema_json is Dictionary):
		return _failure("Tools tab schema-copy metadata should expose an outputSchema object.")
	var copied_output_properties = (copied_output_schema_json as Dictionary).get("properties", {})
	if not (copied_output_properties is Dictionary) or not (copied_output_properties as Dictionary).has("structuredContent"):
		return _failure("Tools tab output-schema metadata should resolve shared presentation outputSchema.")
	if (copied_output_properties as Dictionary).has("raw_output_only") or str((copied_output_schema_json as Dictionary).get("$schema", "")) != "https://json-schema.org/draft/2020-12/schema":
		return _failure("Tools tab output-schema metadata should not use poisoned raw schemas.")
	var signature_before_poison_update: String = _instance.call("_build_tree_signature", base_model)
	_poison_all_raw_tool_definitions(tools_by_category)
	var signature_after_poison_update: String = _instance.call("_build_tree_signature", base_model)
	if signature_before_poison_update != signature_after_poison_update:
		return _failure("Tools tab refresh signature should ignore raw tool definition changes when shared presentation metadata exists.")
	var shared_metadata_after_poison: Dictionary = _instance.call("_get_tool_metadata", "system_dap_debugger", dap_tool.get_metadata(0))
	if JSON.stringify(shared_metadata_after_poison).contains("RAW SHOULD NOT APPEAR"):
		return _failure("Tools tab metadata lookup should ignore poisoned raw tool definitions when shared presentation metadata exists.")
	root = tool_tree.get_root()
	core_domain = _find_child_by_metadata(root, "domain", "core")
	system_category = _find_child_by_metadata(core_domain, "category", "system")
	if core_domain == null or system_category == null:
		return _failure("Tools tab should keep current presentation domain/category nodes before preview poisoning assertions.")
	_instance.call("_apply_selection_metadata", {"kind": "domain", "key": "core"})
	await tree.process_frame
	if preview_text.text.contains("RAW SHOULD NOT APPEAR") or not preview_text.text.contains("System"):
		return _failure("Tools tab domain preview should use presentation category children instead of poisoned raw category facts.")
	_instance.call("_apply_selection_metadata", {"kind": "category", "key": "system", "category": "system"})
	await tree.process_frame
	if preview_text.text.contains("RAW SHOULD NOT APPEAR") or preview_text.text.contains("raw_only_param") or not preview_text.text.contains("DAP 调试器"):
		return _failure("Tools tab category preview should list tools from shared presentation metadata instead of poisoned raw tool definitions.")
	if dap_tool.get_icon(0) == null:
		return _failure("Tools tab should render protocol icons from shared presentation metadata on tool rows.")
	var dap_icon_metadata = dap_tool.get_metadata(0)
	if not (dap_icon_metadata is Dictionary) or str((dap_icon_metadata as Dictionary).get("mcp_icon_src", "")) != TEST_ICON_SRC:
		return _failure("Tools tab should preserve rendered protocol icon source metadata for tool row affordances.")
	_instance.call("_show_tree_context_menu", dap_tool, expected_context_position)
	var schema_popup := _find_context_popup(_instance)
	if schema_popup == null:
		return _failure("Tools tab should expose schema context menu actions for selected tools.")
	if _find_popup_item(schema_popup, "Copy Input Schema JSON") < 0 or _find_popup_item(schema_popup, "Copy Output Schema JSON") < 0:
		return _failure("Tools tab context menu should expose separate input and output schema copy actions.")
	schema_popup.hide()
	var search_edit = _instance.get_node("ContentSplit/TopPane/SearchOuterMargin/ToolSearchEdit") as LineEdit
	if search_edit == null:
		return _failure("Tools tab rendering test could not resolve the search edit control.")
	search_edit.text = "no matching tool should render synchronously"
	_instance.call("_on_search_text_changed", search_edit.text)
	if not bool(_instance.get("_search_render_queued")):
		return _failure("Tools tab search should queue tree rendering instead of rebuilding synchronously.")
	var immediate_root = tool_tree.get_root()
	if _find_child_by_metadata(immediate_root, "domain", "core") == null:
		return _failure("Tools tab search should not clear and rebuild the tree during the text-changed callback.")
	search_edit.text = "contract fixture for system_dap_debugger"
	_instance.call("_on_search_text_changed", search_edit.text)
	if not bool(_instance.get("_search_render_queued")):
		return _failure("Tools tab search should keep one queued render for same-frame query bursts.")
	await tree.process_frame
	if bool(_instance.get("_search_render_queued")):
		return _failure("Tools tab search should flush the queued render on the next frame.")
	var searched_root = tool_tree.get_root()
	var searched_core_domain = _find_child_by_metadata(searched_root, "domain", "core")
	var searched_system_category = _find_child_by_metadata(searched_core_domain, "category", "system")
	var searched_dap_tool = _find_child_by_metadata(searched_system_category, "tool", "system_dap_debugger")
	if searched_dap_tool == null:
		return _failure("Tools tab search should match shared presentation metadata descriptions.")
	search_edit.text = ""
	_instance.call("_on_search_text_changed", "")
	await tree.process_frame
	root = tool_tree.get_root()
	core_domain = _find_child_by_metadata(root, "domain", "core")
	system_category = _find_child_by_metadata(core_domain, "category", "system")
	dap_tool = _find_child_by_metadata(system_category, "tool", "system_dap_debugger")
	if dap_tool == null:
		return _failure("Tools tab should restore the DAP row after clearing metadata search.")
	var atomic_dap_tool = _find_child_by_metadata(dap_tool, "atomic", "dap_debugger")
	if atomic_dap_tool == null:
		return _failure("Tools tab should render the DAP atomic tool under the high-level DAP debugger entry.")
	if atomic_dap_tool.get_icon(0) == null:
		return _failure("Tools tab should render protocol icons from shared presentation metadata on atomic rows.")
	var atomic_dap_configuration_done_action = _find_child_by_metadata(atomic_dap_tool, "action", "dap_debugger.configuration_done")
	if atomic_dap_configuration_done_action == null or atomic_dap_configuration_done_action.get_text(0) != "配置完成":
		return _failure("Tools tab should localize DAP atomic action children.")
	_instance.call("_apply_selection_metadata", atomic_dap_tool.get_metadata(0))
	await tree.process_frame
	if not preview_text.text.contains("adapter_args | object | 发送给调试适配器的启动或附加参数。"):
		return _failure("Tools tab should localize DAP atomic parameter descriptions in the selected tool preview.")
	if preview_text.text.contains("Launch/attach arguments sent to the adapter"):
		return _failure("Tools tab should not leak raw English DAP atomic schema parameter descriptions in localized previews.")
	_instance.call("_apply_selection_metadata", atomic_dap_configuration_done_action.get_metadata(0))
	await tree.process_frame
	if not preview_text.text.contains("adapter_args | object | 发送给调试适配器的启动或附加参数。"):
		return _failure("Tools tab should localize DAP atomic action parameter descriptions in the selected action preview.")
	if preview_text.text.contains("Launch/attach arguments sent to the adapter"):
		return _failure("Tools tab should not leak raw English DAP atomic action schema parameter descriptions in localized previews.")
	dap_configuration_done_action = _find_child_by_metadata(dap_tool, "action", "system_dap_debugger.configuration_done")
	if dap_configuration_done_action == null:
		return _failure("Tools tab should keep the DAP debugger action row available after search rebuilds.")
	_instance.call("_apply_selection_metadata", dap_configuration_done_action.get_metadata(0))
	await tree.process_frame
	if not preview_text.text.contains("工具动作: 节点自带动作名") or not preview_text.text.contains("节点自带动作描述。"):
		return _failure("Tools tab action preview should consume label and description keys from shared presentation node metadata.")
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
	var refreshed_editor_evidence_tool = _find_child_by_metadata(refreshed_system_category, "tool", "system_editor_evidence")
	if refreshed_editor_evidence_tool == null or refreshed_editor_evidence_tool.get_text(0) != "编辑器取证（刷新）":
		return _failure("Tools tab should rebuild tree item text when the active language changes.")
	var fallback_model := refreshed_model.duplicate(true)
	fallback_model["toolTree"] = []
	fallback_model["toolGroups"] = []
	fallback_model["tool_presentation"] = {}
	_instance.apply_model(fallback_model)
	await tree.process_frame
	var expected_legacy_tool_count := SystemTreeCatalog.SYSTEM_TOOL_ATOMIC_CHILDREN.size() + 1
	if tool_count_label.text != "已启用 %d/%d" % [expected_legacy_tool_count, expected_legacy_tool_count]:
		return _failure("Tools tab should preserve the legacy header count when the presentation tree is unavailable.")
	var legacy_error: String = await _assert_legacy_fallback_catalog_rendering(tool_tree, preview_text, search_edit)
	if not legacy_error.is_empty():
		return _failure(legacy_error)
	var icon_cache_error := _assert_icon_texture_cache_is_bounded()
	if not icon_cache_error.is_empty():
		return _failure(icon_cache_error)

	return {
		"name": "tools_tab_rendering_contracts",
		"success": true,
		"error": "",
		"details": {
			"top_level_domain_count": initial_top_level_domain_count,
			"system_tool_count": initial_system_tool_count,
			"user_tool_count": initial_user_tool_count,
			"catalog_tool_count": SystemTreeCatalog.SYSTEM_TOOL_ATOMIC_CHILDREN.size()
		}
	}


func _assert_icon_texture_cache_is_bounded() -> String:
	var cache_limit := 64
	for index in range(cache_limit + 8):
		var src := "contract-icon-%03d" % index
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color(1.0, 1.0, 1.0, 1.0))
		var texture := ImageTexture.create_from_image(image)
		_instance.call("_store_icon_texture", src, texture)
	if int(_instance._icon_texture_cache.size()) != cache_limit:
		return "Tools tab protocol icon texture cache should be bounded to MAX_ICON_TEXTURE_CACHE_ENTRIES."
	if _instance._icon_texture_cache.has("contract-icon-000"):
		return "Tools tab protocol icon texture cache should evict least-recently-used entries."
	var retained_key := "contract-icon-%03d" % (cache_limit + 7)
	if not _instance._icon_texture_cache.has(retained_key):
		return "Tools tab protocol icon texture cache should retain recently inserted icons."
	var refreshed_key := "contract-icon-%03d" % (cache_limit - 1)
	_instance.call("_store_icon_texture", refreshed_key, _instance._icon_texture_cache.get(refreshed_key))
	_instance.call("_store_icon_texture", "contract-icon-new", ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8)))
	if not _instance._icon_texture_cache.has(refreshed_key):
		return "Tools tab protocol icon texture cache hits should refresh LRU order."
	return ""


func _build_exposed_tools(tools_by_category: Dictionary) -> Array:
	var exposed: Array = []
	for tool_def in tools_by_category.get("system", []):
		if not (tool_def is Dictionary):
			continue
		var tool := (tool_def as Dictionary).duplicate(true)
		tool["name"] = "system_%s" % str(tool.get("name", ""))
		tool["category"] = "system"
		exposed.append(tool)
	for tool_def in tools_by_category.get("plugin_runtime", []):
		if not (tool_def is Dictionary):
			continue
		var tool := (tool_def as Dictionary).duplicate(true)
		tool["name"] = "plugin_runtime_%s" % str(tool.get("name", ""))
		tool["category"] = "plugin_runtime"
		exposed.append(tool)
	for tool_def in tools_by_category.get("user", []):
		if not (tool_def is Dictionary):
			continue
		var tool := (tool_def as Dictionary).duplicate(true)
		tool["name"] = "user_%s" % str(tool.get("name", ""))
		tool["category"] = "user"
		exposed.append(tool)
	return exposed


func _build_tools_by_category() -> Dictionary:
	var tools_by_category := {
		"plugin_runtime": [
			{
				"name": "state",
				"description": "Contract fixture for plugin runtime state"
			}
		],
		"system": [],
		"user": [
			{
				"name": "sample_tool",
				"description": "Sample user tool",
				"source": "user_tool",
				"script_path": "res://addons/godot_dotnet_mcp/custom_tools/sample_tool.gd",
				"icons": [{"src": _oversized_icon_src(), "mimeType": "image/svg+xml"}]
			}
		]
	}
	var system_tools := SystemTreeCatalog.SYSTEM_TOOL_ATOMIC_CHILDREN.keys()
	system_tools.sort()
	for full_name in system_tools:
		_add_tool_def(tools_by_category, str(full_name), _system_actions_for(str(full_name)))
		for entry in SystemTreeCatalog.SYSTEM_TOOL_ATOMIC_CHILDREN.get(full_name, []):
			var atomic_full_name := ""
			var atomic_actions: Array = []
			if entry is Dictionary:
				atomic_full_name = str(entry.get("tool", ""))
				atomic_actions = entry.get("actions", [])
			else:
				atomic_full_name = str(entry)
			_add_tool_def(tools_by_category, atomic_full_name, atomic_actions)
	return tools_by_category


func _poison_raw_tool_definitions_after_presentation(tools_by_category: Dictionary) -> void:
	for raw_tool in tools_by_category.get("system", []):
		if not (raw_tool is Dictionary):
			continue
		var tool_def := raw_tool as Dictionary
		if str(tool_def.get("name", "")) != "dap_debugger":
			continue
		tool_def["description"] = "RAW SHOULD NOT APPEAR"
		tool_def["inputSchema"] = {
			"type": "object",
			"properties": {
				"action": {"type": "string", "enum": ["status"]},
				"raw_only_param": {"type": "string", "description": "RAW SHOULD NOT APPEAR"}
			}
		}
		tool_def["outputSchema"] = {
			"type": "object",
			"properties": {
				"raw_output_only": {"type": "string", "description": "RAW SHOULD NOT APPEAR"}
			}
		}


func _poison_all_raw_tool_definitions(tools_by_category: Dictionary) -> void:
	for category in tools_by_category.keys():
		var entries = tools_by_category.get(category, [])
		if not (entries is Array):
			continue
		for raw_tool in entries:
			if not (raw_tool is Dictionary):
				continue
			var tool_def := raw_tool as Dictionary
			tool_def["description"] = "RAW SHOULD NOT APPEAR"
			tool_def["source"] = "RAW SHOULD NOT APPEAR"
			tool_def["script_path"] = "RAW SHOULD NOT APPEAR"
			tool_def["load_state"] = "RAW SHOULD NOT APPEAR"


func _override_presentation_action_metadata(presentation: Dictionary, action_key: String, label_key: String, description_key: String) -> void:
	var nodes = presentation.get("toolTree", [])
	if nodes is Array:
		_override_presentation_action_metadata_recursive(nodes as Array, action_key, label_key, description_key)


func _override_presentation_action_metadata_recursive(nodes: Array, action_key: String, label_key: String, description_key: String) -> bool:
	for raw_node in nodes:
		if not (raw_node is Dictionary):
			continue
		var node := raw_node as Dictionary
		if str(node.get("kind", "")) == "action" and str(node.get("key", "")) == action_key:
			node["labelKey"] = label_key
			node["descriptionKey"] = description_key
			return true
		var children = node.get("children", [])
		if children is Array and _override_presentation_action_metadata_recursive(children as Array, action_key, label_key, description_key):
			return true
	return false


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
			_merge_tool_actions(existing, actions)
			return
	var tool_def := {
		"name": tool_name,
		"description": "Contract fixture for %s" % full_name
	}
	if not actions.is_empty():
		tool_def["inputSchema"] = {
			"type": "object",
			"properties": {
				"action": {"type": "string", "enum": actions.duplicate()}
			}
		}
	if full_name == "system_dap_debugger" or full_name == "dap_debugger":
		tool_def["icons"] = [{"src": TEST_ICON_SRC, "mimeType": "image/svg+xml"}]
		tool_def["inputSchema"] = {
			"type": "object",
			"properties": {
				"action": {"type": "string", "enum": actions, "description": "DAP debugger action"},
				"adapter_args": {"type": "object", "description": "Launch/attach arguments sent to the adapter"},
				"fallback_note": {"type": "string", "description": "Fallback-only schema description"}
			},
			"required": ["action"]
		}
		tool_def["outputSchema"] = {
			"type": "object",
			"properties": {
				"structuredContent": {"type": "object", "description": "Contract structured output"},
				"isError": {"type": "boolean", "description": "Tool error marker"}
			},
			"required": ["structuredContent"]
		}
	tools_by_category[category].append(tool_def)


func _oversized_icon_src() -> String:
	var encoded := ""
	for _index in range(7000):
		encoded += "A"
	return "data:image/svg+xml;base64,%s" % encoded


func _merge_tool_actions(tool_def: Dictionary, actions: Array) -> void:
	if actions.is_empty():
		return
	var input_schema = tool_def.get("inputSchema", {})
	if not (input_schema is Dictionary):
		tool_def["inputSchema"] = {
			"type": "object",
			"properties": {
				"action": {"type": "string", "enum": actions}
			}
		}
		return
	var properties = (input_schema as Dictionary).get("properties", {})
	if not (properties is Dictionary):
		properties = {}
		(input_schema as Dictionary)["properties"] = properties
	var action_schema = (properties as Dictionary).get("action", {})
	if not (action_schema is Dictionary):
		action_schema = {"type": "string", "enum": []}
		(properties as Dictionary)["action"] = action_schema
	var enum_values = (action_schema as Dictionary).get("enum", [])
	if enum_values is Array:
		enum_values = (enum_values as Array).duplicate()
	else:
		enum_values = []
	(action_schema as Dictionary)["enum"] = enum_values
	for action in actions:
		if not (enum_values as Array).has(action):
			(enum_values as Array).append(action)


func _split_full_name(full_name: String) -> Dictionary:
	var categories := ["plugin_developer", "plugin_evolution", "plugin_runtime", "filesystem", "animation", "navigation", "material", "resource", "particle", "geometry", "lighting", "tilemap", "project", "editor", "runtime", "system", "script", "signal", "shader", "debug", "scene", "group", "audio", "node", "user", "dap", "ui"]
	for category in categories:
		if full_name.begins_with("%s_" % category):
			return {"category": category, "tool": full_name.trim_prefix("%s_" % category)}
	return {}


func _system_actions_for(full_name: String) -> Array:
	match full_name:
		"system_dap_debugger":
			return ["status", "get_settings", "set_settings", "initialize", "launch", "attach", "configuration_done", "disconnect", "terminate", "threads", "set_breakpoint", "remove_breakpoint", "list_breakpoints", "pause", "continue", "step_over", "stack_trace", "output"]
		"system_userdata_maintenance":
			return ["ensure_layout", "list_capture_cache", "cleanup_capture_cache", "cleanup_legacy_cache"]
		"system_runtime_control":
			return ["status", "enable", "disable"]
		"system_runtime_step":
			return ["step", "capture", "input"]
		"system_editor_evidence":
			return ["status", "capture"]
		"system_editor_control":
			return ["list_main_screens", "set_main_screen", "get_distraction_free", "set_distraction_free", "capture_editor", "clear_output", "list_controls", "wait_for_ui", "list_dock_tabs", "activate_dock_tab", "activate_ui", "list_tree_items", "select_tree_item", "list_menus", "open_menu", "select_menu_item", "get_control", "capture_control", "focus_control", "activate_control", "click_control", "right_click_control", "hover_control", "leave_control", "set_control_text", "set_value", "list_popups", "get_popup", "capture_popup", "press_popup_button", "select_popup_menu_item", "set_popup_text", "close_popup"]
		"system_settings_dialog":
			return ["open", "status", "search", "list_tabs", "activate_tab", "list_categories", "focus_category", "list_rows", "resolve_row", "read_value", "focus_value", "set_value", "verify_value", "focus_result", "run_task", "capture", "close"]
		"system_inspector":
			return ["status", "edit_object", "inspect_resource", "refresh", "list_properties", "resolve_property", "read_value", "focus_value", "set_value", "verify_value", "run_task", "capture"]
		"system_editor_plugin_control":
			return ["list", "get_status", "enable", "disable"]
		"system_project_configure":
			return ["get_settings", "set_setting", "list_autoloads", "add_autoload", "remove_autoload", "list_input_actions", "get_input_action", "list_export_presets"]
		"system_project_lifecycle":
			return ["start", "stop"]
		"system_scene_inspect":
			return ["validate", "analyze", "full"]
		"system_plugin_maintenance":
			return ["status", "reload", "update_status", "set_update_source", "start_update"]
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


func _assert_tools_tab_prefers_shared_presentation_metadata() -> String:
	var source_path := "res://addons/godot_dotnet_mcp/ui/tools_tab.gd"
	if not FileAccess.file_exists(source_path):
		return "Tools tab source should exist for presentation metadata guard."
	var source := FileAccess.get_file_as_string(source_path)
	if source.find("SystemTreeCatalog") != -1:
		return "Tools tab should not depend directly on SystemTreeCatalog; route catalog fallback facts through ToolPresentationService."
	if source.find("ToolPresentationService.get_atomic_child_specs") == -1:
		return "Tools tab legacy fallback rendering should consume atomic child specs from ToolPresentationService."
	if source.find("ToolPresentationService.get_action_name_key") == -1 or source.find("ToolPresentationService.get_action_desc_key") == -1:
		return "Tools tab legacy action localization should consume action key helpers from ToolPresentationService."
	if source.find("if _has_presentation_tree(_current_model):\n\t\treturn lines") == -1:
		return "Tools tab atomic preview should not fall back to raw atomic specs when shared presentation metadata exists."
	if source.find("if _has_presentation_tree(model):") == -1:
		return "Tools tab tree signature should use a presentation-only branch when shared presentation metadata exists."
	if source.find("ToolPresentationService.build_presentation_signature") == -1:
		return "Tools tab tree signature should use reusable presentation signatures instead of serializing the full tree on every refresh."
	if source.find("JSON.stringify(_active_tool_presentation().get(\"toolTree\"") != -1 or source.find("JSON.stringify((presentation as Dictionary).get(\"toolMetadataByName\"") != -1:
		return "Tools tab tree signature should not deep-serialize presentation trees or metadata on every refresh."
	if source.find("func _filter_presentation_node") != -1:
		return "Tools tab search should render shared presentation nodes directly instead of deep-copying filtered presentation trees."
	return ""


func _assert_tools_tab_uses_lightweight_tree_signatures() -> String:
	var source_path := "res://addons/godot_dotnet_mcp/ui/tools_tab.gd"
	if not FileAccess.file_exists(source_path):
		return "Tools tab source should exist for tree signature guard."
	var source := FileAccess.get_file_as_string(source_path)
	var signature_start := source.find("func _build_tree_signature")
	if signature_start == -1:
		return "Tools tab should keep a tree signature builder."
	var signature_end := source.find("func _get_presentation_signature", signature_start)
	if signature_end == -1:
		return "Tools tab tree signature guard could not find the signature function boundary."
	var signature_source := source.substr(signature_start, signature_end - signature_start)
	if signature_source.find("JSON.stringify") != -1:
		return "Tools tab tree signatures should avoid JSON serialization in hot tab-switch refresh paths."
	if source.find("func _build_sorted_string_array_signature") == -1 or source.find("func _build_collapsed_nodes_signature") == -1:
		return "Tools tab tree signatures should use lightweight deterministic helpers for arrays and collapse state."
	return ""


func _assert_legacy_fallback_catalog_rendering(tool_tree: Tree, preview_text: TextEdit, search_edit: LineEdit) -> String:
	var root := tool_tree.get_root()
	var system_root := _find_child_by_metadata(root, "root", "system")
	if system_root == null:
		return "Tools tab legacy fallback should render the system root."
	var editor_control_tool := _find_child_by_metadata(system_root, "tool", "system_editor_control")
	if editor_control_tool == null:
		return "Tools tab legacy fallback should render system_editor_control."
	var popup_atomic := _find_child_by_metadata(editor_control_tool, "atomic", "editor_popup")
	if popup_atomic == null:
		return "Tools tab legacy fallback should render editor_popup atomic children via ToolPresentationService."
	var popup_capture_action := _find_child_by_metadata(popup_atomic, "action", "editor_popup.capture_popup")
	if popup_capture_action == null:
		return "Tools tab legacy fallback should render catalog-edge atomic actions via ToolPresentationService."
	_instance.call("_apply_selection_metadata", editor_control_tool.get_metadata(0))
	await _instance.get_tree().process_frame
	if not preview_text.text.contains("截图"):
		return "Tools tab legacy preview should include catalog-edge atomic action labels."
	search_edit.text = "截图"
	_instance.call("_on_search_text_changed", search_edit.text)
	await _instance.get_tree().process_frame
	root = tool_tree.get_root()
	system_root = _find_child_by_metadata(root, "root", "system")
	editor_control_tool = _find_child_by_metadata(system_root, "tool", "system_editor_control") if system_root != null else null
	popup_atomic = _find_child_by_metadata(editor_control_tool, "atomic", "editor_popup") if editor_control_tool != null else null
	if popup_atomic == null or _find_child_by_metadata(popup_atomic, "action", "editor_popup.capture_popup") == null:
		return "Tools tab legacy search should match catalog-edge atomic action labels after service indirection."
	search_edit.text = ""
	_instance.call("_on_search_text_changed", "")
	await _instance.get_tree().process_frame
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
		var nested := _find_child_by_metadata(child, kind, key)
		if nested != null:
			return nested
		child = child.get_next()
	return null


func _count_presentation_kind(nodes: Array, kind: String) -> int:
	var count := 0
	for node_value in nodes:
		if not (node_value is Dictionary):
			continue
		var node := node_value as Dictionary
		if str(node.get("kind", "")) == kind:
			count += 1
		var children = node.get("children", [])
		if children is Array:
			count += _count_presentation_kind(children as Array, kind)
	return count


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


func _find_popup_item(popup: PopupMenu, label: String) -> int:
	for index in range(popup.get_item_count()):
		if popup.get_item_text(index) == label:
			return index
	return -1


func _failure(message: String) -> Dictionary:
	return {
		"name": "tools_tab_rendering_contracts",
		"success": false,
		"error": message
	}
