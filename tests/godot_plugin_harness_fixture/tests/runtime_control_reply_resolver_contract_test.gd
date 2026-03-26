extends RefCounted

const RuntimeControlReplyResolverScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_control_reply_resolver.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var resolver = RuntimeControlReplyResolverScript.new()
	resolver.configure({
		"get_recent_runtime_events": Callable(self, "_get_recent_events"),
		"build_error": Callable(self, "_build_error")
	})

	var resolved := resolver.resolve_fallback_reply("reply-42", {
		"session_id": 42,
		"action": "step"
	})
	if str(resolved.get("error", "")) != "runtime_command_failed":
		return _failure("Reply resolver did not normalize the fallback error payload.")

	var data = resolved.get("data", {})
	if not (data is Dictionary) or str((data as Dictionary).get("action", "")) != "step":
		return _failure("Reply resolver did not preserve the pending action when mapping fallback errors.")

	var success_payload := resolver.build_reply_from_runtime_payload({
		"ok": true,
		"message": "Runtime command completed",
		"data": {
			"frame_count": 1
		}
	}, "capture")
	if not bool(success_payload.get("success", false)):
		return _failure("Reply resolver did not preserve successful runtime replies.")

	resolver.reset()
	return {
		"name": "runtime_control_reply_resolver_contracts",
		"success": true,
		"error": "",
		"details": {
			"error_message": str(resolved.get("message", "")),
			"success_message": str(success_payload.get("message", ""))
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	pass


func _get_recent_events() -> Array[Dictionary]:
	return [
		{
			"kind": "runtime_reply",
			"payload": {
				"request_id": "reply-42",
				"ok": false,
				"error": "runtime_command_failed",
				"message": "Runtime command failed",
				"data": {
					"reason": "synthetic"
				},
				"session_id": 42
			}
		}
	]


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


func _failure(message: String) -> Dictionary:
	return {
		"name": "runtime_control_reply_resolver_contracts",
		"success": false,
		"error": message
	}
