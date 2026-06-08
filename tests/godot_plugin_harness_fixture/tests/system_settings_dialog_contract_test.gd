extends RefCounted

# {"name": "system_settings_dialog_contracts"}

const SettingsDialogImplScript = preload("res://addons/godot_dotnet_mcp/tools/system/impl_settings_dialog.gd")
const VALUE_PAYLOAD_KEYS = ["text", "value", "value_text", "value_editor_type", "value_source", "pressed", "button_pressed", "selected", "selected_index"]


class FakeBridge extends RefCounted:
	var project_visible := false
	var editor_visible := false
	var project_filter_text := ""
	var editor_filter_text := ""
	var project_current_tab_index := 0
	var editor_current_tab_index := 0
	var localized_project_item := "Настройки проекта..."
	var localized_editor_item := "Настройки редактора..."
	var project_name_value := "Example"
	var use_custom_user_dir := true
	var snap_2d_transforms_to_pixel := false
	var max_renderable_elements := 128000.0
	var direct_spin_value := 3.0
	var plain_slider_value := 0.25
	var popup_capture_enabled := true
	var control_capture_enabled := true
	var editor_capture_enabled := true
	var calls: Array[Dictionary] = []

	func call_atomic(tool_name: String, args: Dictionary) -> Dictionary:
		var action := str(args.get("action", ""))
		calls.append({"tool": tool_name, "action": action, "args": args.duplicate(true)})
		match tool_name:
			"editor_ui_control":
				match action:
					"list_visible":
						var visible_controls := _visible_controls()
						var limit := maxi(int(args.get("limit", visible_controls.size())), 1)
						return success({"count": visible_controls.size(), "controls": visible_controls.slice(0, mini(limit, visible_controls.size()))})
					"list_tree_items":
						return success({"target_path": str(args.get("target_path", "")), "count": _visible_tree_items(str(args.get("target_path", ""))).size(), "items": _visible_tree_items(str(args.get("target_path", "")))})
					"select_tree_item":
						return _select_tree_item(args)
					"select_menu_item":
						var item_text := str(args.get("item_text", ""))
						if item_text == localized_project_item:
							project_visible = true
							return success({"menu_title": str(args.get("menu_title", "")), "item_text": item_text})
						if item_text == localized_editor_item:
							editor_visible = true
							return success({"menu_title": str(args.get("menu_title", "")), "item_text": item_text})
						return error("Menu item not found")
					"focus_control":
						return success({"target_path": str(args.get("target_path", ""))})
					"activate_ui":
						var target_path := str(args.get("target_path", ""))
						var tab_index := int(args.get("tab_index", -1))
						var tab_title := str(args.get("tab_title", ""))
						if target_path.contains("ProjectSettings"):
							var resolved_project_index := _resolve_project_tab(tab_index, tab_title)
							if resolved_project_index < 0:
								return error("Project Settings tab not found")
							project_current_tab_index = resolved_project_index
							return success({"target_path": target_path, "active_path": _project_tab_path(resolved_project_index), "tab_index": resolved_project_index, "tab_title": _project_tab_title(resolved_project_index)})
						if target_path.contains("EditorSettings"):
							var resolved_editor_index := _resolve_editor_tab(tab_index, tab_title)
							if resolved_editor_index < 0:
								return error("Editor Settings tab not found")
							editor_current_tab_index = resolved_editor_index
							return success({"target_path": target_path, "active_path": _editor_tab_path(resolved_editor_index), "tab_index": resolved_editor_index, "tab_title": _editor_tab_title(resolved_editor_index)})
						return error("Unsupported activate_ui target")
					"set_text":
						var target_path := str(args.get("target_path", ""))
						var text := str(args.get("text", ""))
						if target_path.contains("ProjectSettings"):
							if target_path.ends_with("/Filter"):
								project_filter_text = text
							elif target_path.ends_with("/Name/Value"):
								project_name_value = text
						if target_path.contains("EditorSettings"):
							editor_filter_text = text
						return success({"target_path": target_path, "text": text})
					"set_value":
						var target_path := str(args.get("target_path", ""))
						if target_path.ends_with("/MaxRenderableElements/Value"):
							max_renderable_elements = float(args.get("value", 0.0))
							return success({"target_path": target_path, "value": max_renderable_elements})
						if target_path.ends_with("/DirectSpin"):
							direct_spin_value = float(args.get("value", 0.0))
							return success({"target_path": target_path, "value": direct_spin_value})
						if target_path.ends_with("/PlainSlider"):
							plain_slider_value = float(args.get("value", 0.0))
							return success({"target_path": target_path, "value": plain_slider_value})
						return error("Value target not found")
					"activate_control":
						var target_path := str(args.get("target_path", ""))
						if target_path.ends_with("/UseCustomUserDir/Value"):
							use_custom_user_dir = not use_custom_user_dir
							return success({"target_path": target_path})
						if target_path.ends_with("/Snap2DTransformsToPixel/Value"):
							snap_2d_transforms_to_pixel = not snap_2d_transforms_to_pixel
							return success({"target_path": target_path})
						return error("Activation target not found")
					"capture_control":
						var target_path := str(args.get("target_path", ""))
						if target_path.contains("ProjectSettings") and project_visible and control_capture_enabled:
							return success({"path": str(args.get("path", "user://settings_dialog.png")), "target_path": target_path, "capture_mode": "control"})
						if target_path.contains("EditorSettings") and editor_visible and control_capture_enabled:
							return success({"path": str(args.get("path", "user://settings_dialog.png")), "target_path": target_path, "capture_mode": "control"})
						return error("Control capture target not found")
					_:
						return error("Unsupported editor_ui_control action: %s" % action)
			"editor_popup":
				match action:
					"list_visible":
						var popups: Array[Dictionary] = []
						if project_visible:
							popups.append({"node_path": "/root/ProjectSettings", "title": "Project Settings", "class": "AcceptDialog"})
						if editor_visible:
							popups.append({"node_path": "/root/EditorSettings", "title": "Editor Settings", "class": "AcceptDialog"})
						return success({"count": popups.size(), "popups": popups})
					"capture_popup":
						var target_path := str(args.get("target_path", ""))
						if target_path.contains("ProjectSettings") and project_visible and popup_capture_enabled:
							return success({"path": str(args.get("path", "user://settings_dialog.png")), "target_path": target_path, "popup_path": "/root/ProjectSettings", "capture_mode": "popup"})
						if target_path.contains("EditorSettings") and editor_visible and popup_capture_enabled:
							return success({"path": str(args.get("path", "user://settings_dialog.png")), "target_path": target_path, "popup_path": "/root/EditorSettings", "capture_mode": "popup"})
						return error("Popup capture target not found")
					"close_popup":
						var target_path := str(args.get("target_path", ""))
						if target_path.contains("ProjectSettings"):
							project_visible = false
						if target_path.contains("EditorSettings"):
							editor_visible = false
						return success({"target_path": target_path})
					_:
						return error("Unsupported editor_popup action: %s" % action)
			"editor_screenshot":
				if action == "capture" and editor_capture_enabled:
					return success({"path": str(args.get("path", "user://settings_dialog.png")), "capture_mode": "full"})
				return error("Unsupported editor_screenshot action: %s" % action)
			_:
				return error("Unsupported atomic tool: %s" % tool_name)

	func call_atomic_async(tool_name: String, args: Dictionary) -> Dictionary:
		calls.append({"tool": tool_name, "action": str(args.get("action", "")), "args": args.duplicate(true), "async": true})
		await Engine.get_main_loop().process_frame
		if tool_name == "editor_ui_control" and str(args.get("action", "")) == "wait_for_ui":
			var target_path := str(args.get("target_path", ""))
			if not target_path.is_empty():
				var expected_text := str(args.get("text", ""))
				var target_text := project_filter_text if target_path.contains("ProjectSettings") else editor_filter_text
				if expected_text == target_text:
					return success({"condition_met": true, "target_path": target_path, "text": expected_text})
				return error("Timed out", {"condition_met": false, "target_path": target_path, "text": expected_text})
			var text_query := str(args.get("text_query", ""))
			var found := (text_query == "Project Settings" and project_visible) or (text_query == "Editor Settings" and editor_visible)
			if found:
				return success({"condition_met": true, "text_query": text_query, "matched_controls": _visible_controls()})
			return error("Timed out", {"condition_met": false, "text_query": text_query})
		return call_atomic(tool_name, args)

	func success(data = {}, message: String = "") -> Dictionary:
		return {"success": true, "data": data, "message": message}

	func error(message: String, data = {}) -> Dictionary:
		return {"success": false, "error": "bridge_error", "message": message, "data": data}

	func _visible_controls() -> Array[Dictionary]:
		var rows: Array[Dictionary] = []
		if project_visible:
			rows.append({"path": "/root/ProjectSettings", "class": "AcceptDialog", "title": "Project Settings", "visible": true, "enabled": true})
			rows.append(_tab_container_row("ProjectSettings", "/root/ProjectSettings/Tabs", project_current_tab_index, _project_tab_titles()))
			rows.append({"path": "/root/ProjectSettings/Filter", "class": "LineEdit", "name": "Filter Settings", "text": project_filter_text, "visible": true, "enabled": true})
			if project_filter_text.is_empty():
				for index in range(12):
					rows.append({"path": "/root/ProjectSettings/General/VisibleRow%s" % index, "parent_path": "/root/ProjectSettings/General", "class": "HBoxContainer", "text": "Visible Row %s" % index, "visible": true, "disabled": false, "editable_text": false, "child_count": 0})
			rows.append({"path": "/root/ProjectSettings/SectionedInspector", "parent_path": "/root/ProjectSettings", "class": "SectionedInspector", "name": "SectionedInspector", "visible": true, "enabled": true, "child_count": 2})
			rows.append({"path": "/root/ProjectSettings/SectionedInspector/Left", "parent_path": "/root/ProjectSettings/SectionedInspector", "class": "VBoxContainer", "visible": true, "enabled": true, "child_count": 1})
			rows.append({"path": "/root/ProjectSettings/SectionedInspector/Left/Sections", "parent_path": "/root/ProjectSettings/SectionedInspector/Left", "class": "Tree", "visible": true, "enabled": true, "child_count": 3})
			rows.append({"path": "/root/ProjectSettings/SectionedInspector/Right", "parent_path": "/root/ProjectSettings/SectionedInspector", "class": "VBoxContainer", "visible": true, "enabled": true, "child_count": 1})
			rows.append({"path": "/root/ProjectSettings/SectionedInspector/Right/Inspector", "parent_path": "/root/ProjectSettings/SectionedInspector/Right", "class": "EditorInspector", "name": "EditorInspector", "visible": true, "enabled": true, "child_count": 1})
			rows.append({"path": "/root/ProjectSettings/SectionedInspector/Right/Inspector/SettingsTree", "parent_path": "/root/ProjectSettings/SectionedInspector/Right/Inspector", "class": "Tree", "name": "Settings Tree", "visible": true, "enabled": true, "child_count": 1})
			rows.append({"path": "/root/ProjectSettings/SettingsList", "parent_path": "/root/ProjectSettings", "class": "Tree", "name": "Settings List", "visible": true, "enabled": true, "child_count": 2})
			if project_filter_text.contains("application/config/name"):
				rows.append({"path": "/root/ProjectSettings/General/Application/Config/Name", "parent_path": "/root/ProjectSettings/General/Application/Config", "class": "HBoxContainer", "text": "Application Config Name", "visible": true, "disabled": false, "editable_text": false, "child_count": 2})
				rows.append({"path": "/root/ProjectSettings/General/Application/Config/Name/Value", "parent_path": "/root/ProjectSettings/General/Application/Config/Name", "class": "LineEdit", "text": project_name_value, "visible": true, "disabled": false, "editable_text": true})
			if project_filter_text.contains("application/config/use_custom_user_dir"):
				rows.append({"path": "/root/ProjectSettings/General/Application/Config/UseCustomUserDir", "parent_path": "/root/ProjectSettings/General/Application/Config", "class": "HBoxContainer", "text": "Use Custom User Dir", "visible": true, "disabled": false, "editable_text": false, "child_count": 2})
				rows.append({"path": "/root/ProjectSettings/General/Application/Config/UseCustomUserDir/Value", "parent_path": "/root/ProjectSettings/General/Application/Config/UseCustomUserDir", "class": "CheckBox", "text": "Enabled", "pressed": use_custom_user_dir, "visible": true, "disabled": false})
			if project_filter_text.contains("application/config/display_enabled_label"):
				rows.append({"path": "/root/ProjectSettings/General/Application/Config/DisplayEnabledLabel", "parent_path": "/root/ProjectSettings/General/Application/Config", "class": "HBoxContainer", "text": "Display Enabled Label", "visible": true, "disabled": false, "editable_text": false, "child_count": 2})
				rows.append({"path": "/root/ProjectSettings/General/Application/Config/DisplayEnabledLabel/Value", "parent_path": "/root/ProjectSettings/General/Application/Config/DisplayEnabledLabel", "class": "CheckBox", "text": "Enabled", "visible": true, "disabled": false})
			if project_filter_text.contains("rendering/2d/snap/snap_2d_transforms_to_pixel"):
				rows.append({"path": "/root/ProjectSettings/General/Rendering/2D/Snap/Snap2DTransformsToPixel", "parent_path": "/root/ProjectSettings/General/Rendering/2D/Snap", "class": "HBoxContainer", "text": "Snap 2D Transforms To Pixel", "visible": true, "disabled": false, "editable_text": false, "child_count": 2})
				rows.append({"path": "/root/ProjectSettings/General/Rendering/2D/Snap/Snap2DTransformsToPixel/Value", "parent_path": "/root/ProjectSettings/General/Rendering/2D/Snap/Snap2DTransformsToPixel", "class": "CheckButton", "button_pressed": snap_2d_transforms_to_pixel, "visible": true, "disabled": false})
			if project_filter_text.contains("rendering/limits/rendering/max_renderable_elements"):
				rows.append({"path": "/root/ProjectSettings/General/Rendering/Limits/Rendering/MaxRenderableElements", "parent_path": "/root/ProjectSettings/General/Rendering/Limits/Rendering", "class": "HBoxContainer", "text": "Max Renderable Elements", "visible": true, "disabled": false, "editable_text": false, "child_count": 2})
				rows.append({"path": "/root/ProjectSettings/General/Rendering/Limits/Rendering/MaxRenderableElements/Value", "parent_path": "/root/ProjectSettings/General/Rendering/Limits/Rendering/MaxRenderableElements", "class": "SpinBox", "value": max_renderable_elements, "text": str(max_renderable_elements), "visible": true, "disabled": false})
			if project_filter_text.contains("editor/direct_spin"):
				rows.append({"path": "/root/ProjectSettings/General/Editor/DirectSpin", "parent_path": "/root/ProjectSettings/General/Editor", "class": "SpinBox", "setting_path": "editor/direct_spin", "value": direct_spin_value, "text": str(direct_spin_value), "visible": true, "disabled": false})
			if project_filter_text.contains("editor/plain_slider"):
				rows.append({"path": "/root/ProjectSettings/General/Editor/PlainSlider", "parent_path": "/root/ProjectSettings/General/Editor", "class": "Slider", "setting_path": "editor/plain_slider", "value": plain_slider_value, "text": str(plain_slider_value), "visible": true, "disabled": false})
			if project_filter_text.contains("editor/plain_label"):
				rows.append({"path": "/root/ProjectSettings/General/Editor/PlainLabel", "parent_path": "/root/ProjectSettings/General/Editor", "class": "HBoxContainer", "setting_path": "editor/plain_label", "text": "Plain Label", "visible": true, "disabled": false, "editable_text": false, "child_count": 0})
			if project_filter_text.contains("editor/display_value_label"):
				rows.append({"path": "/root/ProjectSettings/General/Editor/DisplayValueLabel", "parent_path": "/root/ProjectSettings/General/Editor", "class": "HBoxContainer", "setting_path": "editor/display_value_label", "text": "Display Value Label", "visible": true, "disabled": false, "editable_text": false, "child_count": 1})
				rows.append({"path": "/root/ProjectSettings/General/Editor/DisplayValueLabel/Value", "parent_path": "/root/ProjectSettings/General/Editor/DisplayValueLabel", "class": "Label", "text": "Read only", "visible": true, "disabled": false})
			if project_filter_text.contains("application/run/main_scene"):
				rows.append({"path": "/root/ProjectSettings/General/Application/Run/MainScene", "parent_path": "/root/ProjectSettings/General/Application/Run", "class": "HBoxContainer", "text": "Main Scene", "visible": true, "disabled": false, "editable_text": false, "child_count": 2})
				rows.append({"path": "/root/ProjectSettings/General/Application/Run/MainScene/Value", "parent_path": "/root/ProjectSettings/General/Application/Run/MainScene", "class": "OptionButton", "text": "res://Main.tscn", "selected": 2, "visible": true, "disabled": false})
			if project_filter_text.contains("ambiguous/example"):
				rows.append({"path": "/root/ProjectSettings/General/Ambiguous/ExampleA", "parent_path": "/root/ProjectSettings/General/Ambiguous", "class": "HBoxContainer", "text": "Ambiguous Example", "setting_path": "ambiguous/example", "visible": true, "disabled": false, "editable_text": false, "child_count": 1})
				rows.append({"path": "/root/ProjectSettings/General/Ambiguous/ExampleB", "parent_path": "/root/ProjectSettings/General/Ambiguous", "class": "HBoxContainer", "text": "Ambiguous Example", "setting_path": "ambiguous/example", "visible": true, "disabled": false, "editable_text": false, "child_count": 1})
		if editor_visible:
			rows.append({"path": "/root/EditorSettings", "class": "AcceptDialog", "title": "Editor Settings", "visible": true, "enabled": true})
			rows.append(_tab_container_row("EditorSettings", "/root/EditorSettings/Tabs", editor_current_tab_index, _editor_tab_titles()))
			rows.append({"path": "/root/EditorSettings/Filter", "class": "LineEdit", "name": "Filter Settings", "text": editor_filter_text, "visible": true, "enabled": true})
			rows.append({"path": "/root/EditorSettings/CategoryTree", "parent_path": "/root/EditorSettings", "class": "Tree", "name": "Category Tree", "visible": true, "enabled": true, "child_count": 2})
			if editor_filter_text.contains("interface/editor/editor_language"):
				rows.append({"path": "/root/EditorSettings/Interface/Editor/Language", "parent_path": "/root/EditorSettings/Interface/Editor", "class": "HBoxContainer", "text": "Editor Language", "visible": true, "disabled": false, "editable_text": false, "child_count": 2})
		return rows

	func _visible_tree_items(target_path: String) -> Array[Dictionary]:
		if target_path == "/root/ProjectSettings/SectionedInspector/Left/Sections":
			return [
				{"index": 0, "text": "Application", "item_path": "Application", "depth": 0, "tree_control_path": target_path, "visible": true, "selected": false, "collapsed": false, "child_count": 2},
				{"index": 1, "text": "Config", "item_path": "Application/Config", "depth": 1, "tree_control_path": target_path, "visible": true, "selected": false, "collapsed": false, "child_count": 0},
				{"index": 2, "text": "Run", "item_path": "Application/Run", "depth": 1, "tree_control_path": target_path, "visible": true, "selected": false, "collapsed": false, "child_count": 0},
				{"index": 3, "text": "Rendering", "item_path": "Rendering", "depth": 0, "tree_control_path": target_path, "visible": true, "selected": false, "collapsed": false, "child_count": 1},
				{"index": 4, "text": "2D", "item_path": "Rendering/2D", "depth": 1, "tree_control_path": target_path, "visible": true, "selected": false, "collapsed": false, "child_count": 0}
			]
		if target_path == "/root/ProjectSettings/SettingsList":
			return [
				{"index": 0, "text": "Advanced Settings", "item_path": "Advanced Settings", "depth": 0, "tree_control_path": target_path, "visible": true, "selected": false, "collapsed": false, "child_count": 0},
				{"index": 1, "text": "Project Settings", "item_path": "Project Settings", "depth": 0, "tree_control_path": target_path, "visible": true, "selected": false, "collapsed": false, "child_count": 0}
			]
		if target_path == "/root/ProjectSettings/SectionedInspector/Right/Inspector/SettingsTree":
			return [
				{"index": 0, "text": "Inspector Settings", "item_path": "Inspector Settings", "depth": 0, "tree_control_path": target_path, "visible": true, "selected": false, "collapsed": false, "child_count": 0}
			]
		if target_path == "/root/EditorSettings/CategoryTree":
			return [
				{"index": 0, "text": "Interface", "item_path": "Interface", "depth": 0, "tree_control_path": target_path, "visible": true, "selected": false, "collapsed": false, "child_count": 1},
				{"index": 1, "text": "Editor", "item_path": "Interface/Editor", "depth": 1, "tree_control_path": target_path, "visible": true, "selected": false, "collapsed": false, "child_count": 0}
			]
		return []

	func _select_tree_item(args: Dictionary) -> Dictionary:
		var target_path := str(args.get("target_path", ""))
		var item_path := str(args.get("item_path", ""))
		var item_index := int(args.get("item_index", -1))
		for item in _visible_tree_items(target_path):
			if str(item.get("item_path", "")) == item_path or int(item.get("index", -1)) == item_index:
				var selected := item.duplicate(true)
				selected["selected"] = true
				return success({"target_path": target_path, "selected_item": selected, "resolution": {"candidate_count": 1}})
		return error("Tree item not found", {"target_path": target_path, "item_path": item_path, "item_index": item_index})

	func _tab_container_row(surface_prefix: String, path: String, current_index: int, titles: Array[String]) -> Dictionary:
		var tabs: Array[Dictionary] = []
		for index in range(titles.size()):
			tabs.append({
				"index": index,
				"title": titles[index],
				"control_path": "%s/%s" % [path, titles[index].replace(" ", "")],
				"control_name": titles[index].replace(" ", ""),
				"current": index == current_index,
				"visible": index == current_index
			})
		return {
			"path": path,
			"parent_path": "/root/%s" % surface_prefix,
			"class": "TabContainer",
			"name": "Tabs",
			"visible": true,
			"enabled": true,
			"tab_count": tabs.size(),
			"current_tab_index": current_index,
			"tabs": tabs
		}

	func _project_tab_titles() -> Array[String]:
		return ["General", "Input Map", "Localization", "Plugins", "Globals"]

	func _editor_tab_titles() -> Array[String]:
		return ["General", "Shortcuts"]

	func _project_tab_title(index: int) -> String:
		var titles := _project_tab_titles()
		return titles[index] if index >= 0 and index < titles.size() else ""

	func _editor_tab_title(index: int) -> String:
		var titles := _editor_tab_titles()
		return titles[index] if index >= 0 and index < titles.size() else ""

	func _project_tab_path(index: int) -> String:
		return "/root/ProjectSettings/Tabs/%s" % _project_tab_title(index).replace(" ", "")

	func _editor_tab_path(index: int) -> String:
		return "/root/EditorSettings/Tabs/%s" % _editor_tab_title(index).replace(" ", "")

	func _resolve_project_tab(tab_index: int, tab_title: String) -> int:
		return _resolve_tab(_project_tab_titles(), tab_index, tab_title)

	func _resolve_editor_tab(tab_index: int, tab_title: String) -> int:
		return _resolve_tab(_editor_tab_titles(), tab_index, tab_title)

	func _resolve_tab(titles: Array[String], tab_index: int, tab_title: String) -> int:
		if tab_index >= 0 and tab_index < titles.size():
			return tab_index
		var query := tab_title.strip_edges().to_lower()
		if query.is_empty():
			return -1
		for index in range(titles.size()):
			var title := titles[index].to_lower()
			if title == query or title.contains(query):
				return index
		return -1


