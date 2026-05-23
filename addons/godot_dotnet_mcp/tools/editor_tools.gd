@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

## Editor control tools for Godot MCP
## Provides editor UI, theme, and preferences management

const NotificationTools = preload("res://addons/godot_dotnet_mcp/tools/editor/notification_tools.gd")
const FilesystemTools = preload("res://addons/godot_dotnet_mcp/tools/editor/filesystem_tools.gd")
const PluginTools = preload("res://addons/godot_dotnet_mcp/tools/editor/plugin_tools.gd")
const SettingsTools = preload("res://addons/godot_dotnet_mcp/tools/editor/settings_tools.gd")
const StateTools = preload("res://addons/godot_dotnet_mcp/tools/editor/state_tools.gd")
const InspectorTools = preload("res://addons/godot_dotnet_mcp/tools/editor/inspector_tools.gd")
const UIControlTools = preload("res://addons/godot_dotnet_mcp/tools/editor/ui_control_tools.gd")
const UndoRedoTools = preload("res://addons/godot_dotnet_mcp/tools/editor/undo_redo_tools.gd")

var _notification_tools := NotificationTools.new()
var _filesystem_tools := FilesystemTools.new()
var _plugin_tools := PluginTools.new()
var _settings_tools := SettingsTools.new()
var _state_tools := StateTools.new()
var _inspector_tools := InspectorTools.new()
var _ui_control_tools := UIControlTools.new()
var _undo_redo_tools := UndoRedoTools.new()
var _plugin_host_override = null


func configure_context(context = null) -> void:
	if context == null:
		dispose()
		return
	_editor_interface_override = context.get("editor_interface", null)
	_undo_redo_override = context.get("undo_redo", null)
	_scene_root_override = context.get("scene_root", null)
	_plugin_host_override = context.get("plugin_host", null)


func dispose() -> void:
	_editor_interface_override = null
	_undo_redo_override = null
	_scene_root_override = null
	_plugin_host_override = null
	_ui_control_tools = UIControlTools.new()
	_undo_redo_tools = UndoRedoTools.new()


func _get_editor_interface():
	if _editor_interface_override != null:
		return _editor_interface_override
	if not Engine.is_editor_hint():
		return null
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


func _build_subtool_context() -> Dictionary:
	return {
		"editor_interface": _editor_interface_override,
		"undo_redo": _undo_redo_override,
		"scene_root": _scene_root_override,
		"plugin_host": _plugin_host_override
	}


