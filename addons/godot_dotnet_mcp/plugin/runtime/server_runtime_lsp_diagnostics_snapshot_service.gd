@tool
extends RefCounted
class_name ServerRuntimeLspDiagnosticsSnapshotService


func build_snapshot(loader) -> Dictionary:
	if loader == null:
		return _build_unavailable_snapshot("Tool loader is unavailable")

	if loader.has_method("get_lsp_diagnostics_debug_snapshot"):
		var loader_snapshot = loader.get_lsp_diagnostics_debug_snapshot()
		if loader_snapshot is Dictionary and not (loader_snapshot as Dictionary).is_empty():
			return _normalize_snapshot(loader_snapshot as Dictionary)
	if loader.has_method("get_gdscript_lsp_diagnostics_service"):
		var service = loader.get_gdscript_lsp_diagnostics_service()
		if service != null and service.has_method("get_debug_snapshot"):
			return _normalize_snapshot({
				"has_tool_loader": true,
				"service_available": true,
				"service": service.get_debug_snapshot()
			})

	return _build_unavailable_snapshot("Tool loader does not expose LSP diagnostics state")


func _build_unavailable_snapshot(message: String) -> Dictionary:
	return {
		"loader": {
			"available": false,
			"has_tool_loader": false,
			"owns_diagnostics_service": false,
			"service_generation": 0,
			"tool_loader_status": {}
		},
		"service": {
			"available": false,
			"request_count": 0,
			"active_key": "",
			"cache_entry_count": 0,
			"last_completed_status": {},
			"status": {},
			"last_error": ""
		},
		"client": {
			"available": false
		},
		"error": message
	}


func _normalize_snapshot(raw_snapshot: Dictionary) -> Dictionary:
	var snapshot: Dictionary = _build_unavailable_snapshot("LSP diagnostics status is unavailable")
	var loader_summary_raw = snapshot.get("loader", {})
	var loader_summary: Dictionary = loader_summary_raw if loader_summary_raw is Dictionary else {}
	loader_summary["available"] = bool(raw_snapshot.get("has_tool_loader", false))
	loader_summary["has_tool_loader"] = bool(raw_snapshot.get("has_tool_loader", false))
	loader_summary["owns_diagnostics_service"] = bool(raw_snapshot.get("service_available", false))
	loader_summary["service_generation"] = int(raw_snapshot.get("service_generation", 0))
	loader_summary["tool_loader_status"] = raw_snapshot.get("tool_loader_status", {})
	snapshot["loader"] = loader_summary

	var service_raw = raw_snapshot.get("service", {})
	var service_snapshot: Dictionary = {}
	if service_raw is Dictionary:
		service_snapshot = (service_raw as Dictionary).duplicate(true)

	var service_summary_raw = snapshot.get("service", {})
	var service_summary: Dictionary = service_summary_raw if service_summary_raw is Dictionary else {}
	service_summary["available"] = bool(raw_snapshot.get("service_available", false)) and not service_snapshot.is_empty()
	service_summary["request_count"] = int(service_snapshot.get("request_count", 0))
	service_summary["active_key"] = str(service_snapshot.get("active_key", ""))
	service_summary["cache_entry_count"] = int(service_snapshot.get("cache_entry_count", 0))
	service_summary["last_completed_status"] = service_snapshot.get("last_completed_status", {})
	service_summary["status"] = service_snapshot.get("status", {})

	var status_raw = service_summary.get("status", {})
	var status_dict: Dictionary = status_raw if status_raw is Dictionary else {}
	var last_completed_raw = service_summary.get("last_completed_status", {})
	var last_completed: Dictionary = last_completed_raw if last_completed_raw is Dictionary else {}
	var client_raw = service_snapshot.get("client", {})
	if client_raw is Dictionary:
		var client_snapshot := (client_raw as Dictionary).duplicate(true)
		client_snapshot["available"] = not client_snapshot.is_empty()
		snapshot["client"] = client_snapshot

	var last_error := str(status_dict.get("error", ""))
	if last_error.is_empty():
		last_error = str(last_completed.get("error", ""))
	service_summary["last_error"] = last_error
	snapshot["service"] = service_summary

	if bool(service_summary.get("available", false)):
		snapshot.erase("error")
	elif not last_error.is_empty():
		snapshot["error"] = last_error
	return snapshot
