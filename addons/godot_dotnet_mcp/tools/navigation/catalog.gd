@tool
extends RefCounted


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "navigation",
			"description": """NAVIGATION SYSTEM: Manage navigation meshes, regions, and agents.

ACTIONS:
- get_map_info: Get navigation map information
- list_regions: List all NavigationRegion2D/3D nodes
- list_agents: List all NavigationAgent2D/3D nodes
- bake_mesh: Bake a NavigationRegion's mesh
- get_path: Calculate path between two points
- set_agent_target: Set an agent's target position
- get_agent_info: Get agent state information
- set_region_enabled: Enable/disable a navigation region
- set_agent_enabled: Enable/disable navigation agent
""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["get_map_info", "list_regions", "list_agents", "bake_mesh", "get_path", "set_agent_target", "get_agent_info", "set_region_enabled", "set_agent_enabled"],
						"description": "Navigation action"
					},
					"path": {
						"type": "string",
						"description": "Node path for regions/agents"
					},
					"mode": {
						"type": "string",
						"enum": ["2d", "3d"],
						"description": "Navigation mode"
					},
					"from": {
						"type": "object",
						"description": "Start position"
					},
					"to": {
						"type": "object",
						"description": "End position"
					},
					"target": {
						"type": "object",
						"description": "Target position for agent"
					},
					"enabled": {
						"type": "boolean",
						"description": "Enable/disable state"
					}
				},
				"required": ["action"]
			}
		}
	]
