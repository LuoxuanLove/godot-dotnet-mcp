@tool
extends RefCounted


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "signal",
			"description": """SIGNALS: Inspect and manage node signals and connections.

ACTIONS:
- list: List all signals of a node
- get_info: Get detailed signal information
- list_connections: List all connections of a signal
- connect: Connect a signal to a method
- disconnect: Disconnect a signal
- disconnect_all: Disconnect all connections of a signal
- emit: Emit a signal (for testing)
- is_connected: Check if signal is connected
- list_all_connections: List all signal connections in scene
""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["list", "get_info", "list_connections", "connect", "disconnect", "disconnect_all", "emit", "is_connected", "list_all_connections"],
						"description": "Signal action"
					},
					"path": {
						"type": "string",
						"description": "Node path"
					},
					"source": {
						"type": "string",
						"description": "Source node path (for connect/disconnect)"
					},
					"target": {
						"type": "string",
						"description": "Target node path"
					},
					"signal": {
						"type": "string",
						"description": "Signal name"
					},
					"method": {
						"type": "string",
						"description": "Target method name"
					},
					"args": {
						"type": "array",
						"items": {},
						"description": "Arguments for signal emission"
					},
					"flags": {
						"type": "integer",
						"description": "Connection flags"
					},
					"include_inherited": {
						"type": "boolean",
						"description": "Include inherited signals"
					}
				},
				"required": ["action"]
			}
		}
	]
