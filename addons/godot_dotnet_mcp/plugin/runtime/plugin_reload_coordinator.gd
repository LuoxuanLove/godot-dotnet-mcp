@tool
extends Node

var _plugin_id := ""
var _phase := 0
var _editor_interface
var _server_controller = null


func configure(plugin_id: String, editor_interface, server_controller = null) -> void:
	_plugin_id = plugin_id
	_editor_interface = editor_interface
	_server_controller = server_controller


func request_reload(domain_id: String, reason: String = "manual") -> Dictionary:
	if _server_controller == null:
		return {"success": false, "error": "Server runtime controller is unavailable"}
	if domain_id.is_empty():
		return {"success": false, "error": "Missing reload domain"}
	var status = _server_controller.reload_domain(domain_id)
	return {
		"success": (status.get("failed_domains", []) as Array).is_empty(),
		"mode": "domain",
		"domain": domain_id,
		"reason": reason,
		"status": status
	}


func request_reload_by_script(script_path: String, reason: String = "manual") -> Dictionary:
	if _server_controller == null:
		return {"success": false, "error": "Server runtime controller is unavailable"}
	if script_path.is_empty():
		return {"success": false, "error": "Missing reload script path"}
	var status = _server_controller.request_reload_by_script(script_path, reason)
	return {
		"success": bool(status.get("success", false)),
		"mode": "script",
		"script_path": script_path,
		"reason": reason,
		"status": status
	}


func request_reload_all(reason: String = "manual") -> Dictionary:
	if _server_controller == null:
		return {"success": false, "error": "Server runtime controller is unavailable"}
	var status = _server_controller.reload_all_domains()
	return {
		"success": (status.get("failed_domains", []) as Array).is_empty(),
		"mode": "all",
		"reason": reason,
		"status": status
	}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


func _process(_delta: float) -> void:
	var editor_interface = _get_editor_interface()
	if editor_interface == null or _plugin_id.is_empty():
		queue_free()
		return

	match _phase:
		0:
			editor_interface.set_plugin_enabled(_plugin_id, false)
			_phase = 1
		1:
			editor_interface.set_plugin_enabled(_plugin_id, true)
			queue_free()


func _get_editor_interface():
	if _editor_interface != null and is_instance_valid(_editor_interface):
		return _editor_interface
	return null
