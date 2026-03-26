@tool
extends RefCounted
class_name MCPRuntimeControlService

const MCPRuntimeDebugStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_debug_store.gd")
const MCPRuntimeControlSessionSelectorScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_control_session_selector.gd")
const MCPRuntimeControlErrorMapperScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_control_error_mapper.gd")
const MCPRuntimeControlReplyResolverScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_control_reply_resolver.gd")
const MCPRuntimeControlRequestCoordinatorScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_control_request_coordinator.gd")
const DEFAULT_COMMAND_TIMEOUT_MS := 5000
const DEFAULT_SEQUENCE_TIMEOUT_MS := 15000
const DEFAULT_ENABLE_TIMEOUT_MS := 5000

var _plugin: EditorPlugin
var _debugger_bridge: EditorDebuggerPlugin
var _log := Callable()
var _armed_session_id := -1
var _armed_at_unix := 0
var _session_selector = MCPRuntimeControlSessionSelectorScript.new()
var _error_mapper = MCPRuntimeControlErrorMapperScript.new()
var _reply_resolver = MCPRuntimeControlReplyResolverScript.new()
var _request_coordinator = MCPRuntimeControlRequestCoordinatorScript.new()


func configure(plugin: EditorPlugin, debugger_bridge: EditorDebuggerPlugin, callbacks: Dictionary = {}) -> void:
	_plugin = plugin
	if _debugger_bridge != debugger_bridge:
		if _debugger_bridge != null:
			_request_coordinator.mark_all_pending_requests("runtime_session_lost", "Runtime control bridge changed before the command completed")
		_disconnect_debugger_bridge()
		_debugger_bridge = debugger_bridge
		_connect_debugger_bridge()
	_log = callbacks.get("log", Callable())
	_session_selector.configure(_plugin, _debugger_bridge)
	_error_mapper.configure({
		"build_editor_context": Callable(self, "_build_editor_error_context"),
		"get_debugger_session_snapshot": Callable(self, "_get_debugger_session_snapshot")
	})
	_reply_resolver.configure({
		"get_recent_runtime_events": Callable(self, "_get_recent_runtime_events"),
		"build_error": Callable(self, "_build_runtime_control_error")
	})
	_request_coordinator.configure({
		"send_runtime_command": Callable(self, "_send_runtime_command"),
		"resolve_fallback_reply": Callable(_reply_resolver, "resolve_fallback_reply"),
		"build_reply_from_runtime_payload": Callable(_reply_resolver, "build_reply_from_runtime_payload"),
		"build_error": Callable(self, "_build_runtime_control_error"),
		"get_scene_tree": Callable(self, "_get_scene_tree")
	})
	_validate_armed_session()


func reset() -> void:
	_request_coordinator.mark_all_pending_requests("runtime_session_lost", "Runtime control service reset before the command completed")
	_armed_session_id = -1
	_armed_at_unix = 0
	_disconnect_debugger_bridge()
	_debugger_bridge = null
	_plugin = null
	_log = Callable()
	_request_coordinator.reset()
	_session_selector.reset()
	_error_mapper.reset()
	_reply_resolver.reset()


func get_status() -> Dictionary:
	_validate_armed_session()
	var active_session_id := _session_selector.get_preferred_session_id()
	var session_snapshot := _session_selector.get_debugger_session_snapshot()
	var active_session_count := int(session_snapshot.get("active_session_count", 0))
	var commandable_session_count := int(session_snapshot.get("commandable_session_count", 0))
	var available := active_session_id >= 0
	var armed := _armed_session_id >= 0
	var message := ""
	if not available:
		if active_session_count > 0 and commandable_session_count == 0:
			message = "A runtime session exists, but it is not commandable yet. Verify the project is running from the editor with remote debugging enabled."
		else:
			message = "No active runtime debugger session is available. Run the project first."
	elif not armed:
		message = "Runtime control is disabled for the current session."
	else:
		message = "Runtime control is enabled for the current session."

	return {
		"available": available,
		"armed": armed,
		"active_session_id": active_session_id,
		"session_snapshot": session_snapshot,
		"armed_session_id": _armed_session_id,
		"armed_at_unix": _armed_at_unix,
		"last_reply_at_unix": _request_coordinator.get_last_reply_at_unix(),
		"pending_request_count": _request_coordinator.get_pending_request_count(),
		"message": message
	}


