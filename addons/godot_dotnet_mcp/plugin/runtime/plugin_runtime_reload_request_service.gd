@tool
extends RefCounted
class_name PluginRuntimeReloadRequestService


func request_reload(domain_id: String, reason: String = "manual", server_controller = null) -> Dictionary:
	if server_controller == null:
		return {"success": false, "error": "Server runtime controller is unavailable"}
	if domain_id.is_empty():
		return {"success": false, "error": "Missing reload domain"}
	if not server_controller.has_method("reload_domain"):
		return {"success": false, "error": "Server runtime controller does not support domain reload requests"}
	var status = server_controller.reload_domain(domain_id)
	return {
		"success": (status.get("failed_domains", []) as Array).is_empty(),
		"mode": "domain",
		"domain": domain_id,
		"reason": reason,
		"status": status
	}


func request_reload_by_script(script_path: String, reason: String = "manual", server_controller = null) -> Dictionary:
	if server_controller == null:
		return {"success": false, "error": "Server runtime controller is unavailable"}
	if script_path.is_empty():
		return {"success": false, "error": "Missing reload script path"}
	if not server_controller.has_method("request_reload_by_script"):
		return {"success": false, "error": "Server runtime controller does not support script reload requests"}
	var status = server_controller.request_reload_by_script(script_path, reason)
	return {
		"success": bool(status.get("success", false)),
		"mode": "script",
		"script_path": script_path,
		"reason": reason,
		"status": status
	}


func request_reload_all(reason: String = "manual", server_controller = null) -> Dictionary:
	if server_controller == null:
		return {"success": false, "error": "Server runtime controller is unavailable"}
	if not server_controller.has_method("reload_all_domains"):
		return {"success": false, "error": "Server runtime controller does not support full reload requests"}
	var status = server_controller.reload_all_domains()
	return {
		"success": (status.get("failed_domains", []) as Array).is_empty(),
		"mode": "all",
		"reason": reason,
		"status": status
	}
