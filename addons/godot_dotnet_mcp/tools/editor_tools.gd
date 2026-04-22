@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"
class_name MCPEditorTools

## Editor control tools for Godot MCP
## Provides editor UI, theme, and preferences management

const NotificationTools = preload("res://addons/godot_dotnet_mcp/tools/editor/notification_tools.gd")
const FilesystemTools = preload("res://addons/godot_dotnet_mcp/tools/editor/filesystem_tools.gd")
const PluginTools = preload("res://addons/godot_dotnet_mcp/tools/editor/plugin_tools.gd")
const SettingsTools = preload("res://addons/godot_dotnet_mcp/tools/editor/settings_tools.gd")
const StateTools = preload("res://addons/godot_dotnet_mcp/tools/editor/state_tools.gd")
const InspectorTools = preload("res://addons/godot_dotnet_mcp/tools/editor/inspector_tools.gd")
const UndoRedoTools = preload("res://addons/godot_dotnet_mcp/tools/editor/undo_redo_tools.gd")

var _editor_interface_override = null
var _undo_redo_override = null
var _scene_root_override = null
var _notification_tools := NotificationTools.new()
var _filesystem_tools := FilesystemTools.new()
var _plugin_tools := PluginTools.new()
var _settings_tools := SettingsTools.new()
var _state_tools := StateTools.new()
var _inspector_tools := InspectorTools.new()
var _undo_redo_tools := UndoRedoTools.new()


func configure_context(context = null) -> void:
	if context == null:
		dispose()
		return
	_editor_interface_override = context.get("editor_interface", null)
	_undo_redo_override = context.get("undo_redo", null)
	_scene_root_override = context.get("scene_root", null)


func dispose() -> void:
	_editor_interface_override = null
	_undo_redo_override = null
	_scene_root_override = null
	_undo_redo_tools = UndoRedoTools.new()


func _get_editor_interface():
	if _editor_interface_override != null:
		return _editor_interface_override
	if Engine.has_singleton("EditorInterface"):
		return Engine.get_singleton("EditorInterface")
	return null


func _get_edited_scene_root():
	if _scene_root_override != null:
		return _scene_root_override
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop.has_method("get_edited_scene_root"):
		return main_loop.get_edited_scene_root()
	return null


func _find_node_by_path(path: String) -> Node:
	var root = _get_edited_scene_root()
	if not root:
		return null

	var normalized_path = _normalize_node_path(path, root)
	if normalized_path.is_empty() or normalized_path == ".":
		return root
	if normalized_path.begins_with("/"):
		var absolute_node = root.get_node_or_null(NodePath(normalized_path))
		if absolute_node:
			return absolute_node
	return root.get_node_or_null(NodePath(normalized_path))


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "status",
			"description": """EDITOR STATUS: Get information about the current editor state.

ACTIONS:
- get_info: Get editor version and status info
- get_main_screen: Get currently active main screen (2D, 3D, Script, AssetLib)
- set_main_screen: Switch to a different main screen
- get_distraction_free: Get distraction-free mode status
- set_distraction_free: Toggle distraction-free mode
- get_godot_path: Get the current Godot executable path and project root

EXAMPLES:
- Get editor info: {"action": "get_info"}
- Get main screen: {"action": "get_main_screen"}
- Switch to 3D: {"action": "set_main_screen", "screen": "3D"}
- Toggle distraction-free: {"action": "set_distraction_free", "enabled": true}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
					"enum": ["get_info", "get_main_screen", "set_main_screen", "get_distraction_free", "set_distraction_free", "get_godot_path"],
						"description": "Status action"
					},
					"screen": {
						"type": "string",
						"enum": ["2D", "3D", "Script", "AssetLib"],
						"description": "Main screen to switch to"
					},
					"enabled": {
						"type": "boolean",
						"description": "Enable/disable distraction-free mode"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "screenshot",
			"description": """EDITOR SCREENSHOT: Capture the current editor UI viewport to a PNG file.

ACTIONS:
- capture: Save the current editor window image to a file path.

