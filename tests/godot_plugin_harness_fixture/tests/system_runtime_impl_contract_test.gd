extends RefCounted

const RuntimeImplScript = preload("res://addons/godot_dotnet_mcp/tools/system/impl_runtime.gd")
const RuntimeAtomicExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/runtime/executor.gd")


class FakeBridge extends RefCounted:
	var runtime_executor = RuntimeAtomicExecutorScript.new()
	var calls: Array[String] = []

	func configure_runtime(context: Dictionary) -> void:
		runtime_executor.configure_runtime(context)

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

	func call_atomic(full_name: String, args: Dictionary = {}) -> Dictionary:
		calls.append(full_name)
		if not full_name.begins_with("runtime_"):
			return error("Unexpected atomic tool: %s" % full_name)
		return runtime_executor.execute(full_name.trim_prefix("runtime_"), args)

	func call_atomic_async(full_name: String, args: Dictionary = {}) -> Dictionary:
		calls.append(full_name)
		if not full_name.begins_with("runtime_"):
			return error("Unexpected atomic tool: %s" % full_name)
		return await runtime_executor.execute_async(full_name.trim_prefix("runtime_"), args)


class FakeRuntimeControlService extends RefCounted:
	var last_capture_args: Dictionary = {}
	var last_enable_args: Dictionary = {}
	var last_inputs_args: Dictionary = {}
	var last_step_args: Dictionary = {}

	func get_status() -> Dictionary:
		return {
			"available": true,
			"armed": true,
			"active_session_id": 9,
			"message": "Runtime control enabled for the current session."
		}

	func enable_control(args: Dictionary) -> Dictionary:
		last_enable_args = args.duplicate(true)
		return {
			"success": true,
			"data": {
				"armed": true,
				"session_id": 11,
				"runtime_state": {"tick": 2}
			},
			"message": "Runtime control enabled"
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
		last_inputs_args = args.duplicate(true)
		return {
			"success": true,
			"data": {"inputs": args.get("inputs", [])},
			"message": "Runtime input sent"
		}

	func step(args: Dictionary) -> Dictionary:
		last_step_args = args.duplicate(true)
		return {
			"success": true,
			"data": {
				"wait_frames": int(args.get("wait_frames", 0)),
				"frame": {"path": "res://capture/frame_0002.png"},
				"runtime_state": {"tick": 3}
			},
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
	var fake_bridge := FakeBridge.new()
	impl.bridge = fake_bridge
	var runtime_context := {
		"server": FakeRuntimeServer.new(fake_service)
	}
	fake_bridge.configure_runtime(runtime_context)
	impl.configure_runtime(runtime_context)

	var tool_defs: Array[Dictionary] = impl.get_tools()
	if tool_defs.size() != 2:
		return _failure("runtime system impl should expose exactly two high-level tools after merging runtime I/O.")
	var tool_names: Array[String] = []
	for tool_def in tool_defs:
		tool_names.append(str(tool_def.get("name", "")))
	for expected_name in ["runtime_control", "runtime_step"]:
		if not tool_names.has(expected_name):
			return _failure("runtime system impl is missing tool '%s'." % expected_name)
	var runtime_step_schema := _find_tool_schema(tool_defs, "runtime_step")
	if runtime_step_schema.is_empty():
		return _failure("runtime_step schema should be available for contract inspection.")
	var input_item_properties := _get_runtime_input_item_properties(runtime_step_schema)
	if input_item_properties.is_empty():
		return _failure("runtime_step schema should describe runtime input entries.")
	var kind_enum = (input_item_properties.get("kind", {}) as Dictionary).get("enum", [])
	if not (kind_enum is Array) or not (kind_enum as Array).has("mouse"):
		return _failure("runtime_step schema should expose mouse input entries.")
	var op_enum = (input_item_properties.get("op", {}) as Dictionary).get("enum", [])
	if not (op_enum is Array) or not (op_enum as Array).has("click") or not (op_enum as Array).has("move"):
		return _failure("runtime_step schema should expose mouse click and move operations.")
	if not input_item_properties.has("x") or not input_item_properties.has("y") or not input_item_properties.has("position"):
		return _failure("runtime_step schema should expose mouse coordinates.")

	var status_result: Dictionary = await impl.execute_async("runtime_control", {"action": "status"})
	if not bool(status_result.get("success", false)):
		return _failure("runtime_control status did not return a success payload.")
	var status_data = status_result.get("data", {})
	if not (status_data is Dictionary) or not bool((status_data as Dictionary).get("armed", false)):
		return _failure("runtime_control status did not expose the armed runtime state.")
	fake_bridge.configure_runtime({})
	var stale_status_result: Dictionary = await fake_bridge.runtime_executor.execute_async("control", {"action": "status"})
	var stale_status_data = stale_status_result.get("data", {})
	if not (stale_status_data is Dictionary) or bool((stale_status_data as Dictionary).get("available", true)):
		return _failure("runtime executor should clear stale runtime_control_service when reconfigured without one.")
	fake_bridge.configure_runtime(runtime_context)

	var enable_result: Dictionary = await impl.execute_async("runtime_control", {
		"action": "enable",
		"timeout_ms": 123
	})
	if not bool(enable_result.get("success", false)):
		return _failure("runtime_control enable did not return a success payload.")
	if int(fake_service.last_enable_args.get("timeout_ms", 0)) != 123:
		return _failure("runtime_control enable did not forward timeout_ms to the runtime control service.")

	var disable_result: Dictionary = await impl.execute_async("runtime_control", {"action": "disable"})
	if not bool(disable_result.get("success", false)):
		return _failure("runtime_control disable did not return a success payload.")

	var invalid_action: Dictionary = await impl.execute_async("runtime_control", {"action": "bogus"})
	if str(invalid_action.get("error", "")) != "invalid_argument":
		return _failure("runtime_control bogus action did not return invalid_argument.")
	var invalid_action_data = invalid_action.get("data", {})
	if not (invalid_action_data is Dictionary) or str((invalid_action_data as Dictionary).get("hint", "")).find("status, enable, disable") == -1:
		return _failure("runtime_control bogus action response is missing a hint.")

	var invalid_capture: Dictionary = await impl.execute_async("runtime_step", {"action": "capture", "frame_count": 0})
	if str(invalid_capture.get("error", "")) != "invalid_argument":
		return _failure("runtime_step(action=capture, frame_count=0) did not return invalid_argument.")

	var capture_result: Dictionary = await impl.execute_async("runtime_step", {
		"action": "capture",
		"frame_count": 2,
		"interval_frames": 3,
		"capture_dir": "user://contract_runtime_captures"
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
	if int((capture_data as Dictionary).get("requested_interval_frames", 0)) != 3:
		return _failure("runtime_capture did not preserve requested_interval_frames.")
	if int(fake_service.last_capture_args.get("frame_count", 0)) != 2:
		return _failure("runtime_capture did not forward frame_count to the runtime control service.")
	if str(fake_service.last_capture_args.get("capture_dir", "")) != "user://contract_runtime_captures":
		return _failure("runtime_capture did not forward capture_dir to the runtime control service.")

	var input_result: Dictionary = await impl.execute_async("runtime_step", {
		"action": "input",
		"inputs": [
			{"kind": "key", "target": "Space", "op": "tap", "duration_ms": 15}
		]
	})
	if not bool(input_result.get("success", false)):
		return _failure("runtime_input valid request did not return success.")
	if int((fake_service.last_inputs_args.get("inputs", []) as Array).size()) != 1:
		return _failure("runtime_input did not forward inputs to the runtime control service.")

	var step_result: Dictionary = await impl.execute_async("runtime_step", {
		"action": "step",
		"wait_frames": 4,
		"capture": true,
		"capture_dir": "user://contract_step_captures",
		"capture_label": "step-check"
	})
	if not bool(step_result.get("success", false)):
		return _failure("runtime_step valid request did not return success.")
	var step_data = step_result.get("data", {})
	if not (step_data is Dictionary) or int((step_data as Dictionary).get("wait_frames", 0)) != 4:
		return _failure("runtime_step did not preserve wait_frames.")
	if str((step_data as Dictionary).get("runtime_state", {}).get("tick", "")) != "3":
		return _failure("runtime_step did not preserve runtime_state from the service result.")
	if str((step_data as Dictionary).get("frame", {}).get("path", "")).is_empty():
		return _failure("runtime_step did not preserve the captured frame payload.")
	if int(fake_service.last_step_args.get("wait_frames", 0)) != 4:
		return _failure("runtime_step did not forward wait_frames to the runtime control service.")
	if str(fake_service.last_step_args.get("capture_dir", "")) != "user://contract_step_captures":
		return _failure("runtime_step did not forward capture_dir to the runtime control service.")
	for expected_atomic in ["runtime_control", "runtime_capture", "runtime_input", "runtime_step"]:
		if not fake_bridge.calls.has(expected_atomic):
			return _failure("runtime system impl should route through atomic bridge for %s." % expected_atomic)
	var unknown_step_action: Dictionary = await impl.execute_async("runtime_step", {"action": "bogus"})
	if str(unknown_step_action.get("error", "")) != "invalid_argument":
		return _failure("runtime_step should reject unknown merged runtime action.")

	return {
		"name": "system_runtime_impl_contracts",
		"success": true,
		"error": "",
		"details": {
			"status_message": str(status_result.get("message", "")),
			"capture_mode": str((capture_data as Dictionary).get("capture_mode", "")),
			"tool_count": tool_defs.size()
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "system_runtime_impl_contracts",
		"success": false,
		"error": message
	}


func _find_tool_schema(tool_defs: Array[Dictionary], tool_name: String) -> Dictionary:
	for tool_def in tool_defs:
		if str(tool_def.get("name", "")) == tool_name:
			var schema = tool_def.get("inputSchema", {})
			if schema is Dictionary:
				return schema
	return {}


func _get_runtime_input_item_properties(schema: Dictionary) -> Dictionary:
	var properties = schema.get("properties", {})
	if not (properties is Dictionary):
		return {}
	var inputs = (properties as Dictionary).get("inputs", {})
	if not (inputs is Dictionary):
		return {}
	var items = (inputs as Dictionary).get("items", {})
	if not (items is Dictionary):
		return {}
	var item_properties = (items as Dictionary).get("properties", {})
	if item_properties is Dictionary:
		return item_properties
	return {}
