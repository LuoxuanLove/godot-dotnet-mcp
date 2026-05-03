@tool
extends RefCounted

## System implementation: editor_control

var bridge

const HANDLED_TOOLS := ["editor_control", "editor_log"]


func handles(tool_name: String) -> bool:
	return tool_name in HANDLED_TOOLS


func configure_runtime(_context: Dictionary) -> void:
	pass


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "editor_control",
			"description": "EDITOR CONTROL: High-level editor UI workflow entry. Use it to switch main workspace tabs, activate dock/plugin/bottom-panel UI through Godot APIs without OS mouse/window automation, capture the full editor UI, inspect visible controls and coordinate mapping, capture a specific control, focus or activate controls, dispatch control-local left/right mouse clicks, edit popup text, and close editor popups. Prefer this tool when the task depends on the current editor interface, not just project files.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": [
							"set_main_screen",
							"capture_editor",
							"list_controls",
							"list_dock_tabs",
							"activate_dock_tab",
							"activate_ui",
							"get_control",
							"capture_control",
							"focus_control",
							"activate_control",
							"click_control",
							"right_click_control",
							"set_control_text",
							"list_popups",
							"press_popup_button",
							"set_popup_text",
							"close_popup"
						],
						"description": "Editor control action"
					},
					"screen": {
						"type": "string",
						"enum": ["2D", "3D", "Script", "AssetLib"],
						"description": "Main screen for set_main_screen"
					},
					"path": {
						"type": "string",
						"description": "Output screenshot path for capture_editor/capture_control"
					},
					"target_path": {
						"type": "string",
						"description": "Editor control path returned from list_controls/list_popups"
					},
					"title": {
						"type": "string",
						"description": "Dock tab title for activate_dock_tab/activate_ui"
					},
					"semantic_path": {
						"type": "string",
						"description": "Stable semantic UI path for activate_ui, e.g. MCPDock/config, MCPDock/tools, MCPDock/home"
					},
					"tab_title": {
						"type": "string",
						"description": "Tab title or child name for activate_ui when target_path points to a TabContainer"
					},
					"tab_index": {
						"type": "integer",
						"description": "Tab index for activate_ui when target_path points to a TabContainer"
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
						"description": "Text for set_control_text/set_popup_text"
					},
					"local_x": {
						"type": "number",
						"description": "Control-local X coordinate for click_control/right_click_control; defaults to the control center"
					},
					"local_y": {
						"type": "number",
						"description": "Control-local Y coordinate for click_control/right_click_control; defaults to the control center"
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

	var action := str(args.get("action", "")).strip_edges()
	match action:
		"set_main_screen":
			return bridge.call_atomic("editor_status", {
				"action": "set_main_screen",
				"screen": str(args.get("screen", "")).strip_edges()
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
		"set_control_text":
			return bridge.call_atomic("editor_ui_control", {
				"action": "set_text",
				"target_path": str(args.get("target_path", "")).strip_edges(),
				"text": str(args.get("text", ""))
			})
		"list_popups":
			return bridge.call_atomic("editor_popup", {"action": "list_visible"})
		"press_popup_button":
			return bridge.call_atomic("editor_popup", {
				"action": "press_button",
				"target_path": str(args.get("target_path", "")).strip_edges()
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
