@tool
extends "res://addons/godot_dotnet_mcp/tools/system/project/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action := str(args.get("action", "")).strip_edges()
	var setting := str(args.get("setting", "")).strip_edges()
	match action:
		"get_settings":
			if setting.is_empty():
				return bridge.error("setting path is required for get_settings")
			return bridge.call_atomic("project_info", {"action": "get_settings", "setting": setting})
		"set_setting":
			if setting.is_empty():
				return bridge.error("setting path is required for set_setting")
			return bridge.call_atomic("project_settings", {"action": "set", "setting": setting, "value": args.get("value", null)})
		"list_autoloads":
			return bridge.call_atomic("project_autoload", {"action": "list"})
		"add_autoload":
			return bridge.call_atomic("project_autoload", {
				"action": "add",
				"name": str(args.get("name", "")),
				"path": str(args.get("path", ""))
			})
		"remove_autoload":
			return bridge.call_atomic("project_autoload", {
				"action": "remove",
				"name": str(args.get("name", ""))
			})
		"list_input_actions":
			return bridge.call_atomic("project_input", {"action": "list_actions"})
		_:
			return bridge.error("Unknown action: %s. Valid: get_settings, set_setting, list_autoloads, add_autoload, remove_autoload, list_input_actions" % action)
