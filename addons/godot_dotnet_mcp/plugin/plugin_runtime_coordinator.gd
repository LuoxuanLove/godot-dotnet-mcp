@tool
extends RefCounted

const UserToolWatchService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_watch_service.gd")
const CentralServerAttachServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/central_server_attach_service.gd")
const CentralServerProcessServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/central_server_process_service.gd")


func configure_user_tool_watch_service(current_service, plugin, create_reload_coordinator: Callable, user_tool_service, callbacks: Dictionary = {}):
	var service = current_service
	if service == null:
		service = UserToolWatchService.new()
	service.stop()
	service.configure(plugin, create_reload_coordinator.call(), user_tool_service, callbacks)
	service.start()
	return service


func configure_central_server_process_service(current_service, plugin, settings: Dictionary):
	var service = current_service
	if service == null:
		service = CentralServerProcessServiceScript.new()
	service.configure(plugin, settings)
	service.refresh_detection()
	return service


func ensure_local_central_server_if_needed(process_service, attach_service, last_endpoint_reachable: bool) -> Dictionary:
	if process_service == null or attach_service == null:
		return {
			"last_endpoint_reachable": last_endpoint_reachable
		}

	var attach_status = attach_service.get_status()
	if not bool(attach_status.get("enabled", true)):
		return {
			"last_endpoint_reachable": last_endpoint_reachable
		}

	var attach_state = str(attach_status.get("status", "idle"))
	if attach_state == "attached" or attach_state == "attaching" or attach_state == "heartbeat_pending":
		var attached_status = process_service.get_status()
		return {
			"last_endpoint_reachable": bool(attached_status.get("endpoint_reachable", false))
		}

	var status = process_service.ensure_service_running()
	var endpoint_reachable = bool(status.get("endpoint_reachable", false))
	if endpoint_reachable and not last_endpoint_reachable:
		attach_service.request_attach_soon()
	if str(status.get("status", "")) == "starting":
		attach_service.request_attach_soon()

	return {
		"last_endpoint_reachable": endpoint_reachable
	}


func configure_central_server_attach_service(current_service, plugin, settings: Dictionary, save_settings: Callable):
	var service = current_service
	if service == null:
		service = CentralServerAttachServiceScript.new()
	service.configure(plugin, settings, {
		"save_settings": save_settings
	})
	service.start()
	return service
