@tool
extends RefCounted


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "query",
			"description": """RESOURCE QUERY: Search and list resources in the project.

ACTIONS:
- list: List resources by type or in directory
- search: Search for resources by name pattern
- get_info: Get detailed information about a resource
- get_dependencies: Get resource dependencies

RESOURCE TYPES:
- PackedScene (.tscn, .scn): Scene files
- Script (.gd, .cs): Script files
- Texture2D (.png, .jpg, .svg): Images
- AudioStream (.wav, .ogg, .mp3): Audio files
- Material (.material, .tres): Materials
- Shader (.gdshader): Shader files
- Font (.ttf, .otf): Font files
- Animation (.anim): Animation files

EXAMPLES:
- List all scenes: {"action": "list", "type": "PackedScene"}
- List in directory: {"action": "list", "path": "res://scenes"}
- Search textures: {"action": "search", "pattern": "*player*", "type": "Texture2D"}
- Get resource info: {"action": "get_info", "path": "res://sprites/player.png"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["list", "search", "get_info", "get_dependencies"],
						"description": "Query action"
					},
					"type": {
						"type": "string",
						"description": "Resource type filter"
					},
					"path": {
						"type": "string",
						"description": "Directory path or resource path"
					},
					"pattern": {
						"type": "string",
						"description": "Search pattern (supports * wildcard)"
					},
					"recursive": {
						"type": "boolean",
						"description": "Search subdirectories (default: true)"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "create",
			"description": """RESOURCE CREATE: Create a new resource file from a resource type.

ACTIONS:
- create: Create a new resource

RESOURCE CREATION:
- Resource: Generic resource
- GDScript: Create a new .gd script resource
- StyleBox: UI style
- Environment: 3D environment
- Material: Create material resource

EXAMPLES:
- Create script: {"type": "GDScript", "path": "res://scripts/player.gd"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"type": {
						"type": "string",
						"description": "Resource type to create"
					},
					"path": {
						"type": "string",
						"description": "Resource path"
					}
				},
				"required": ["type", "path"]
			}
		},
		{
			"name": "file_ops",
			"description": """RESOURCE FILE OPS: Copy, move, delete or reload an existing resource file.

ACTIONS:
- copy: Copy a resource
- move: Move or rename a resource
- delete: Delete a resource
- reload: Reload a resource from disk

EXAMPLES:
- Copy resource: {"action": "copy", "source": "res://sprites/enemy.png", "dest": "res://sprites/boss.png"}
- Reload: {"action": "reload", "path": "res://materials/metal.tres"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["copy", "move", "delete", "reload"],
						"description": "Resource file action"
					},
					"source": {
						"type": "string",
						"description": "Source path for copy/move"
					},
					"dest": {
						"type": "string",
						"description": "Destination path"
					},
					"path": {
						"type": "string",
						"description": "Resource path for delete/reload"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "texture",
			"description": """TEXTURE OPERATIONS: Manage texture resources.

ACTIONS:
- get_info: Get texture information (size, format, etc.)
- list_all: List all textures in project
- assign_to_node: Assign texture to a node's property

EXAMPLES:
- Get texture info: {"action": "get_info", "path": "res://sprites/player.png"}
- List textures: {"action": "list_all"}
- Assign to Sprite2D: {"action": "assign_to_node", "texture_path": "res://sprites/player.png", "node_path": "/root/Player/Sprite2D", "property": "texture"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["get_info", "list_all", "assign_to_node"],
						"description": "Texture action"
					},
					"path": {
						"type": "string",
						"description": "Texture path"
					},
					"texture_path": {
						"type": "string",
						"description": "Texture resource path"
					},
					"node_path": {
						"type": "string",
						"description": "Target node path"
					},
					"property": {
						"type": "string",
						"description": "Property name"
					}
				},
				"required": ["action"]
			}
		}
	]
