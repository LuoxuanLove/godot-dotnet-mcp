@tool
extends "res://addons/godot_dotnet_mcp/tools/plugin_shared.gd"


func get_registration() -> Dictionary:
	return {
		"category": "plugin_developer",
		"domain_key": "plugin",
		"hot_reloadable": false
	}


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "settings",
			"description": "PLUGIN DEVELOPER SETTINGS: Read current Dock-facing developer settings.",
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		},
		{
			"name": "log_level",
			"description": "PLUGIN DEVELOPER LOG LEVEL: Set the minimum debug buffer level.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"level": {
						"type": "string",
						"enum": ["trace", "debug", "info", "warning", "error"]
					}
				},
				"required": ["level"]
			}
		},
		{
			"name": "user_visibility",
			"description": "PLUGIN DEVELOPER USER VISIBILITY: Toggle whether the User category is visible in the Dock.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"enabled": {"type": "boolean"}
				},
				"required": ["enabled"]
			}
		},
		{
			"name": "list_languages",
			"description": "PLUGIN DEVELOPER LANGUAGES: List available UI languages and the active selection.",
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		},
		{
			"name": "set_language",
			"description": "PLUGIN DEVELOPER LANGUAGE: Change the Dock language.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"language": {"type": "string"}
				},
				"required": ["language"]
			}
		},
		{
			"name": "list_profiles",
			"description": "PLUGIN DEVELOPER PROFILES: List builtin and custom tool presets.",
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		},
		{
			"name": "apply_profile",
			"description": "PLUGIN DEVELOPER APPLY PROFILE: Apply a saved tool preset.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"profile_id": {"type": "string"}
				},
				"required": ["profile_id"]
			}
		},
		{
			"name": "save_profile",
			"description": "PLUGIN DEVELOPER SAVE PROFILE: Save the current tool selection as a custom preset.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"profile_name": {"type": "string"}
				},
				"required": ["profile_name"]
			}
		},
		{
			"name": "usage_guide",
			"description": "PLUGIN DEVELOPER USAGE GUIDE: Return the recommended usage flow, reload policy and development/debug loop for this plugin.",
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"settings":
			return _call_plugin_method("get_developer_settings_for_tools", [], "Plugin developer bridge is unavailable")
		"log_level":
			return _call_plugin_method("set_log_level_for_tools", [str(args.get("level", "info"))], "Plugin developer bridge is unavailable")
		"user_visibility":
			return _call_plugin_method("set_show_user_tools_from_tools", [bool(args.get("enabled", false))], "Plugin developer bridge is unavailable")
		"list_languages":
			return _call_plugin_method("get_languages_for_tools", [], "Plugin developer bridge is unavailable")
		"set_language":
			return _call_plugin_method("set_language_from_tools", [str(args.get("language", ""))], "Plugin developer bridge is unavailable")
		"list_profiles":
			return _call_plugin_method("list_profiles_from_tools", [], "Plugin developer bridge is unavailable")
		"apply_profile":
			return _call_plugin_method("apply_profile_from_tools", [str(args.get("profile_id", ""))], "Plugin developer bridge is unavailable")
		"save_profile":
			return _call_plugin_method("save_profile_from_tools", [str(args.get("profile_name", ""))], "Plugin developer bridge is unavailable")
		"usage_guide":
			return _call_plugin_method("get_usage_guide_from_tools", [], "Plugin developer bridge is unavailable")
		_:
			return _error("Unknown plugin developer tool: %s" % tool_name)
