@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"
class_name MCPAnimationTools

## Animation tools for Godot MCP
## Provides animation creation, playback control, and track management

const PlayerTools = preload("res://addons/godot_dotnet_mcp/tools/animation/player_tools.gd")
const AnimationResourceTools = preload("res://addons/godot_dotnet_mcp/tools/animation/animation_resource_tools.gd")
const StateMachineTools = preload("res://addons/godot_dotnet_mcp/tools/animation/state_machine_tools.gd")
const TweenTools = preload("res://addons/godot_dotnet_mcp/tools/animation/tween_tools.gd")
const BlendSpaceTools = preload("res://addons/godot_dotnet_mcp/tools/animation/blend_space_tools.gd")
const BlendTreeTools = preload("res://addons/godot_dotnet_mcp/tools/animation/blend_tree_tools.gd")

var _player_tools := PlayerTools.new()
var _animation_resource_tools := AnimationResourceTools.new()
var _state_machine_tools := StateMachineTools.new()
var _tween_tools := TweenTools.new()
var _blend_space_tools := BlendSpaceTools.new()
var _blend_tree_tools := BlendTreeTools.new()


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "player",
			"description": """ANIMATION PLAYER: Control AnimationPlayer nodes.

ACTIONS:
- list: List all animations in an AnimationPlayer
- play: Play an animation
- stop: Stop current animation
- pause: Pause current animation
- seek: Seek to a specific time
- get_current: Get currently playing animation info
- set_speed: Set playback speed

EXAMPLES:
- List animations: {"action": "list", "path": "/root/Player/AnimationPlayer"}
- Play animation: {"action": "play", "path": "/root/Player/AnimationPlayer", "animation": "walk"}
- Play backwards: {"action": "play", "path": "/root/Player/AnimationPlayer", "animation": "walk", "backwards": true}
- Stop: {"action": "stop", "path": "/root/Player/AnimationPlayer"}
- Seek: {"action": "seek", "path": "/root/Player/AnimationPlayer", "time": 0.5}
- Set speed: {"action": "set_speed", "path": "/root/Player/AnimationPlayer", "speed": 2.0}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["list", "play", "stop", "pause", "seek", "get_current", "set_speed"],
						"description": "Animation player action"
					},
					"path": {
						"type": "string",
						"description": "AnimationPlayer node path"
					},
					"animation": {
						"type": "string",
						"description": "Animation name to play"
					},
					"backwards": {
						"type": "boolean",
						"description": "Play animation backwards"
					},
					"time": {
						"type": "number",
						"description": "Time to seek to"
					},
					"speed": {
						"type": "number",
						"description": "Playback speed"
					}
				},
				"required": ["action", "path"]
			}
		},
		{
			"name": "animation",
			"description": """ANIMATION RESOURCE: Create and manage animation resources.

ACTIONS:
- create: Create a new animation
- delete: Delete an animation
- duplicate: Duplicate an animation
- rename: Rename an animation
- get_info: Get animation details (length, tracks, etc.)
- set_length: Set animation length
- set_loop: Set animation looping

