extends RefCounted

const RuntimeControlServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/runtime_control_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var bridge_guard := _assert_debugger_bridge_clears_stopped_sessions()
	if not bridge_guard.is_empty():
		return _failure(bridge_guard)

	var service = RuntimeControlServiceScript.new()

	var status: Dictionary = service.get_status()
	if bool(status.get("available", true)):
		return _failure("Runtime control unexpectedly reported an available session without a debugger bridge.")
	if bool(status.get("armed", true)):
		return _failure("Runtime control unexpectedly reported an armed session without enable_control().")
	if str(status.get("message", "")).find("No active runtime debugger session") == -1:
		return _failure("Runtime control status did not explain the missing runtime session.")

	var disable_result: Dictionary = service.disable_control()
	if not bool(disable_result.get("success", false)):
		return _failure("disable_control() should succeed even when runtime control is already disabled.")

	var capture_result: Dictionary = await service.capture({"frame_count": 0})
	if not _is_invalid_argument(capture_result, "capture"):
		return _failure("capture(frame_count=0) did not return invalid_argument with editor context.")

	var input_result: Dictionary = await service.send_inputs({"inputs": []})
	if not _is_invalid_argument(input_result, "input"):
		return _failure("send_inputs(inputs=[]) did not return invalid_argument with editor context.")

	var step_result: Dictionary = await service.step({"wait_frames": -1})
	if not _is_invalid_argument(step_result, "step"):
		return _failure("step(wait_frames=-1) did not return invalid_argument with editor context.")

	return {
		"name": "runtime_control_contracts",
		"success": true,
		"error": "",
		"details": {
			"status_message": str(status.get("message", "")),
			"disable_message": str(disable_result.get("message", ""))
		}
	}


func _assert_debugger_bridge_clears_stopped_sessions() -> String:
	var source_path := "res://addons/godot_dotnet_mcp/plugin/runtime/mcp_editor_debugger_bridge.gd"
	if not FileAccess.file_exists(source_path):
		return "Editor debugger bridge source should exist for stopped-session cleanup guard."
	var source := FileAccess.get_file_as_string(source_path)
	var marker := "func _on_session_stopped(session_id: int) -> void:"
	var start := source.find(marker)
	if start == -1:
		return "Editor debugger bridge should keep the stopped-session callback."
	var next_callback := source.find("\nfunc _on_session_breaked", start)
	var stopped_body := source.substr(start, source.length() - start)
	if next_callback > start:
		stopped_body = source.substr(start, next_callback - start)
	if stopped_body.find("_record_session_state") == -1 or stopped_body.find("_record_runtime_session_event") == -1:
		return "Editor debugger bridge should record stopped sessions before cleanup."
	if stopped_body.find("_wired_sessions.erase(session_id)") == -1:
		return "Editor debugger bridge should immediately clear stopped sessions from the wired map."
	return ""


func _is_invalid_argument(result: Dictionary, action: String) -> bool:
	if str(result.get("error", "")) != "invalid_argument":
		return false
	var data = result.get("data", {})
	if not (data is Dictionary):
		return false
	var editor_context = (data as Dictionary).get("editor_context", {})
	if not (editor_context is Dictionary):
		return false
	if str((editor_context as Dictionary).get("action", "")) != action:
		return false
	return not str((data as Dictionary).get("hint", "")).is_empty()


func _failure(message: String) -> Dictionary:
	return {
		"name": "runtime_control_contracts",
		"success": false,
		"error": message
	}
