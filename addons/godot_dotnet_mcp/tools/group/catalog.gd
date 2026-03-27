@tool
extends RefCounted


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "group",
			"description": """GROUPS: Manage node groups.

ACTIONS:
- list: List all groups a node belongs to
- add: Add node to a group
- remove: Remove node from a group
- is_in: Check if node is in a group
- get_nodes: Get all nodes in a group
- call_group: Call method on all nodes in group
- set_group: Set property on all nodes in group
""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["list", "add", "remove", "is_in", "get_nodes", "call_group", "set_group"],
						"description": "Group action"
					},
					"path": {
						"type": "string",
						"description": "Node path"
					},
					"group": {
						"type": "string",
						"description": "Group name"
					},
					"method": {
						"type": "string",
						"description": "Method to call"
					},
					"property": {
						"type": "string",
						"description": "Property to set"
					},
					"value": {
						"description": "Value to set"
					},
					"args": {
						"type": "array",
						"items": {},
						"description": "Method arguments"
					}
				},
				"required": ["action"]
			}
		}
	]