EXAMPLES:
- Create animation: {"action": "create", "path": "/root/Player/AnimationPlayer", "name": "attack", "length": 1.0}
- Delete animation: {"action": "delete", "path": "/root/Player/AnimationPlayer", "name": "old_anim"}
- Rename: {"action": "rename", "path": "/root/Player/AnimationPlayer", "name": "walk", "new_name": "walk_slow"}
- Set loop: {"action": "set_loop", "path": "/root/Player/AnimationPlayer", "name": "idle", "loop": true}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["create", "delete", "duplicate", "rename", "get_info", "set_length", "set_loop"],
						"description": "Animation action"
					},
					"path": {
						"type": "string",
						"description": "AnimationPlayer node path"
					},
					"name": {
						"type": "string",
						"description": "Animation name"
					},
					"new_name": {
						"type": "string",
						"description": "New name for rename"
					},
					"length": {
						"type": "number",
						"description": "Animation length in seconds"
					},
					"loop": {
						"type": "boolean",
						"description": "Enable/disable looping"
					}
				},
				"required": ["action", "path"]
			}
		},
		{
			"name": "track",
			"description": """ANIMATION TRACK: Manage animation tracks and keyframes.

ACTIONS:
- list: List all tracks in an animation
- add_property_track: Add a property track
- add_method_track: Add a method call track
- remove_track: Remove a track
- add_key: Add a keyframe to a track
- remove_key: Remove a keyframe

TRACK TYPES:
- Property tracks: Animate any node property
- Method tracks: Call methods at specific times

EXAMPLES:
- List tracks: {"action": "list", "path": "/root/Player/AnimationPlayer", "animation": "walk"}
- Add property track: {"action": "add_property_track", "path": "/root/Player/AnimationPlayer", "animation": "walk", "node_path": "Sprite2D:position"}
- Add key: {"action": "add_key", "path": "/root/Player/AnimationPlayer", "animation": "walk", "track": 0, "time": 0.0, "value": {"x": 0, "y": 0}}
- Add key at end: {"action": "add_key", "path": "/root/Player/AnimationPlayer", "animation": "walk", "track": 0, "time": 1.0, "value": {"x": 100, "y": 0}}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["list", "add_property_track", "add_method_track", "remove_track", "add_key", "remove_key"],
						"description": "Track action"
					},
					"path": {
						"type": "string",
						"description": "AnimationPlayer node path"
					},
					"animation": {
						"type": "string",
						"description": "Animation name"
					},
					"node_path": {
						"type": "string",
						"description": "Node path and property (e.g., 'Sprite2D:position')"
					},
					"track": {
						"type": "integer",
						"description": "Track index"
					},
					"time": {
						"type": "number",
						"description": "Keyframe time"
					},
					"value": {
						"description": "Keyframe value"
					},
					"method": {
						"type": "string",
						"description": "Method name for method track"
					}
				},
				"required": ["action", "path"]
			}
		},
		{
			"name": "tween",
			"description": """TWEEN: Create and control tweens for procedural animations.

ACTIONS:
- create: Create a tween on a node
- property: Tween a property value
- method: Tween with method calls
- callback: Add a callback at the end
- info: Get tween documentation and common usages

EASING TYPES: LINEAR, SINE, QUAD, CUBIC, QUART, QUINT, EXPO, CIRC, ELASTIC, BACK, BOUNCE
TRANSITION TYPES: IN, OUT, IN_OUT, OUT_IN

EXAMPLES:
- Tween position: {"action": "property", "path": "/root/Player", "property": "position", "final_value": {"x": 100, "y": 200}, "duration": 1.0}
- Tween with easing: {"action": "property", "path": "/root/Player", "property": "position", "final_value": {"x": 100, "y": 200}, "duration": 1.0, "ease": "QUAD", "trans": "OUT"}
- Tween modulate: {"action": "property", "path": "/root/Sprite", "property": "modulate", "final_value": {"r": 1, "g": 0, "b": 0, "a": 1}, "duration": 0.5}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["create", "property", "method", "callback", "info"],
						"description": "Tween action"
					},
					"path": {
						"type": "string",
						"description": "Target node path"
					},
					"property": {
						"type": "string",
						"description": "Property to tween"
					},
					"final_value": {
						"description": "Final value of the tween"
					},
					"duration": {
						"type": "number",
						"description": "Tween duration in seconds"
					},
					"ease": {
						"type": "string",
						"enum": ["LINEAR", "SINE", "QUAD", "CUBIC", "QUART", "QUINT", "EXPO", "CIRC", "ELASTIC", "BACK", "BOUNCE"],
						"description": "Easing type"
					},
					"trans": {
						"type": "string",
						"enum": ["IN", "OUT", "IN_OUT", "OUT_IN"],
						"description": "Transition type"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "animation_tree",
			"description": """ANIMATION TREE: Create and manage AnimationTree nodes for advanced animation blending.

ACTIONS:
- create: Create AnimationTree node with specified root type
- get: Get AnimationTree configuration
- set_active: Enable/disable the AnimationTree
- set_root: Set the root animation node type
- set_player: Assign AnimationPlayer to the tree
- set_parameter: Set a tree parameter value
- get_parameters: List all parameters

ROOT TYPES:
- state_machine: AnimationNodeStateMachine
- blend_tree: AnimationNodeBlendTree
- blend_space_1d: AnimationNodeBlendSpace1D
- blend_space_2d: AnimationNodeBlendSpace2D
- animation: AnimationNodeAnimation

EXAMPLES:
- Create tree: {"action": "create", "path": "/root/Player", "name": "AnimationTree", "root_type": "state_machine"}
- Set active: {"action": "set_active", "path": "/root/Player/AnimationTree", "active": true}
- Set player: {"action": "set_player", "path": "/root/Player/AnimationTree", "player": "/root/Player/AnimationPlayer"}
- Set parameter: {"action": "set_parameter", "path": "/root/Player/AnimationTree", "parameter": "parameters/blend_position", "value": 0.5}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["create", "get", "set_active", "set_root", "set_player", "set_parameter", "get_parameters"],
						"description": "AnimationTree action"
					},
					"path": {
						"type": "string",
						"description": "Node path (parent for create, tree for others)"
					},
					"name": {
						"type": "string",
						"description": "Name for new AnimationTree node"
					},
					"root_type": {
						"type": "string",
						"enum": ["state_machine", "blend_tree", "blend_space_1d", "blend_space_2d", "animation"],
						"description": "Root animation node type"
					},
					"active": {
						"type": "boolean",
						"description": "Enable/disable tree processing"
					},
					"player": {
						"type": "string",
						"description": "Path to AnimationPlayer"
					},
					"parameter": {
						"type": "string",
						"description": "Parameter path"
					},
					"value": {
						"description": "Parameter value"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "state_machine",
			"description": """STATE MACHINE: Configure AnimationNodeStateMachine for state-based animation.

ACTIONS:
- add_state: Add animation state to state machine
- remove_state: Remove a state
- add_transition: Add transition between states
- remove_transition: Remove a transition
- set_start: Set start state
- set_end: Set end state
- list_states: List all states
- list_transitions: List all transitions
- travel: Trigger travel to state (at runtime)
- get_current: Get current state

STATE TYPES:
- animation: Play a single animation
- blend_space_1d: 1D blend space
- blend_space_2d: 2D blend space
- blend_tree: Nested blend tree
- state_machine: Nested state machine

EXAMPLES:
- Add state: {"action": "add_state", "path": "/root/Player/AnimationTree", "state": "idle", "animation": "idle_anim"}
- Add blend state: {"action": "add_state", "path": "/root/Player/AnimationTree", "state": "locomotion", "type": "blend_space_2d"}
- Add transition: {"action": "add_transition", "path": "/root/Player/AnimationTree", "from": "idle", "to": "walk", "advance_mode": "auto"}
- Set start: {"action": "set_start", "path": "/root/Player/AnimationTree", "state": "idle"}
- Travel: {"action": "travel", "path": "/root/Player/AnimationTree", "state": "attack"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["add_state", "remove_state", "add_transition", "remove_transition", "set_start", "set_end", "list_states", "list_transitions", "travel", "get_current"],
						"description": "State machine action"
					},
					"path": {
						"type": "string",
						"description": "AnimationTree node path"
					},
					"state": {
						"type": "string",
						"description": "State name"
					},
					"animation": {
						"type": "string",
						"description": "Animation name for animation state"
					},
					"type": {
						"type": "string",
						"enum": ["animation", "blend_space_1d", "blend_space_2d", "blend_tree", "state_machine"],
						"description": "State node type"
					},
					"from": {
						"type": "string",
						"description": "Source state for transition"
					},
					"to": {
						"type": "string",
						"description": "Target state for transition"
					},
					"advance_mode": {
						"type": "string",
						"enum": ["auto", "enabled", "disabled"],
						"description": "Transition advance mode"
					},
					"switch_mode": {
						"type": "string",
						"enum": ["immediate", "sync", "at_end"],
						"description": "Transition switch mode"
					},
					"xfade_time": {
						"type": "number",
						"description": "Cross-fade duration"
					},
					"position": {
						"type": "object",
						"description": "State position in graph editor"
					}
				},
				"required": ["action", "path"]
			}
		},
		{
			"name": "blend_space",
			"description": """BLEND SPACE: Configure BlendSpace1D/2D for animation blending.

ACTIONS:
- add_point: Add blend point with animation
- remove_point: Remove a blend point
- set_blend_mode: Set blend mode
- get_points: List all blend points
- set_min_max: Set blend space bounds
- set_snap: Set snap value for grid
- triangulate: Re-triangulate 2D blend space

BLEND MODES (2D only):
- interpolated: Smooth interpolation
- discrete: Jump to nearest
- discrete_carry: Discrete with carry

EXAMPLES:
- Add 1D point: {"action": "add_point", "path": "/root/Player/AnimationTree", "node": "parameters/locomotion", "animation": "walk", "position": 0.5}
- Add 2D point: {"action": "add_point", "path": "/root/Player/AnimationTree", "node": "parameters/locomotion", "animation": "run_right", "position": {"x": 1, "y": 0}}
- Set bounds: {"action": "set_min_max", "path": "/root/Player/AnimationTree", "node": "parameters/locomotion", "min": -1, "max": 1}
- Set 2D bounds: {"action": "set_min_max", "path": "/root/Player/AnimationTree", "node": "parameters/locomotion", "min_x": -1, "max_x": 1, "min_y": -1, "max_y": 1}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["add_point", "remove_point", "set_blend_mode", "get_points", "set_min_max", "set_snap", "triangulate"],
						"description": "Blend space action"
					},
					"path": {
						"type": "string",
						"description": "AnimationTree node path"
					},
					"node": {
						"type": "string",
						"description": "Path to blend space node within tree"
					},
					"animation": {
						"type": "string",
						"description": "Animation name for blend point"
					},
					"position": {
						"description": "Blend position (number for 1D, {x,y} for 2D)"
					},
					"point_index": {
						"type": "integer",
						"description": "Point index to remove"
					},
					"blend_mode": {
						"type": "string",
						"enum": ["interpolated", "discrete", "discrete_carry"],
						"description": "Blend mode for 2D"
					},
					"min": {
						"type": "number",
						"description": "Minimum value (1D)"
					},
					"max": {
						"type": "number",
						"description": "Maximum value (1D)"
					},
					"min_x": {
						"type": "number",
						"description": "Minimum X value (2D)"
					},
					"max_x": {
						"type": "number",
						"description": "Maximum X value (2D)"
					},
					"min_y": {
						"type": "number",
						"description": "Minimum Y value (2D)"
					},
					"max_y": {
						"type": "number",
						"description": "Maximum Y value (2D)"
					},
					"snap": {
						"type": "number",
						"description": "Snap value for grid"
					}
				},
				"required": ["action", "path"]
			}
		},
		{
			"name": "blend_tree",
			"description": """BLEND TREE: Build AnimationNodeBlendTree for complex animation graphs.

ACTIONS:
- add_node: Add node to blend tree
- remove_node: Remove a node
- connect: Connect two nodes
- disconnect: Disconnect nodes
- set_position: Set node position in graph
- list_nodes: List all nodes and connections
- set_node_parameter: Set node-specific parameter

NODE TYPES:
- animation: AnimationNodeAnimation - plays animation
- blend2: AnimationNodeBlend2 - blend two animations
- blend3: AnimationNodeBlend3 - blend three animations
- add2: AnimationNodeAdd2 - additive blend
- add3: AnimationNodeAdd3 - additive blend 3
- one_shot: AnimationNodeOneShot - one-shot overlay
- time_scale: AnimationNodeTimeScale - speed control
- time_seek: AnimationNodeTimeSeek - seek control
- transition: AnimationNodeTransition - switch between inputs
- blend_space_1d: AnimationNodeBlendSpace1D
- blend_space_2d: AnimationNodeBlendSpace2D
- state_machine: AnimationNodeStateMachine

EXAMPLES:
- Add animation: {"action": "add_node", "path": "/root/Player/AnimationTree", "name": "idle", "type": "animation", "animation": "idle_anim"}
- Add blend: {"action": "add_node", "path": "/root/Player/AnimationTree", "name": "walk_blend", "type": "blend2"}
- Connect: {"action": "connect", "path": "/root/Player/AnimationTree", "from": "idle", "to": "walk_blend", "port": 0}
- Connect to output: {"action": "connect", "path": "/root/Player/AnimationTree", "from": "walk_blend", "to": "output"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["add_node", "remove_node", "connect", "disconnect", "set_position", "list_nodes", "set_node_parameter"],
						"description": "Blend tree action"
					},
					"path": {
						"type": "string",
						"description": "AnimationTree node path"
					},
					"name": {
						"type": "string",
						"description": "Node name in blend tree"
					},
					"type": {
						"type": "string",
						"enum": ["animation", "blend2", "blend3", "add2", "add3", "one_shot", "time_scale", "time_seek", "transition", "blend_space_1d", "blend_space_2d", "state_machine"],
						"description": "Node type to add"
					},
					"animation": {
						"type": "string",
						"description": "Animation name for animation nodes"
					},
					"from": {
						"type": "string",
						"description": "Source node name"
					},
					"to": {
						"type": "string",
						"description": "Target node name"
					},
					"port": {
						"type": "integer",
						"description": "Input port index on target node"
					},
					"position": {
						"type": "object",
						"description": "Node position {x, y}"
					},
					"parameter": {
						"type": "string",
						"description": "Parameter name for set_node_parameter"
					},
					"value": {
						"description": "Parameter value"
					}
				},
				"required": ["action", "path"]
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"player": return _player_tools.execute(null, args)
		"animation": return _animation_resource_tools.execute(null, args)
		"tween": return _tween_tools.execute(null, args)
		"animation_tree": return _execute_animation_tree(args)
		"state_machine": return _state_machine_tools.execute(null, args)
		"blend_space": return _blend_space_tools.execute(null, args)
		"blend_tree": return _blend_tree_tools.execute(null, args)
		_:
			return _error("Unknown tool: %s" % tool_name)
