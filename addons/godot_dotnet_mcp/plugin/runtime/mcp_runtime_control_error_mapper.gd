@tool
extends RefCounted
class_name MCPRuntimeControlErrorMapper

var _build_editor_context := Callable()
var _get_debugger_session_snapshot := Callable()


func configure(callbacks: Dictionary = {}) -> void:
	_build_editor_context = callbacks.get("build_editor_context", Callable())
	_get_debugger_session_snapshot = callbacks.get("get_debugger_session_snapshot", Callable())


func reset() -> void:
	_build_editor_context = Callable()
	_get_debugger_session_snapshot = Callable()


func success(data, message: String) -> Dictionary:
	return {
		"success": true,
		"data": data,
		"message": message
	}


func error(error_type: String, message: String, data = {}, action: String = "") -> Dictionary:
	var payload := {}
	if data is Dictionary:
		payload = (data as Dictionary).duplicate(true)
	elif data != null:
		payload = {"details": data}
	payload["editor_context"] = _build_editor_context_safe(action)
	if not payload.has("hint"):
		var hint := _build_error_hint(error_type)
		if not hint.is_empty():
			payload["hint"] = hint
	var result := {
		"success": false,
		"error": error_type,
		"message": message
	}
	if not payload.is_empty():
		result["data"] = payload
	return result


func _build_editor_context_safe(action: String) -> Dictionary:
	if _build_editor_context.is_valid():
		var context = _build_editor_context.call(action)
		if context is Dictionary:
			return (context as Dictionary).duplicate(true)
	return {
		"layer": "editor_runtime_control",
		"action": action
	}


func _build_error_hint(error_type: String) -> String:
	match error_type:
		"runtime_not_running":
			var session_snapshot := _get_debugger_session_snapshot_safe()
			if int(session_snapshot.get("active_session_count", 0)) > 0 and int(session_snapshot.get("commandable_session_count", 0)) == 0:
				return "The editor sees a runtime session, but it is not commandable. Ensure the game was launched from the editor in debug mode and that remote debugging is active."
			return "Call system_project_run first, then enable runtime control again."
		"runtime_control_disabled":
			return "Call system_runtime_control with action=enable before sending runtime automation commands."
		"runtime_session_lost":
			return "Ensure the project is still running in the editor, then call system_runtime_control with action=enable again."
		"runtime_command_timeout":
			return "Retry the command, or reduce wait_frames / frame_count if the runtime is under load."
		"runtime_bridge_unavailable":
			return "Reattach or relaunch the editor session before retrying the runtime command."
		"invalid_argument":
			return "Fix the runtime tool arguments and retry."
		_:
			return ""


func _get_debugger_session_snapshot_safe() -> Dictionary:
	if _get_debugger_session_snapshot.is_valid():
		var snapshot = _get_debugger_session_snapshot.call()
		if snapshot is Dictionary:
			return (snapshot as Dictionary).duplicate(true)
	return {
		"session_count": 0,
		"active_session_count": 0,
		"commandable_session_count": 0,
		"sessions": []
	}