func _configure_subtool(tool) -> void:
	if tool != null and tool.has_method("configure_context"):
		tool.configure_context(_build_subtool_context())


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "status",
			"description": """EDITOR STATUS: Get information about the current editor state.

ACTIONS:
- get_info: Get editor version and status info
- get_main_screen: Get currently active main screen (2D, 3D, Script, AssetLib)
- get_focus_context: Get current editor focus owner and selected scene nodes
- set_main_screen: Switch to a different main screen
- get_distraction_free: Get distraction-free mode status
- set_distraction_free: Toggle distraction-free mode
- get_godot_path: Get the current Godot executable path and project root

EXAMPLES:
- Get editor info: {"action": "get_info"}
- Get main screen: {"action": "get_main_screen"}
- Get focus context: {"action": "get_focus_context"}
- Switch to 3D: {"action": "set_main_screen", "screen": "3D"}
- Toggle distraction-free: {"action": "set_distraction_free", "enabled": true}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["get_info", "get_main_screen", "get_focus_context", "set_main_screen", "get_distraction_free", "set_distraction_free", "get_godot_path"],
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
- Capture to custom path: {"action": "capture", "path": "user://godot_dotnet_mcp/captures/editor/custom.png"}
- Capture a region: {"action": "capture", "x": 32, "y": 16, "width": 128, "height": 96}""",
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
						"description": "Output PNG path (res:// or user://). Defaults to user://godot_dotnet_mcp/captures/editor/...; root-level user://file.png is normalized into the managed editor capture directory."
					},
					"x": {
						"type": "integer",
						"description": "Optional capture region X origin"
					},
					"y": {
						"type": "integer",
						"description": "Optional capture region Y origin"
					},
					"width": {
						"type": "integer",
						"description": "Optional capture region width"
					},
					"height": {
						"type": "integer",
						"description": "Optional capture region height"
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
			"name": "ui_control",
			"description": """EDITOR UI CONTROL: Enumerate visible editor controls, inspect one control by path, activate editor/plugin UI through Godot APIs without OS mouse/window automation, capture control-local screenshots, focus a control, activate safe button-like controls, dispatch control-local left/right mouse clicks, and write text into text-editing controls.

ACTIONS:
- list_visible: Enumerate visible editor controls
- list_dock_tabs: Enumerate dock tabs by title/path, including hidden ones when requested
- activate_dock_tab: Activate a dock tab by its title
- activate_ui: Non-invasively activate dock/plugin/bottom-panel UI by semantic_path, dock title, bottom_panel_title/path, or TabContainer target_path plus tab_title/tab_index
- get_control: Fetch one control summary by target_path
- capture_control: Capture a screenshot cropped to one control
- focus_control: Move editor focus to a control
- activate_control: Activate a button-like control
- click_control: Dispatch a left mouse click at local_x/local_y inside a control
- right_click_control: Dispatch a right mouse click at local_x/local_y inside a control
- set_text: Write text into a text-editing control

EXAMPLES:
- List controls: {"action": "list_visible", "class_name": "LineEdit"}
- List dock tabs: {"action": "list_dock_tabs", "include_hidden": true}
- Activate dock tab: {"action": "activate_dock_tab", "title": "MCP"}
- Activate MCPDock config: {"action": "activate_ui", "semantic_path": "MCPDock/config", "path": "user://godot_dotnet_mcp/captures/editor_controls/mcpdock_config.png"}
- Activate TabContainer tab: {"action": "activate_ui", "target_path": "/root/Editor/MCP/TabContainer", "tab_title": "ConfigTab"}
- Activate bottom panel: {"action": "activate_ui", "bottom_panel_title": "Output"}
- Inspect one control: {"action": "get_control", "target_path": "/root/Editor/SearchPanel/SearchInput"}
- Capture one control: {"action": "capture_control", "target_path": "/root/Editor/SearchPanel/SearchInput"}
- Focus control: {"action": "focus_control", "target_path": "/root/Editor/SearchPanel/SearchInput"}
- Activate control: {"action": "activate_control", "target_path": "/root/Editor/FileSystemDock/RefreshButton"}
- Right-click control row: {"action": "right_click_control", "target_path": "/root/Editor/MCP/ToolsTab/ToolTree", "local_x": 24, "local_y": 42}
- Set text: {"action": "set_text", "target_path": "/root/Editor/SearchPanel/SearchInput", "text": "Player"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["list_visible", "list_dock_tabs", "activate_dock_tab", "activate_ui", "get_control", "capture_control", "focus_control", "activate_control", "click_control", "right_click_control", "set_text"],
						"description": "UI control action"
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
					"target_path": {
						"type": "string",
						"description": "Editor control path returned from list_visible"
					},
					"path": {
						"type": "string",
						"description": "Output PNG path for capture_control"
					},
					"text": {
						"type": "string",
						"description": "Text for set_text"
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
						"description": "Optional class filter for list_visible"
					},
					"text_query": {
						"type": "string",
						"description": "Optional text filter for list_visible"
					},
					"include_hidden": {
						"type": "boolean",
						"description": "Include hidden controls in list_visible"
					},
					"limit": {
						"type": "integer",
						"description": "Maximum controls returned from list_visible"
					},
					"max_depth": {
						"type": "integer",
						"description": "Maximum tree depth for list_visible"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "popup",
			"description": """EDITOR POPUP CONTROL: Enumerate visible floating editor popups, including popup rect/text/parent metadata and PopupMenu items, and perform minimal safe interactions.

ACTIONS:
- list_visible: List visible popup/window roots and actionable children with rect/text/parent metadata
- press_button: Activate a popup button by target_path
- set_text: Set text on a popup LineEdit/TextEdit by target_path
- close_popup: Close a popup/window by target_path

EXAMPLES:
- List popups: {"action": "list_visible"}
- Press button: {"action": "press_button", "target_path": "/root/Editor/ConfirmDialog/OkButton"}
- Set text: {"action": "set_text", "target_path": "/root/Editor/SearchDialog/Input", "text": "Player"}
- Close popup: {"action": "close_popup", "target_path": "/root/Editor/SearchDialog"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["list_visible", "press_button", "set_text", "close_popup"],
						"description": "Popup action"
					},
					"target_path": {
						"type": "string",
						"description": "Popup control path returned from list_visible"
					},
					"text": {
						"type": "string",
						"description": "Text to write for set_text"
					}
				},
				"required": ["action"]
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
	_configure_subtool(_state_tools)
	_configure_subtool(_settings_tools)
	_configure_subtool(_undo_redo_tools)
	_configure_subtool(_notification_tools)
	_configure_subtool(_inspector_tools)
	_configure_subtool(_filesystem_tools)
	_configure_subtool(_plugin_tools)
	_configure_subtool(_ui_control_tools)
	match tool_name:
		"status":
			return _state_tools.execute(_get_editor_interface(), {"tool": "status", "action": args.get("action", ""), "screen": args.get("screen", ""), "enabled": args.get("enabled", false)})
		"screenshot":
			return _state_tools.execute(_get_editor_interface(), {
				"tool": "screenshot",
				"action": args.get("action", ""),
				"path": args.get("path", ""),
				"x": args.get("x", null),
				"y": args.get("y", null),
				"width": args.get("width", null),
				"height": args.get("height", null)
			})
		"settings":
			return _settings_tools.execute(_get_editor_interface(), args)
		"undo_redo":
			return _undo_redo_tools.execute(_get_editor_interface(), args)
		"notification":
			return _notification_tools.execute(_get_editor_interface(), args)
		"ui_control":
			return _ui_control_tools.execute(_get_editor_interface(), args)
		"popup":
			return _notification_tools.execute_popup(_get_editor_interface(), args)
		"inspector":
			return _inspector_tools.execute(_get_editor_interface(), args)
		"filesystem":
			return _filesystem_tools.execute(_get_editor_interface(), args)
		"plugin":
			return _plugin_tools.execute(_get_editor_interface(), args)
		_:
			return _error("Unknown tool: %s" % tool_name)
