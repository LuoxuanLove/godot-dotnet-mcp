@tool
extends RefCounted


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "status",
			"description": "EDITOR STATUS: Read editor version, main screen and distraction-free mode.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["get_info", "get_main_screen", "set_main_screen", "get_distraction_free", "set_distraction_free"]},
					"screen": {"type": "string", "enum": ["2D", "3D", "Script", "AssetLib"]},
					"enabled": {"type": "boolean"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "settings",
			"description": "EDITOR SETTINGS: Access and modify editor preferences.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["get", "set", "list_category", "reset"]},
					"setting": {"type": "string"},
					"value": {},
					"category": {"type": "string"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "undo_redo",
			"description": "UNDO/REDO: Access the editor undo/redo system.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["get_info", "undo", "redo", "create_action", "commit_action", "add_do_property", "add_undo_property", "add_do_method", "add_undo_method", "merge_mode"]},
					"name": {"type": "string"},
					"context": {"type": "string", "enum": ["local", "global"]},
					"path": {"type": "string"},
					"property": {"type": "string"},
					"value": {},
					"method": {"type": "string"},
					"args": {"type": "array", "items": {}},
					"merge_mode": {"type": "string", "enum": ["disable", "ends", "all"]}
				},
				"required": ["action"]
			}
		},
		{
			"name": "notification",
			"description": "NOTIFICATIONS: Show informational messages in the editor.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["toast", "popup", "confirm"]},
					"message": {"type": "string"},
					"title": {"type": "string"},
					"severity": {"type": "string", "enum": ["info", "warning", "error"]}
				},
				"required": ["action", "message"]
			}
		},
		{
			"name": "inspector",
			"description": "INSPECTOR CONTROL: Control the editor inspector panel.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["edit_object", "get_edited", "refresh", "get_selected_property", "inspect_resource"]},
					"path": {"type": "string"},
					"resource_path": {"type": "string"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "filesystem",
			"description": "FILESYSTEM DOCK: Control the FileSystem dock.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["select_file", "get_selected", "get_current_path", "scan", "reimport"]},
					"path": {"type": "string"},
					"paths": {"type": "array", "items": {"type": "string"}}
				},
				"required": ["action"]
			}
		},
		{
			"name": "plugin",
			"description": "PLUGIN MANAGEMENT: Enable or disable editor plugins.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["list", "is_enabled", "enable", "disable"]},
					"plugin": {"type": "string"}
				},
				"required": ["action"]
			}
		}
	]
