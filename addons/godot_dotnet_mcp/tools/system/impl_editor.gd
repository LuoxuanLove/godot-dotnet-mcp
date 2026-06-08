@tool
extends RefCounted

## System implementation: editor_control

var bridge

const HANDLED_TOOLS := ["editor_control", "editor_log", "editor_plugin_control"]


func handles(tool_name: String) -> bool:
	return tool_name in HANDLED_TOOLS


func configure_runtime(_context: Dictionary) -> void:
	pass


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "editor_control",
			"description": "EDITOR CONTROL: High-level editor UI workflow entry. Prefer semantic actions such as activate_ui, activate_dock_tab, set_main_screen, menu selection, tree selection, and settings-dialog workflows before raw controls. Use control-level focus, activation, text, value, and popup actions next. Use control-local click, right-click, hover, and leave only as fallback for unsupported UI, context menus, tooltips, or pointer-event validation; click and right-click fallback results include input dispatch and target observation evidence when available. Prefer this tool when the task depends on the current editor interface, not just project files.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": [
							"list_main_screens",
							"set_main_screen",
							"get_distraction_free",
							"set_distraction_free",
							"capture_editor",
							"list_controls",
							"wait_for_ui",
							"list_dock_tabs",
							"activate_dock_tab",
							"activate_ui",
							"list_tree_items",
							"select_tree_item",
							"list_menus",
							"open_menu",
							"select_menu_item",
							"get_control",
							"capture_control",
							"focus_control",
							"activate_control",
							"click_control",
							"right_click_control",
							"hover_control",
							"leave_control",
							"set_control_text",
							"set_value",
							"list_popups",
							"get_popup",
							"capture_popup",
							"press_popup_button",
							"select_popup_menu_item",
							"set_popup_text",
							"close_popup"
						],
						"description": "Editor control action"
					},
					"screen": {
						"type": "string",
						"description": "Main screen for set_main_screen"
					},
					"enabled": {
						"type": "boolean",
						"description": "Enable or disable distraction-free mode"
					},
					"path": {
						"type": "string",
						"description": "Output screenshot path for capture_editor/capture_control/capture_popup"
					},
					"target_path": {
						"type": "string",
						"description": "Editor control or popup path returned from list_controls/list_popups"
					},
					"title": {
						"type": "string",
						"description": "Dock tab title for activate_dock_tab/activate_ui"
					},
					"semantic_path": {
						"type": "string",
						"description": "Stable semantic UI path for activate_ui, e.g. MCPDock/config, MCPDock/tools, MCPDock/home. Prefer this semantic target before raw control paths or coordinates."
					},
					"tab_title": {
						"type": "string",
						"description": "Tab title or child name for activate_ui when target_path points to a TabContainer"
					},
					"tab_index": {
						"type": "integer",
						"description": "Tab index for activate_ui when target_path points to a TabContainer"
					},
					"menu_title": {
						"type": "string",
						"description": "Top menu title/text/name for open_menu/select_menu_item"
					},
					"item_text": {
						"type": "string",
						"description": "PopupMenu item text for select_menu_item"
					},
					"item_index": {
						"type": "integer",
						"description": "PopupMenu item index for select_menu_item"
					},
					"item_path": {
						"type": "string",
						"description": "Tree item path for select_tree_item"
					},
					"bottom_panel_title": {
						"type": "string",
						"description": "Bottom panel control title/name/text for activate_ui"
					},
					"bottom_panel_path": {
						"type": "string",
						"description": "Bottom panel control path for activate_ui"
					},
					"text": {
						"type": "string",
						"description": "Text for set_control_text/set_popup_text, PopupMenu item text for select_popup_menu_item, or expected text for wait_for_ui"
					},
					"value": {
						"type": "number",
						"description": "Numeric value for set_value"
					},
					"condition": {
						"type": "string",
						"enum": [
							"exists",
							"not_exists",
							"visible",
							"hidden",
							"text_contains",
							"text_equals",
							"enabled",
							"disabled"
						],
						"description": "Condition for wait_for_ui (default: exists)"
					},
					"timeout_ms": {
						"type": "integer",
						"description": "Maximum wait time for wait_for_ui in milliseconds (default 1000, capped by the plugin)"
					},
					"poll_interval_ms": {
						"type": "integer",
						"description": "Polling interval for wait_for_ui in milliseconds (default 50, capped by the plugin)"
					},
					"index": {
						"type": "integer",
						"description": "PopupMenu item index for select_popup_menu_item"
					},
					"id": {
						"type": "integer",
						"description": "PopupMenu item id for select_popup_menu_item"
					},
					"local_x": {
						"type": "number",
						"description": "Control-local X coordinate for click_control/right_click_control/hover_control fallback actions; defaults to the control center. Use coordinates returned by control tools, not guessed OS screen coordinates."
					},
					"local_y": {
						"type": "number",
						"description": "Control-local Y coordinate for click_control/right_click_control/hover_control fallback actions; defaults to the control center. Use coordinates returned by control tools, not guessed OS screen coordinates."
					},
					"class_name": {
						"type": "string",
						"description": "Optional control class filter for list_controls"
					},
					"text_query": {
						"type": "string",
						"description": "Optional case-insensitive text filter for list_controls"
					},
					"include_hidden": {
						"type": "boolean",
						"description": "Include hidden controls in list_controls (default: false)"
					},
					"limit": {
						"type": "integer",
						"description": "Maximum number of controls returned by list_controls"
					},
					"max_depth": {
						"type": "integer",
						"description": "Maximum traversal depth for list_controls"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "editor_plugin_control",
			"description": "EDITOR PLUGIN CONTROL: Inspect and toggle third-party EditorPlugin session state. Reports plugin.cfg metadata, project-setting state, current editor-session state, visible UI/main-screen hints, and restart/manual-activation guidance. Refuses to toggle this MCP plugin by default; use dedicated plugin reload/update tools for this plugin.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": [
							"list",
							"get_status",
							"enable",
							"disable"
						],
						"description": "Editor plugin control action"
					},
					"plugin": {
						"type": "string",
						"description": "Plugin folder name under res://addons/"
					},
					"allow_self": {
						"type": "boolean",
						"description": "Allow toggling this MCP plugin despite reconnect/disconnect risk (default false)"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "editor_log",
			"description": "EDITOR LOG: High-level Output panel access for agents. Use it to read current editor output, read filtered warning/error lines, or clear the Output panel without dropping down to atomic debug tools.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": [
							"get_output",
							"get_errors",
							"clear_output"
						],
						"description": "Editor Output panel action"
					},
					"limit": {
						"type": "integer",
						"description": "Maximum number of lines returned"
					},
					"include_warnings": {
						"type": "boolean",
						"description": "Include warnings when action=get_errors (default: true)"
					}
				},
				"required": ["action"]
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name not in HANDLED_TOOLS:
		return bridge.error("Unknown tool: %s" % tool_name)

	if tool_name == "editor_log":
		return _execute_editor_log(args)
	if tool_name == "editor_plugin_control":
		return _execute_editor_plugin_control(args)

	var action := str(args.get("action", "")).strip_edges()
	match action:
		"set_main_screen":
			return bridge.call_atomic("editor_status", {
				"action": "set_main_screen",
				"screen": str(args.get("screen", "")).strip_edges()
			})
		"list_main_screens":
			return bridge.call_atomic("editor_status", {"action": "list_main_screens"})
		"get_distraction_free":
			return bridge.call_atomic("editor_status", {"action": "get_distraction_free"})
		"set_distraction_free":
			return bridge.call_atomic("editor_status", {
				"action": "set_distraction_free",
				"enabled": bool(args.get("enabled", false))
			})
		"capture_editor":
			return _capture_editor(args)
		"list_controls":
			return bridge.call_atomic("editor_ui_control", {
				"action": "list_visible",
				"class_name": str(args.get("class_name", "")).strip_edges(),
				"text_query": str(args.get("text_query", "")).strip_edges(),
				"include_hidden": bool(args.get("include_hidden", false)),
				"limit": int(args.get("limit", 200)),
				"max_depth": int(args.get("max_depth", 6))
			})
		"wait_for_ui":
			return bridge.call_atomic("editor_ui_control", {
				"action": "wait_for_ui",
				"target_path": str(args.get("target_path", "")).strip_edges(),
				"class_name": str(args.get("class_name", "")).strip_edges(),
				"text_query": str(args.get("text_query", "")).strip_edges(),
				"include_hidden": bool(args.get("include_hidden", false)),
				"limit": int(args.get("limit", 200)),
				"max_depth": int(args.get("max_depth", 6)),
				"condition": str(args.get("condition", "exists")).strip_edges(),
				"text": str(args.get("text", "")),
				"timeout_ms": int(args.get("timeout_ms", 1000)),
				"poll_interval_ms": int(args.get("poll_interval_ms", 50))
			})
		"list_dock_tabs":
			return bridge.call_atomic("editor_ui_control", {
				"action": "list_dock_tabs",
				"include_hidden": bool(args.get("include_hidden", true))
			})
		"activate_dock_tab":
			var title := str(args.get("title", "")).strip_edges()
			if title.is_empty():
				return bridge.error("title is required")
			return bridge.call_atomic("editor_ui_control", {
				"action": "activate_dock_tab",
				"title": title
			})
		"activate_ui":
			return bridge.call_atomic("editor_ui_control", {
				"action": "activate_ui",
				"title": str(args.get("title", "")).strip_edges(),
				"semantic_path": str(args.get("semantic_path", "")).strip_edges(),
				"target_path": str(args.get("target_path", "")).strip_edges(),
				"tab_title": str(args.get("tab_title", "")).strip_edges(),
				"tab_index": int(args.get("tab_index", -1)),
				"bottom_panel_title": str(args.get("bottom_panel_title", "")).strip_edges(),
				"bottom_panel_path": str(args.get("bottom_panel_path", "")).strip_edges(),
				"path": str(args.get("path", "")).strip_edges()
			})
		"list_tree_items":
			return bridge.call_atomic("editor_ui_control", {
				"action": "list_tree_items",
				"target_path": str(args.get("target_path", "")).strip_edges(),
				"text_query": str(args.get("text_query", "")).strip_edges(),
				"include_hidden": bool(args.get("include_hidden", false)),
				"limit": int(args.get("limit", 200))
			})
		"select_tree_item":
			return bridge.call_atomic("editor_ui_control", {
				"action": "select_tree_item",
				"target_path": str(args.get("target_path", "")).strip_edges(),
				"item_path": str(args.get("item_path", "")).strip_edges(),
				"item_index": int(args.get("item_index", -1))
			})
		"list_menus":
			return bridge.call_atomic("editor_ui_control", {
				"action": "list_menus",
				"text_query": str(args.get("text_query", "")).strip_edges(),
				"include_hidden": bool(args.get("include_hidden", false)),
				"limit": int(args.get("limit", 200)),
				"max_depth": int(args.get("max_depth", 6))
			})
		"open_menu":
			return bridge.call_atomic("editor_ui_control", {
				"action": "open_menu",
				"target_path": str(args.get("target_path", "")).strip_edges(),
				"menu_title": str(args.get("menu_title", "")).strip_edges()
			})
		"select_menu_item":
			return bridge.call_atomic("editor_ui_control", {
				"action": "select_menu_item",
				"target_path": str(args.get("target_path", "")).strip_edges(),
				"menu_title": str(args.get("menu_title", "")).strip_edges(),
				"item_text": str(args.get("item_text", "")).strip_edges(),
				"item_index": int(args.get("item_index", -1))
			})
		"get_control":
			return bridge.call_atomic("editor_ui_control", {
				"action": "get_control",
				"target_path": str(args.get("target_path", "")).strip_edges()
			})
		"capture_control":
			return bridge.call_atomic("editor_ui_control", {
				"action": "capture_control",
				"target_path": str(args.get("target_path", "")).strip_edges(),
				"path": str(args.get("path", "")).strip_edges()
			})
		"focus_control":
			return bridge.call_atomic("editor_ui_control", {
				"action": "focus_control",
				"target_path": str(args.get("target_path", "")).strip_edges()
			})
		"activate_control":
			return bridge.call_atomic("editor_ui_control", {
				"action": "activate_control",
				"target_path": str(args.get("target_path", "")).strip_edges()
			})
		"click_control":
			return bridge.call_atomic("editor_ui_control", {
				"action": "click_control",
				"target_path": str(args.get("target_path", "")).strip_edges(),
				"local_x": args.get("local_x", null),
				"local_y": args.get("local_y", null)
			})
		"right_click_control":
			return bridge.call_atomic("editor_ui_control", {
				"action": "right_click_control",
				"target_path": str(args.get("target_path", "")).strip_edges(),
				"local_x": args.get("local_x", null),
				"local_y": args.get("local_y", null)
			})
		"hover_control":
			return bridge.call_atomic("editor_ui_control", {
				"action": "hover_control",
				"target_path": str(args.get("target_path", "")).strip_edges(),
				"local_x": args.get("local_x", null),
				"local_y": args.get("local_y", null)
			})
		"leave_control":
			return bridge.call_atomic("editor_ui_control", {
				"action": "leave_control",
				"target_path": str(args.get("target_path", "")).strip_edges(),
				"local_x": args.get("local_x", null),
				"local_y": args.get("local_y", null)
			})
		"set_control_text":
			return bridge.call_atomic("editor_ui_control", {
				"action": "set_text",
				"target_path": str(args.get("target_path", "")).strip_edges(),
				"text": str(args.get("text", ""))
			})
		"set_value":
			if not args.has("value"):
				return bridge.error("value is required for set_value")
			return bridge.call_atomic("editor_ui_control", {
				"action": "set_value",
				"target_path": str(args.get("target_path", "")).strip_edges(),
				"value": args.get("value")
			})
		"list_popups":
			return bridge.call_atomic("editor_popup", {"action": "list_visible"})
		"get_popup":
			return bridge.call_atomic("editor_popup", {
				"action": "get_popup",
				"target_path": str(args.get("target_path", "")).strip_edges()
			})
		"capture_popup":
			return bridge.call_atomic("editor_popup", {
				"action": "capture_popup",
				"target_path": str(args.get("target_path", "")).strip_edges(),
				"path": str(args.get("path", "")).strip_edges()
			})
		"press_popup_button":
			return bridge.call_atomic("editor_popup", {
				"action": "press_button",
				"target_path": str(args.get("target_path", "")).strip_edges()
			})
		"select_popup_menu_item":
			return bridge.call_atomic("editor_popup", {
				"action": "select_item",
				"target_path": str(args.get("target_path", "")).strip_edges(),
				"index": args.get("index", null),
				"id": args.get("id", null),
				"text": args.get("text", null)
			})
		"set_popup_text":
			return bridge.call_atomic("editor_popup", {
				"action": "set_text",
				"target_path": str(args.get("target_path", "")).strip_edges(),
				"text": str(args.get("text", ""))
			})
		"close_popup":
			return bridge.call_atomic("editor_popup", {
				"action": "close_popup",
				"target_path": str(args.get("target_path", "")).strip_edges()
			})
		_:
			return bridge.error("Unknown action: %s" % action)


