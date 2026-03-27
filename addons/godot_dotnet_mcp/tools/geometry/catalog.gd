@tool
extends RefCounted


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "csg",
			"description": """CSG: Create and combine 3D primitives.""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["create", "get_info", "set_operation", "set_material", "set_size", "set_use_collision", "bake_mesh", "list"]
					},
					"path": {"type": "string"},
					"parent": {"type": "string"},
					"name": {"type": "string"},
					"type": {
						"type": "string",
						"enum": ["csg_box_3d", "csg_sphere_3d", "csg_cylinder_3d", "csg_torus_3d", "csg_polygon_3d", "csg_mesh_3d", "csg_combiner_3d"]
					},
					"operation": {
						"type": "string",
						"enum": ["union", "intersection", "subtraction"]
					},
					"material": {"type": "string"},
					"size": {"type": "object"},
					"radius": {"type": "number"},
					"height": {"type": "number"},
					"use_collision": {"type": "boolean"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "gridmap",
			"description": """GRIDMAP: 3D tile-based level design.""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["create", "get_info", "set_mesh_library", "get_cell", "set_cell", "erase_cell", "clear", "get_used_cells", "get_used_cells_by_item", "get_meshes", "set_cell_size"]
					},
					"path": {"type": "string"},
					"parent": {"type": "string"},
					"name": {"type": "string"},
					"library": {"type": "string"},
					"x": {"type": "integer"},
					"y": {"type": "integer"},
					"z": {"type": "integer"},
					"item": {"type": "integer"},
					"orientation": {"type": "integer"},
					"cell_size": {"type": "object"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "multimesh",
			"description": """MULTIMESH: Efficient rendering of many identical meshes.""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["create", "get_info", "set_mesh", "set_instance_count", "set_transform", "set_color", "set_custom_data", "set_visible_count", "populate_random", "clear"]
					},
					"path": {"type": "string"},
					"parent": {"type": "string"},
					"name": {"type": "string"},
					"mesh": {"type": "string"},
					"count": {"type": "integer"},
					"index": {"type": "integer"},
					"position": {"type": "object"},
					"rotation": {"type": "object"},
					"scale": {"type": "object"},
					"color": {"type": "object"},
					"bounds": {"type": "object"},
					"use_colors": {"type": "boolean"}
				},
				"required": ["action"]
			}
		}
	]
