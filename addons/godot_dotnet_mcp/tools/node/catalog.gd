@tool
extends RefCounted


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "query",
			"description": """NODE QUERY: Find and inspect nodes in the scene.

ACTIONS:
- find_by_name: Find nodes by name pattern (wildcards: *, ?)
- find_by_type: Find nodes by class type
- find_children: Find children matching pattern and/or type
- find_parent: Find parent node matching pattern
- get_info: Get detailed node information
- get_children: Get direct children
- get_path_to: Get relative path to another node
- tree_string: Get scene tree as formatted string""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["find_by_name", "find_by_type", "find_children", "find_parent", "get_info", "get_children", "get_path_to", "tree_string"]},
					"pattern": {"type": "string"},
					"type": {"type": "string"},
					"path": {"type": "string"},
					"from_path": {"type": "string"},
					"to_path": {"type": "string"},
					"recursive": {"type": "boolean"},
					"owned": {"type": "boolean"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "lifecycle",
			"description": """NODE LIFECYCLE: Create, delete, duplicate, and manage node instances.

ACTIONS:
- create
- delete
- duplicate
- instantiate
- replace
- request_ready
- attach_script
- rename""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["create", "delete", "duplicate", "instantiate", "replace", "request_ready", "attach_script", "rename"]},
					"type": {"type": "string"},
					"name": {"type": "string"},
					"path": {"type": "string"},
					"node_path": {"type": "string"},
					"parent_path": {"type": "string"},
					"scene_path": {"type": "string"},
					"script_path": {"type": "string"},
					"new_name": {"type": "string"},
					"new_node_path": {"type": "string"},
					"flags": {"type": "array", "items": {"type": "string"}}
				},
				"required": ["action"]
			}
		},
		{
			"name": "transform",
			"description": """NODE TRANSFORM: Modify position, rotation, scale.

ACTIONS:
- set_position
- set_rotation
- set_rotation_degrees
- set_scale
- get_transform
- move
- rotate
- look_at
- reset""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["set_position", "set_rotation", "set_rotation_degrees", "set_scale", "get_transform", "move", "rotate", "look_at", "reset"]},
					"path": {"type": "string"},
					"x": {"type": "number"},
					"y": {"type": "number"},
					"z": {"type": "number"},
					"radians": {"type": "number"},
					"degrees": {"type": "number"},
					"global": {"type": "boolean"}
				},
				"required": ["action", "path"]
			}
		},
		{
			"name": "property",
			"description": """NODE PROPERTY: Get and set any node property.

ACTIONS:
- get
- set
- list
- reset
- revert""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["get", "set", "list", "reset", "revert"]},
					"path": {"type": "string"},
					"property": {"type": "string"},
					"value": {},
					"filter": {"type": "string"}
				},
				"required": ["action", "path"]
			}
		},
		{
			"name": "hierarchy",
			"description": """NODE HIERARCHY: Manage parent-child relationships.

ACTIONS:
- reparent
- reorder
- move_up
- move_down
- move_to_front
- move_to_back
- set_owner
- get_owner""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["reparent", "reorder", "move_up", "move_down", "move_to_front", "move_to_back", "set_owner", "get_owner"]},
					"path": {"type": "string"},
					"new_parent": {"type": "string"},
					"index": {"type": "integer"},
					"keep_global": {"type": "boolean"},
					"owner_path": {"type": "string"}
				},
				"required": ["action", "path"]
			}
		},
		{
			"name": "process",
			"description": """PROCESS CONTROL: Manage node processing and input.""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["get_status", "set_process", "set_physics_process", "set_input", "set_unhandled_input", "set_unhandled_key_input", "set_shortcut_input", "set_process_mode", "set_process_priority", "set_physics_priority"]},
					"path": {"type": "string"},
					"enabled": {"type": "boolean"},
					"mode": {"type": "string", "enum": ["inherit", "pausable", "when_paused", "always", "disabled"]},
					"priority": {"type": "integer"}
				},
				"required": ["action", "path"]
			}
		},
		{
			"name": "metadata",
			"description": """METADATA OPERATIONS: Manage custom node metadata.""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["get", "set", "has", "remove", "list"]},
					"path": {"type": "string"},
					"key": {"type": "string"},
					"value": {}
				},
				"required": ["action", "path"]
			}
		},
		{
			"name": "call",
			"description": """METHOD CALLING: Call methods on nodes.""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["call", "call_deferred", "propagate_call", "has_method", "get_method_list"]},
					"path": {"type": "string"},
					"method": {"type": "string"},
					"args": {"type": "array", "items": {}},
					"parent_first": {"type": "boolean"},
					"filter": {"type": "string"}
				},
				"required": ["action", "path"]
			}
		},
		{
			"name": "visibility",
			"description": """VISIBILITY CONTROL: Manage node rendering.""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["show", "hide", "toggle", "is_visible", "set_z_index", "set_z_relative", "set_y_sort", "set_modulate", "set_self_modulate", "set_visibility_layer"]},
					"path": {"type": "string"},
					"value": {},
					"color": {"type": "object"},
					"enabled": {"type": "boolean"}
				},
				"required": ["action", "path"]
			}
		}
	]