# ==================== ANIMATION TREE ====================

func _execute_animation_tree(args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	var path = args.get("path", "")

	if path.is_empty():
		return _error("Path is required")

	match action:
		"create":
			return _create_animation_tree(args)
		"get":
			return _get_animation_tree(path)
		"set_active":
			return _set_tree_active(path, args.get("active", true))
		"set_root":
			return _set_tree_root(path, args.get("root_type", "state_machine"))
		"set_player":
			return _set_tree_player(path, args.get("player", ""))
		"set_parameter":
			return _set_tree_parameter(path, args.get("parameter", ""), args.get("value"))
		"get_parameters":
			return _get_tree_parameters(path)
		_:
			return _error("Unknown action: %s" % action)


func _create_animation_tree(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var name = args.get("name", "AnimationTree")
	var root_type = args.get("root_type", "state_machine")

	var parent = _find_node_by_path(path)
	if not parent:
		return _error("Parent node not found: %s" % path)

	var tree = AnimationTree.new()
	tree.name = name

	# Create root node based on type
	var root_node = _create_animation_node(root_type)
	if not root_node:
		return _error("Unknown root type: %s" % root_type)

	tree.tree_root = root_node
	parent.add_child(tree)
	tree.owner = parent.owner if parent.owner else parent

	return _success({
		"path": _get_scene_path(tree),
		"name": name,
		"root_type": root_type
	}, "AnimationTree created")


func _create_animation_node(type: String) -> AnimationRootNode:
	match type:
		"state_machine":
			return AnimationNodeStateMachine.new()
		"blend_tree":
			return AnimationNodeBlendTree.new()
		"blend_space_1d":
			return AnimationNodeBlendSpace1D.new()
		"blend_space_2d":
			return AnimationNodeBlendSpace2D.new()
		"animation":
			return AnimationNodeAnimation.new()
		_:
			return null


func _get_animation_tree(path: String) -> Dictionary:
	var node = _find_node_by_path(path)
	if not node:
		return _error("Node not found: %s" % path)

	if not node is AnimationTree:
		return _error("Node is not an AnimationTree")

	var tree: AnimationTree = node
	var root_type = ""
	if tree.tree_root:
		root_type = tree.tree_root.get_class()

	return _success({
		"path": _get_scene_path(tree),
		"active": tree.active,
		"root_type": root_type,
		"anim_player": str(tree.anim_player) if tree.anim_player else "",
		"advance_expression_base_node": str(tree.advance_expression_base_node)
	})


func _set_tree_active(path: String, active: bool) -> Dictionary:
	var node = _find_node_by_path(path)
	if not node:
		return _error("Node not found: %s" % path)

	if not node is AnimationTree:
		return _error("Node is not an AnimationTree")

	var tree: AnimationTree = node
	tree.active = active

	return _success({
		"path": _get_scene_path(tree),
		"active": active
	}, "AnimationTree %s" % ("activated" if active else "deactivated"))


func _set_tree_root(path: String, root_type: String) -> Dictionary:
	var node = _find_node_by_path(path)
	if not node:
		return _error("Node not found: %s" % path)

	if not node is AnimationTree:
		return _error("Node is not an AnimationTree")

	var tree: AnimationTree = node
	var root_node = _create_animation_node(root_type)
	if not root_node:
		return _error("Unknown root type: %s" % root_type)

	tree.tree_root = root_node

	return _success({
		"path": _get_scene_path(tree),
		"root_type": root_type
	}, "Root node set")


func _set_tree_player(path: String, player_path: String) -> Dictionary:
	var node = _find_node_by_path(path)
	if not node:
		return _error("Node not found: %s" % path)

	if not node is AnimationTree:
		return _error("Node is not an AnimationTree")

	var tree: AnimationTree = node

	# Convert absolute path to relative
	var player = _find_node_by_path(player_path)
	if not player:
		return _error("AnimationPlayer not found: %s" % player_path)

	if not player is AnimationPlayer:
		return _error("Node is not an AnimationPlayer: %s" % player_path)

	tree.anim_player = tree.get_path_to(player)

	return _success({
		"path": _get_scene_path(tree),
		"player": str(tree.anim_player)
	}, "AnimationPlayer assigned")


func _set_tree_parameter(path: String, parameter: String, value) -> Dictionary:
	var node = _find_node_by_path(path)
	if not node:
		return _error("Node not found: %s" % path)

	if not node is AnimationTree:
		return _error("Node is not an AnimationTree")

	var tree: AnimationTree = node

	if parameter.is_empty():
		return _error("Parameter path is required")

	# Convert value if needed
	var converted_value = _convert_track_value(value)

	tree.set(parameter, converted_value)

	return _success({
		"path": _get_scene_path(tree),
		"parameter": parameter,
		"value": _serialize_value(converted_value)
	}, "Parameter set")


func _get_tree_parameters(path: String) -> Dictionary:
	var node = _find_node_by_path(path)
	if not node:
		return _error("Node not found: %s" % path)

	if not node is AnimationTree:
		return _error("Node is not an AnimationTree")

	var tree: AnimationTree = node
	var params: Array[Dictionary] = []

	for prop in tree.get_property_list():
		var prop_name = str(prop.name)
		if prop_name.begins_with("parameters/"):
			params.append({
				"name": prop_name,
				"value": _serialize_value(tree.get(prop_name)),
				"type": prop.type
			})

	return _success({
		"path": _get_scene_path(tree),
		"count": params.size(),
		"parameters": params
	})


func _convert_track_value(value):
	return _normalize_input_value(value)