EXAMPLES:
- Capture to default path: {"action": "capture"}
- Capture to custom path: {"action": "capture", "path": "user://captures/editor.png"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["capture"],
						"description": "Screenshot action"
					},
					"path": {
						"type": "string",
						"description": "Output PNG path (res:// or user://). Defaults to user://godot_mcp_editor_captures/..."
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "settings",
			"description": """EDITOR SETTINGS: Access and modify editor preferences.

ACTIONS:
- get: Get an editor setting
- set: Set an editor setting
- list_category: List settings in a category
- reset: Reset setting to default

COMMON SETTINGS:
- interface/theme/preset: Editor theme
- interface/editor/main_font_size: Main editor font size
- interface/editor/code_font_size: Code editor font size
- text_editor/theme/highlighting/background_color: Script editor background
- filesystem/file_dialog/show_hidden_files: Show hidden files

EXAMPLES:
- Get font size: {"action": "get", "setting": "interface/editor/main_font_size"}
- Set font size: {"action": "set", "setting": "interface/editor/code_font_size", "value": 16}
- List interface settings: {"action": "list_category", "category": "interface"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["get", "set", "list_category", "reset"],
						"description": "Settings action"
					},
					"setting": {
						"type": "string",
						"description": "Setting path"
					},
					"value": {
						"description": "New value for setting"
					},
					"category": {
						"type": "string",
						"description": "Category to list"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "undo_redo",
			"description": """UNDO/REDO: Access the editor's undo/redo system with action tracking.

ACTIONS:
- get_info: Get current undo/redo state
- undo: Perform undo
- redo: Perform redo
- create_action: Start a new tracked action
- commit_action: Commit current action
- add_do_property: Add property change for do
- add_undo_property: Add property change for undo
- add_do_method: Add method call for do
- add_undo_method: Add method call for undo
- merge_mode: Get/set merge mode for actions

CONTEXTS:
- local: Scene-specific history (default)
- global: Editor-wide history

EXAMPLES:
- Get info: {"action": "get_info"}
- Create action: {"action": "create_action", "name": "Move Node", "context": "local"}
- Add do property: {"action": "add_do_property", "path": "/root/Player", "property": "position", "value": {"x": 100, "y": 200}}
- Commit: {"action": "commit_action"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["get_info", "undo", "redo", "create_action", "commit_action", "add_do_property", "add_undo_property", "add_do_method", "add_undo_method", "merge_mode"],
						"description": "Undo/redo action"
					},
					"name": {
						"type": "string",
						"description": "Action name for create_action"
					},
					"context": {
						"type": "string",
						"enum": ["local", "global"],
						"description": "Undo/redo context"
					},
					"path": {
						"type": "string",
						"description": "Node path for property/method"
					},
					"property": {
						"type": "string",
						"description": "Property name"
					},
					"value": {
						"description": "Property value"
					},
					"method": {
						"type": "string",
						"description": "Method name"
					},
					"args": {
						"type": "array",
						"items": {},
						"description": "Method arguments"
					},
					"merge_mode": {
						"type": "string",
						"enum": ["disable", "ends", "all"],
						"description": "Merge mode for actions"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "notification",
			"description": """NOTIFICATIONS: Show notifications in the editor.

ACTIONS:
- toast: Show a toast notification
- popup: Show a popup dialog
- confirm: Show a confirmation dialog (non-blocking, returns immediately)

SEVERITY:
- info: Informational (blue)
- warning: Warning (yellow)
- error: Error (red)

EXAMPLES:
- Show toast: {"action": "toast", "message": "Build complete!", "severity": "info"}
- Show popup: {"action": "popup", "title": "Alert", "message": "Something happened"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["toast", "popup", "confirm"],
						"description": "Notification action"
					},
					"message": {
						"type": "string",
						"description": "Notification message"
					},
					"title": {
						"type": "string",
						"description": "Dialog title"
					},
					"severity": {
						"type": "string",
						"enum": ["info", "warning", "error"],
						"description": "Notification severity"
					}
				},
				"required": ["action", "message"]
			}
		},
		{
			"name": "inspector",
			"description": """INSPECTOR CONTROL: Control the editor inspector panel.

ACTIONS:
- edit_object: Edit a specific node/resource in inspector
- get_edited: Get currently edited object info
- refresh: Refresh the inspector
- get_selected_property: Get the currently selected property path
- inspect_resource: Inspect a resource file

EXAMPLES:
- Edit node: {"action": "edit_object", "path": "/root/Player"}
- Get edited: {"action": "get_edited"}
- Refresh: {"action": "refresh"}
- Inspect resource: {"action": "inspect_resource", "resource_path": "res://materials/metal.tres"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["edit_object", "get_edited", "refresh", "get_selected_property", "inspect_resource"],
						"description": "Inspector action"
					},
					"path": {
						"type": "string",
						"description": "Node path to edit"
					},
					"resource_path": {
						"type": "string",
						"description": "Resource path to inspect"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "filesystem",
			"description": """FILESYSTEM DOCK: Control the FileSystem dock.

ACTIONS:
- select_file: Select a file in the FileSystem dock
- get_selected: Get currently selected paths
- get_current_path: Get current directory path
- scan: Trigger filesystem scan
- reimport: Reimport specific files

EXAMPLES:
- Select file: {"action": "select_file", "path": "res://scenes/main.tscn"}
- Get selected: {"action": "get_selected"}
- Scan filesystem: {"action": "scan"}
- Reimport: {"action": "reimport", "paths": ["res://sprites/player.png"]}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["select_file", "get_selected", "get_current_path", "scan", "reimport"],
						"description": "Filesystem action"
					},
					"path": {
						"type": "string",
						"description": "File path to select"
					},
					"paths": {
						"type": "array",
						"items": {"type": "string"},
						"description": "File paths to reimport"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "plugin",
			"description": """PLUGIN MANAGEMENT: Enable/disable editor plugins.

ACTIONS:
- list: List all available plugins
- is_enabled: Check if a plugin is enabled
- enable: Enable a plugin
- disable: Disable a plugin

EXAMPLES:
- List plugins: {"action": "list"}
- Check status: {"action": "is_enabled", "plugin": "my_plugin"}
- Enable plugin: {"action": "enable", "plugin": "my_plugin"}
- Disable plugin: {"action": "disable", "plugin": "my_plugin"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["list", "is_enabled", "enable", "disable"],
						"description": "Plugin action"
					},
					"plugin": {
						"type": "string",
						"description": "Plugin name (folder name in addons/)"
					}
				},
				"required": ["action"]
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"status":
			return _state_tools.execute(_get_editor_interface(), {"tool": "status", "action": args.get("action", ""), "screen": args.get("screen", ""), "enabled": args.get("enabled", false)})
		"screenshot":
			return _state_tools.execute(_get_editor_interface(), {"tool": "screenshot", "action": args.get("action", ""), "path": args.get("path", "")})
		"settings":
			return _settings_tools.execute(_get_editor_interface(), args)
		"undo_redo":
			return _undo_redo_tools.execute(_get_editor_interface(), args)
		"notification":
			return _notification_tools.execute(_get_editor_interface(), args)
		"inspector":
			return _inspector_tools.execute(_get_editor_interface(), args)
		"filesystem":
			return _filesystem_tools.execute(_get_editor_interface(), args)
		"plugin":
			return _plugin_tools.execute(_get_editor_interface(), args)
		_:
			return _error("Unknown tool: %s" % tool_name)

