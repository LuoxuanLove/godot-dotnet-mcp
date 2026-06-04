extends RefCounted

# {"name": "system_editor_control_contracts"}

const SystemEditorImplScript = preload("res://addons/godot_dotnet_mcp/tools/system/impl_editor.gd")


class FakeBridge extends RefCounted:
	func call_atomic(tool_name: String, args: Dictionary) -> Dictionary:
		match tool_name:
			"editor_status":
				if str(args.get("action", "")) == "set_main_screen":
					return success({"screen": str(args.get("screen", ""))})
				return error("Unsupported editor_status action")
			"editor_screenshot":
				if str(args.get("action", "")) == "capture":
					return success({"path": "user://editor.png"})
				return error("Unsupported editor_screenshot action")
			"editor_ui_control":
				match str(args.get("action", "")):
					"list_visible":
						return success({
							"count": 1,
							"controls": [{"path": "/root/Editor/SearchPanel/SearchField", "class": "LineEdit"}]
						})
					"list_dock_tabs":
						return success({
							"count": 1,
							"tabs": [{"title": "MCP", "path": "/root/Editor/Docks/MCP"}]
						})
					"activate_dock_tab":
						return success({"title": str(args.get("title", ""))})
					"activate_ui":
						return success({
							"title": str(args.get("title", "")),
							"semantic_path": str(args.get("semantic_path", "")),
							"target_path": str(args.get("target_path", "")),
							"tab_title": str(args.get("tab_title", "")),
							"tab_index": int(args.get("tab_index", -1)),
							"bottom_panel_title": str(args.get("bottom_panel_title", "")),
							"bottom_panel_path": str(args.get("bottom_panel_path", "")),
							"path": str(args.get("path", ""))
						})
					"list_menus":
						return success({
							"count": 1,
							"menus": [{"path": "/root/Editor/MenuBar/Project", "text": "Project"}]
						})
					"open_menu":
						return success({
							"target_path": str(args.get("target_path", "")),
							"menu_title": str(args.get("menu_title", ""))
						})
					"select_menu_item":
						return success({
							"target_path": str(args.get("target_path", "")),
							"menu_title": str(args.get("menu_title", "")),
							"item_text": str(args.get("item_text", "")),
							"item_index": int(args.get("item_index", -1))
						})
					"get_control":
						return success({
							"control": {"path": str(args.get("target_path", "")), "class": "LineEdit"}
						})
					"capture_control":
						return success({"path": "user://control.png", "target_path": str(args.get("target_path", ""))})
					"focus_control":
						return success({"target_path": str(args.get("target_path", ""))})
					"activate_control":
						return success({"target_path": str(args.get("target_path", ""))})
					"click_control", "right_click_control":
						return success({
							"target_path": str(args.get("target_path", "")),
							"local_x": args.get("local_x", null),
							"local_y": args.get("local_y", null)
						})
					"set_text":
						return success({"target_path": str(args.get("target_path", "")), "text": str(args.get("text", ""))})
					_:
						return error("Unsupported editor_ui_control action")
			"editor_popup":
				match str(args.get("action", "")):
					"list_visible":
						return success({"count": 1, "popups": [{"node_path": "/root/Editor/SearchDialog"}]})
					"press_button", "set_text", "close_popup":
						return success({"target_path": str(args.get("target_path", ""))})
					_:
						return error("Unsupported editor_popup action")
			_:
				return error("Unsupported atomic tool: %s" % tool_name)

	func success(data = {}, message: String = "") -> Dictionary:
		return {"success": true, "data": data, "message": message}

	func error(message: String, data = {}) -> Dictionary:
		return {"success": false, "error": "bridge_error", "message": message, "data": data}


