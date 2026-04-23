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
							"tabs": [{"title": "MCPDock", "path": "/root/Editor/Docks/MCPDock"}]
						})
					"activate_dock_tab":
						return success({"title": str(args.get("title", ""))})
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

	var set_screen_result: Dictionary = impl.execute("editor_control", {
		"action": "set_main_screen",
		"screen": "3D"
	})
	if not bool(set_screen_result.get("success", false)):
		return _failure("system editor_control should delegate set_main_screen.")

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
		"title": "MCPDock"
	})
	if not bool(activate_dock_result.get("success", false)):
		return _failure("system editor_control should delegate activate_dock_tab.")

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