func execute_async(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name == "editor_control" and str(args.get("action", "")).strip_edges() == "wait_for_ui":
		return await bridge.call_atomic_async("editor_ui_control", {
			"action": "wait_for_ui",
			"target_path": str(args.get("target_path", "")).strip_edges(),
			"class_name": str(args.get("class_name", "")).strip_edges(),
			"text_query": str(args.get("text_query", "")).strip_edges(),
			"include_hidden": bool(args.get("include_hidden", false)),
			"limit": int(args.get("limit", 200)),
			"max_depth": int(args.get("max_depth", 6)),
			"condition": str(args.get("condition", "exists")).strip_edges(),
			"text": str(args.get("text", "")),
			"timeout_ms": int(args.get("timeout_ms", 1000)),
			"poll_interval_ms": int(args.get("poll_interval_ms", 50))
		})
	return execute(tool_name, args)


func _capture_editor(args: Dictionary) -> Dictionary:
	var capture_result: Dictionary = bridge.call_atomic("editor_screenshot", {
		"action": "capture",
		"path": str(args.get("path", "")).strip_edges(),
		"x": args.get("x", null),
		"y": args.get("y", null),
		"width": args.get("width", null),
		"height": args.get("height", null)
	})
	if not bool(capture_result.get("success", false)):
		return capture_result
	var popup_result: Dictionary = bridge.call_atomic("editor_popup", {"action": "list_visible"})
	if bool(popup_result.get("success", false)):
		var data: Dictionary = capture_result.get("data", {})
		var popup_data: Dictionary = popup_result.get("data", {})
		data["visible_popup_count"] = int(popup_data.get("count", 0))
		data["visible_popups"] = popup_data.get("popups", [])
		capture_result["data"] = data
	return capture_result


func _execute_editor_plugin_control(args: Dictionary) -> Dictionary:
	var action := str(args.get("action", "")).strip_edges()
	match action:
		"list":
			return bridge.call_atomic("editor_plugin", {"action": "list"})
		"get_status":
			return bridge.call_atomic("editor_plugin", {
				"action": "inspect",
				"plugin": str(args.get("plugin", "")).strip_edges()
			})
		"enable", "disable":
			return bridge.call_atomic("editor_plugin", {
				"action": action,
				"plugin": str(args.get("plugin", "")).strip_edges(),
				"allow_self": bool(args.get("allow_self", false))
			})
		_:
			return bridge.error("Unknown action: %s" % action)


func _execute_editor_log(args: Dictionary) -> Dictionary:
	var action := str(args.get("action", "")).strip_edges()
	match action:
		"get_output":
			return bridge.call_atomic("debug_editor_log", {
				"action": "get_output",
				"limit": int(args.get("limit", 100))
			})
		"get_errors":
			return bridge.call_atomic("debug_editor_log", {
				"action": "get_errors",
				"limit": int(args.get("limit", 50)),
				"include_warnings": bool(args.get("include_warnings", true))
			})
		"clear_output":
			return bridge.call_atomic("debug_editor_log", {
				"action": "clear"
			})
		_:
			return bridge.error("Unknown action: %s" % action)
