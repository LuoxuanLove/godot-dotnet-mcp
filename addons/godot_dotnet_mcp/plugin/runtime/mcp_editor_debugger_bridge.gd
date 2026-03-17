@tool
extends EditorDebuggerPlugin
class_name MCPEditorDebuggerBridge

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const MCPRuntimeDebugStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_debug_store.gd")

const MESSAGE_PREFIX := "godot_mcp/"
const EVENT_CHANNEL := "godot_mcp/runtime_event"
const LOG_CHANNEL := "godot_mcp/runtime_log"

var _wired_sessions: Dictionary = {}


func _has_capture(message: String) -> bool:
	return str(message).begins_with(MESSAGE_PREFIX)


func _capture(message: String, data, session_id: int) -> bool:
	var payload := _extract_payload(data)
	match str(message):
		EVENT_CHANNEL:
			var event_name := str(payload.get("event", "runtime_event"))
			MCPRuntimeDebugStore.record_runtime_event("runtime_event", payload, session_id)
			MCPDebugBuffer.record("info", "runtime_bridge", event_name, "", {
				"session_id": session_id,
				"payload": payload.duplicate(true)
			})
			return true
		LOG_CHANNEL:
			var level := str(payload.get("level", "info")).to_lower()
			var message_text := str(payload.get("message", ""))
			MCPRuntimeDebugStore.record_runtime_event("runtime_log", payload, session_id)
			MCPDebugBuffer.record(level, "runtime_bridge", message_text, "", {
				"session_id": session_id,
				"payload": payload.duplicate(true)
			})
			return true
		_:
			return false


func _setup_session(session_id: int) -> void:
	var session := get_session(session_id)
	if session == null:
		return
	if _wired_sessions.has(session_id):
		return

	session.started.connect(Callable(self, "_on_session_started").bind(session_id))
	session.stopped.connect(Callable(self, "_on_session_stopped").bind(session_id))
	session.breaked.connect(Callable(self, "_on_session_breaked").bind(session_id))
	session.continued.connect(Callable(self, "_on_session_continued").bind(session_id))
	_wired_sessions[session_id] = true
	_record_session_state(session_id, session, "attached", {})


func _on_session_started(session_id: int) -> void:
	var session := get_session(session_id)
	_record_session_state(session_id, session, "started", {})
	_record_runtime_session_event(session_id, "session_started")


func _on_session_stopped(session_id: int) -> void:
	var session := get_session(session_id)
	_record_session_state(session_id, session, "stopped", {})
	_record_runtime_session_event(session_id, "session_stopped")


func _on_session_breaked(can_debug: bool, session_id: int) -> void:
	var session := get_session(session_id)
	_record_session_state(session_id, session, "breaked", {
		"can_debug": can_debug
	})


func _on_session_continued(session_id: int) -> void:
	var session := get_session(session_id)
	_record_session_state(session_id, session, "continued", {})


func _record_session_state(session_id: int, session: EditorDebuggerSession, state: String, metadata: Dictionary) -> void:
	if session != null and not is_instance_valid(session):
		return
	var payload := {
		"active": session != null and session.is_active(),
		"debuggable": session != null and session.is_debuggable(),
		"breaked": session != null and session.is_breaked()
	}
	if metadata is Dictionary:
		for key in metadata.keys():
			payload[key] = metadata[key]
	MCPRuntimeDebugStore.record_session_state(session_id, state, payload)
	MCPDebugBuffer.record("info", "editor_debugger", "Session %d %s" % [session_id, state], "", payload)


func _record_runtime_session_event(session_id: int, event_name: String) -> void:
	var payload := {
		"event": event_name,
		"scene": "",
		"metadata": {
			"session_id": session_id
		}
	}
	MCPRuntimeDebugStore.record_runtime_event("runtime_event", payload, session_id)
	MCPDebugBuffer.record("info", "runtime_bridge", event_name, "", {
		"session_id": session_id,
		"payload": payload.duplicate(true)
	})


func _extract_payload(data) -> Dictionary:
	if data is Array and data.size() > 0 and data[0] is Dictionary:
		return (data[0] as Dictionary).duplicate(true)
	if data is Dictionary:
		return (data as Dictionary).duplicate(true)
	return {}
