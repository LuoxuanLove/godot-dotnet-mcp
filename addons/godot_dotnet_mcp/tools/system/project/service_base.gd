@tool
extends RefCounted

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")

var bridge


func _get_runtime_summary() -> Dictionary:
	return bridge.extract_data(bridge.call_atomic("debug_runtime_bridge", {"action": "get_summary"}))


func _get_runtime_errors(limit: int) -> Array:
	return bridge.extract_array(bridge.call_atomic("debug_runtime_bridge", {
		"action": "get_errors_context", "limit": limit
	}), "errors")


func _get_runtime_warnings(limit: int) -> Array:
	var result: Dictionary = bridge.call_atomic("debug_runtime_bridge", {
		"action": "get_recent_filtered",
		"level": "warning",
		"tail": limit,
		"limit": max(limit * 4, 20)
	})
	var warnings: Array = []
	for event in bridge.extract_array(result, "events"):
		if not (event is Dictionary):
			continue
		var payload = event.get("payload", {})
		if not (payload is Dictionary):
			payload = {}
		warnings.append({
			"timestamp": str(event.get("timestamp_text", "")),
			"message": str((payload as Dictionary).get("message", "")),
			"source": str((payload as Dictionary).get("source", (payload as Dictionary).get("script", "")))
		})
	return warnings


func _get_lsp_runtime_health_summary() -> Dictionary:
	var summary: Dictionary = {"enabled": false, "available": false, "last_state": "unavailable", "last_error": ""}
	if bridge == null or not bridge.has_method("get_tool_loader"):
		summary["last_error"] = "Tool loader is unavailable"
		return summary
	var loader = bridge.get_tool_loader()
	if loader == null or not loader.has_method("get_lsp_diagnostics_debug_snapshot"):
		summary["last_error"] = "LSP diagnostics snapshot is unavailable"
		return summary
	summary["enabled"] = loader.has_method("get_gdscript_lsp_diagnostics_service")
	var snapshot_raw = loader.get_lsp_diagnostics_debug_snapshot()
	if not (snapshot_raw is Dictionary):
		summary["last_error"] = "LSP diagnostics snapshot is unavailable"
		return summary
	var snapshot: Dictionary = snapshot_raw
	var service_snapshot: Dictionary = snapshot.get("service", {}) if snapshot.get("service", {}) is Dictionary else {}
	var current_status: Dictionary = service_snapshot.get("status", {}) if service_snapshot.get("status", {}) is Dictionary else {}
	var last_completed: Dictionary = service_snapshot.get("last_completed_status", {}) if service_snapshot.get("last_completed_status", {}) is Dictionary else {}
	var source_status := current_status if not current_status.is_empty() else last_completed
	summary["available"] = bool(snapshot.get("service_available", false))
	summary["last_state"] = str(source_status.get("phase", source_status.get("state", "idle")))
	summary["last_error"] = str(source_status.get("error", last_completed.get("error", "")))
	return summary


func _get_tool_loader_health_summary() -> Dictionary:
	var summary: Dictionary = {"enabled": false, "available": false, "status": "unavailable", "tool_count": 0, "exposed_tool_count": 0, "last_error": ""}
	if bridge == null or not bridge.has_method("get_tool_loader"):
		summary["last_error"] = "Tool loader is unavailable"
		return summary
	var loader = bridge.get_tool_loader()
	if loader == null or not loader.has_method("get_tool_loader_status"):
		summary["last_error"] = "Tool loader status is unavailable"
		return summary
	summary["enabled"] = true
	var status_raw = loader.get_tool_loader_status()
	if not (status_raw is Dictionary):
		summary["last_error"] = "Tool loader status is unavailable"
		return summary
	var status: Dictionary = status_raw
	summary["available"] = true
	summary["status"] = str(status.get("status", "unknown"))
	summary["tool_count"] = int(status.get("tool_count", 0))
	summary["exposed_tool_count"] = int(status.get("exposed_tool_count", 0))
	summary["last_error"] = str(status.get("last_error", ""))
	return summary


func _is_runtime_running(summary: Dictionary) -> bool:
	var sessions = summary.get("sessions", {})
	if sessions is Dictionary:
		for session_id in (sessions as Dictionary).keys():
			var session = (sessions as Dictionary).get(session_id, {})
			if session is Dictionary and str((session as Dictionary).get("state", "")) in ["started", "running"]:
				return true
	elif sessions is Array:
		for session in sessions:
			if session is Dictionary and str((session as Dictionary).get("state", "")) in ["started", "running"]:
				return true
	return false


func _goal_contains(goal: String, keywords: Array) -> bool:
	var lowered := goal.to_lower()
	for keyword in keywords:
		if lowered.find(str(keyword).to_lower()) != -1:
			return true
	return false
