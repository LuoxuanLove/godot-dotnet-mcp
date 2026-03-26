extends RefCounted

const RuntimeControlRequestCoordinatorScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_control_request_coordinator.gd")

var _tree: SceneTree
var _coordinator = RuntimeControlRequestCoordinatorScript.new()
var _auto_reply := true


func run_case(tree: SceneTree) -> Dictionary:
	_tree = tree
	_coordinator.configure({
		"send_runtime_command": Callable(self, "_send_runtime_command"),
		"resolve_fallback_reply": Callable(self, "_resolve_fallback_reply"),
		"build_reply_from_runtime_payload": Callable(self, "_build_reply_from_runtime_payload"),
		"build_error": Callable(self, "_build_error"),
		"get_scene_tree": Callable(self, "_get_scene_tree")
	})

	_auto_reply = true
	var success_result: Dictionary = await _coordinator.request_runtime_command(7, "capture", {
		"frame_count": 1
	}, 1000)
	if not bool(success_result.get("success", false)):
		return _failure("Request coordinator did not preserve a successful runtime round trip.")
	if int(_coordinator.get_pending_request_count()) != 0:
		return _failure("Request coordinator left pending requests after a successful reply.")
	if int(_coordinator.get_last_reply_at_unix()) <= 0:
		return _failure("Request coordinator did not record the last reply timestamp.")

	_auto_reply = false
	_tree.create_timer(0.0).timeout.connect(func() -> void:
		_coordinator.mark_pending_requests_for_session(7, "runtime_session_lost", "The runtime debugger session stopped before the command completed.")
	)
	var lost_result: Dictionary = await _coordinator.request_runtime_command(7, "step", {
		"wait_frames": 1
	}, 1000)
	if str(lost_result.get("error", "")) != "runtime_session_lost":
		return _failure("Request coordinator did not surface the session-lost error for pending requests.")

	return {
		"name": "runtime_control_request_coordinator_contracts",
		"success": true,
		"error": "",
		"details": {
			"success_message": str(success_result.get("message", "")),
			"lost_error": str(lost_result.get("error", "")),
			"last_reply_at_unix": int(_coordinator.get_last_reply_at_unix())
		}
	}


func cleanup_case(_tree_arg: SceneTree) -> void:
	_coordinator.reset()
	_tree = null
	_auto_reply = true


func _send_runtime_command(session_id: int, payload: Dictionary) -> Dictionary:
	if _auto_reply:
		var request_id := str(payload.get("request_id", ""))
		var action := str(payload.get("action", ""))
		_tree.create_timer(0.0).timeout.connect(func() -> void:
			_coordinator.handle_runtime_reply(session_id, {
				"request_id": request_id,
				"ok": true,
				"message": "Runtime command completed",
				"data": {
					"echo_action": action
				}
			})
		)
	return {"success": true}


func _resolve_fallback_reply(_request_id: String, _pending: Dictionary) -> Dictionary:
	return {}


func _build_reply_from_runtime_payload(payload: Dictionary, _action: String) -> Dictionary:
	if bool(payload.get("ok", false)):
		return {
			"success": true,
			"data": (payload.get("data", {}) as Dictionary).duplicate(true),
			"message": str(payload.get("message", "Runtime command completed"))
		}
	return _build_error(str(payload.get("error", "runtime_command_failed")), str(payload.get("message", "Runtime command failed")), payload.get("data", {}), "")


func _build_error(error_type: String, message: String, data = {}, action: String = "") -> Dictionary:
	return {
		"success": false,
		"error": error_type,
		"message": message,
		"data": {
			"payload": data,
			"action": action
		}
	}


func _get_scene_tree() -> SceneTree:
	return _tree


func _failure(message: String) -> Dictionary:
	return {
		"name": "runtime_control_request_coordinator_contracts",
		"success": false,
		"error": message
	}
