@tool
extends "res://addons/godot_dotnet_mcp/tools/animation/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	var path = args.get("path", "")
	if path.is_empty():
		return _error("Path is required")
	var tree = _get_animation_tree(path)
	if tree == null:
		return _error("Node is not an AnimationTree")
	var state_machine = tree.tree_root
	if not state_machine is AnimationNodeStateMachine:
		return _error("Tree root is not a StateMachine")
	match action:
		"add_state":
			return _add_state(tree, state_machine, args)
		"remove_state":
			return _remove_state(state_machine, args.get("state", ""))
		"add_transition":
			return _add_transition(state_machine, args)
		"remove_transition":
			return _remove_transition(state_machine, args.get("from", ""), args.get("to", ""))
		"set_start":
			return _set_start_state(state_machine, args.get("state", ""))
		"set_end":
			return _set_end_state(state_machine, args.get("state", ""))
		"list_states":
			return _list_states(state_machine)
		"list_transitions":
			return _list_transitions(state_machine)
		"travel":
			return _travel_to_state(tree, args.get("state", ""))
		"get_current":
			return _get_current_state(tree)
		_:
			return _error("Unknown action: %s" % action)


func _add_state(_tree: AnimationTree, sm: AnimationNodeStateMachine, args: Dictionary) -> Dictionary:
	var state_name = args.get("state", "")
	var state_type = args.get("type", "animation")
	var animation = args.get("animation", "")
	var position = args.get("position", {})
	if state_name.is_empty():
		return _error("State name is required")
	if sm.has_node(state_name):
		return _error("State already exists: %s" % state_name)
	var state_node: AnimationRootNode
	match state_type:
		"animation":
			var anim_node = AnimationNodeAnimation.new()
			if not animation.is_empty():
				anim_node.animation = animation
			state_node = anim_node
		"blend_space_1d":
			state_node = AnimationNodeBlendSpace1D.new()
		"blend_space_2d":
			state_node = AnimationNodeBlendSpace2D.new()
		"blend_tree":
			state_node = AnimationNodeBlendTree.new()
		"state_machine":
			state_node = AnimationNodeStateMachine.new()
		_:
			return _error("Unknown state type: %s" % state_type)
	var pos = Vector2.ZERO
	if position.has("x") and position.has("y"):
		pos = Vector2(position.x, position.y)
	sm.add_node(state_name, state_node, pos)
	return _success({"state": state_name, "type": state_type, "animation": animation, "position": {"x": pos.x, "y": pos.y}}, "State added")


func _remove_state(sm: AnimationNodeStateMachine, state_name: String) -> Dictionary:
	if state_name.is_empty():
		return _error("State name is required")
	if not sm.has_node(state_name):
		return _error("State not found: %s" % state_name)
	sm.remove_node(state_name)
	return _success({"state": state_name}, "State removed")


func _add_transition(sm: AnimationNodeStateMachine, args: Dictionary) -> Dictionary:
	var from_state = args.get("from", "")
	var to_state = args.get("to", "")
	var advance_mode = args.get("advance_mode", "auto")
	var switch_mode = args.get("switch_mode", "immediate")
	var xfade_time = args.get("xfade_time", 0.0)
	if from_state.is_empty() or to_state.is_empty():
		return _error("Both 'from' and 'to' states are required")
	if not sm.has_node(from_state):
		return _error("Source state not found: %s" % from_state)
	if not sm.has_node(to_state):
		return _error("Target state not found: %s" % to_state)
	var transition = AnimationNodeStateMachineTransition.new()
	match advance_mode:
		"auto":
			transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
		"enabled":
			transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
		"disabled":
			transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_DISABLED
	match switch_mode:
		"immediate":
			transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
		"sync":
			transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_SYNC
		"at_end":
			transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	transition.xfade_time = xfade_time
	sm.add_transition(from_state, to_state, transition)
	return _success({"from": from_state, "to": to_state, "advance_mode": advance_mode, "switch_mode": switch_mode, "xfade_time": xfade_time}, "Transition added")


func _remove_transition(sm: AnimationNodeStateMachine, from_state: String, to_state: String) -> Dictionary:
	if from_state.is_empty() or to_state.is_empty():
		return _error("Both 'from' and 'to' states are required")
	if sm.has_transition(from_state, to_state):
		sm.remove_transition_by_index(sm.find_transition(from_state, to_state))
		return _success({"from": from_state, "to": to_state}, "Transition removed")
	return _error("Transition not found: %s -> %s" % [from_state, to_state])


func _set_start_state(sm: AnimationNodeStateMachine, state_name: String) -> Dictionary:
	if state_name.is_empty():
		return _error("State name is required")
	if not sm.has_node(state_name):
		return _error("State not found: %s" % state_name)
	sm.set_graph_offset(sm.get_node_position(state_name))
	return _success({"start_state": state_name}, "Start state set")


func _set_end_state(sm: AnimationNodeStateMachine, state_name: String) -> Dictionary:
	if state_name.is_empty():
		return _error("State name is required")
	if not sm.has_node(state_name):
		return _error("State not found: %s" % state_name)
	return _success({"end_state": state_name, "note": "End states are defined by transitions with no outgoing connections"}, "End state noted")


func _list_states(sm: AnimationNodeStateMachine) -> Dictionary:
	var states: Array[Dictionary] = []
	var node_names = sm.get_node_list()
	for node_name in node_names:
		if sm.has_node(node_name):
			var node = sm.get_node(node_name)
			var pos = sm.get_node_position(node_name)
			states.append({"name": str(node_name), "type": node.get_class(), "position": {"x": pos.x, "y": pos.y}})
	return _success({"count": states.size(), "states": states})


func _list_transitions(sm: AnimationNodeStateMachine) -> Dictionary:
	var transitions: Array[Dictionary] = []
	for i in range(sm.get_transition_count()):
		var transition = sm.get_transition(i)
		transitions.append({"from": sm.get_transition_from(i), "to": sm.get_transition_to(i), "advance_mode": transition.advance_mode, "switch_mode": transition.switch_mode, "xfade_time": transition.xfade_time})
	return _success({"count": transitions.size(), "transitions": transitions})


func _travel_to_state(tree: AnimationTree, state_name: String) -> Dictionary:
	if state_name.is_empty():
		return _error("State name is required")
	var playback = tree.get("parameters/playback")
	if playback and playback is AnimationNodeStateMachinePlayback:
		playback.travel(state_name)
		return _success({"target_state": state_name}, "Traveling to state")
	return _error("Could not get state machine playback")


func _get_current_state(tree: AnimationTree) -> Dictionary:
	var playback = tree.get("parameters/playback")
	if playback and playback is AnimationNodeStateMachinePlayback:
		return _success({"current_state": playback.get_current_node(), "is_playing": playback.is_playing(), "travel_path": playback.get_travel_path()})
	return _error("Could not get state machine playback")
