@tool
extends RefCounted


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "read",
			"description": """SCRIPT READ: Read a Godot script file as plain text.

SUPPORTED:
- GDScript (.gd)
- C# (.cs)

EXAMPLES:
- Read a C# script: {"path": "res://Scripts/Player.cs"}
- Read a GDScript: {"path": "res://addons/example/tool.gd"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Script file path (res://...)"
					}
				},
				"required": ["path"]
			}
		},
		{
			"name": "open",
			"description": """SCRIPT OPEN: Open scripts in Godot's script editor.

ACTIONS:
- open: Open a script
- open_at_line: Open a script at a specific line
- get_open_scripts: List open scripts

EXAMPLES:
- Open: {"action": "open", "path": "res://Scripts/Player.cs"}
- Open at line: {"action": "open_at_line", "path": "res://Scripts/Player.cs", "line": 42}
- List open scripts: {"action": "get_open_scripts"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["open", "open_at_line", "get_open_scripts"]
					},
					"path": {
						"type": "string",
						"description": "Script file path"
					},
					"line": {
						"type": "integer",
						"description": "Line number for open_at_line"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "inspect",
			"description": """SCRIPT INSPECT: Parse a Godot script and return language-aware metadata.

RETURNS:
- language
- class_name
- base_type
- namespace (C#)
- methods
- exports
- export_groups

EXAMPLES:
- Inspect C#: {"path": "res://Scripts/Player.cs"}
- Inspect GDScript: {"path": "res://addons/example/tool.gd"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Script file path"
					}
				},
				"required": ["path"]
			}
		},
		{
			"name": "symbols",
			"description": """SCRIPT SYMBOLS: List symbols parsed from a Godot script.

FILTERS:
- kind: class, method, export, enum
- query: substring match on symbol name

EXAMPLES:
- All symbols: {"path": "res://Scripts/Player.cs"}
- Only exports: {"path": "res://Scripts/Player.cs", "kind": "export"}
- Filter by name: {"path": "res://Scripts/Player.cs", "query": "Score"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Script file path"
					},
					"kind": {
						"type": "string",
						"enum": ["class", "method", "export", "enum"]
					},
					"query": {
						"type": "string",
						"description": "Filter symbols by substring"
					}
				},
				"required": ["path"]
			}
		},
		{
			"name": "exports",
			"description": """SCRIPT EXPORTS: Return exported members declared by a script.

SUPPORTED:
- [Export] members in C#
- @export variables in GDScript

EXAMPLES:
- C# exports: {"path": "res://Scripts/Player.cs"}
- GDScript exports: {"path": "res://addons/example/tool.gd"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Script file path"
					}
				},
				"required": ["path"]
			}
		},
		{
			"name": "references",
			"description": """SCRIPT REFERENCES: Build an on-demand cross-file script index for scene usage and C# inheritance lookups.

ACTIONS:
- get_scene_refs: List .tscn files that reference a script via script = ExtResource(...)
- get_base_type: Return the direct base type for a C# class
- get_class_map: List all discovered C# class-to-path mappings

NOTES:
- The current stable implementation is path-first for get_scene_refs/get_base_type
- Use get_class_map to resolve a class name to its script path when needed
- refresh rebuilds the cached index for the current editor session

EXAMPLES:
- Scene refs by path: {"action": "get_scene_refs", "path": "res://Scripts/Player.cs"}
- Base type by path: {"action": "get_base_type", "path": "res://Scripts/Player.cs"}
- Class map: {"action": "get_class_map"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["get_scene_refs", "get_base_type", "get_class_map"]
					},
					"path": {
						"type": "string",
						"description": "Optional script file path"
					},
					"class_name": {
						"type": "string",
						"description": "Optional class name"
					},
					"namespace": {
						"type": "string",
						"description": "Optional namespace filter for C# classes"
					},
					"refresh": {
						"type": "boolean",
						"description": "Rebuild the cached index before querying"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "edit_gd",
			"description": """GDSCRIPT EDIT: Edit GDScript files only.

ACTIONS:
- create: Create a new .gd script
- write: Replace full script content
- delete: Delete a .gd script
- add_function: Append a function
- remove_function: Remove a function by name
- add_variable: Add a variable declaration
- add_signal: Add a signal declaration
- add_export: Add an exported variable
- get_functions: List parsed functions
- get_variables: List parsed variables

EXAMPLES:
- Create: {"action": "create", "path": "res://scripts/player.gd", "extends": "Node2D"}
- Add function: {"action": "add_function", "path": "res://scripts/player.gd", "name": "flash", "body": "return 1", "return_type": "int"}
- List variables: {"action": "get_variables", "path": "res://scripts/player.gd"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["create", "write", "delete", "add_function", "remove_function", "add_variable", "add_signal", "add_export", "get_functions", "get_variables", "replace_function_body", "remove_member", "rename_member"]
					},
					"path": {
						"type": "string",
						"description": "GDScript file path"
					},
					"content": {
						"type": "string"
					},
					"extends": {
						"type": "string"
					},
					"class_name": {
						"type": "string"
					},
					"name": {
						"type": "string"
					},
					"type": {
						"type": "string"
					},
					"value": {
						"type": "string"
					},
					"params": {
						"type": "array",
						"items": {"type": "string"}
					},
					"body": {
						"type": "string"
					},
					"return_type": {
						"type": "string"
					},
					"member_type": {
						"type": "string",
						"description": "Member type hint for remove_member/rename_member: function, variable, signal, export, auto (default: auto)"
					},
					"new_name": {
						"type": "string",
						"description": "New name for rename_member"
					}
				},
				"required": ["action", "path"]
			}
		},
		{
			"name": "edit_cs",
			"description": """C# EDIT: Template-based editing for .cs scripts.

ACTIONS:
- create: Create a new .cs script from namespace/class/base_type
- write: Replace full script content
- add_field: Append a field near the end of the primary class
- add_method: Append a method stub near the end of the primary class

EXAMPLES:
- Create: {"action": "create", "path": "res://Scripts/Player.cs", "namespace": "Game", "class_name": "Player", "base_type": "Node"}
- Add field: {"action": "add_field", "path": "res://Scripts/Player.cs", "name": "Speed", "type": "float", "value": "5.0f", "exported": true}
- Add method: {"action": "add_method", "path": "res://Scripts/Player.cs", "name": "Jump", "return_type": "void", "body": "// TODO: implement"}
- Write: {"action": "write", "path": "res://Scripts/Player.cs", "content": "using Godot;"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["create", "write", "add_field", "add_method", "replace_method_body", "delete_member", "rename_member"]
					},
					"path": {
						"type": "string",
						"description": "C# script file path"
					},
					"namespace": {
						"type": "string"
					},
					"class_name": {
						"type": "string"
					},
					"base_type": {
						"type": "string"
					},
					"content": {
						"type": "string"
					},
					"name": {
						"type": "string"
					},
					"type": {
						"type": "string"
					},
					"value": {
						"type": "string"
					},
					"access": {
						"type": "string"
					},
					"modifiers": {
						"type": "array",
						"items": {"type": "string"}
					},
					"exported": {
						"type": "boolean"
					},
					"params": {
						"type": "array",
						"items": {"type": "string"}
					},
					"body": {
						"type": "string"
					},
					"return_type": {
						"type": "string"
					},
					"member_type": {
						"type": "string",
						"description": "Member type hint for delete_member/rename_member: method, field, property, auto (default: auto)"
					},
					"new_name": {
						"type": "string",
						"description": "New name for rename_member"
					}
				},
				"required": ["action", "path"]
			}
		}
	]