func run_case(_tree: SceneTree) -> Dictionary:
	var impl = SettingsDialogImplScript.new()
	var fake := FakeBridge.new()
	impl.bridge = fake

	var tool_defs: Array[Dictionary] = impl.get_tools()
	if tool_defs.size() != 1:
		return _failure("impl_settings_dialog.gd should expose exactly one high-level system tool.")
	if str(tool_defs[0].get("name", "")) != "settings_dialog":
		return _failure("impl_settings_dialog.gd should expose settings_dialog.")
	var schema: Dictionary = tool_defs[0].get("inputSchema", {})
	var properties: Dictionary = schema.get("properties", {})
	var actions: Array = properties.get("action", {}).get("enum", [])
	for action in ["open", "status", "search", "list_tabs", "activate_tab", "list_categories", "focus_category", "list_rows", "resolve_row", "read_value", "focus_value", "set_value", "verify_value", "focus_result", "run_task", "capture", "close"]:
		if not actions.has(action):
			return _failure("settings_dialog schema should expose action: %s." % action)
	for property_name in ["capture_policy", "require_capture"]:
		if not properties.has(property_name):
			return _failure("settings_dialog schema should expose %s for run_task workflows." % property_name)
	if not properties.has("tab_index"):
		return _failure("settings_dialog schema should expose tab_index for activate_tab.")
	for property_name in ["category", "category_path", "category_index"]:
		if not properties.has(property_name):
			return _failure("settings_dialog schema should expose %s for category workflows." % property_name)
	var surfaces: Array = properties.get("surface", {}).get("enum", [])
	for surface in ["project_settings", "editor_settings"]:
		if not surfaces.has(surface):
			return _failure("settings_dialog schema should expose surface: %s." % surface)

	var missing_status := impl.execute("settings_dialog", {"action": "status", "surface": "project_settings"})
	if not bool(missing_status.get("success", false)):
		return _failure("status should succeed even when a settings surface is not open.")
	if bool(missing_status.get("data", {}).get("dialog_found", true)):
		return _failure("status should report dialog_found=false before open.")
	var missing_categories := impl.execute("settings_dialog", {"action": "list_categories", "surface": "project_settings"})
	if not bool(missing_categories.get("success", false)):
		return _failure("list_categories should succeed even when the requested settings surface is not visible.")
	if int(missing_categories.get("data", {}).get("category_count", -1)) != 0:
		return _failure("list_categories should return no categories before the settings surface is visible.")
	var missing_focus_category := impl.execute("settings_dialog", {
		"action": "focus_category",
		"surface": "project_settings",
		"category_path": "Application/Config"
	})
	if bool(missing_focus_category.get("success", false)):
		return _failure("focus_category should fail when the requested settings surface is not visible.")
	var missing_focus_workflow: Array = missing_focus_category.get("data", {}).get("workflow", [])
	var missing_focus_step: Dictionary = missing_focus_workflow[missing_focus_workflow.size() - 1] if not missing_focus_workflow.is_empty() else {}
	if str(missing_focus_step.get("reason", "")) != "surface_not_visible":
		return _failure("focus_category missing-surface failure should report surface_not_visible.")
	var missing_read_value := impl.execute("settings_dialog", {
		"action": "read_value",
		"surface": "project_settings",
		"setting_path": "application/config/name"
	})
	if bool(missing_read_value.get("success", false)):
		return _failure("read_value should fail when the requested settings surface is not visible.")
	var missing_read_workflow: Array = missing_read_value.get("data", {}).get("workflow", [])
	var missing_read_step: Dictionary = missing_read_workflow[missing_read_workflow.size() - 1] if not missing_read_workflow.is_empty() else {}
	if str(missing_read_step.get("reason", "")) != "surface_not_visible":
		return _failure("read_value missing-surface failure should report surface_not_visible.")
	var missing_focus_value := impl.execute("settings_dialog", {
		"action": "focus_value",
		"surface": "project_settings",
		"setting_path": "application/config/name"
	})
	if bool(missing_focus_value.get("success", false)):
		return _failure("focus_value should fail when the requested settings surface is not visible.")
	var missing_focus_value_workflow: Array = missing_focus_value.get("data", {}).get("workflow", [])
	var missing_focus_value_step: Dictionary = missing_focus_value_workflow[missing_focus_value_workflow.size() - 1] if not missing_focus_value_workflow.is_empty() else {}
	if str(missing_focus_value_step.get("reason", "")) != "surface_not_visible":
		return _failure("focus_value missing-surface failure should report surface_not_visible.")
	var missing_activate_tab := impl.execute("settings_dialog", {
		"action": "activate_tab",
		"surface": "project_settings",
		"tab": "Plugins"
	})
	if bool(missing_activate_tab.get("success", false)):
		return _failure("activate_tab should fail when the requested settings surface is not visible.")

	var opened := await impl.execute_async("settings_dialog", {"action": "open", "surface": "project_settings", "timeout_ms": 500})
	if not bool(opened.get("success", false)):
		return _failure("open should select the Project Settings menu item and wait for the dialog.")
	if not bool(opened.get("data", {}).get("dialog_found", false)):
		return _failure("open should return dialog_found=true after the surface appears.")
	if not _has_call(fake.calls, "editor_ui_control", "select_menu_item"):
		return _failure("open should delegate to editor_ui_control.select_menu_item.")
	if not _has_async_call(fake.calls, "editor_ui_control", "wait_for_ui"):
		return _failure("open should delegate to editor_ui_control.wait_for_ui.")
	if not _has_menu_item_call(fake.calls, fake.localized_project_item):
		return _failure("open should try localized Project Settings menu item candidates.")

	var calls_before_list_tabs := fake.calls.size()
	var listed_tabs := impl.execute("settings_dialog", {
		"action": "list_tabs",
		"surface": "project_settings"
	})
	if not bool(listed_tabs.get("success", false)):
		return _failure("list_tabs should succeed against a visible settings surface.")
	var listed_tabs_data: Dictionary = listed_tabs.get("data", {})
	if int(listed_tabs_data.get("tab_count", 0)) != 5:
		return _failure("list_tabs should return the settings TabContainer tabs.")
	if str(listed_tabs_data.get("current_tab", "")) != "General" or int(listed_tabs_data.get("current_tab_index", -1)) != 0:
		return _failure("list_tabs should report the current settings tab.")
	if not _has_tab_title(listed_tabs_data.get("tabs", []), "Plugins"):
		return _failure("list_tabs should expose Project Settings tab titles.")
	if _has_call_since(fake.calls, calls_before_list_tabs, "editor_ui_control", "set_text"):
		return _failure("list_tabs must not write the settings search field.")

	var calls_before_activate_tab := fake.calls.size()
	var activated_tab := impl.execute("settings_dialog", {
		"action": "activate_tab",
		"surface": "project_settings",
		"tab": "Plugins"
	})
	if not bool(activated_tab.get("success", false)):
		return _failure("activate_tab should activate a visible settings tab by title.")
	if fake.project_current_tab_index != 3:
		return _failure("activate_tab should delegate tab switching through editor_ui_control.activate_ui.")
	if str(activated_tab.get("data", {}).get("selected_tab", {}).get("title", "")) != "Plugins":
		return _failure("activate_tab should report the selected tab metadata.")
	if not _has_call_since(fake.calls, calls_before_activate_tab, "editor_ui_control", "activate_ui"):
		return _failure("activate_tab should call editor_ui_control.activate_ui.")
	if _has_call_since(fake.calls, calls_before_activate_tab, "editor_ui_control", "set_text"):
		return _failure("activate_tab must not write the settings search field.")

	var activated_tab_by_index := impl.execute("settings_dialog", {
		"action": "activate_tab",
		"surface": "project_settings",
		"tab_index": 0
	})
	if not bool(activated_tab_by_index.get("success", false)) or fake.project_current_tab_index != 0:
		return _failure("activate_tab should activate a visible settings tab by index.")
	var missing_selector_tab := impl.execute("settings_dialog", {
		"action": "activate_tab",
		"surface": "project_settings"
	})
	if bool(missing_selector_tab.get("success", false)):
		return _failure("activate_tab should require either tab or tab_index.")
	var unknown_tab := impl.execute("settings_dialog", {
		"action": "activate_tab",
		"surface": "project_settings",
		"tab": "Missing"
	})
	if bool(unknown_tab.get("success", false)) or str(unknown_tab.get("data", {}).get("resolution", {}).get("reason", "")) != "tab_not_found":
		return _failure("activate_tab should fail with tab_not_found for unknown tabs.")

	var calls_before_list_categories := fake.calls.size()
	var listed_categories := impl.execute("settings_dialog", {
		"action": "list_categories",
		"surface": "project_settings",
		"category": "Application",
		"limit": 10
	})
	if not bool(listed_categories.get("success", false)):
		return _failure("list_categories should succeed against a visible settings category tree.")
	var category_data: Dictionary = listed_categories.get("data", {})
	if int(category_data.get("category_count", 0)) != 3:
		return _failure("list_categories should return matching visible category tree items.")
	if str(category_data.get("tree_control_path", "")) != "/root/ProjectSettings/SectionedInspector/Left/Sections":
		return _failure("list_categories should report the SectionedInspector category tree control path.")
	var project_categories: Array = category_data.get("categories", [])
	if _find_category_by_path(project_categories, "Advanced Settings").is_empty() == false:
		return _failure("list_categories must not include items from non-category settings Tree controls.")
	if _find_category_by_path(project_categories, "Inspector Settings").is_empty() == false:
		return _failure("list_categories must not include Tree items nested under the settings EditorInspector.")
	var config_category := _find_category_by_path(project_categories, "Application/Config")
	if config_category.is_empty():
		return _failure("list_categories should preserve nested category_path evidence.")
	if str(config_category.get("confidence", "")) != "high":
		return _failure("list_categories should assign high confidence to category tree items with path and index.")
	if _has_call_since(fake.calls, calls_before_list_categories, "editor_ui_control", "set_text"):
		return _failure("list_categories must not write the settings search field.")

	var focused_category := impl.execute("settings_dialog", {
		"action": "focus_category",
		"surface": "project_settings",
		"category_path": "Application/Config",
		"limit": 10
	})
	if not bool(focused_category.get("success", false)):
		return _failure("focus_category should select a unique visible settings category.")
	if not _has_call(fake.calls, "editor_ui_control", "select_tree_item"):
		return _failure("focus_category should delegate to editor_ui_control.select_tree_item.")
	if str(focused_category.get("data", {}).get("focused_category", {}).get("category_path", "")) != "Application/Config":
		return _failure("focus_category should return the focused category model.")

	var ambiguous_category := impl.execute("settings_dialog", {
		"action": "focus_category",
		"surface": "project_settings",
		"query": "Application",
		"limit": 10
	})
	if bool(ambiguous_category.get("success", false)):
		return _failure("focus_category should fail when multiple categories match the selector.")
	if str(ambiguous_category.get("data", {}).get("resolution", {}).get("reason", "")) != "ambiguous_category":
		return _failure("focus_category ambiguous failure should report ambiguous_category.")

	var searched := await impl.execute_async("settings_dialog", {
		"action": "search",
		"surface": "project_settings",
		"setting_path": "application/config/name",
		"limit": 10
	})
	if not bool(searched.get("success", false)):
		return _failure("search should succeed against visible controls.")
	if int(searched.get("data", {}).get("result_count", 0)) != 1:
		return _failure("search should return the matching setting-like row only.")
	var first_result := ((searched.get("data", {}).get("results", []) as Array)[0]) as Dictionary
	if str(first_result.get("setting_path_hint", "")) != "application/config/name":
		return _failure("search should preserve conservative setting_path_hint evidence.")
	if not _has_call(fake.calls, "editor_ui_control", "set_text"):
		return _failure("search should write the query into the settings search field.")

	var calls_before_list_rows := fake.calls.size()
	var listed_rows := impl.execute("settings_dialog", {
		"action": "list_rows",
		"surface": "project_settings",
		"setting_path": "application/config/name",
		"limit": 10
	})
	if not bool(listed_rows.get("success", false)):
		return _failure("list_rows should succeed against visible controls.")
	if int(listed_rows.get("data", {}).get("row_count", 0)) != 1:
		return _failure("list_rows should return conservative read-only row models.")
	var first_row := ((listed_rows.get("data", {}).get("rows", []) as Array)[0]) as Dictionary
	if str(first_row.get("confidence", "")) != "medium":
		return _failure("list_rows should assign medium confidence when row has label/path but no stable setting path.")
	if str(first_row.get("row_control_path", "")) != "/root/ProjectSettings/General/Application/Config/Name":
		return _failure("list_rows should preserve the row_control_path evidence.")
	if str(first_row.get("row_control_path", "")).ends_with("/Filter") or str(first_row.get("row_control_path", "")).ends_with("/Value"):
		return _failure("list_rows should not return filter or value child controls as setting rows.")
	if _has_call_since(fake.calls, calls_before_list_rows, "editor_ui_control", "set_text"):
		return _failure("list_rows must not write the settings search field.")

	var calls_before_resolve_row := fake.calls.size()
	var resolved_row := impl.execute("settings_dialog", {
		"action": "resolve_row",
		"surface": "project_settings",
		"setting_path": "application/config/name",
		"limit": 10
	})
	if not bool(resolved_row.get("success", false)):
		return _failure("resolve_row should succeed for a uniquely visible row.")
	var resolved_row_data: Dictionary = resolved_row.get("data", {})
	if str(resolved_row_data.get("row_control_path", "")) != "/root/ProjectSettings/General/Application/Config/Name":
		return _failure("resolve_row should return the unique row control path.")
	if str(resolved_row_data.get("value_control_path", "")) != "/root/ProjectSettings/General/Application/Config/Name/Value":
		return _failure("resolve_row should expose the matching value control path.")
	if str(resolved_row_data.get("resolution", {}).get("selector", {}).get("setting_path", "")) != "application/config/name":
		return _failure("resolve_row should preserve selector evidence.")
	if _has_value_payload_key(resolved_row_data.get("row", {})):
		return _failure("resolve_row should not expose value-bearing fields through the row payload.")
	if _has_value_payload_key(resolved_row_data.get("value_control", {})):
		return _failure("resolve_row should not expose value-bearing fields through the value control payload.")
	if _has_call_since(fake.calls, calls_before_resolve_row, "editor_ui_control", "set_text"):
		return _failure("resolve_row must not write the settings search field.")

	var resolved_by_value_path := impl.execute("settings_dialog", {
		"action": "resolve_row",
		"surface": "project_settings",
		"target_path": "/root/ProjectSettings/General/Application/Config/Name/Value",
		"limit": 10
	})
	if not bool(resolved_by_value_path.get("success", false)):
		return _failure("resolve_row should resolve a value child target_path back to its setting row.")
	if str(resolved_by_value_path.get("data", {}).get("row_control_path", "")) != "/root/ProjectSettings/General/Application/Config/Name":
		return _failure("resolve_row value child resolution should return the row path.")
	var resolved_by_value_text := impl.execute("settings_dialog", {
		"action": "resolve_row",
		"surface": "project_settings",
		"query": "Example",
		"limit": 10
	})
	if bool(resolved_by_value_text.get("success", false)):
		return _failure("resolve_row should not match rows by current value text.")
	if str(resolved_by_value_text.get("message", "")).contains("read_value"):
		return _failure("resolve_row value-text miss should not mention read_value in the public message.")

	var calls_before_read_value := fake.calls.size()
	var read_value := impl.execute("settings_dialog", {
		"action": "read_value",
		"surface": "project_settings",
		"setting_path": "application/config/name",
		"limit": 10
	})
	if not bool(read_value.get("success", false)):
		return _failure("read_value should succeed for a uniquely visible row.")
	var read_value_data: Dictionary = read_value.get("data", {})
	if str(read_value_data.get("value", "")) != "Example" or str(read_value_data.get("value_text", "")) != "Example":
		return _failure("read_value should return the current text value and raw value_text.")
	if str(read_value_data.get("value_editor_type", "")) != "text":
		return _failure("read_value should classify LineEdit value controls as text.")
	if str(read_value_data.get("value_source", "")) != "/root/ProjectSettings/General/Application/Config/Name/Value":
		return _failure("read_value should report the value child control as value_source.")
	if _has_call_since(fake.calls, calls_before_read_value, "editor_ui_control", "set_text"):
		return _failure("read_value must not write the settings search field.")
	var calls_before_verify_value := fake.calls.size()
	var verified_text_value := impl.execute("settings_dialog", {
		"action": "verify_value",
		"surface": "project_settings",
		"setting_path": "application/config/name",
		"expected_value": "Example",
		"limit": 10
	})
	if not bool(verified_text_value.get("success", false)):
		return _failure("verify_value should succeed when a visible text row matches expected_value.")
	if not bool(verified_text_value.get("data", {}).get("verification", {}).get("success", false)):
		return _failure("verify_value should return verification.success=true for matching text.")
	var verified_text_workflow: Array = verified_text_value.get("data", {}).get("workflow", [])
	if verified_text_workflow.is_empty() or str(verified_text_workflow[verified_text_workflow.size() - 1].get("step", "")) != "verify_value":
		return _failure("verify_value should append a verify_value workflow step.")
	if _has_call_since(fake.calls, calls_before_verify_value, "editor_ui_control", "set_text"):
		return _failure("verify_value must not write the settings search field.")
	var mismatched_text_value := impl.execute("settings_dialog", {
		"action": "verify_value",
		"surface": "project_settings",
		"setting_path": "application/config/name",
		"expected_value": "Other",
		"limit": 10
	})
	if bool(mismatched_text_value.get("success", false)):
		return _failure("verify_value should fail when the visible text row differs from expected_value.")
	if str(mismatched_text_value.get("data", {}).get("verification", {}).get("reason", "")) != "value_mismatch":
		return _failure("verify_value mismatch should report value_mismatch.")
	var read_value_by_value_path := impl.execute("settings_dialog", {
		"action": "read_value",
		"surface": "project_settings",
		"target_path": "/root/ProjectSettings/General/Application/Config/Name/Value",
		"limit": 10
	})
	if not bool(read_value_by_value_path.get("success", false)):
		return _failure("read_value should resolve a value child target_path back to its setting row.")
	var calls_before_focus_value := fake.calls.size()
	var focused_value := impl.execute("settings_dialog", {
		"action": "focus_value",
		"surface": "project_settings",
		"setting_path": "application/config/name",
		"limit": 10
	})
	if not bool(focused_value.get("success", false)):
		return _failure("focus_value should focus a uniquely visible row value control.")
	var focused_value_data: Dictionary = focused_value.get("data", {})
	if str(focused_value_data.get("value_control_path", "")) != "/root/ProjectSettings/General/Application/Config/Name/Value":
		return _failure("focus_value should return the focused value control path.")
	if str(focused_value_data.get("focused_value", {}).get("editor_type", "")) != "text":
		return _failure("focus_value should classify the focused value editor type.")
	if not _has_call_since_with_target(fake.calls, calls_before_focus_value, "editor_ui_control", "focus_control", "/root/ProjectSettings/General/Application/Config/Name/Value"):
		return _failure("focus_value should delegate to editor_ui_control.focus_control for the value control.")
	if _has_call_since(fake.calls, calls_before_focus_value, "editor_ui_control", "set_text"):
		return _failure("focus_value must not write the settings search field.")
	var focus_value_by_value_path := impl.execute("settings_dialog", {
		"action": "focus_value",
		"surface": "project_settings",
		"target_path": "/root/ProjectSettings/General/Application/Config/Name/Value",
		"limit": 10
	})
	if not bool(focus_value_by_value_path.get("success", false)):
		return _failure("focus_value should resolve a value child target_path back to its setting row.")
	var set_text_value := await impl.execute_async("settings_dialog", {
		"action": "set_value",
		"surface": "project_settings",
		"setting_path": "application/config/name",
		"value": "Renamed Project",
		"limit": 10
	})
	if not bool(set_text_value.get("success", false)):
		return _failure("set_value should update a unique text row.")
	if str(set_text_value.get("data", {}).get("before", {}).get("value", "")) != "Example":
		return _failure("set_value should report the previous text value.")
	if str(set_text_value.get("data", {}).get("after", {}).get("value", "")) != "Renamed Project":
		return _failure("set_value should verify the updated text value.")
	if str(set_text_value.get("data", {}).get("write", {}).get("write_action", "")) != "set_text":
		return _failure("set_value should use editor_ui_control.set_text for text rows.")
	var hidden_set_value := await impl.execute_async("settings_dialog", {
		"action": "set_value",
		"surface": "project_settings",
		"setting_path": "application/config/name",
		"value": "HiddenWrite",
		"include_hidden": true,
		"limit": 10
	})
	if bool(hidden_set_value.get("success", false)) or str(hidden_set_value.get("data", {}).get("reason", "")) != "hidden_write_refused":
		return _failure("set_value should refuse direct hidden-control writes.")
	var low_confidence_set_value := await impl.execute_async("settings_dialog", {
		"action": "set_value",
		"surface": "project_settings",
		"setting_path": "application/config/name",
		"value": "LowConfidenceWrite",
		"require_confidence": "low",
		"limit": 10
	})
	if bool(low_confidence_set_value.get("success", false)) or str(low_confidence_set_value.get("data", {}).get("reason", "")) != "low_confidence_write_refused":
		return _failure("set_value should refuse direct low-confidence writes.")

	await impl.execute_async("settings_dialog", {
		"action": "search",
		"surface": "project_settings",
		"setting_path": "application/config/use_custom_user_dir",
		"limit": 10
	})
	var bool_value := impl.execute("settings_dialog", {
		"action": "read_value",
		"surface": "project_settings",
		"setting_path": "application/config/use_custom_user_dir",
		"limit": 10
	})
	if not bool(bool_value.get("success", false)) or bool(bool_value.get("data", {}).get("value", false)) != true:
		return _failure("read_value should return a typed true value for CheckBox rows.")
	if str(bool_value.get("data", {}).get("value_editor_type", "")) != "bool":
		return _failure("read_value should classify CheckBox value controls as bool.")
	var verified_bool_value := impl.execute("settings_dialog", {
		"action": "verify_value",
		"surface": "project_settings",
		"setting_path": "application/config/use_custom_user_dir",
		"expected_value": true,
		"limit": 10
	})
	if not bool(verified_bool_value.get("success", false)):
		return _failure("verify_value should succeed when a visible bool row matches expected_value.")
	var bool_type_mismatch := impl.execute("settings_dialog", {
		"action": "verify_value",
		"surface": "project_settings",
		"setting_path": "application/config/use_custom_user_dir",
		"expected_value": "true",
		"limit": 10
	})
	if bool(bool_type_mismatch.get("success", false)):
		return _failure("verify_value should fail when a bool row is compared with non-bool expected_value.")
	if str(bool_type_mismatch.get("data", {}).get("verification", {}).get("reason", "")) != "type_mismatch":
		return _failure("verify_value bool type mismatch should report type_mismatch.")
	var set_bool_value := await impl.execute_async("settings_dialog", {
		"action": "set_value",
		"surface": "project_settings",
		"setting_path": "application/config/use_custom_user_dir",
		"value": false,
		"limit": 10
	})
	if not bool(set_bool_value.get("success", false)):
		return _failure("set_value should update a unique bool row.")
	if bool(set_bool_value.get("data", {}).get("after", {}).get("value", true)) != false:
		return _failure("set_value should verify the updated bool value.")
	if str(set_bool_value.get("data", {}).get("write", {}).get("write_action", "")) != "activate_control":
		return _failure("set_value should use editor_ui_control.activate_control when a bool row changes.")
	var set_bool_noop := await impl.execute_async("settings_dialog", {
		"action": "set_value",
		"surface": "project_settings",
		"setting_path": "application/config/use_custom_user_dir",
		"value": false,
		"limit": 10
	})
	if not bool(set_bool_noop.get("success", false)) or str(set_bool_noop.get("data", {}).get("write", {}).get("write_action", "")) != "noop":
		return _failure("set_value should no-op when a bool row already has the requested value.")

	await impl.execute_async("settings_dialog", {
		"action": "search",
		"surface": "project_settings",
		"setting_path": "application/config/display_enabled_label",
		"limit": 10
	})
	var bool_text_only_value := impl.execute("settings_dialog", {
		"action": "read_value",
		"surface": "project_settings",
		"setting_path": "application/config/display_enabled_label",
		"limit": 10
	})
	if not bool(bool_text_only_value.get("success", false)):
		return _failure("read_value should still return text-only bool-like controls as observable values.")
	if bool_text_only_value.get("data", {}).get("value", false) is bool:
		return _failure("read_value must not infer bool true/false from label text without explicit pressed/button_pressed/value state.")
	if str(bool_text_only_value.get("data", {}).get("value", "")) != "Enabled":
		return _failure("read_value should preserve raw text for bool-like controls without explicit state fields.")
	var set_bool_text_only := await impl.execute_async("settings_dialog", {
		"action": "set_value",
		"surface": "project_settings",
		"setting_path": "application/config/display_enabled_label",
		"value": false,
		"limit": 10
	})
	if bool(set_bool_text_only.get("success", false)):
		return _failure("set_value should fail when a bool-like row lacks explicit current state.")
	if str(set_bool_text_only.get("data", {}).get("write", {}).get("reason", "")) != "bool_state_unavailable":
		return _failure("set_value bool text-only failure should report bool_state_unavailable.")

	await impl.execute_async("settings_dialog", {
		"action": "search",
		"surface": "project_settings",
		"setting_path": "rendering/2d/snap/snap_2d_transforms_to_pixel",
		"limit": 10
	})
	var false_value := impl.execute("settings_dialog", {
		"action": "read_value",
		"surface": "project_settings",
		"setting_path": "rendering/2d/snap/snap_2d_transforms_to_pixel",
		"limit": 10
	})
	if not bool(false_value.get("success", false)) or bool(false_value.get("data", {}).get("value", true)) != false:
		return _failure("read_value should return a typed false value for CheckButton rows.")
	if str(false_value.get("data", {}).get("row", {}).get("setting_path", "")) != "rendering/2d/snap/snap_2d_transforms_to_pixel":
		return _failure("read_value should preserve 2D-style setting path hints without inserting stray underscores.")

	await impl.execute_async("settings_dialog", {
		"action": "search",
		"surface": "project_settings",
		"setting_path": "rendering/limits/rendering/max_renderable_elements",
		"limit": 10
	})
	var number_value := impl.execute("settings_dialog", {
		"action": "read_value",
		"surface": "project_settings",
		"setting_path": "rendering/limits/rendering/max_renderable_elements",
		"limit": 10
	})
	if not bool(number_value.get("success", false)) or float(number_value.get("data", {}).get("value", 0.0)) != 128000.0:
		return _failure("read_value should return a typed number value for SpinBox rows.")
	var verified_number_value := impl.execute("settings_dialog", {
		"action": "verify_value",
		"surface": "project_settings",
		"setting_path": "rendering/limits/rendering/max_renderable_elements",
		"expected_value": "128000",
		"limit": 10
	})
	if not bool(verified_number_value.get("success", false)):
		return _failure("verify_value should compare numeric strings against number rows.")
	var set_number_value := await impl.execute_async("settings_dialog", {
		"action": "set_value",
		"surface": "project_settings",
		"setting_path": "rendering/limits/rendering/max_renderable_elements",
		"value": 64000,
		"limit": 10
	})
	if not bool(set_number_value.get("success", false)):
		return _failure("set_value should update a unique number row.")
	if float(set_number_value.get("data", {}).get("after", {}).get("value", 0.0)) != 64000.0:
		return _failure("set_value should verify the updated number value.")
	if str(set_number_value.get("data", {}).get("write", {}).get("write_action", "")) != "set_value":
		return _failure("set_value should use editor_ui_control.set_value for number rows.")
	await impl.execute_async("settings_dialog", {
		"action": "search",
		"surface": "project_settings",
		"setting_path": "editor/direct_spin",
		"limit": 10
	})
	var set_direct_value := await impl.execute_async("settings_dialog", {
		"action": "set_value",
		"surface": "project_settings",
		"setting_path": "editor/direct_spin",
		"value": 7,
		"limit": 10
	})
	if not bool(set_direct_value.get("success", false)):
		return _failure("set_value should update a unique row that is itself a writable value control.")
	if str(set_direct_value.get("data", {}).get("write", {}).get("value_control_path", "")) != "/root/ProjectSettings/General/Editor/DirectSpin":
		return _failure("set_value should target the direct value row when no child value control exists.")
	if float(set_direct_value.get("data", {}).get("after", {}).get("value", 0.0)) != 7.0:
		return _failure("set_value should verify direct value row updates.")
	var focus_direct_value := impl.execute("settings_dialog", {
		"action": "focus_value",
		"surface": "project_settings",
		"setting_path": "editor/direct_spin",
		"limit": 10
	})
	if not bool(focus_direct_value.get("success", false)):
		return _failure("focus_value should focus a direct value row when the row itself is a value editor.")
	if str(focus_direct_value.get("data", {}).get("value_control_path", "")) != "/root/ProjectSettings/General/Editor/DirectSpin":
		return _failure("focus_value should target the direct value row itself when no child value control exists.")

	await impl.execute_async("settings_dialog", {
		"action": "search",
		"surface": "project_settings",
		"setting_path": "editor/plain_slider",
		"limit": 10
	})
	var slider_value := impl.execute("settings_dialog", {
		"action": "read_value",
		"surface": "project_settings",
		"setting_path": "editor/plain_slider",
		"limit": 10
	})
	if not bool(slider_value.get("success", false)) or str(slider_value.get("data", {}).get("value_editor_type", "")) != "number":
		return _failure("read_value should classify plain Slider rows as number values.")
	var set_slider_value := await impl.execute_async("settings_dialog", {
		"action": "set_value",
		"surface": "project_settings",
		"setting_path": "editor/plain_slider",
		"value": 0.75,
		"limit": 10
	})
	if not bool(set_slider_value.get("success", false)):
		return _failure("set_value should update a unique plain Slider row.")
	if str(set_slider_value.get("data", {}).get("write", {}).get("value_editor_type", "")) != "number":
		return _failure("set_value should preserve number editor typing for plain Slider rows.")
	if float(set_slider_value.get("data", {}).get("after", {}).get("value", 0.0)) != 0.75:
		return _failure("set_value should verify plain Slider row updates.")

	await impl.execute_async("settings_dialog", {
		"action": "search",
		"surface": "project_settings",
		"setting_path": "editor/plain_label",
		"limit": 10
	})
	var focus_plain_label := impl.execute("settings_dialog", {
		"action": "focus_value",
		"surface": "project_settings",
		"setting_path": "editor/plain_label",
		"limit": 10
	})
	if bool(focus_plain_label.get("success", false)):
		return _failure("focus_value should not focus a plain settings row with no value control.")
	var focus_plain_label_workflow: Array = focus_plain_label.get("data", {}).get("workflow", [])
	var focus_plain_label_step: Dictionary = focus_plain_label_workflow[focus_plain_label_workflow.size() - 1] if not focus_plain_label_workflow.is_empty() else {}
	if str(focus_plain_label_step.get("reason", "")) != "value_control_not_found":
		return _failure("focus_value plain-row failure should report value_control_not_found.")

	await impl.execute_async("settings_dialog", {
		"action": "search",
		"surface": "project_settings",
		"setting_path": "editor/display_value_label",
		"limit": 10
	})
	var focus_display_value_label := impl.execute("settings_dialog", {
		"action": "focus_value",
		"surface": "project_settings",
		"setting_path": "editor/display_value_label",
		"limit": 10
	})
	if bool(focus_display_value_label.get("success", false)):
		return _failure("focus_value should not focus a display-only /Value label.")
	var focus_display_value_workflow: Array = focus_display_value_label.get("data", {}).get("workflow", [])
	var focus_display_value_step: Dictionary = focus_display_value_workflow[focus_display_value_workflow.size() - 1] if not focus_display_value_workflow.is_empty() else {}
	if str(focus_display_value_step.get("reason", "")) != "value_control_not_found":
		return _failure("focus_value display-only value failure should report value_control_not_found.")

	await impl.execute_async("settings_dialog", {
		"action": "search",
		"surface": "project_settings",
		"setting_path": "application/run/main_scene",
		"limit": 10
	})
	var enum_value := impl.execute("settings_dialog", {
		"action": "read_value",
		"surface": "project_settings",
		"setting_path": "application/run/main_scene",
		"limit": 10
	})
	var enum_payload = enum_value.get("data", {}).get("value", {})
	if not bool(enum_value.get("success", false)) or not (enum_payload is Dictionary):
		return _failure("read_value should return structured enum value data for OptionButton rows.")
	if str((enum_payload as Dictionary).get("text", "")) != "res://Main.tscn" or int((enum_payload as Dictionary).get("selected", -1)) != 2:
		return _failure("read_value should preserve enum selected text and index.")
	var verified_enum_text := impl.execute("settings_dialog", {
		"action": "verify_value",
		"surface": "project_settings",
		"setting_path": "application/run/main_scene",
		"expected_value": "res://Main.tscn",
		"limit": 10
	})
	if not bool(verified_enum_text.get("success", false)):
		return _failure("verify_value should compare enum text against string expected_value.")
	var verified_enum_selected := impl.execute("settings_dialog", {
		"action": "verify_value",
		"surface": "project_settings",
		"setting_path": "application/run/main_scene",
		"expected_value": {"text": "res://Main.tscn", "selected": 2},
		"limit": 10
	})
	if not bool(verified_enum_selected.get("success", false)):
		return _failure("verify_value should compare enum text and selected index from dictionary expected_value.")
	var set_enum_value := await impl.execute_async("settings_dialog", {
		"action": "set_value",
		"surface": "project_settings",
		"setting_path": "application/run/main_scene",
		"value": "res://Other.tscn",
		"limit": 10
	})
	if bool(set_enum_value.get("success", false)):
		return _failure("set_value should not claim support for enum rows yet.")
	if str(set_enum_value.get("data", {}).get("write", {}).get("reason", "")) != "unsupported_value_editor_type":
		return _failure("set_value enum failure should report unsupported_value_editor_type.")

	await impl.execute_async("settings_dialog", {
		"action": "search",
		"surface": "project_settings",
		"setting_path": "ambiguous/example",
		"limit": 10
	})
	var ambiguous_value := impl.execute("settings_dialog", {
		"action": "read_value",
		"surface": "project_settings",
		"setting_path": "ambiguous/example",
		"limit": 1
	})
	if bool(ambiguous_value.get("success", false)):
		return _failure("read_value should fail when multiple rows match the selector even if the requested limit is small.")
	if str(ambiguous_value.get("data", {}).get("resolution", {}).get("reason", "")) != "ambiguous_row":
		return _failure("read_value ambiguous failure should report the ambiguous_row reason.")
	var ambiguous_verified_value := impl.execute("settings_dialog", {
		"action": "verify_value",
		"surface": "project_settings",
		"setting_path": "ambiguous/example",
		"expected_value": "x",
		"limit": 1
	})
	if bool(ambiguous_verified_value.get("success", false)):
		return _failure("verify_value should fail when multiple rows match the selector.")
	if str(ambiguous_verified_value.get("data", {}).get("resolution", {}).get("reason", "")) != "ambiguous_row":
		return _failure("verify_value ambiguous failure should preserve ambiguous_row resolution.")
	var ambiguous_set_value := await impl.execute_async("settings_dialog", {
		"action": "set_value",
		"surface": "project_settings",
		"setting_path": "ambiguous/example",
		"value": "x",
		"limit": 1
	})
	if bool(ambiguous_set_value.get("success", false)):
		return _failure("set_value should fail when multiple rows match the selector even if the requested limit is small.")
	if str(ambiguous_set_value.get("data", {}).get("resolution", {}).get("reason", "")) != "ambiguous_row":
		return _failure("set_value ambiguous failure should report the ambiguous_row reason.")
	var ambiguous_focus_value := impl.execute("settings_dialog", {
		"action": "focus_value",
		"surface": "project_settings",
		"setting_path": "ambiguous/example",
		"limit": 1
	})
	if bool(ambiguous_focus_value.get("success", false)):
		return _failure("focus_value should fail when multiple rows match the selector even if the requested limit is small.")
	if str(ambiguous_focus_value.get("data", {}).get("resolution", {}).get("reason", "")) != "ambiguous_row":
		return _failure("focus_value ambiguous failure should report the ambiguous_row reason.")

	var ambiguous_resolve := impl.execute("settings_dialog", {
		"action": "resolve_row",
		"surface": "project_settings",
		"setting_path": "ambiguous/example",
		"limit": 1
	})
	if bool(ambiguous_resolve.get("success", false)):
		return _failure("resolve_row should fail when multiple rows match the selector even if the requested limit is small.")
	if str(ambiguous_resolve.get("data", {}).get("resolution", {}).get("reason", "")) != "ambiguous_row":
		return _failure("resolve_row ambiguous failure should report the ambiguous_row reason.")
	if str(ambiguous_resolve.get("message", "")).contains("read_value"):
		return _failure("resolve_row ambiguous failure should not mention read_value in the public message.")
	var ambiguous_resolve_data: Dictionary = ambiguous_resolve.get("data", {})
	if ambiguous_resolve_data.has("all_controls") or ambiguous_resolve_data.has("results"):
		return _failure("resolve_row ambiguous failure should not expose raw observed controls or results.")
	if _has_value_payload_key(ambiguous_resolve_data.get("resolution", {})):
		return _failure("resolve_row ambiguous failure should not expose value-bearing fields through resolution candidates.")

	fake.project_name_value = "Example"
	var calls_before_read_task := fake.calls.size()
	var read_task := await impl.execute_async("settings_dialog", {
		"action": "run_task",
		"surface": "project_settings",
		"category_path": "Application/Config",
		"setting_path": "application/config/name",
		"capture_policy": "none",
		"limit": 10
	})
	if not bool(read_task.get("success", false)):
		return _failure("run_task read mode should open, locate, resolve, and read a unique settings row.")
	var read_task_data: Dictionary = read_task.get("data", {})
	if str(read_task_data.get("task_action", "")) != "run_task" or str(read_task_data.get("mode", "")) != "read":
		return _failure("run_task read mode should report its task action and mode.")
	if str(read_task_data.get("before", {}).get("value", "")) != "Example":
		return _failure("run_task read mode should preserve the before value payload.")
	if not read_task_data.get("steps", {}).has("open") or not read_task_data.get("steps", {}).has("resolve_row") or not read_task_data.get("steps", {}).has("read_before"):
		return _failure("run_task read mode should preserve high-level step evidence.")
	if _task_steps_have_raw_payload(read_task_data.get("steps", {})):
		return _failure("run_task step evidence should summarize workflow data without exposing raw control/result payloads.")
	if _has_call_since(fake.calls, calls_before_read_task, "editor_ui_control", "set_value") or _has_call_since(fake.calls, calls_before_read_task, "editor_ui_control", "activate_control"):
		return _failure("run_task read mode must not invoke write-oriented editor controls.")

	var verify_task := await impl.execute_async("settings_dialog", {
		"action": "run_task",
		"surface": "project_settings",
		"setting_path": "application/config/name",
		"expected_value": "Example",
		"capture_policy": "none",
		"limit": 10
	})
	if not bool(verify_task.get("success", false)):
		return _failure("run_task verify mode should succeed when expected_value matches.")
	if str(verify_task.get("data", {}).get("mode", "")) != "verify":
		return _failure("run_task verify mode should be reported when expected_value is supplied without value.")
	if not bool(verify_task.get("data", {}).get("verification", {}).get("performed", false)):
		return _failure("run_task verify mode should report performed verification.")
	if str(verify_task.get("data", {}).get("verification", {}).get("expected_source", "")) != "expected_value":
		return _failure("run_task verify mode should mark expected_value as the expected source.")

	var verify_task_mismatch := await impl.execute_async("settings_dialog", {
		"action": "run_task",
		"surface": "project_settings",
		"setting_path": "application/config/name",
		"expected_value": "Mismatch",
		"capture_policy": "on_failure",
		"limit": 10
	})
	if bool(verify_task_mismatch.get("success", false)):
		return _failure("run_task verify mode should fail when expected_value does not match.")
	if str(verify_task_mismatch.get("data", {}).get("failed_step", "")) != "verify_after":
		return _failure("run_task verify mismatch should fail at verify_after.")
	if str(verify_task_mismatch.get("data", {}).get("capture_backend", "")) != "popup":
		return _failure("run_task on_failure capture policy should capture failure evidence.")

	var calls_before_final_mismatch := fake.calls.size()
	var final_verify_task_mismatch := await impl.execute_async("settings_dialog", {
		"action": "run_task",
		"surface": "project_settings",
		"setting_path": "application/config/name",
		"expected_value": "Mismatch",
		"capture_policy": "final",
		"limit": 10
	})
	if bool(final_verify_task_mismatch.get("success", false)):
		return _failure("run_task verify mode should fail when expected_value does not match under capture_policy=final.")
	if str(final_verify_task_mismatch.get("data", {}).get("failed_step", "")) != "verify_after":
		return _failure("run_task final capture policy mismatch should fail at verify_after.")
	if str(final_verify_task_mismatch.get("data", {}).get("capture_backend", "")) != "none":
		return _failure("run_task capture_policy=final should not capture failure evidence.")
	if _has_call_since(fake.calls, calls_before_final_mismatch, "editor_popup", "capture_popup") or _has_call_since(fake.calls, calls_before_final_mismatch, "editor_ui_control", "capture_control") or _has_call_since(fake.calls, calls_before_final_mismatch, "editor_screenshot", "capture"):
		return _failure("run_task capture_policy=final failure path must not dispatch capture backends.")

	var set_task := await impl.execute_async("settings_dialog", {
		"action": "run_task",
		"surface": "project_settings",
		"setting_path": "application/config/name",
		"value": "Renamed",
		"capture_policy": "final",
		"limit": 10
	})
	if not bool(set_task.get("success", false)):
		return _failure("run_task set mode should write and verify supported text rows.")
	var set_task_data: Dictionary = set_task.get("data", {})
	if str(set_task_data.get("mode", "")) != "set":
		return _failure("run_task set mode should be reported when value is supplied without expected_value.")
	if str(set_task_data.get("before", {}).get("value", "")) != "Example" or str(set_task_data.get("after", {}).get("value", "")) != "Renamed":
		return _failure("run_task set mode should preserve before and after value payloads.")
	if str(set_task_data.get("verification", {}).get("expected_source", "")) != "value":
		return _failure("run_task set mode should default expected_value to value.")
	if not bool(set_task_data.get("write_attempted", false)) or not bool(set_task_data.get("write_verified", false)):
		return _failure("run_task set mode should mark successful write evidence.")
	if str(set_task_data.get("capture_backend", "")) != "popup":
		return _failure("run_task final capture policy should use surface-aware capture evidence.")

	var set_task_expected_mismatch := await impl.execute_async("settings_dialog", {
		"action": "run_task",
		"surface": "project_settings",
		"setting_path": "application/config/name",
		"value": "MismatchTarget",
		"expected_value": "AnotherValue",
		"capture_policy": "none",
		"limit": 10
	})
	if bool(set_task_expected_mismatch.get("success", false)):
		return _failure("run_task set_and_verify mode should fail when explicit expected_value does not match after writing.")
	if str(set_task_expected_mismatch.get("data", {}).get("failed_step", "")) != "verify_after":
		return _failure("run_task set_and_verify mismatch should fail at verify_after.")
	if not bool(set_task_expected_mismatch.get("data", {}).get("write_attempted", false)) or bool(set_task_expected_mismatch.get("data", {}).get("write_verified", true)):
		return _failure("run_task set_and_verify mismatch should preserve write side-effect evidence.")

	var calls_before_ambiguous_task := fake.calls.size()
	var ambiguous_task := await impl.execute_async("settings_dialog", {
		"action": "run_task",
		"surface": "project_settings",
		"setting_path": "ambiguous/example",
		"value": "Blocked",
		"capture_policy": "none",
		"limit": 10
	})
	if bool(ambiguous_task.get("success", false)):
		return _failure("run_task should fail before writing when row resolution is ambiguous.")
	if str(ambiguous_task.get("data", {}).get("failed_step", "")) != "resolve_row":
		return _failure("run_task ambiguous row should fail at resolve_row.")
	if _has_call_since(fake.calls, calls_before_ambiguous_task, "editor_ui_control", "set_value"):
		return _failure("run_task ambiguous row must not reach value writes.")

	var hidden_write_task := await impl.execute_async("settings_dialog", {
		"action": "run_task",
		"surface": "project_settings",
		"setting_path": "application/config/name",
		"value": "Hidden",
		"include_hidden": true
	})
	if bool(hidden_write_task.get("success", false)) or str(hidden_write_task.get("data", {}).get("reason", "")) != "hidden_write_refused":
		return _failure("run_task should refuse writes while include_hidden=true.")
	var low_confidence_task := await impl.execute_async("settings_dialog", {
		"action": "run_task",
		"surface": "project_settings",
		"setting_path": "application/config/name",
		"value": "Low",
		"require_confidence": "low"
	})
	if bool(low_confidence_task.get("success", false)) or str(low_confidence_task.get("data", {}).get("reason", "")) != "low_confidence_write_refused":
		return _failure("run_task should refuse low-confidence writes.")
	var missing_selector_task := await impl.execute_async("settings_dialog", {
		"action": "run_task",
		"surface": "project_settings",
		"capture_policy": "none"
	})
	if bool(missing_selector_task.get("success", false)) or str(missing_selector_task.get("data", {}).get("reason", "")) != "row_selector_required":
		return _failure("run_task should require a row selector.")

	var calls_before_capture_policy_refused := fake.calls.size()
	var capture_policy_refused_task := await impl.execute_async("settings_dialog", {
		"action": "run_task",
		"surface": "project_settings",
		"setting_path": "application/config/name",
		"require_capture": true,
		"capture_policy": "none",
		"limit": 10
	})
	if bool(capture_policy_refused_task.get("success", false)) or str(capture_policy_refused_task.get("data", {}).get("reason", "")) != "capture_policy_refused":
		return _failure("run_task should fail preflight when require_capture=true but capture_policy=none.")
	if fake.calls.size() != calls_before_capture_policy_refused:
		return _failure("run_task capture policy preflight failure must not touch the editor UI.")

	fake.popup_capture_enabled = false
	fake.control_capture_enabled = false
	fake.editor_capture_enabled = false
	var capture_required_task := await impl.execute_async("settings_dialog", {
		"action": "run_task",
		"surface": "project_settings",
		"setting_path": "application/config/name",
		"require_capture": true,
		"limit": 10
	})
	fake.popup_capture_enabled = true
	fake.control_capture_enabled = true
	fake.editor_capture_enabled = true
	if bool(capture_required_task.get("success", false)):
		return _failure("run_task should fail when require_capture=true and no capture backend succeeds.")
	if str(capture_required_task.get("data", {}).get("failed_step", "")) != "capture" or str(capture_required_task.get("data", {}).get("capture_backend", "")) != "none":
		return _failure("run_task require_capture failure should report capture as the failed step.")

	fake.popup_capture_enabled = false
	fake.control_capture_enabled = false
	fake.editor_capture_enabled = false
	var always_capture_best_effort_task := await impl.execute_async("settings_dialog", {
		"action": "run_task",
		"surface": "project_settings",
		"setting_path": "application/config/name",
		"capture_policy": "always",
		"limit": 10
	})
	fake.popup_capture_enabled = true
	fake.control_capture_enabled = true
	fake.editor_capture_enabled = true
	if not bool(always_capture_best_effort_task.get("success", false)):
		return _failure("run_task capture_policy=always should remain best-effort unless require_capture=true.")
	if str(always_capture_best_effort_task.get("data", {}).get("capture_backend", "")) != "none":
		return _failure("run_task capture_policy=always should report capture_backend=none when best-effort capture is unavailable.")

	fake.project_name_value = "Example"
	fake.popup_capture_enabled = false
	fake.control_capture_enabled = false
	fake.editor_capture_enabled = false
	var calls_before_capture_blocked_write := fake.calls.size()
	var capture_blocked_write := await impl.execute_async("settings_dialog", {
		"action": "run_task",
		"surface": "project_settings",
		"setting_path": "application/config/name",
		"value": "ShouldNotWrite",
		"require_capture": true,
		"capture_policy": "final",
		"limit": 10
	})
	fake.popup_capture_enabled = true
	fake.control_capture_enabled = true
	fake.editor_capture_enabled = true
	if bool(capture_blocked_write.get("success", false)):
		return _failure("run_task should fail before writing when required capture evidence is unavailable.")
	if fake.project_name_value != "Example":
		return _failure("run_task capture preflight failure must preserve the setting value before writes.")
	if _has_call_since_with_target(fake.calls, calls_before_capture_blocked_write, "editor_ui_control", "set_text", "/root/ProjectSettings/General/Application/Config/Name/Value"):
		return _failure("run_task capture preflight failure must not dispatch text writes.")
	if str(capture_blocked_write.get("data", {}).get("failed_step", "")) != "capture":
		return _failure("run_task capture preflight write block should report capture as the failed step.")

	var focused := impl.execute("settings_dialog", {
		"action": "focus_result",
		"surface": "project_settings",
		"target_path": str(first_result.get("path", ""))
	})
	if not bool(focused.get("success", false)):
		return _failure("focus_result should focus a returned result path.")
	if not _has_call(fake.calls, "editor_ui_control", "focus_control"):
		return _failure("focus_result should delegate to editor_ui_control.focus_control.")

	var calls_before_capture := fake.calls.size()
	var captured := impl.execute("settings_dialog", {
		"action": "capture",
		"surface": "project_settings",
		"path": "user://custom_settings.png"
	})
	if not bool(captured.get("success", false)):
		return _failure("capture should succeed for a visible settings surface.")
	var captured_data: Dictionary = captured.get("data", {})
	if str(captured_data.get("capture_path", "")) != "user://custom_settings.png":
		return _failure("capture should return the screenshot path from the selected capture backend.")
	if str(captured_data.get("capture_surface", "")) != "project_settings":
		return _failure("capture should preserve the requested settings surface.")
	if str(captured_data.get("capture_backend", "")) != "popup":
		return _failure("capture should prefer the visible settings popup backend.")
	if str(captured_data.get("capture_target_path", "")) != "/root/ProjectSettings":
		return _failure("capture should target the observed Project Settings popup path.")
	if str(captured_data.get("capture", {}).get("capture_mode", "")) != "popup":
		return _failure("capture should preserve popup capture payload metadata.")
	if not _has_call_since_with_target(fake.calls, calls_before_capture, "editor_popup", "capture_popup", "/root/ProjectSettings"):
		return _failure("capture should delegate to editor_popup.capture_popup for visible settings popups.")

	var calls_before_focused_capture := fake.calls.size()
	var focused_with_capture := impl.execute("settings_dialog", {
		"action": "focus_result",
		"surface": "project_settings",
		"target_path": str(first_result.get("path", "")),
		"capture": true
	})
	if not bool(focused_with_capture.get("success", false)):
		return _failure("focus_result(capture=true) should focus a returned result path.")
	var focused_capture_data: Dictionary = focused_with_capture.get("data", {})
	if str(focused_capture_data.get("capture_backend", "")) != "popup":
		return _failure("focus_result(capture=true) should recover settings surface context and prefer popup capture.")
	if not _has_call_since_with_target(fake.calls, calls_before_focused_capture, "editor_popup", "capture_popup", "/root/ProjectSettings"):
		return _failure("focus_result(capture=true) should delegate capture to the current settings popup.")

	fake.popup_capture_enabled = false
	var control_fallback := impl.execute("settings_dialog", {
		"action": "capture",
		"surface": "project_settings",
		"path": "user://control_fallback.png"
	})
	fake.popup_capture_enabled = true
	if not bool(control_fallback.get("success", false)):
		return _failure("capture should still succeed when popup capture is unavailable and control capture works.")
	var control_fallback_data: Dictionary = control_fallback.get("data", {})
	if str(control_fallback_data.get("capture_backend", "")) != "control":
		return _failure("capture should fall back from popup capture to control capture.")
	if str(control_fallback_data.get("capture_target_path", "")) != "/root/ProjectSettings":
		return _failure("control fallback should target the observed settings dialog control path.")
	if not (control_fallback_data.get("capture_fallback_reasons", []) as Array).has("popup_capture_failed"):
		return _failure("control fallback should report the failed popup capture attempt.")

	fake.popup_capture_enabled = false
	fake.control_capture_enabled = false
	var editor_fallback := impl.execute("settings_dialog", {
		"action": "capture",
		"surface": "project_settings",
		"path": "user://editor_fallback.png"
	})
	fake.popup_capture_enabled = true
	fake.control_capture_enabled = true
	if not bool(editor_fallback.get("success", false)):
		return _failure("capture should still succeed when only the full-editor screenshot backend works.")
	var editor_fallback_data: Dictionary = editor_fallback.get("data", {})
	if str(editor_fallback_data.get("capture_backend", "")) != "editor":
		return _failure("capture should fall back to full-editor screenshots after narrower targets fail.")
	var editor_fallback_reasons: Array = editor_fallback_data.get("capture_fallback_reasons", [])
	if not editor_fallback_reasons.has("popup_capture_failed") or not editor_fallback_reasons.has("control_capture_failed"):
		return _failure("editor fallback should report both narrower capture failures.")

	fake.popup_capture_enabled = false
	fake.control_capture_enabled = false
	fake.editor_capture_enabled = false
	var failed_capture := impl.execute("settings_dialog", {
		"action": "capture",
		"surface": "project_settings"
	})
	fake.popup_capture_enabled = true
	fake.control_capture_enabled = true
	fake.editor_capture_enabled = true
	if not bool(failed_capture.get("success", false)):
		return _failure("capture action should return a settings workflow payload even when evidence backends fail.")
	var failed_capture_data: Dictionary = failed_capture.get("data", {})
	if str(failed_capture_data.get("capture_backend", "")) != "none":
		return _failure("failed capture should report capture_backend=none.")
	if str(failed_capture_data.get("capture_error", "")).is_empty():
		return _failure("failed capture should preserve an error message from the final capture backend.")

	var closed := impl.execute("settings_dialog", {"action": "close", "surface": "project_settings"})
	if not bool(closed.get("success", false)):
		return _failure("close should close a visible settings popup.")
	if not _has_call(fake.calls, "editor_popup", "close_popup"):
		return _failure("close should delegate to editor_popup.close_popup.")

	var editor_opened := await impl.execute_async("settings_dialog", {"action": "open", "surface": "editor_settings"})
	if not bool(editor_opened.get("success", false)):
		return _failure("open should also support editor_settings.")
	if str(editor_opened.get("data", {}).get("surface", "")) != "editor_settings":
		return _failure("editor_settings open should preserve the requested surface.")
	if not _has_menu_item_call(fake.calls, fake.localized_editor_item):
		return _failure("open should try localized Editor Settings menu item candidates.")
	var editor_tabs := impl.execute("settings_dialog", {"action": "list_tabs", "surface": "editor_settings"})
	if not bool(editor_tabs.get("success", false)) or not _has_tab_title(editor_tabs.get("data", {}).get("tabs", []), "Shortcuts"):
		return _failure("list_tabs should also support editor_settings tabs.")
	var editor_categories := impl.execute("settings_dialog", {
		"action": "list_categories",
		"surface": "editor_settings",
		"category_path": "Interface/Editor",
		"limit": 10
	})
	if not bool(editor_categories.get("success", false)):
		return _failure("list_categories should also support editor_settings category trees.")
	if int(editor_categories.get("data", {}).get("category_count", 0)) != 1:
		return _failure("editor_settings list_categories should return only matching editor categories.")
	if str(((editor_categories.get("data", {}).get("categories", []) as Array)[0]).get("category_path", "")) != "Interface/Editor":
		return _failure("editor_settings list_categories should preserve editor category paths.")
	var editor_opened_with_tab := await impl.execute_async("settings_dialog", {"action": "open", "surface": "editor_settings", "tab": "Shortcuts"})
	if not bool(editor_opened_with_tab.get("success", false)):
		return _failure("open should activate a requested tab when the settings surface is already visible.")
	if fake.editor_current_tab_index != 1:
		return _failure("open(tab) should delegate to activate_tab for an already visible settings surface.")
	if str(editor_opened_with_tab.get("data", {}).get("tab_activation", {}).get("selected_tab", {}).get("title", "")) != "Shortcuts":
		return _failure("open(tab) should return the selected tab activation payload.")
	var calls_before_editor_capture := fake.calls.size()
	var editor_captured := impl.execute("settings_dialog", {
		"action": "capture",
		"surface": "editor_settings",
		"path": "user://editor_settings.png"
	})
	if not bool(editor_captured.get("success", false)):
		return _failure("capture should also support editor_settings surfaces.")
	var editor_capture_data: Dictionary = editor_captured.get("data", {})
	if str(editor_capture_data.get("capture_surface", "")) != "editor_settings":
		return _failure("editor_settings capture should preserve the requested surface.")
	if str(editor_capture_data.get("capture_backend", "")) != "popup":
		return _failure("editor_settings capture should use the same popup-first capture path.")
	if str(editor_capture_data.get("capture_target_path", "")) != "/root/EditorSettings":
		return _failure("editor_settings capture should target the observed Editor Settings popup path.")
	if not _has_call_since_with_target(fake.calls, calls_before_editor_capture, "editor_popup", "capture_popup", "/root/EditorSettings"):
		return _failure("editor_settings capture should delegate to editor_popup.capture_popup without Project Settings special cases.")
	var editor_wrong_surface_read := impl.execute("settings_dialog", {
		"action": "read_value",
		"surface": "editor_settings",
		"setting_path": "application/config/name",
		"limit": 10
	})
	if bool(editor_wrong_surface_read.get("success", false)):
		return _failure("read_value should not read Project Settings rows when editor_settings is the requested surface.")

	var editor_searched := await impl.execute_async("settings_dialog", {
		"action": "search",
		"surface": "editor_settings",
		"setting_path": "interface/editor/editor_language",
		"limit": 10
	})
	if not bool(editor_searched.get("success", false)):
		return _failure("search should also support editor_settings rows.")
	if int(editor_searched.get("data", {}).get("result_count", 0)) != 1:
		return _failure("editor_settings search should return the matching setting-like row.")
	var editor_result := ((editor_searched.get("data", {}).get("results", []) as Array)[0]) as Dictionary
	if str(editor_result.get("setting_path_hint", "")) != "interface/editor/language":
		return _failure("editor_settings search should derive the setting path without dropping the interface prefix.")

	return {"name": "system_settings_dialog_contracts", "success": true}