func enable_control(args: Dictionary = {}) -> Dictionary:
	var wait_timeout_ms := _resolve_timeout_ms(args, DEFAULT_ENABLE_TIMEOUT_MS)
	var session_id := await _session_selector.await_commandable_session(wait_timeout_ms)
	if session_id < 0:
		return _error_mapper.error("runtime_not_running", "Runtime control requires an active running project session. Call system_project_run first.", {
			"timeout_ms": wait_timeout_ms
		}, "enable")
	var readiness_result := await _await_runtime_ready(session_id, wait_timeout_ms)
	if not bool(readiness_result.get("success", false)):
		return readiness_result
	_armed_session_id = int(readiness_result.get("session_id", session_id))
	_armed_at_unix = int(Time.get_unix_time_from_system())
	_log_message("Runtime control armed for debugger session %d" % _armed_session_id, "info")
	var readiness_data = readiness_result.get("data", {})
	return _success({
		"armed": true,
		"session_id": _armed_session_id,
		"armed_at_unix": _armed_at_unix,
		"runtime_state": (readiness_data as Dictionary).get("runtime_state", {}) if readiness_data is Dictionary else {}
	}, "Runtime control enabled")


func disable_control() -> Dictionary:
	var previous_session_id := _armed_session_id
	_armed_session_id = -1
	_armed_at_unix = 0
	_request_coordinator.mark_all_pending_requests("runtime_control_disabled", "Runtime control was disabled before the command completed")
	return _success({
		"armed": false,
		"session_id": previous_session_id
	}, "Runtime control disabled")


func capture(args: Dictionary) -> Dictionary:
	var frame_count := int(args.get("frame_count", 1))
	var interval_frames := int(args.get("interval_frames", 1))
	if frame_count <= 0:
		return _error_mapper.error("invalid_argument", "frame_count must be greater than 0", {}, "capture")
	if interval_frames < 0:
		return _error_mapper.error("invalid_argument", "interval_frames must be 0 or greater", {}, "capture")
	var payload := {
		"frame_count": frame_count,
		"interval_frames": interval_frames,
		"capture_label": str(args.get("capture_label", "")),
		"include_runtime_state": bool(args.get("include_runtime_state", true))
	}
	var default_timeout_ms := DEFAULT_COMMAND_TIMEOUT_MS if frame_count <= 1 else DEFAULT_SEQUENCE_TIMEOUT_MS
	var timeout_ms := _resolve_timeout_ms(args, default_timeout_ms)
	return await _request_runtime_command("capture", payload, timeout_ms)


func send_inputs(args: Dictionary) -> Dictionary:
	var inputs = args.get("inputs", [])
	if not (inputs is Array) or (inputs as Array).is_empty():
		return _error_mapper.error("invalid_argument", "system_runtime_input requires a non-empty inputs array", {}, "input")
	var timeout_ms := _resolve_timeout_ms(args, DEFAULT_COMMAND_TIMEOUT_MS)
	return await _request_runtime_command("input", {
		"inputs": (inputs as Array).duplicate(true)
	}, timeout_ms)


func step(args: Dictionary) -> Dictionary:
	var inputs = args.get("inputs", [])
	if inputs != null and not (inputs is Array):
		return _error_mapper.error("invalid_argument", "inputs must be an array when provided", {}, "step")
	var wait_frames := int(args.get("wait_frames", 1))
	if wait_frames < 0:
		return _error_mapper.error("invalid_argument", "wait_frames must be 0 or greater", {}, "step")
	var timeout_ms := _resolve_timeout_ms(args, DEFAULT_SEQUENCE_TIMEOUT_MS)
	var payload := {
		"inputs": (inputs as Array).duplicate(true) if inputs is Array else [],
		"wait_frames": wait_frames,
		"capture": bool(args.get("capture", true)),
		"capture_label": str(args.get("capture_label", "")),
		"include_runtime_state": bool(args.get("include_runtime_state", true))
	}
	return await _request_runtime_command("step", payload, timeout_ms)


