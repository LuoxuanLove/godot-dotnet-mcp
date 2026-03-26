extends RefCounted

const RuntimeReplyServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_reply_service.gd")

var _captured_payloads: Array[Dictionary] = []


func run_case(_tree: SceneTree) -> Dictionary:
	_captured_payloads.clear()

	var service = RuntimeReplyServiceScript.new()
	service.configure({
		"send_reply": Callable(self, "_capture_reply"),
		"get_current_scene_path": Callable(self, "_get_scene_path"),
		"build_runtime_state": Callable(self, "_build_runtime_state")
	})

	service.send_result("reply-success", 9, {
		"success": true,
		"message": "Runtime step completed",
		"data": {
			"frame_count": 1
		}
	}, "step")
	service.send_error("reply-error", 9, "invalid_argument", "Bad runtime step.", {}, "step")
	service.dispose()

	if _captured_payloads.size() != 2:
		return _failure("Runtime reply service did not emit the expected number of payloads.")

	var success_payload: Dictionary = _captured_payloads[0]
	if not bool(success_payload.get("ok", false)):
		return _failure("Runtime reply service did not emit a success payload.")

	var error_payload: Dictionary = _captured_payloads[1]
	if bool(error_payload.get("ok", true)):
		return _failure("Runtime reply service did not emit an error payload.")

	var error_data = error_payload.get("data", {})
	if not (error_data is Dictionary):
		return _failure("Runtime reply service error payload is missing dictionary data.")

	var runtime_context = (error_data as Dictionary).get("runtime_context", {})
	if not (runtime_context is Dictionary):
		return _failure("Runtime reply service error payload is missing runtime_context.")

	if str((runtime_context as Dictionary).get("action", "")) != "step":
		return _failure("Runtime reply service did not preserve the failing action.")

	if str((error_data as Dictionary).get("hint", "")).is_empty():
		return _failure("Runtime reply service did not provide a user-facing hint.")

	if not (error_data as Dictionary).has("runtime_state"):
		return _failure("Runtime reply service did not include runtime_state.")

	return {
		"name": "runtime_reply_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"success_message": str(success_payload.get("message", "")),
			"error_code": str(error_payload.get("error", "")),
			"hint": str((error_data as Dictionary).get("hint", ""))
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	_captured_payloads.clear()


func _capture_reply(payload: Dictionary) -> void:
	_captured_payloads.append(payload.duplicate(true))


func _get_scene_path() -> String:
	return "res://scenes/runtime_reply_test.tscn"


func _build_runtime_state(session_id: int) -> Dictionary:
	return {
		"running": true,
		"scene": _get_scene_path(),
		"session_id": session_id
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "runtime_reply_service_contracts",
		"success": false,
		"error": message
	}
