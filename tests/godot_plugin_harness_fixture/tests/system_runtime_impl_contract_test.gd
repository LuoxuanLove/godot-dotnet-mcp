extends RefCounted

const RuntimeImplScript = preload("res://addons/godot_dotnet_mcp/tools/system/impl_runtime.gd")


class FakeBridge extends RefCounted:
	func success(data, message: String) -> Dictionary:
		return {
			"success": true,
			"data": data,
			"message": message
		}

	func error(message: String) -> Dictionary:
		return {
			"success": false,
			"error": "bridge_error",
			"message": message
		}


class FakeRuntimeControlService extends RefCounted:
	var last_capture_args: Dictionary = {}

	func get_status() -> Dictionary:
		return {
			"available": true,
			"armed": true,
			"active_session_id": 9,
			"message": "Runtime control enabled for the current session."
		}

	func disable_control() -> Dictionary:
		return {
			"success": true,
			"data": {"armed": false},
			"message": "Runtime control disabled"
		}

	func capture(args: Dictionary) -> Dictionary:
		last_capture_args = args.duplicate(true)
		return {
			"success": true,
			"data": {
				"frames": [{"path": "res://capture/frame_0001.png"}],
				"runtime_state": {"tick": 1}
			},
			"message": "Runtime capture completed"
		}

	func send_inputs(args: Dictionary) -> Dictionary:
		return {
			"success": true,
			"data": {"inputs": args.get("inputs", [])},
			"message": "Runtime input sent"
		}

	func step(args: Dictionary) -> Dictionary:
		return {
			"success": true,
			"data": {"wait_frames": int(args.get("wait_frames", 0))},
			"message": "Runtime step completed"
		}


class FakeRuntimeServer extends RefCounted:
	var runtime_control_service

	func _init(service) -> void:
		runtime_control_service = service

	func get_runtime_control_service():
		return runtime_control_service


func run_case(_tree: SceneTree) -> Dictionary:
	var fake_service := FakeRuntimeControlService.new()
	var impl = RuntimeImplScript.new()
	impl.bridge = FakeBridge.new()
	impl.configure_runtime({
		"server": FakeRuntimeServer.new(fake_service)
	})

	var status_result: Dictionary = await impl.execute_async("runtime_control", {"action": "status"})
	if not bool(status_result.get("success", false)):
		return _failure("runtime_control status did not return a success payload.")
	var status_data = status_result.get("data", {})
	if not (status_data is Dictionary) or not bool((status_data as Dictionary).get("armed", false)):
		return _failure("runtime_control status did not expose the armed runtime state.")

	var invalid_action: Dictionary = await impl.execute_async("runtime_control", {"action": "bogus"})
	if str(invalid_action.get("error", "")) != "invalid_argument":
		return _failure("runtime_control bogus action did not return invalid_argument.")
	var invalid_action_data = invalid_action.get("data", {})
	if not (invalid_action_data is Dictionary) or str((invalid_action_data as Dictionary).get("hint", "")).find("status, enable, disable") == -1:
		return _failure("runtime_control bogus action response is missing a hint.")

	var invalid_capture: Dictionary = await impl.execute_async("runtime_capture", {"frame_count": 0})
	if str(invalid_capture.get("error", "")) != "invalid_argument":
		return _failure("runtime_capture(frame_count=0) did not return invalid_argument.")

	var capture_result: Dictionary = await impl.execute_async("runtime_capture", {
		"frame_count": 2,
		"interval_frames": 3
	})
	if not bool(capture_result.get("success", false)):
		return _failure("runtime_capture valid request did not return success.")
	var capture_data = capture_result.get("data", {})
	if not (capture_data is Dictionary):
		return _failure("runtime_capture valid request did not return a dictionary payload.")
	if str((capture_data as Dictionary).get("capture_mode", "")) != "sequence":
		return _failure("runtime_capture did not annotate capture_mode=sequence.")
	if int((capture_data as Dictionary).get("requested_frame_count", 0)) != 2:
		return _failure("runtime_capture did not preserve requested_frame_count.")
	if int(fake_service.last_capture_args.get("frame_count", 0)) != 2:
		return _failure("runtime_capture did not forward frame_count to the runtime control service.")

	return {
		"name": "system_runtime_impl_contracts",
		"success": true,
		"error": "",
		"details": {
			"status_message": str(status_result.get("message", "")),
			"capture_mode": str((capture_data as Dictionary).get("capture_mode", ""))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "system_runtime_impl_contracts",
		"success": false,
		"error": message
	}