func _request_runtime_command(action: String, payload: Dictionary, timeout_ms: int) -> Dictionary:
	_validate_armed_session()
	if _armed_session_id < 0:
		return _error_mapper.error("runtime_control_disabled", "Runtime control is disabled. Call system_runtime_control with action=enable first.", {}, action)
	return await _request_runtime_command_on_session(_armed_session_id, action, payload, timeout_ms)


func _request_runtime_command_on_session(session_id: int, action: String, payload: Dictionary, timeout_ms: int, require_armed: bool = true) -> Dictionary:
	if session_id < 0 or not _session_selector.is_session_commandable(session_id):
		var previous_session_id := session_id if session_id >= 0 else _armed_session_id
		if require_armed and _armed_session_id == session_id:
			_armed_session_id = -1
			_armed_at_unix = 0
		return _error_mapper.error("runtime_session_lost", "The armed runtime debugger session is no longer available.", {
			"session_id": previous_session_id
		}, action)

	return await _request_coordinator.request_runtime_command(session_id, action, payload, timeout_ms)


func _connect_debugger_bridge() -> void:
	if _debugger_bridge == null:
		return
	if _debugger_bridge.has_signal("runtime_reply_received") and not _debugger_bridge.runtime_reply_received.is_connected(_on_runtime_reply_received):
		_debugger_bridge.runtime_reply_received.connect(_on_runtime_reply_received)
	if _debugger_bridge.has_signal("session_state_changed") and not _debugger_bridge.session_state_changed.is_connected(_on_session_state_changed):
		_debugger_bridge.session_state_changed.connect(_on_session_state_changed)


func _disconnect_debugger_bridge() -> void:
	if _debugger_bridge == null:
		return
	if _debugger_bridge.has_signal("runtime_reply_received") and _debugger_bridge.runtime_reply_received.is_connected(_on_runtime_reply_received):
		_debugger_bridge.runtime_reply_received.disconnect(_on_runtime_reply_received)
	if _debugger_bridge.has_signal("session_state_changed") and _debugger_bridge.session_state_changed.is_connected(_on_session_state_changed):
		_debugger_bridge.session_state_changed.disconnect(_on_session_state_changed)


func _on_runtime_reply_received(session_id: int, payload: Dictionary) -> void:
	_request_coordinator.handle_runtime_reply(session_id, payload)


func _on_session_state_changed(session_id: int, state: String, _metadata: Dictionary) -> void:
	if state in ["stopped"]:
		if _armed_session_id == session_id:
			_armed_session_id = -1
			_armed_at_unix = 0
		_request_coordinator.mark_pending_requests_for_session(session_id, "runtime_session_lost", "The runtime debugger session stopped before the command completed.")
	elif state in ["started", "continued", "breaked", "attached"]:
		_validate_armed_session()


func _validate_armed_session() -> void:
	if _armed_session_id >= 0 and not _session_selector.is_session_commandable(_armed_session_id):
		_armed_session_id = -1
		_armed_at_unix = 0


func _send_runtime_command(session_id: int, payload: Dictionary) -> Dictionary:
	var action := str(payload.get("action", ""))
	if _debugger_bridge == null or not is_instance_valid(_debugger_bridge):
		return _error_mapper.error("runtime_bridge_unavailable", "Editor debugger bridge is unavailable", {}, action)
	if not _debugger_bridge.has_method("send_runtime_command"):
		return _error_mapper.error("runtime_bridge_unavailable", "Editor debugger bridge cannot send runtime commands", {}, action)
	var result = _debugger_bridge.send_runtime_command(session_id, payload)
	if result is Dictionary:
		if bool((result as Dictionary).get("success", false)):
			return result
		return _error_mapper.error(
			str((result as Dictionary).get("error", "runtime_bridge_unavailable")),
			str((result as Dictionary).get("message", "Runtime command dispatch failed")),
			(result as Dictionary).get("data", {}),
			action
		)
	return _error_mapper.error("runtime_bridge_unavailable", "Runtime command dispatch failed", {}, action)


