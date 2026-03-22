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
			"name": "rename_profile",
			"description": "PLUGIN DEVELOPER RENAME PROFILE: Rename a saved custom tool preset.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"profile_id": {"type": "string"},
					"profile_name": {"type": "string"}
				},
				"required": ["profile_id", "profile_name"]
			}
		},
		{
			"name": "delete_profile",
			"description": "PLUGIN DEVELOPER DELETE PROFILE: Delete a saved custom tool preset.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"profile_id": {"type": "string"}
				},
				"required": ["profile_id"]
			}
		},
		{
			"name": "export_config",
			"description": "PLUGIN DEVELOPER EXPORT CONFIG: Export the current tool profile id and disabled-tools selection to a JSON file.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string"}
				},
				"required": ["path"]
			}
		},
		{
			"name": "import_config",
			"description": "PLUGIN DEVELOPER IMPORT CONFIG: Import a tool profile id and disabled-tools selection from a JSON file and apply it.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string"}
				},
				"required": ["path"]
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
	return _call_plugin_method(
		"execute_plugin_developer_tool",
		[tool_name, args],
		"Plugin developer bridge is unavailable"
	)
