@tool
extends RefCounted


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "shader",
			"description": """SHADER OPERATIONS: Create and manage shader files.

ACTIONS:
- create: Create a new shader file
- read: Read shader code
- write: Write shader code
- get_info: Get shader information (uniforms, modes)
- get_uniforms: Get all uniform parameters
- set_default: Set a uniform's default value

SHADER TYPES:
- spatial: 3D shaders (Mesh materials)
- canvas_item: 2D shaders (CanvasItem materials)
- particles: GPU particle shaders
- sky: Sky shaders
- fog: Fog volume shaders

EXAMPLES:
- Create shader: {"action": "create", "path": "res://shaders/custom.gdshader", "type": "spatial"}
- Read shader: {"action": "read", "path": "res://shaders/custom.gdshader"}
- Write shader: {"action": "write", "path": "res://shaders/custom.gdshader", "code": "shader_type spatial;\\n..."}
- Get uniforms: {"action": "get_uniforms", "path": "res://shaders/custom.gdshader"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["create", "read", "write", "get_info", "get_uniforms", "set_default"],
						"description": "Shader action"
					},
					"path": {
						"type": "string",
						"description": "Shader file path (res://...gdshader)"
					},
					"type": {
						"type": "string",
						"enum": ["spatial", "canvas_item", "particles", "sky", "fog"],
						"description": "Shader type for creation"
					},
					"code": {
						"type": "string",
						"description": "Shader code"
					},
					"uniform": {
						"type": "string",
						"description": "Uniform name"
					},
					"value": {
						"description": "Default value for uniform"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "shader_material",
			"description": """SHADER MATERIAL: Manage ShaderMaterial instances.

ACTIONS:
- create: Create a new ShaderMaterial
- get_info: Get material information
- set_shader: Set the shader
- get_param: Get a shader parameter value
- set_param: Set a shader parameter value
- list_params: List all shader parameters
- assign_to_node: Assign to a node

EXAMPLES:
- Create material: {"action": "create", "shader_path": "res://shaders/custom.gdshader"}
- Get param: {"action": "get_param", "path": "res://materials/custom.tres", "param": "albedo_color"}
- Set param: {"action": "set_param", "path": "res://materials/custom.tres", "param": "speed", "value": 2.5}
- Assign to node: {"action": "assign_to_node", "material_path": "res://materials/custom.tres", "node_path": "/root/Mesh", "surface": 0}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["create", "get_info", "set_shader", "get_param", "set_param", "list_params", "assign_to_node"],
						"description": "Material action"
					},
					"path": {
						"type": "string",
						"description": "ShaderMaterial resource path"
					},
					"shader_path": {
						"type": "string",
						"description": "Shader file path"
					},
					"material_path": {
						"type": "string",
						"description": "Material path for assignment"
					},
					"node_path": {
						"type": "string",
						"description": "Target node path"
					},
					"surface": {
						"type": "integer",
						"description": "Surface index"
					},
					"param": {
						"type": "string",
						"description": "Parameter name"
					},
					"value": {
						"description": "Parameter value"
					},
					"save_path": {
						"type": "string",
						"description": "Path to save material"
					}
				},
				"required": ["action"]
			}
		}
	]
