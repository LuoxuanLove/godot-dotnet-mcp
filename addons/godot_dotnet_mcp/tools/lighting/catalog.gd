@tool
extends RefCounted


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "light",
			"description": """LIGHTS: Create and configure light nodes.""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["create", "get_info", "set_color", "set_energy", "set_shadow", "set_range", "set_angle", "set_bake_mode", "list"]
					},
					"path": {"type": "string"},
					"parent": {"type": "string"},
					"name": {"type": "string"},
					"type": {
						"type": "string",
						"enum": ["directional_light_3d", "omni_light_3d", "spot_light_3d", "directional_light_2d", "point_light_2d"]
					},
					"color": {"type": "object"},
					"energy": {"type": "number"},
					"enabled": {"type": "boolean"},
					"range": {"type": "number"},
					"angle": {"type": "number"},
					"bake_mode": {
						"type": "string",
						"enum": ["disabled", "static", "dynamic"]
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "environment",
			"description": """ENVIRONMENT: Configure WorldEnvironment and Environment resources.""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["create", "get_info", "set_background", "set_background_color", "set_ambient", "set_fog", "set_glow", "set_ssao", "set_ssr", "set_sdfgi", "set_tonemap", "set_adjustments"]
					},
					"path": {"type": "string"},
					"parent": {"type": "string"},
					"mode": {"type": "string"},
					"color": {"type": "object"},
					"source": {"type": "string"},
					"energy": {"type": "number"},
					"enabled": {"type": "boolean"},
					"intensity": {"type": "number"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "sky",
			"description": """SKY: Configure Sky resources for environments.""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["create", "get_info", "set_procedural", "set_physical", "set_panorama", "set_radiance_size", "set_process_mode"]
					},
					"path": {"type": "string"},
					"type": {
						"type": "string",
						"enum": ["procedural", "physical", "panorama"]
					},
					"texture": {"type": "string"},
					"sky_top_color": {"type": "object"},
					"sky_horizon_color": {"type": "object"},
					"ground_bottom_color": {"type": "object"},
					"ground_horizon_color": {"type": "object"},
					"sun_angle_max": {"type": "number"}
				},
				"required": ["action"]
			}
		}
	]
