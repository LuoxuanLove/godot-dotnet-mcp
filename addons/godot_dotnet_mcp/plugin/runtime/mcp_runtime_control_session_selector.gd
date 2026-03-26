@tool
extends RefCounted
class_name MCPRuntimeControlSessionSelector

var _plugin: EditorPlugin
var _debugger_bridge: EditorDebuggerPlugin


func configure(plugin: EditorPlugin, debugger_bridge: EditorDebuggerPlugin) -> void:
	_plugin = plugin
	_debugger_bridge = debugger_bridge


func reset() -> void:
	_plugin = null
	_debugger_bridge = null


func get_preferred_session_id() -> int:
	if _debugger_bridge == null or not is_instance_valid(_debugger_bridge):
		return -1
	if _debugger_bridge.has_method("get_preferred_runtime_session_id"):
		return int(_debugger_bridge.get_preferred_runtime_session_id())
	return -1


func is_session_commandable(session_id: int) -> bool:
	if _debugger_bridge == null or not is_instance_valid(_debugger_bridge):
		return false
	if _debugger_bridge.has_method("is_session_commandable"):
		return bool(_debugger_bridge.is_session_commandable(session_id))
	return false


func get_debugger_session_snapshot() -> Dictionary:
	if _debugger_bridge == null or not is_instance_valid(_debugger_bridge):
		return {
			"session_count": 0,
			"active_session_count": 0,
			"commandable_session_count": 0,
			"sessions": []
		}
	if _debugger_bridge.has_method("get_runtime_session_snapshot"):
		var snapshot = _debugger_bridge.get_runtime_session_snapshot()
		if snapshot is Dictionary:
			return (snapshot as Dictionary).duplicate(true)
	return {
		"session_count": 0,
		"active_session_count": 0,
		"commandable_session_count": 0,
		"sessions": []
	}


func get_scene_tree() -> SceneTree:
	if _plugin == null or not is_instance_valid(_plugin):
		return null
	return _plugin.get_tree()


func await_commandable_session(timeout_ms: int) -> int:
	var session_id := get_preferred_session_id()
	if session_id >= 0:
		return session_id

	var deadline := Time.get_ticks_msec() + maxi(timeout_ms, 1)
	while Time.get_ticks_msec() <= deadline:
		session_id = get_preferred_session_id()
		if session_id >= 0:
			return session_id
		var tree = get_scene_tree()
		if tree == null:
			break
		await tree.process_frame
	return -1
