extends RefCounted

const SignalExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/signal/executor.gd")


class SignalReceiver extends Node:
	var received: Array = []

	func _on_timeout() -> void:
		received.append("timeout")


var _scene_root: Node = null


func run_case(tree: SceneTree) -> Dictionary:
	var executor = SignalExecutorScript.new()
	_scene_root = _build_scene_fixture(tree)
	executor.configure_context({"scene_root": _scene_root})

	if ResourceLoader.exists("res://addons/godot_dotnet_mcp/tools/signal_tools.gd"):
		return _failure("signal_tools.gd should be removed once the split executor becomes the only stable entry.")

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 1:
		return _failure("Signal executor should expose 1 tool definition after the split.")
	if str(tool_defs[0].get("name", "")) != "signal":
		return _failure("Signal executor should expose the canonical 'signal' tool definition.")

	var list_result: Dictionary = executor.execute("signal", {
		"action": "list",
		"path": "EmitterNode"
	})
	if not bool(list_result.get("success", false)):
		return _failure("Signal list failed through the split query service.")

	var connect_result: Dictionary = executor.execute("signal", {
		"action": "connect",
		"source": "EmitterNode",
		"signal": "timeout",
		"target": "ReceiverNode",
		"method": "_on_timeout"
	})
	if not bool(connect_result.get("success", false)):
		return _failure("Signal connect failed through the split connect service.")

	var is_connected_result: Dictionary = executor.execute("signal", {
		"action": "is_connected",
		"source": "EmitterNode",
		"signal": "timeout",
		"target": "ReceiverNode",
		"method": "_on_timeout"
	})
	if not bool(is_connected_result.get("success", false)):
		return _failure("Signal is_connected failed through the split query service.")
	if not bool(is_connected_result.get("data", {}).get("connected", false)):
		return _failure("Signal should report connected after the split connect service succeeds.")

	var list_connections_result: Dictionary = executor.execute("signal", {
		"action": "list_connections",
		"path": "EmitterNode",
		"signal": "timeout"
	})
	if not bool(list_connections_result.get("success", false)):
		return _failure("Signal list_connections failed through the split query service.")

	var get_info_result: Dictionary = executor.execute("signal", {
		"action": "get_info",
		"path": "EmitterNode",
		"signal": "timeout"
	})
	if not bool(get_info_result.get("success", false)):
		return _failure("Signal get_info failed through the split query service.")

	var emit_result: Dictionary = executor.execute("signal", {
		"action": "emit",
		"path": "EmitterNode",
		"signal": "timeout",
		"args": []
	})
	if not bool(emit_result.get("success", false)):
		return _failure("Signal emit failed through the split emit service.")

	var receiver := _scene_root.get_node_or_null("ReceiverNode") as SignalReceiver
	if receiver == null or receiver.received.size() != 1 or str(receiver.received[0]) != "timeout":
		return _failure("Signal emit should invoke the receiver through the split signal services.")

	var list_all_connections_result: Dictionary = executor.execute("signal", {
		"action": "list_all_connections"
	})
	if not bool(list_all_connections_result.get("success", false)):
		return _failure("Signal list_all_connections failed through the split query service.")

	var disconnect_result: Dictionary = executor.execute("signal", {
		"action": "disconnect",
		"source": "EmitterNode",
		"signal": "timeout",
		"target": "ReceiverNode",
		"method": "_on_timeout"
	})
	if not bool(disconnect_result.get("success", false)):
		return _failure("Signal disconnect failed through the split connect service.")

	var reconnect_result: Dictionary = executor.execute("signal", {
		"action": "connect",
		"source": "EmitterNode",
		"signal": "timeout",
		"target": "ReceiverNode",
		"method": "_on_timeout"
	})
	if not bool(reconnect_result.get("success", false)):
		return _failure("Signal reconnect failed through the split connect service.")

	var disconnect_all_result: Dictionary = executor.execute("signal", {
		"action": "disconnect_all",
		"path": "EmitterNode",
		"signal": "timeout"
	})
	if not bool(disconnect_all_result.get("success", false)):
		return _failure("Signal disconnect_all failed through the split connect service.")

	var disconnected_result: Dictionary = executor.execute("signal", {
		"action": "is_connected",
		"source": "EmitterNode",
		"signal": "timeout",
		"target": "ReceiverNode",
		"method": "_on_timeout"
	})
	if not bool(disconnected_result.get("success", false)):
		return _failure("Signal is_connected after disconnect_all failed through the split query service.")
	if bool(disconnected_result.get("data", {}).get("connected", true)):
		return _failure("Signal should report disconnected after disconnect_all.")

	var invalid_emit_result: Dictionary = executor.execute("signal", {
		"action": "emit",
		"path": "EmitterNode",
		"signal": "pong",
		"args": [1, 2, 3, 4, 5]
	})
	if bool(invalid_emit_result.get("success", false)):
		return _failure("Signal emit should fail when more than four arguments are provided.")

	return {
		"name": "signal_tool_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"signal_count": int(list_result.get("data", {}).get("count", 0)),
			"connection_count": int(list_connections_result.get("data", {}).get("count", 0)),
			"all_connection_count": int(list_all_connections_result.get("data", {}).get("count", 0))
		}
	}


func cleanup_case(tree: SceneTree) -> void:
	if _scene_root != null:
		if _scene_root.get_parent() != null:
			_scene_root.get_parent().remove_child(_scene_root)
		_scene_root.queue_free()
		_scene_root = null
		await tree.process_frame


func _build_scene_fixture(tree: SceneTree) -> Node:
	var root := Node.new()
	root.name = "SignalToolExecutorContracts"
	var emitter := Timer.new()
	emitter.name = "EmitterNode"
	var receiver := SignalReceiver.new()
	receiver.name = "ReceiverNode"
	root.add_child(emitter)
	root.add_child(receiver)
	tree.root.add_child(root)
	return root


func _failure(message: String) -> Dictionary:
	return {
		"name": "signal_tool_executor_contracts",
		"success": false,
		"error": message
	}
