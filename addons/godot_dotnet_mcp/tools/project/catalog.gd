@tool
extends RefCounted


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "info",
			"description": """PROJECT INFO: Get information about the current Godot project.

ACTIONS:
- get_info: Get basic project information
- get_settings: Get project settings
- get_features: Get enabled project features
- get_export_presets: Get configured export presets

EXAMPLES:
- Get project info: {"action": "get_info"}
- Get settings: {"action": "get_settings"}
- Get specific setting: {"action": "get_settings", "setting": "application/config/name"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["get_info", "get_settings", "get_features", "get_export_presets"],
						"description": "Info action"
					},
					"setting": {
						"type": "string",
						"description": "Specific setting path to retrieve"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "dotnet",
			"description": """PROJECT DOTNET: Parse .csproj files and return structured .NET project metadata.

FEATURES:
- Discover .csproj files under res:// when path is omitted
- Read TargetFramework / AssemblyName / RootNamespace / DefineConstants
- Extract PackageReference and ProjectReference items

EXAMPLES:
- Auto-discover: {}
- Read a specific project: {"path": "res://Mechoes.csproj"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Optional .csproj file path"
					}
				}
			}
		},
		{
			"name": "settings",
			"description": """PROJECT SETTINGS: Modify project settings.

ACTIONS:
- set: Set a project setting value
- reset: Reset setting to default
- list_category: List all settings in a category

COMMON SETTINGS:
- application/config/name: Project name
- application/config/description: Project description
- application/run/main_scene: Main scene path
- display/window/size/viewport_width: Window width
- display/window/size/viewport_height: Window height
- rendering/renderer/rendering_method: Renderer (forward_plus, mobile, gl_compatibility)
- physics/2d/default_gravity: 2D gravity
- physics/3d/default_gravity: 3D gravity

CATEGORIES:
- application
- display
- rendering
- physics
- input
- audio
- network
- debug

EXAMPLES:
- Set project name: {"action": "set", "setting": "application/config/name", "value": "My Game"}
- Set window size: {"action": "set", "setting": "display/window/size/viewport_width", "value": 1920}
- List display settings: {"action": "list_category", "category": "display"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["set", "reset", "list_category"],
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
			"name": "input",
			"description": """INPUT MAP: Manage input actions and bindings.

ACTIONS:
- list_actions: List all input actions
- get_action: Get bindings for an action
- add_action: Add a new input action
- remove_action: Remove an input action
- add_binding: Add a binding to an action
- remove_binding: Remove a binding from an action

INPUT TYPES:
- key: Keyboard key (e.g., "A", "Space", "Enter", "Escape")
- mouse: Mouse button (e.g., "left", "right", "middle")
- joypad_button: Gamepad button (e.g., 0 for A/Cross)
- joypad_axis: Gamepad axis (e.g., 0 for left stick X)

EXAMPLES:
- List actions: {"action": "list_actions"}
- Add action: {"action": "add_action", "name": "jump"}
- Add key binding: {"action": "add_binding", "name": "jump", "type": "key", "key": "Space"}
- Add mouse binding: {"action": "add_binding", "name": "shoot", "type": "mouse", "button": "left"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["list_actions", "get_action", "add_action", "remove_action", "add_binding", "remove_binding"],
						"description": "Input action"
					},
					"name": {
						"type": "string",
						"description": "Action name"
					},
					"type": {
						"type": "string",
						"enum": ["key", "mouse", "joypad_button", "joypad_axis"],
						"description": "Input type"
					},
					"key": {
						"type": "string",
						"description": "Key name for keyboard input"
					},
					"button": {
						"type": "string",
						"description": "Button for mouse/joypad"
					},
					"axis": {
						"type": "integer",
						"description": "Axis index for joypad"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "autoload",
			"description": """AUTOLOAD: Manage autoloaded scripts and scenes.

ACTIONS:
- list: List all autoloads
- add: Add a new autoload
- remove: Remove an autoload
- reorder: Change autoload order

EXAMPLES:
- List autoloads: {"action": "list"}
- Add autoload: {"action": "add", "name": "GameManager", "path": "res://scripts/game_manager.gd"}
- Remove autoload: {"action": "remove", "name": "GameManager"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["list", "add", "remove", "reorder"],
						"description": "Autoload action"
					},
					"name": {
						"type": "string",
						"description": "Autoload name"
					},
					"path": {
						"type": "string",
						"description": "Script/scene path"
					},
					"index": {
						"type": "integer",
						"description": "New index for reorder"
					}
				},
				"required": ["action"]
			}
		}
	]
