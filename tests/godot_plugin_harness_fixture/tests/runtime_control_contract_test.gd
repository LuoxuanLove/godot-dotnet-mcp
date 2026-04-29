extends RefCounted

const RuntimeControlServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/runtime_control_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
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