func _has_call(calls: Array, tool_name: String, action: String) -> bool:
	for call in calls:
		if str(call.get("tool", "")) == tool_name and str(call.get("action", "")) == action:
			return true
	return false


func _has_call_since(calls: Array, start_index: int, tool_name: String, action: String) -> bool:
	for index in range(start_index, calls.size()):
		var call: Dictionary = calls[index]
		if str(call.get("tool", "")) == tool_name and str(call.get("action", "")) == action:
			return true
	return false


func _has_call_since_with_target(calls: Array, start_index: int, tool_name: String, action: String, target_path: String) -> bool:
	for index in range(start_index, calls.size()):
		var call: Dictionary = calls[index]
		if str(call.get("tool", "")) == tool_name and str(call.get("action", "")) == action:
			if str(call.get("args", {}).get("target_path", "")) == target_path:
				return true
	return false


func _has_async_call(calls: Array, tool_name: String, action: String) -> bool:
	for call in calls:
		if str(call.get("tool", "")) == tool_name and str(call.get("action", "")) == action and bool(call.get("async", false)):
			return true
	return false


func _has_menu_item_call(calls: Array, item_text: String) -> bool:
	for call in calls:
		if str(call.get("tool", "")) == "editor_ui_control" and str(call.get("action", "")) == "select_menu_item":
			if str(call.get("args", {}).get("item_text", "")) == item_text:
				return true
	return false


