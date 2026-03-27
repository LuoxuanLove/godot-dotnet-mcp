@tool
extends RefCounted


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "management",
			"description": """SCENE MANAGEMENT: Control the currently edited scene in Godot Editor.""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["get_current", "open", "save", "save_as", "create", "close", "reload"]
					},
					"path": {"type": "string"},
					"root_type": {
						"type": "string",
						"enum": ["Node", "Node2D", "Node3D", "Control", "CanvasLayer"]
					},
					"name": {"type": "string"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "hierarchy",
			"description": """SCENE HIERARCHY: Inspect and select nodes in the current scene.""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["get_tree", "get_selected", "select"]
					},
					"depth": {"type": "integer"},
					"include_internal": {"type": "boolean"},
					"paths": {"type": "array", "items": {"type": "string"}}
				},
				"required": ["action"]
			}
		},
		{
			"name": "run",
			"description": """SCENE RUN: Run or stop scenes for testing.""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["play_main", "play_current", "play_custom", "stop"]
					},
					"path": {"type": "string"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "bindings",
			"description": """SCENE BINDINGS: Analyze exported script members used by a scene.""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["current", "from_path"]
					},
					"path": {"type": "string"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "audit",
			"description": """SCENE AUDIT: Return structured scene issues derived from exported bindings.""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["current", "from_path"]
					},
					"path": {"type": "string"}
				},
				"required": ["action"]
			}
		}
	]
