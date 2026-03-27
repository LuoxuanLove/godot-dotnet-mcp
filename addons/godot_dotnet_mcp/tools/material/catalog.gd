@tool
extends RefCounted


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "material",
			"description": """MATERIAL OPERATIONS: Create and manage materials.

ACTIONS:
- create: Create a new material
- get_info: Get material information
- set_property: Set a material property
- get_property: Get a material property
- list_properties: List all material properties
- assign_to_node: Assign material to a node
- duplicate: Duplicate a material
- save: Save material to file

MATERIAL TYPES:
- StandardMaterial3D: PBR material for 3D
- ORMMaterial3D: ORM workflow material
- ShaderMaterial: Custom shader material
- CanvasItemMaterial: 2D material

COMMON PROPERTIES (StandardMaterial3D):
- albedo_color: Base color
- metallic: Metallic value (0-1)
- roughness: Roughness value (0-1)
- emission: Emission color
- normal_scale: Normal map strength

EXAMPLES:
- Create material: {"action": "create", "type": "StandardMaterial3D", "name": "MyMaterial"}
- Get info: {"action": "get_info", "path": "res://materials/metal.tres"}
- Set property: {"action": "set_property", "path": "res://materials/metal.tres", "property": "metallic", "value": 0.9}
- Assign to node: {"action": "assign_to_node", "material_path": "res://materials/metal.tres", "node_path": "/root/Mesh", "surface": 0}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["create", "get_info", "set_property", "get_property", "list_properties", "assign_to_node", "duplicate", "save"],
						"description": "Material action"
					},
					"type": {
						"type": "string",
						"enum": ["StandardMaterial3D", "ORMMaterial3D", "ShaderMaterial", "CanvasItemMaterial"],
						"description": "Material type for creation"
					},
					"name": {
						"type": "string",
						"description": "Material name"
					},
					"path": {
						"type": "string",
						"description": "Material resource path"
					},
					"material_path": {
						"type": "string",
						"description": "Material to assign"
					},
					"node_path": {
						"type": "string",
						"description": "Target node path"
					},
					"surface": {
						"type": "integer",
						"description": "Surface index for MeshInstance3D"
					},
					"property": {
						"type": "string",
						"description": "Property name"
					},
					"value": {
						"description": "Property value"
					},
					"save_path": {
						"type": "string",
						"description": "Path to save material"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "mesh",
			"description": """MESH OPERATIONS: Query and manipulate meshes.

ACTIONS:
- get_info: Get mesh information
- list_surfaces: List all surfaces in a mesh
- get_surface_material: Get material assigned to a surface
- set_surface_material: Set surface material override
- create_primitive: Create a primitive mesh
- get_aabb: Get mesh bounding box

PRIMITIVE TYPES:
- box: BoxMesh
- sphere: SphereMesh
- cylinder: CylinderMesh
- capsule: CapsuleMesh
- plane: PlaneMesh
- prism: PrismMesh
- torus: TorusMesh
- quad: QuadMesh

EXAMPLES:
- Get mesh info: {"action": "get_info", "path": "/root/MeshInstance3D"}
- List surfaces: {"action": "list_surfaces", "path": "/root/MeshInstance3D"}
- Set surface material: {"action": "set_surface_material", "path": "/root/MeshInstance3D", "surface": 0, "material_path": "res://materials/metal.tres"}
- Create primitive: {"action": "create_primitive", "type": "sphere", "radius": 0.5, "height": 1.0}
- Get AABB: {"action": "get_aabb", "path": "/root/MeshInstance3D"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["get_info", "list_surfaces", "get_surface_material", "set_surface_material", "create_primitive", "get_aabb"],
						"description": "Mesh action"
					},
					"path": {
						"type": "string",
						"description": "MeshInstance3D/MeshInstance2D node path"
					},
					"mesh_path": {
						"type": "string",
						"description": "Mesh resource path"
					},
					"type": {
						"type": "string",
						"enum": ["box", "sphere", "cylinder", "capsule", "plane", "prism", "torus", "quad"],
						"description": "Primitive type"
					},
					"surface": {
						"type": "integer",
						"description": "Surface index"
					},
					"material_path": {
						"type": "string",
						"description": "Material resource path"
					},
					"radius": {
						"type": "number",
						"description": "Primitive radius"
					},
					"height": {
						"type": "number",
						"description": "Primitive height"
					},
					"size": {
						"type": "object",
						"description": "Size {x, y, z}"
					}
				},
				"required": ["action"]
			}
		}
	]
