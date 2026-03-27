@tool
extends RefCounted


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "physics_body",
			"description": """PHYSICS BODIES: Create and configure physics bodies.""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["create", "get_info", "set_mode", "set_mass", "set_gravity_scale", "set_linear_velocity", "set_angular_velocity", "apply_force", "apply_impulse", "set_layers", "set_mask", "freeze"],
						"description": "Physics body action"
					},
					"path": {"type": "string", "description": "Node path of physics body"},
					"parent": {"type": "string", "description": "Parent node path for creation"},
					"name": {"type": "string", "description": "Node name for creation"},
					"type": {
						"type": "string",
						"enum": ["rigid_body_2d", "rigid_body_3d", "character_body_2d", "character_body_3d", "static_body_2d", "static_body_3d", "area_2d", "area_3d"],
						"description": "Body type to create"
					},
					"mode": {"type": "string", "enum": ["static", "kinematic", "rigid", "rigid_linear"], "description": "Body freeze mode"},
					"mass": {"type": "number", "description": "Body mass"},
					"gravity_scale": {"type": "number", "description": "Gravity scale multiplier"},
					"velocity": {"type": "object", "description": "Velocity vector {x, y} or {x, y, z}"},
					"force": {"type": "object", "description": "Force vector"},
					"impulse": {"type": "object", "description": "Impulse vector"},
					"position": {"type": "object", "description": "Position to apply force/impulse"},
					"layers": {"type": "integer", "description": "Collision layer bitmask"},
					"mask": {"type": "integer", "description": "Collision mask bitmask"},
					"frozen": {"type": "boolean", "description": "Freeze state"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "collision_shape",
			"description": """COLLISION SHAPES: Manage collision shapes for physics bodies.""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["create", "get_info", "set_shape", "set_disabled", "create_box", "create_sphere", "create_capsule", "create_cylinder", "create_polygon", "set_size", "make_convex_from_siblings"],
						"description": "Collision shape action"
					},
					"path": {"type": "string", "description": "CollisionShape node path"},
					"parent": {"type": "string", "description": "Parent node path for creation"},
					"name": {"type": "string", "description": "Node name"},
					"mode": {"type": "string", "enum": ["2d", "3d"], "description": "2D or 3D mode"},
					"radius": {"type": "number", "description": "Sphere/capsule radius"},
					"height": {"type": "number", "description": "Capsule/cylinder height"},
					"size": {"type": "object", "description": "Box size {x, y, z} or {x, y}"},
					"points": {"type": "array", "items": {"type": "object"}, "description": "Polygon points array"},
					"disabled": {"type": "boolean", "description": "Disabled state"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "physics_joint",
			"description": """PHYSICS JOINTS: Create and configure joints between physics bodies.""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["create", "get_info", "set_nodes", "set_param", "get_param"],
						"description": "Joint action"
					},
					"path": {"type": "string", "description": "Joint node path"},
					"parent": {"type": "string", "description": "Parent node path"},
					"name": {"type": "string", "description": "Joint node name"},
					"type": {
						"type": "string",
						"enum": ["pin_joint_2d", "groove_joint_2d", "damped_spring_joint_2d", "pin_joint_3d", "hinge_joint_3d", "slider_joint_3d", "cone_twist_joint_3d", "generic_6dof_joint_3d"],
						"description": "Joint type"
					},
					"node_a": {"type": "string", "description": "First body path"},
					"node_b": {"type": "string", "description": "Second body path"},
					"param": {"type": "string", "description": "Parameter name"},
					"value": {"description": "Parameter value"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "physics_query",
			"description": """PHYSICS QUERIES: Perform raycasts, shape casts, and spatial queries.""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["raycast", "shape_cast", "point_check", "intersect_shape", "get_rest_info", "list_bodies_in_area"],
						"description": "Query action"
					},
					"mode": {"type": "string", "enum": ["2d", "3d"], "description": "Physics mode"},
					"from": {"type": "object", "description": "Ray start position"},
					"to": {"type": "object", "description": "Ray end position"},
					"point": {"type": "object", "description": "Point to check"},
					"path": {"type": "string", "description": "Node path (for area queries)"},
					"collision_mask": {"type": "integer", "description": "Collision mask filter"},
					"collide_with_bodies": {"type": "boolean", "description": "Include physics bodies"},
					"collide_with_areas": {"type": "boolean", "description": "Include areas"}
				},
				"required": ["action"]
			}
		}
	]
