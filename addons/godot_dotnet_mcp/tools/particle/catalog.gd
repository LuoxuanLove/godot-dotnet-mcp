@tool
extends RefCounted


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "particles",
			"description": """PARTICLE EMITTERS: Create and control particle systems.

ACTIONS:
- create: Create a particle emitter node
- get_info: Get emitter information
- set_emitting: Start/stop emission
- restart: Restart emission
- set_amount: Set particle count
- set_lifetime: Set particle lifetime
- set_one_shot: Set one-shot mode
- set_explosiveness: Set explosiveness ratio
- set_randomness: Set randomness ratio
- set_speed_scale: Set speed scale
- set_process_material: Assign ParticleProcessMaterial
- set_draw_order: Set particle draw order
- convert_to_cpu: Convert GPU particles to CPU particles

EMITTER TYPES:
- gpu_particles_2d: GPU-accelerated 2D particles
- gpu_particles_3d: GPU-accelerated 3D particles
- cpu_particles_2d: CPU-based 2D particles
- cpu_particles_3d: CPU-based 3D particles

EXAMPLES:
- Create emitter: {"action": "create", "type": "gpu_particles_3d", "parent": "/root/Scene"}
- Start emitting: {"action": "set_emitting", "path": "/root/GPUParticles3D", "emitting": true}
- Set amount: {"action": "set_amount", "path": "/root/GPUParticles3D", "amount": 100}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["create", "get_info", "set_emitting", "restart", "set_amount", "set_lifetime", "set_one_shot", "set_explosiveness", "set_randomness", "set_speed_scale", "set_process_material", "set_draw_order", "convert_to_cpu"],
						"description": "Particle action"
					},
					"path": {
						"type": "string",
						"description": "Particle emitter node path"
					},
					"parent": {
						"type": "string",
						"description": "Parent node path for creation"
					},
					"name": {
						"type": "string",
						"description": "Node name"
					},
					"type": {
						"type": "string",
						"enum": ["gpu_particles_2d", "gpu_particles_3d", "cpu_particles_2d", "cpu_particles_3d"],
						"description": "Emitter type"
					},
					"emitting": {
						"type": "boolean",
						"description": "Emission state"
					},
					"amount": {
						"type": "integer",
						"description": "Number of particles"
					},
					"lifetime": {
						"type": "number",
						"description": "Particle lifetime in seconds"
					},
					"one_shot": {
						"type": "boolean",
						"description": "One-shot mode"
					},
					"explosiveness": {
						"type": "number",
						"description": "Explosiveness ratio (0-1)"
					},
					"randomness": {
						"type": "number",
						"description": "Randomness ratio (0-1)"
					},
					"speed_scale": {
						"type": "number",
						"description": "Speed scale multiplier"
					},
					"draw_order": {
						"type": "string",
						"enum": ["index", "lifetime", "reverse_lifetime", "view_depth"],
						"description": "Draw order mode"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "particle_material",
			"description": """PARTICLE MATERIAL: Configure ParticleProcessMaterial properties.

ACTIONS:
- create: Create and assign a new ParticleProcessMaterial
- get_info: Get material properties
- set_direction: Set emission direction
- set_spread: Set spread angle
- set_gravity: Set gravity vector
- set_velocity: Set initial velocity (min/max)
- set_angular_velocity: Set angular velocity
- set_orbit_velocity: Set orbit velocity
- set_linear_accel: Set linear acceleration
- set_radial_accel: Set radial acceleration
- set_tangential_accel: Set tangential acceleration
- set_damping: Set damping
- set_scale: Set particle scale (min/max)
- set_color: Set particle color
- set_color_ramp: Set color gradient
- set_emission_shape: Set emission shape
- set_emission_sphere: Set sphere emission radius
- set_emission_box: Set box emission extents

EXAMPLES:
- Create material: {"action": "create", "path": "/root/GPUParticles3D"}
- Set gravity: {"action": "set_gravity", "path": "/root/GPUParticles3D", "gravity": {"x": 0, "y": -9.8, "z": 0}}
- Set velocity: {"action": "set_velocity", "path": "/root/GPUParticles3D", "min": 5, "max": 10}
- Set scale: {"action": "set_scale", "path": "/root/GPUParticles3D", "min": 0.5, "max": 1.5}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["create", "get_info", "set_direction", "set_spread", "set_gravity", "set_velocity", "set_angular_velocity", "set_orbit_velocity", "set_linear_accel", "set_radial_accel", "set_tangential_accel", "set_damping", "set_scale", "set_color", "set_color_ramp", "set_emission_shape", "set_emission_sphere", "set_emission_box"],
						"description": "Material action"
					},
					"path": {
						"type": "string",
						"description": "Particle emitter path"
					},
					"direction": {
						"type": "object",
						"description": "Direction vector"
					},
					"spread": {
						"type": "number",
						"description": "Spread angle in degrees"
					},
					"gravity": {
						"type": "object",
						"description": "Gravity vector"
					},
					"min": {
						"type": "number",
						"description": "Minimum value"
					},
					"max": {
						"type": "number",
						"description": "Maximum value"
					},
					"color": {
						"type": "object",
						"description": "Color {r, g, b, a}"
					},
					"shape": {
						"type": "string",
						"enum": ["point", "sphere", "sphere_surface", "box", "ring"],
						"description": "Emission shape"
					},
					"radius": {
						"type": "number",
						"description": "Sphere radius"
					},
					"extents": {
						"type": "object",
						"description": "Box extents {x, y, z}"
					}
				},
				"required": ["action"]
			}
		}
	]