func run_case(_tree: SceneTree) -> Dictionary:
	var impl = SystemEditorImplScript.new()
	impl.bridge = FakeBridge.new()

	var tool_defs: Array[Dictionary] = impl.get_tools()
	if tool_defs.size() != 2:
		return _failure("impl_editor.gd should expose exactly two high-level system tools after adding editor_log.")
	var tool_names: Array[String] = []
	for tool_def in tool_defs:
		tool_names.append(str(tool_def.get("name", "")))
	if not tool_names.has("editor_control"):
		return _failure("impl_editor.gd should expose editor_control.")
	if not tool_names.has("editor_log"):
		return _failure("impl_editor.gd should expose editor_log alongside editor_control.")

	var editor_control_schema: Dictionary = {}
	for tool_def in tool_defs:
		if str(tool_def.get("name", "")) == "editor_control":
			editor_control_schema = tool_def.get("inputSchema", {})
			break
	var editor_control_properties: Dictionary = editor_control_schema.get("properties", {})
	if not editor_control_properties.has("title"):
		return _failure("editor_control schema should expose title for activate_dock_tab.")
	if not editor_control_properties.has("semantic_path"):
		return _failure("editor_control schema should expose semantic_path for non-invasive activate_ui.")
	if not editor_control_properties.has("tab_title") or not editor_control_properties.has("tab_index"):
		return _failure("editor_control schema should expose tab_title/tab_index for TabContainer activation.")
	if not editor_control_properties.has("bottom_panel_title") or not editor_control_properties.has("bottom_panel_path"):
		return _failure("editor_control schema should expose bottom_panel_title/bottom_panel_path for bottom panel activation.")
	if not editor_control_properties.has("menu_title") or not editor_control_properties.has("item_text") or not editor_control_properties.has("item_index"):
		return _failure("editor_control schema should expose menu_title/item_text/item_index for top menu control.")
	if not editor_control_properties.has("local_x") or not editor_control_properties.has("local_y"):
		return _failure("editor_control schema should expose local_x/local_y for control-local mouse clicks.")

	var set_screen_result: Dictionary = impl.execute("editor_control", {
		"action": "set_main_screen",
		"screen": "3D"
	})
	if not bool(set_screen_result.get("success", false)):
		return _failure("system editor_control should delegate set_main_screen.")

	var capture_editor_result: Dictionary = impl.execute("editor_control", {
		"action": "capture_editor"
	})
	if not bool(capture_editor_result.get("success", false)):
		return _failure("system editor_control should delegate capture_editor.")
	if int(capture_editor_result.get("data", {}).get("visible_popup_count", -1)) != 1:
		return _failure("system editor_control capture_editor should attach visible popup count.")
	if str(capture_editor_result.get("data", {}).get("visible_popups", [{}])[0].get("node_path", "")) != "/root/Editor/SearchDialog":
		return _failure("system editor_control capture_editor should attach visible popup metadata.")

	var list_controls_result: Dictionary = impl.execute("editor_control", {
		"action": "list_controls",
		"class_name": "LineEdit"
	})
	if not bool(list_controls_result.get("success", false)):
		return _failure("system editor_control should delegate list_controls.")
	if int(list_controls_result.get("data", {}).get("count", 0)) != 1:
		return _failure("system editor_control should preserve the list_controls payload.")

	var list_dock_tabs_result: Dictionary = impl.execute("editor_control", {
		"action": "list_dock_tabs",
		"include_hidden": true
	})
	if not bool(list_dock_tabs_result.get("success", false)):
		return _failure("system editor_control should delegate list_dock_tabs.")
	if int(list_dock_tabs_result.get("data", {}).get("count", 0)) != 1:
		return _failure("system editor_control should preserve the list_dock_tabs payload.")

	var activate_dock_result: Dictionary = impl.execute("editor_control", {
		"action": "activate_dock_tab",
		"title": "MCP"
	})
	if not bool(activate_dock_result.get("success", false)):
		return _failure("system editor_control should delegate activate_dock_tab.")

	var activate_ui_semantic_result: Dictionary = impl.execute("editor_control", {
		"action": "activate_ui",
		"semantic_path": "MCPDock/config",
		"path": "user://mcpdock_config.png"
	})
	if not bool(activate_ui_semantic_result.get("success", false)):
		return _failure("system editor_control should delegate semantic activate_ui.")
	if str(activate_ui_semantic_result.get("data", {}).get("semantic_path", "")) != "MCPDock/config":
		return _failure("system editor_control should preserve activate_ui semantic_path.")

	var activate_ui_tab_result: Dictionary = impl.execute("editor_control", {
		"action": "activate_ui",
		"target_path": "/root/Editor/MCP/TabContainer",
		"tab_title": "ConfigTab",
		"tab_index": 2
	})
	if not bool(activate_ui_tab_result.get("success", false)):
		return _failure("system editor_control should delegate TabContainer activate_ui.")
	if int(activate_ui_tab_result.get("data", {}).get("tab_index", -1)) != 2:
		return _failure("system editor_control should preserve activate_ui tab_index.")

	var activate_ui_bottom_result: Dictionary = impl.execute("editor_control", {
		"action": "activate_ui",
		"bottom_panel_title": "Output",
		"bottom_panel_path": "/root/Editor/BottomPanel/Output"
	})
	if not bool(activate_ui_bottom_result.get("success", false)):
		return _failure("system editor_control should delegate bottom panel activate_ui.")
	if str(activate_ui_bottom_result.get("data", {}).get("bottom_panel_title", "")) != "Output":
		return _failure("system editor_control should preserve activate_ui bottom_panel_title.")

	var list_menus_result: Dictionary = impl.execute("editor_control", {
		"action": "list_menus",
		"text_query": "Project"
	})
	if not bool(list_menus_result.get("success", false)):
		return _failure("system editor_control should delegate list_menus.")
	if int(list_menus_result.get("data", {}).get("count", 0)) != 1:
		return _failure("system editor_control should preserve list_menus payload.")

	var open_menu_result: Dictionary = impl.execute("editor_control", {
		"action": "open_menu",
		"menu_title": "Project"
	})
	if not bool(open_menu_result.get("success", false)):
		return _failure("system editor_control should delegate open_menu.")
	if str(open_menu_result.get("data", {}).get("menu_title", "")) != "Project":
		return _failure("system editor_control should preserve open_menu menu_title.")

	var select_menu_item_result: Dictionary = impl.execute("editor_control", {
		"action": "select_menu_item",
		"menu_title": "Project",
		"item_text": "Project Settings...",
		"item_index": 0
	})
	if not bool(select_menu_item_result.get("success", false)):
		return _failure("system editor_control should delegate select_menu_item.")
	if str(select_menu_item_result.get("data", {}).get("item_text", "")) != "Project Settings...":
		return _failure("system editor_control should preserve select_menu_item item_text.")

	var activate_dock_missing_title_result: Dictionary = impl.execute("editor_control", {
		"action": "activate_dock_tab"
	})
	if bool(activate_dock_missing_title_result.get("success", false)):
		return _failure("system editor_control should reject activate_dock_tab without title.")
	if str(activate_dock_missing_title_result.get("message", "")) != "title is required":
		return _failure("system editor_control should return a clear title is required error.")

	var capture_control_result: Dictionary = impl.execute("editor_control", {
		"action": "capture_control",
		"target_path": "/root/Editor/SearchPanel/SearchField"
	})
	if not bool(capture_control_result.get("success", false)):
		return _failure("system editor_control should delegate capture_control.")

	var click_control_result: Dictionary = impl.execute("editor_control", {
		"action": "click_control",
		"target_path": "/root/Editor/SearchPanel/SearchField",
		"local_x": 12,
		"local_y": 8
	})
	if not bool(click_control_result.get("success", false)):
		return _failure("system editor_control should delegate click_control.")
	if int(click_control_result.get("data", {}).get("local_x", 0)) != 12:
		return _failure("system editor_control should preserve click_control local_x.")

	var right_click_control_result: Dictionary = impl.execute("editor_control", {
		"action": "right_click_control",
		"target_path": "/root/Editor/SearchPanel/SearchField",
		"local_y": 9
	})
	if not bool(right_click_control_result.get("success", false)):
		return _failure("system editor_control should delegate right_click_control.")

	var popup_result: Dictionary = impl.execute("editor_control", {"action": "list_popups"})
	if not bool(popup_result.get("success", false)):
		return _failure("system editor_control should delegate list_popups.")

	var set_text_result: Dictionary = impl.execute("editor_control", {
		"action": "set_control_text",
		"target_path": "/root/Editor/SearchPanel/SearchField",
		"text": "Player"
	})
	if not bool(set_text_result.get("success", false)):
		return _failure("system editor_control should delegate set_control_text.")

	return {
		"name": "system_editor_control_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"list_count": int(list_controls_result.get("data", {}).get("count", 0)),
			"popup_count": int(popup_result.get("data", {}).get("count", 0))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "system_editor_control_contracts",
		"success": false,
		"error": message
	}
