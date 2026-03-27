@tool
extends RefCounted


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "directory",
			"description": """DIRECTORY OPERATIONS: Manage directories in the project.

ACTIONS:
- list: List contents of a directory
- create: Create a new directory
- delete: Delete an empty directory
- exists: Check if directory exists
- get_files: Get all files in directory (with filters)

EXAMPLES:
- List directory: {"action": "list", "path": "res://scenes"}
- Create directory: {"action": "create", "path": "res://new_folder"}
- Get all .gd files: {"action": "get_files", "path": "res://scripts", "filter": "*.gd"}
- Check exists: {"action": "exists", "path": "res://assets"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["list", "create", "delete", "exists", "get_files"],
						"description": "Directory action"
					},
					"path": {
						"type": "string",
						"description": "Directory path (res://...)"
					},
					"filter": {
						"type": "string",
						"description": "File filter pattern (e.g., *.gd, *.tscn)"
					},
					"recursive": {
						"type": "boolean",
						"description": "Include subdirectories"
					}
				},
				"required": ["action", "path"]
			}
		},
		{
			"name": "file_read",
			"description": """FILE READ: Read file content and inspect file presence or metadata.

ACTIONS:
- read: Read file contents
- exists: Check if file exists
- get_info: Get file information

NOTE: For script files, prefer using script_read, script_inspect, or script_edit_gd tools.
For resources, prefer using resource_query, resource_file_ops, or resource_create tools.

EXAMPLES:
- Read file: {"action": "read", "path": "res://data/config.json"}
- Get info: {"action": "get_info", "path": "res://project.godot"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["read", "exists", "get_info"],
						"description": "File action"
					},
					"path": {
						"type": "string",
						"description": "File path"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "file_write",
			"description": """FILE WRITE: Create or append plain-text files inside the project.

ACTIONS:
- write: Write content to file
- append: Append content to file

EXAMPLES:
- Write file: {"action": "write", "path": "res://data/save.json", "content": "{\\"level\\": 1}"}
- Append file: {"action": "append", "path": "res://notes.txt", "content": "\\nline"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["write", "append"],
						"description": "Write action"
					},
					"path": {
						"type": "string",
						"description": "File path"
					},
					"content": {
						"type": "string",
						"description": "Content to write/append"
					}
				},
				"required": ["action", "path"]
			}
		},
		{
			"name": "file_manage",
			"description": """FILE MANAGE: Delete, copy or move files in the project.

ACTIONS:
- delete: Delete a file
- copy: Copy a file
- move: Move or rename a file

EXAMPLES:
- Delete: {"action": "delete", "path": "res://old.txt"}
- Copy: {"action": "copy", "source": "res://template.txt", "dest": "res://copy.txt"}
- Move: {"action": "move", "source": "res://old.txt", "dest": "res://new.txt"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["delete", "copy", "move"],
						"description": "Manage action"
					},
					"path": {
						"type": "string",
						"description": "File path"
					},
					"source": {
						"type": "string",
						"description": "Source path for copy/move"
					},
					"dest": {
						"type": "string",
						"description": "Destination path for copy/move"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "json",
			"description": """JSON OPERATIONS: Read and write JSON files.

ACTIONS:
- read: Read and parse JSON file
- write: Write data as JSON file
- get_value: Get a specific value from JSON file using path
- set_value: Set a specific value in JSON file

EXAMPLES:
- Read JSON: {"action": "read", "path": "res://data/config.json"}
- Write JSON: {"action": "write", "path": "res://data/settings.json", "data": {"volume": 0.8}}
- Get value: {"action": "get_value", "path": "res://data/config.json", "key": "player.health"}
- Set value: {"action": "set_value", "path": "res://data/config.json", "key": "player.health", "value": 100}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["read", "write", "get_value", "set_value"],
						"description": "JSON action"
					},
					"path": {
						"type": "string",
						"description": "JSON file path"
					},
					"data": {
						"description": "Data to write (for write action)"
					},
					"key": {
						"type": "string",
						"description": "Dot-separated path to value (e.g., 'player.health')"
					},
					"value": {
						"description": "Value to set"
					}
				},
				"required": ["action", "path"]
			}
		},
		{
			"name": "search",
			"description": """FILE SEARCH: Search for files and content in the project.

ACTIONS:
- find_files: Find files by name pattern
- grep: Search for text content in files
- find_and_replace: Find and replace text in files

EXAMPLES:
- Find files: {"action": "find_files", "pattern": "*.gd", "path": "res://"}
- Search content: {"action": "grep", "pattern": "func _ready", "path": "res://scripts"}
- Find and replace: {"action": "find_and_replace", "find": "old_name", "replace": "new_name", "path": "res://scripts", "filter": "*.gd"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["find_files", "grep", "find_and_replace"],
						"description": "Search action"
					},
					"pattern": {
						"type": "string",
						"description": "Search pattern"
					},
					"path": {
						"type": "string",
						"description": "Directory to search in"
					},
					"find": {
						"type": "string",
						"description": "Text to find (for find_and_replace)"
					},
					"replace": {
						"type": "string",
						"description": "Replacement text"
					},
					"filter": {
						"type": "string",
						"description": "File filter (e.g., *.gd)"
					},
					"recursive": {
						"type": "boolean",
						"description": "Search recursively"
					}
				},
				"required": ["action"]
			}
		}
	]