func _has_value_payload_key(value) -> bool:
	if value is Dictionary:
		var dict := value as Dictionary
		for key in dict.keys():
			if VALUE_PAYLOAD_KEYS.has(str(key)):
				return true
			if _has_value_payload_key(dict.get(key)):
				return true
		return false
	if value is Array:
		for item in value:
			if _has_value_payload_key(item):
				return true
	return false


func _task_steps_have_raw_payload(steps) -> bool:
	if not (steps is Dictionary):
		return false
	for step_name in (steps as Dictionary).keys():
		var step = (steps as Dictionary).get(step_name)
		if not (step is Dictionary):
			continue
		var data = (step as Dictionary).get("data", {})
		if not (data is Dictionary):
			continue
		for raw_key in ["all_controls", "results", "raw_controls", "surface_matches", "popup_matches"]:
			if (data as Dictionary).has(raw_key):
				return true
	return false


func _has_tab_title(tabs: Array, title: String) -> bool:
	for tab in tabs:
		if tab is Dictionary and str((tab as Dictionary).get("title", "")) == title:
			return true
	return false


func _find_category_by_path(categories: Array, category_path: String) -> Dictionary:
	for category in categories:
		if category is Dictionary and str((category as Dictionary).get("category_path", "")) == category_path:
			return category as Dictionary
	return {}


func _failure(message: String) -> Dictionary:
	return {"name": "system_settings_dialog_contracts", "success": false, "error": message}
