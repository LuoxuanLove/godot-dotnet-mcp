@tool
extends RefCounted


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "player",
			"description": "ANIMATION PLAYER: Control AnimationPlayer playback and inspection.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["list", "play", "stop", "pause", "seek", "get_current", "set_speed"]},
					"path": {"type": "string"},
					"animation": {"type": "string"},
					"backwards": {"type": "boolean"},
					"time": {"type": "number"},
					"speed": {"type": "number"}
				},
				"required": ["action", "path"]
			}
		},
		{
			"name": "animation",
			"description": "ANIMATION RESOURCE: Create and manage Animation resources on an AnimationPlayer.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["create", "delete", "duplicate", "rename", "get_info", "set_length", "set_loop"]},
					"path": {"type": "string"},
					"name": {"type": "string"},
					"new_name": {"type": "string"},
					"length": {"type": "number"},
					"loop": {"type": "boolean"}
				},
				"required": ["action", "path"]
			}
		},
		{
			"name": "track",
			"description": "ANIMATION TRACK: Manage animation tracks and keyframes.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["list", "add_property_track", "add_method_track", "remove_track", "add_key", "remove_key"]},
					"path": {"type": "string"},
					"animation": {"type": "string"},
					"node_path": {"type": "string"},
					"track": {"type": "integer"},
					"time": {"type": "number"},
					"value": {},
					"method": {"type": "string"},
					"key": {"type": "integer"}
				},
				"required": ["action", "path"]
			}
		},
		{
			"name": "tween",
			"description": "TWEEN: Provide tween documentation and simple property tween creation.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["create", "property", "method", "callback", "info"]},
					"path": {"type": "string"},
					"property": {"type": "string"},
					"final_value": {},
					"duration": {"type": "number"},
					"ease": {"type": "string", "enum": ["LINEAR", "SINE", "QUAD", "CUBIC", "QUART", "QUINT", "EXPO", "CIRC", "ELASTIC", "BACK", "BOUNCE", "IN", "OUT", "IN_OUT", "OUT_IN"]},
					"trans": {"type": "string", "enum": ["LINEAR", "SINE", "QUAD", "CUBIC", "QUART", "QUINT", "EXPO", "CIRC", "ELASTIC", "BACK", "BOUNCE", "IN", "OUT", "IN_OUT", "OUT_IN"]}
				},
				"required": ["action"]
			}
		},
		{
			"name": "animation_tree",
			"description": "ANIMATION TREE: Create and configure AnimationTree nodes.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["create", "get", "set_active", "set_root", "set_player", "set_parameter", "get_parameters"]},
					"path": {"type": "string"},
					"name": {"type": "string"},
					"root_type": {"type": "string", "enum": ["state_machine", "blend_tree", "blend_space_1d", "blend_space_2d", "animation"]},
					"active": {"type": "boolean"},
					"player": {"type": "string"},
					"parameter": {"type": "string"},
					"value": {}
				},
				"required": ["action"]
			}
		},
		{
			"name": "state_machine",
			"description": "STATE MACHINE: Configure AnimationNodeStateMachine graphs.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["add_state", "remove_state", "add_transition", "remove_transition", "set_start", "set_end", "list_states", "list_transitions", "travel", "get_current"]},
					"path": {"type": "string"},
					"state": {"type": "string"},
					"animation": {"type": "string"},
					"type": {"type": "string", "enum": ["animation", "blend_space_1d", "blend_space_2d", "blend_tree", "state_machine"]},
					"from": {"type": "string"},
					"to": {"type": "string"},
					"advance_mode": {"type": "string", "enum": ["auto", "enabled", "disabled"]},
					"switch_mode": {"type": "string", "enum": ["immediate", "sync", "at_end"]},
					"xfade_time": {"type": "number"},
					"position": {"type": "object"}
				},
				"required": ["action", "path"]
			}
		},
		{
			"name": "blend_space",
			"description": "BLEND SPACE: Configure BlendSpace1D and BlendSpace2D nodes.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["add_point", "remove_point", "set_blend_mode", "get_points", "set_min_max", "set_snap", "triangulate"]},
					"path": {"type": "string"},
					"node": {"type": "string"},
					"animation": {"type": "string"},
					"position": {},
					"point_index": {"type": "integer"},
					"blend_mode": {"type": "string", "enum": ["interpolated", "discrete", "discrete_carry"]},
					"min": {"type": "number"},
					"max": {"type": "number"},
					"min_x": {"type": "number"},
					"max_x": {"type": "number"},
					"min_y": {"type": "number"},
					"max_y": {"type": "number"},
					"snap": {"type": "number"}
				},
				"required": ["action", "path"]
			}
		},
		{
			"name": "blend_tree",
			"description": "BLEND TREE: Build AnimationNodeBlendTree graphs.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["add_node", "remove_node", "connect", "disconnect", "set_position", "list_nodes", "set_node_parameter"]},
					"path": {"type": "string"},
					"name": {"type": "string"},
					"type": {"type": "string", "enum": ["animation", "blend2", "blend3", "add2", "add3", "one_shot", "time_scale", "time_seek", "transition", "blend_space_1d", "blend_space_2d", "state_machine"]},
					"animation": {"type": "string"},
					"from": {"type": "string"},
					"to": {"type": "string"},
					"port": {"type": "integer"},
					"position": {"type": "object"},
					"parameter": {"type": "string"},
					"value": {}
				},
				"required": ["action", "path"]
			}
		}
	]