func _await_runtime_ready(initial_session_id: int, timeout_ms: int) -> Dictionary:
	var session_id := initial_session_id
	var deadline := Time.get_ticks_msec() + maxi(timeout_ms, 1)
	var last_error := {}
	while Time.get_ticks_msec() <= deadline:
		if session_id < 0 or not _session_selector.is_session_commandable(session_id):
			var remaining_for_session := maxi(deadline - Time.get_ticks_msec(), 1)
			session_id = await _session_selector.await_commandable_session(mini(remaining_for_session, 1000))
			if session_id < 0:
				last_error = _error_mapper.error("runtime_not_running", "Runtime control requires an active running project session. Call system_project_run first.", {
					"timeout_ms": timeout_ms
				}, "enable")
				break

		var remaining_ms := maxi(deadline - Time.get_ticks_msec(), 1)
		var attempt_timeout_ms := mini(remaining_ms, 1500)
		var readiness_result := await _request_runtime_command_on_session(
			session_id,
			"status",
			{
				"include_runtime_state": true
			},
			attempt_timeout_ms,
			false
		)
		if bool(readiness_result.get("success", false)):
			readiness_result["session_id"] = session_id
			return readiness_result

		var error_type := str(readiness_result.get("error", ""))
		if error_type not in ["runtime_command_timeout", "runtime_session_lost", "runtime_bridge_unavailable"]:
			readiness_result["session_id"] = session_id
			return readiness_result

		last_error = (readiness_result as Dictionary).duplicate(true)
		last_error["session_id"] = session_id

		var tree = _session_selector.get_scene_tree()
		if tree == null:
			break
		await tree.process_frame

	if last_error.is_empty():
		last_error = _error_mapper.error("runtime_command_timeout", "Timed out waiting for the runtime bridge to become ready.", {
			"timeout_ms": timeout_ms
		}, "enable")
	last_error["session_id"] = session_id
	return last_error


func _resolve_timeout_ms(args: Dictionary, default_value: int) -> int:
	var timeout_ms := int(args.get("timeout_ms", default_value))
	if timeout_ms <= 0:
		return default_value
	return timeout_ms


func _log_message(message: String, level: String = "debug") -> void:
	if _log.is_valid():
		_log.call(message, level)


func _success(data, message: String) -> Dictionary:
	return {
		"success": true,
		"data": data,
		"message": message
	}


func _build_editor_error_context(action: String = "") -> Dictionary:
	_validate_armed_session()
	var active_session_id := _session_selector.get_preferred_session_id()
	var session_snapshot := _session_selector.get_debugger_session_snapshot()
	return {
		"layer": "editor_runtime_control",
		"action": action,
		"available": active_session_id >= 0,
		"active_session_id": active_session_id,
		"session_snapshot": session_snapshot,
		"armed": _armed_session_id >= 0,
		"armed_session_id": _armed_session_id,
		"armed_at_unix": _armed_at_unix,
		"last_reply_at_unix": _request_coordinator.get_last_reply_at_unix(),
		"pending_request_count": _request_coordinator.get_pending_request_count()
	}


func _get_scene_tree() -> SceneTree:
	return _session_selector.get_scene_tree()


func _get_debugger_session_snapshot() -> Dictionary:
	return _session_selector.get_debugger_session_snapshot()

func _get_recent_runtime_events() -> Array[Dictionary]:
	return MCPRuntimeDebugStore.get_recent(80)


func _build_runtime_control_error(error_type: String, message: String, data = {}, action: String = "") -> Dictionary:
	return _error_mapper.error(error_type, message, data, action)
