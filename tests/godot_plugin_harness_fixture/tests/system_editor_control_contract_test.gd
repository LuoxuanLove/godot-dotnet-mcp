extends RefCounted

# {"name": "system_editor_control_contracts"}

const SystemEditorImplScript = preload("res://addons/godot_dotnet_mcp/tools/system/impl_editor.gd")


class FakeBridge extends RefCounted:
	func call_atomic(tool_name: String, args: Dictionary) -> Dictionary:
		match tool_name:
			"editor_status":
				match str(args.get("action", "")):
					"set_main_screen":
						return success({
							"screen": str(args.get("screen", "")),
							"before_screen": "2D",
							"after_screen": str(args.get("screen", "")),
							"visible_button_found": str(args.get("screen", "")) == "Godex"
						})
					"list_main_screens":
						return success({
							"current_screen": "2D",
							"count": 5,
							"available": ["2D", "3D", "Script", "AssetLib", "Godex"],
							"main_screens": [{"name": "Godex", "control_path": "/root/Editor/TopBar/Godex"}]
						})
					"get_distraction_free":
						return success({"enabled": false})
					"set_distraction_free":
						return success({"enabled": bool(args.get("enabled", false))})
					_:
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
					"wait_for_ui":
						return success({
							"condition": str(args.get("condition", "")),
							"condition_met": true,
							"target_path": str(args.get("target_path", "")),
							"text": str(args.get("text", "")),
							"timeout_ms": int(args.get("timeout_ms", 0)),
							"poll_interval_ms": int(args.get("poll_interval_ms", 0))
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
					"list_tree_items":
						return success({
							"target_path": str(args.get("target_path", "")),
							"text_query": str(args.get("text_query", "")),
							"count": 2,
							"items": [
								{"index": 0, "text": "Application", "item_path": "Application"},
								{"index": 1, "text": "Config", "item_path": "Application/Config"}
							]
						})
					"select_tree_item":
						return success({
							"target_path": str(args.get("target_path", "")),
							"selected_item": {
								"index": int(args.get("item_index", -1)),
								"item_path": str(args.get("item_path", ""))
							}
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
					"click_control", "right_click_control", "hover_control", "leave_control":
						return success({
							"target_path": str(args.get("target_path", "")),
							"action": str(args.get("action", "")),
							"local_x": args.get("local_x", null),
							"local_y": args.get("local_y", null),
							"input_dispatch": {"event_count": 2},
							"target_observation": {
								"button_like": str(args.get("target_path", "")).ends_with("RefreshButton"),
								"activation_supported": true,
								"activation_observed": false,
								"signal_observation": {
									"supported": true,
									"observed": false,
									"activation_observed": false,
									"input_observed": false,
									"signals": {}
								},
								"state_before": {},
								"state_after": {},
								"state_changed": false,
								"hints": []
							}
						})
					"set_text":
						return success({"target_path": str(args.get("target_path", "")), "text": str(args.get("text", ""))})
					"set_value":
						return success({"target_path": str(args.get("target_path", "")), "value": args.get("value", null)})
					_:
						return error("Unsupported editor_ui_control action")
			"editor_popup":
				match str(args.get("action", "")):
					"list_visible":
						return success({"count": 1, "popups": [{"node_path": "/root/Editor/SearchDialog"}]})
					"get_popup":
						return success({
							"target_path": str(args.get("target_path", "")),
							"popup_path": "/root/Editor/SearchDialog",
							"popup": {"node_path": "/root/Editor/SearchDialog", "class": "AcceptDialog"}
						})
					"capture_popup":
						return success({
							"path": str(args.get("path", "")),
							"target_path": str(args.get("target_path", "")),
							"popup_path": "/root/Editor/SearchDialog",
							"capture_mode": "popup"
						})
					"select_item":
						return success({
							"target_path": str(args.get("target_path", "")),
							"selector": {
								"index": args.get("index", null),
								"id": args.get("id", null),
								"text": args.get("text", null)
							},
							"selected_item": {"index": int(args.get("index", -1)), "id": int(args.get("id", -1)), "text": str(args.get("text", ""))}
						})
					"press_button", "set_text", "close_popup":
						return success({"target_path": str(args.get("target_path", ""))})
					_:
						return error("Unsupported editor_popup action")
			"editor_plugin":
				match str(args.get("action", "")):
					"list":
						return success({
							"count": 1,
							"plugins": [{"plugin": "diagnostic_plugin", "editor_enabled": true, "setting_enabled": true}]
						})
					"inspect":
						return success({"plugin": str(args.get("plugin", "")), "editor_enabled": true, "setting_enabled": true})
					"enable", "disable":
						return success({
							"plugin": str(args.get("plugin", "")),
							"requested_enabled": str(args.get("action", "")) == "enable",
							"allow_self": bool(args.get("allow_self", false))
						})
					_:
						return error("Unsupported editor_plugin action")
			_:
				return error("Unsupported atomic tool: %s" % tool_name)

	func call_atomic_async(tool_name: String, args: Dictionary) -> Dictionary:
		await Engine.get_main_loop().process_frame
		return call_atomic(tool_name, args)

	func success(data = {}, message: String = "") -> Dictionary:
		return {"success": true, "data": data, "message": message}

	func error(message: String, data = {}) -> Dictionary:
		return {"success": false, "error": "bridge_error", "message": message, "data": data}


func run_case(_tree: SceneTree) -> Dictionary:
	var impl = SystemEditorImplScript.new()
	impl.bridge = FakeBridge.new()

	var tool_defs: Array[Dictionary] = impl.get_tools()
	if tool_defs.size() != 3:
		return _failure("impl_editor.gd should expose exactly three high-level system tools after adding editor_plugin_control.")
	var tool_names: Array[String] = []
	for tool_def in tool_defs:
		tool_names.append(str(tool_def.get("name", "")))
	if not tool_names.has("editor_control"):
		return _failure("impl_editor.gd should expose editor_control.")
	if not tool_names.has("editor_log"):
		return _failure("impl_editor.gd should expose editor_log alongside editor_control.")
	if not tool_names.has("editor_plugin_control"):
		return _failure("impl_editor.gd should expose editor_plugin_control.")

	var editor_control_schema: Dictionary = {}
	for tool_def in tool_defs:
		if str(tool_def.get("name", "")) == "editor_control":
			var editor_control_description := str(tool_def.get("description", ""))
			if editor_control_description.find("semantic") == -1 or editor_control_description.find("control-level") == -1 or editor_control_description.find("fallback") == -1:
				return _failure("editor_control description should document semantic-first, control-level-second, mouse-fallback UI automation guidance.")
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
	if not editor_control_properties.has("enabled"):
		return _failure("editor_control schema should expose enabled for distraction-free mode.")
	if not editor_control_properties.has("index") or not editor_control_properties.has("id"):
		return _failure("editor_control schema should expose index/id for PopupMenu item selection.")
	var editor_control_actions: Array = editor_control_properties.get("action", {}).get("enum", [])
	for expected_action in ["list_main_screens", "get_distraction_free", "set_distraction_free", "wait_for_ui", "list_tree_items", "select_tree_item", "get_popup", "capture_popup", "select_popup_menu_item", "hover_control", "leave_control", "set_value"]:
		if not editor_control_actions.has(expected_action):
			return _failure("editor_control schema should expose %s." % expected_action)
	if not editor_control_properties.has("value"):
		return _failure("editor_control schema should expose value for set_value.")
	if not editor_control_properties.has("item_path"):
		return _failure("editor_control schema should expose item_path for select_tree_item.")
	for expected_property in ["condition", "timeout_ms", "poll_interval_ms"]:
		if not editor_control_properties.has(expected_property):
			return _failure("editor_control schema should expose %s for wait_for_ui." % expected_property)
	var semantic_path_description := str((editor_control_properties.get("semantic_path", {}) as Dictionary).get("description", ""))
	if semantic_path_description.find("Prefer") == -1 or semantic_path_description.find("before raw control paths or coordinates") == -1:
		return _failure("editor_control semantic_path description should prefer semantic targets before raw paths or coordinates.")
	for coordinate_property in ["local_x", "local_y"]:
		var coordinate_description := str((editor_control_properties.get(coordinate_property, {}) as Dictionary).get("description", ""))
		if coordinate_description.find("fallback") == -1 or coordinate_description.find("not guessed OS screen coordinates") == -1:
			return _failure("editor_control %s description should limit coordinate input to fallback actions and returned control coordinates." % coordinate_property)
	for control_action in ["focus_control", "activate_control", "set_control_text", "set_value", "press_popup_button", "select_popup_menu_item"]:
		if not editor_control_actions.has(control_action):
			return _failure("editor_control schema should expose control-level action %s." % control_action)

	var set_screen_result: Dictionary = impl.execute("editor_control", {
		"action": "set_main_screen",
		"screen": "Godex"
	})
	if not bool(set_screen_result.get("success", false)):
		return _failure("system editor_control should delegate set_main_screen.")
	if str(set_screen_result.get("data", {}).get("after_screen", "")) != "Godex":
		return _failure("system editor_control should allow plugin main screen names.")

	var list_screens_result: Dictionary = impl.execute("editor_control", {"action": "list_main_screens"})
	if not bool(list_screens_result.get("success", false)):
		return _failure("system editor_control should delegate list_main_screens.")
	if not (list_screens_result.get("data", {}).get("available", []) as Array).has("Godex"):
		return _failure("system editor_control list_main_screens should expose plugin main screens.")

	var distraction_result: Dictionary = impl.execute("editor_control", {"action": "get_distraction_free"})
	if not bool(distraction_result.get("success", false)):
		return _failure("system editor_control should delegate get_distraction_free.")
	var set_distraction_result: Dictionary = impl.execute("editor_control", {
		"action": "set_distraction_free",
		"enabled": true
	})
	if not bool(set_distraction_result.get("success", false)) or not bool(set_distraction_result.get("data", {}).get("enabled", false)):
		return _failure("system editor_control should delegate set_distraction_free.")

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
	var wait_result: Dictionary = await impl.execute_async("editor_control", {
		"action": "wait_for_ui",
		"target_path": "/root/Editor/SearchPanel/SearchField",
		"condition": "text_contains",
		"text": "Search",
		"timeout_ms": 250,
		"poll_interval_ms": 25
	})
	if not bool(wait_result.get("success", false)):
		return _failure("system editor_control should delegate wait_for_ui.")
	if str(wait_result.get("data", {}).get("condition", "")) != "text_contains":
		return _failure("system editor_control should preserve wait_for_ui condition.")
	if int(wait_result.get("data", {}).get("timeout_ms", 0)) != 250:
		return _failure("system editor_control should preserve wait_for_ui timeout_ms.")

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
	if int(click_control_result.get("data", {}).get("input_dispatch", {}).get("event_count", 0)) != 2:
		return _failure("system editor_control should preserve click_control input dispatch evidence.")
	if not click_control_result.get("data", {}).has("target_observation"):
		return _failure("system editor_control should preserve click_control target observation metadata.")

	var right_click_control_result: Dictionary = impl.execute("editor_control", {
		"action": "right_click_control",
		"target_path": "/root/Editor/SearchPanel/SearchField",
		"local_y": 9
	})
	if not bool(right_click_control_result.get("success", false)):
		return _failure("system editor_control should delegate right_click_control.")
	var hover_control_result: Dictionary = impl.execute("editor_control", {
		"action": "hover_control",
		"target_path": "/root/Editor/SearchPanel/SearchField",
		"local_x": 14,
		"local_y": 10
	})
	if not bool(hover_control_result.get("success", false)):
		return _failure("system editor_control should delegate hover_control.")
	if str(hover_control_result.get("data", {}).get("action", "")) != "hover_control":
		return _failure("system editor_control should preserve hover_control action.")
	var leave_control_result: Dictionary = impl.execute("editor_control", {
		"action": "leave_control",
		"target_path": "/root/Editor/SearchPanel/SearchField"
	})
	if not bool(leave_control_result.get("success", false)):
		return _failure("system editor_control should delegate leave_control.")

	var popup_result: Dictionary = impl.execute("editor_control", {"action": "list_popups"})
	if not bool(popup_result.get("success", false)):
		return _failure("system editor_control should delegate list_popups.")

	var get_popup_result: Dictionary = impl.execute("editor_control", {
		"action": "get_popup",
		"target_path": "/root/Editor/SearchDialog/SearchInput"
	})
	if not bool(get_popup_result.get("success", false)):
		return _failure("system editor_control should delegate get_popup.")
	if str(get_popup_result.get("data", {}).get("popup_path", "")) != "/root/Editor/SearchDialog":
		return _failure("system editor_control should preserve get_popup popup_path.")

	var capture_popup_result: Dictionary = impl.execute("editor_control", {
		"action": "capture_popup",
		"target_path": "/root/Editor/SearchDialog/SearchInput",
		"path": "user://search_dialog.png"
	})
	if not bool(capture_popup_result.get("success", false)):
		return _failure("system editor_control should delegate capture_popup.")
	if str(capture_popup_result.get("data", {}).get("capture_mode", "")) != "popup":
		return _failure("system editor_control should preserve capture_popup capture mode.")

	var popup_select_result: Dictionary = impl.execute("editor_control", {
		"action": "select_popup_menu_item",
		"target_path": "/root/Editor/SearchDialog",
		"index": 2,
		"id": 42,
		"text": "Rename"
	})
	if not bool(popup_select_result.get("success", false)):
		return _failure("system editor_control should delegate select_popup_menu_item.")
	if int(popup_select_result.get("data", {}).get("selected_item", {}).get("index", -1)) != 2:
		return _failure("system editor_control should preserve select_popup_menu_item index.")

	var set_text_result: Dictionary = impl.execute("editor_control", {
		"action": "set_control_text",
		"target_path": "/root/Editor/SearchPanel/SearchField",
		"text": "Player"
	})
	if not bool(set_text_result.get("success", false)):
		return _failure("system editor_control should delegate set_control_text.")
	var set_value_result: Dictionary = impl.execute("editor_control", {
		"action": "set_value",
		"target_path": "/root/Editor/SearchPanel/NumericValue",
		"value": 42
	})
	if not bool(set_value_result.get("success", false)):
		return _failure("system editor_control should delegate set_value.")
	if int(set_value_result.get("data", {}).get("value", 0)) != 42:
		return _failure("system editor_control should preserve set_value numeric payload.")
	var missing_value_result: Dictionary = impl.execute("editor_control", {
		"action": "set_value",
		"target_path": "/root/Editor/SearchPanel/NumericValue"
	})
	if bool(missing_value_result.get("success", false)):
		return _failure("system editor_control set_value should reject missing value instead of defaulting to zero.")
	if not str(missing_value_result.get("message", "")).contains("value is required"):
		return _failure("system editor_control set_value missing value should report a required value error.")

	var list_tree_items_result: Dictionary = impl.execute("editor_control", {
		"action": "list_tree_items",
		"target_path": "/root/Editor/ProjectSettings/CategoryTree",
		"text_query": "Application"
	})
	if not bool(list_tree_items_result.get("success", false)):
		return _failure("system editor_control should delegate list_tree_items.")
	if int(list_tree_items_result.get("data", {}).get("count", 0)) != 2:
		return _failure("system editor_control should preserve list_tree_items result payload.")
	var select_tree_item_result: Dictionary = impl.execute("editor_control", {
		"action": "select_tree_item",
		"target_path": "/root/Editor/ProjectSettings/CategoryTree",
		"item_path": "Application/Config",
		"item_index": 1
	})
	if not bool(select_tree_item_result.get("success", false)):
		return _failure("system editor_control should delegate select_tree_item.")
	if str(select_tree_item_result.get("data", {}).get("selected_item", {}).get("item_path", "")) != "Application/Config":
		return _failure("system editor_control should preserve select_tree_item path payload.")

	var plugin_list_result: Dictionary = impl.execute("editor_plugin_control", {"action": "list"})
	if not bool(plugin_list_result.get("success", false)) or int(plugin_list_result.get("data", {}).get("count", 0)) != 1:
		return _failure("system editor_plugin_control should delegate plugin list.")
	var plugin_status_result: Dictionary = impl.execute("editor_plugin_control", {
		"action": "get_status",
		"plugin": "diagnostic_plugin"
	})
	if not bool(plugin_status_result.get("success", false)) or str(plugin_status_result.get("data", {}).get("plugin", "")) != "diagnostic_plugin":
		return _failure("system editor_plugin_control should delegate plugin status inspection.")
	var plugin_enable_result: Dictionary = impl.execute("editor_plugin_control", {
		"action": "enable",
		"plugin": "diagnostic_plugin"
	})
	if not bool(plugin_enable_result.get("success", false)) or not bool(plugin_enable_result.get("data", {}).get("requested_enabled", false)):
		return _failure("system editor_plugin_control should delegate plugin enable.")
	var plugin_disable_self_result: Dictionary = impl.execute("editor_plugin_control", {
		"action": "disable",
		"plugin": "godot_dotnet_mcp",
		"allow_self": true
	})
	if not bool(plugin_disable_self_result.get("success", false)) or not bool(plugin_disable_self_result.get("data", {}).get("allow_self", false)):
		return _failure("system editor_plugin_control should forward allow_self for explicit self-toggle requests.")

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
