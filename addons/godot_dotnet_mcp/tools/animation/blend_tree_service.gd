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
	var blend_tree = tree.tree_root
	if not blend_tree is AnimationNodeBlendTree:
		return _error("Tree root is not a BlendTree")
	match action:
		"add_node":
			return _add_blend_tree_node(blend_tree, args)
		"remove_node":
			return _remove_blend_tree_node(blend_tree, args.get("name", ""))
		"connect":
			return _connect_blend_tree_nodes(blend_tree, args)
		"disconnect":
			return _disconnect_blend_tree_nodes(blend_tree, args)
		"set_position":
			return _set_blend_tree_node_position(blend_tree, args)
		"list_nodes":
			return _list_blend_tree_nodes(blend_tree)
		"set_node_parameter":
			return _set_blend_tree_node_parameter(blend_tree, args)
		_:
			return _error("Unknown action: %s" % action)


func _add_blend_tree_node(bt: AnimationNodeBlendTree, args: Dictionary) -> Dictionary:
	var node_name = args.get("name", "")
	var node_type = args.get("type", "animation")
	var animation = args.get("animation", "")
	var position = args.get("position", {})
	if node_name.is_empty():
		return _error("Node name is required")
	if bt.has_node(node_name):
		return _error("Node already exists: %s" % node_name)
	var node: AnimationNode
	match node_type:
		"animation":
			var anim_node = AnimationNodeAnimation.new()
			if not animation.is_empty():
				anim_node.animation = animation
			node = anim_node
		"blend2":
			node = AnimationNodeBlend2.new()
		"blend3":
			node = AnimationNodeBlend3.new()
		"add2":
			node = AnimationNodeAdd2.new()
		"add3":
			node = AnimationNodeAdd3.new()
		"one_shot":
			node = AnimationNodeOneShot.new()
		"time_scale":
			node = AnimationNodeTimeScale.new()
		"time_seek":
			node = AnimationNodeTimeSeek.new()
		"transition":
			node = AnimationNodeTransition.new()
		"blend_space_1d":
			node = AnimationNodeBlendSpace1D.new()
		"blend_space_2d":
			node = AnimationNodeBlendSpace2D.new()
		"state_machine":
			node = AnimationNodeStateMachine.new()
		_:
			return _error("Unknown node type: %s" % node_type)
	var pos = Vector2.ZERO
	if position.has("x") and position.has("y"):
		pos = Vector2(position.x, position.y)
	bt.add_node(node_name, node, pos)
	return _success({"name": node_name, "type": node_type, "animation": animation if node_type == "animation" else null, "position": {"x": pos.x, "y": pos.y}}, "Node added")


func _remove_blend_tree_node(bt: AnimationNodeBlendTree, node_name: String) -> Dictionary:
	if node_name.is_empty():
		return _error("Node name is required")
	if not bt.has_node(node_name):
		return _error("Node not found: %s" % node_name)
	bt.remove_node(node_name)
	return _success({"name": node_name}, "Node removed")


func _connect_blend_tree_nodes(bt: AnimationNodeBlendTree, args: Dictionary) -> Dictionary:
	var from_node = args.get("from", "")
	var to_node = args.get("to", "")
	var port = args.get("port", 0)
	if from_node.is_empty() or to_node.is_empty():
		return _error("Both 'from' and 'to' nodes are required")
	if from_node != "output" and not bt.has_node(from_node):
		return _error("Source node not found: %s" % from_node)
	if to_node != "output" and not bt.has_node(to_node):
		return _error("Target node not found: %s" % to_node)
	bt.connect_node(to_node, port, from_node)
	return _success({"from": from_node, "to": to_node, "port": port}, "Nodes connected")


func _disconnect_blend_tree_nodes(bt: AnimationNodeBlendTree, args: Dictionary) -> Dictionary:
	var to_node = args.get("to", "")
	var port = args.get("port", 0)
	if to_node.is_empty():
		return _error("Target node is required")
	bt.disconnect_node(to_node, port)
	return _success({"to": to_node, "port": port}, "Nodes disconnected")


func _set_blend_tree_node_position(bt: AnimationNodeBlendTree, args: Dictionary) -> Dictionary:
	var node_name = args.get("name", "")
	var position = args.get("position", {})
	if node_name.is_empty():
		return _error("Node name is required")
	if not bt.has_node(node_name):
		return _error("Node not found: %s" % node_name)
	var pos = Vector2.ZERO
	if position.has("x") and position.has("y"):
		pos = Vector2(position.x, position.y)
	bt.set_node_position(node_name, pos)
	return _success({"name": node_name, "position": {"x": pos.x, "y": pos.y}}, "Position set")


func _list_blend_tree_nodes(bt: AnimationNodeBlendTree) -> Dictionary:
	var nodes: Array[Dictionary] = []
	var node_list: Array = []
	for potential_name in ["output"]:
		if bt.has_node(potential_name):
			node_list.append(potential_name)
	for prop in bt.get_property_list():
		var prop_name = str(prop.name)
		if prop_name.begins_with("nodes/") and prop_name.ends_with("/node"):
			var node_name = prop_name.replace("nodes/", "").replace("/node", "")
			if not node_name in node_list:
				node_list.append(node_name)
	for node_name in node_list:
		if not bt.has_node(node_name):
			continue
		var node = bt.get_node(node_name)
		var pos = bt.get_node_position(node_name)
		var info: Dictionary = {"name": node_name, "type": node.get_class(), "position": {"x": pos.x, "y": pos.y}}
		if node is AnimationNodeAnimation:
			info["animation"] = node.animation
		nodes.append(info)
	return _success({"count": nodes.size(), "nodes": nodes})


func _set_blend_tree_node_parameter(bt: AnimationNodeBlendTree, args: Dictionary) -> Dictionary:
	var node_name = args.get("name", "")
	var parameter = args.get("parameter", "")
	var value = args.get("value")
	if node_name.is_empty():
		return _error("Node name is required")
	if parameter.is_empty():
		return _error("Parameter name is required")
	if not bt.has_node(node_name):
		return _error("Node not found: %s" % node_name)
	var node = bt.get_node(node_name)
	if not parameter in node:
		return _error("Parameter not found: %s" % parameter)
	node.set(parameter, _convert_track_value(value))
	return _success({"name": node_name, "parameter": parameter, "value": _serialize_value(value)}, "Parameter set")
