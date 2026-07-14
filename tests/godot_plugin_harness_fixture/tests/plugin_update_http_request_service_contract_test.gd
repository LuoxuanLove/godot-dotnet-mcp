extends RefCounted

# {"name": "plugin_update_http_request_service_contracts"}

const PluginUpdateHttpRequestServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_http_request_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var source_guard := _verify_plugin_entrypoint_delegates_update_http_requests()
	if not source_guard.is_empty():
		return _failure(source_guard)

	var service = PluginUpdateHttpRequestServiceScript.new()
	var request_node := HTTPRequest.new()
	service.configure_request_node(request_node, "UpdateArchiveSyncRequest", 42.5, 123456, "user://godot_dotnet_mcp/test.zip")
	if request_node.name != "UpdateArchiveSyncRequest":
		return _failure("PluginUpdateHttpRequestService should own update request node names.", {"name": request_node.name})
	if request_node.timeout != 42.5:
		return _failure("PluginUpdateHttpRequestService should apply update HTTP timeouts.", {"timeout": request_node.timeout})
	if request_node.body_size_limit != 123456:
		return _failure("PluginUpdateHttpRequestService should apply update HTTP body limits.", {"limit": request_node.body_size_limit})
	if request_node.download_file != "user://godot_dotnet_mcp/test.zip":
		return _failure("PluginUpdateHttpRequestService should apply archive download paths.", {"path": request_node.download_file})
	request_node.free()

	var missing_host_result: Dictionary = service.start_request(
		null,
		"MissingHostRequest",
		"https://example.invalid",
		PackedStringArray(),
		Callable(),
		1.0,
		64
	)
	if bool(missing_host_result.get("success", true)):
		return _failure("PluginUpdateHttpRequestService should reject missing request parents.", missing_host_result)
	if int(missing_host_result.get("error", OK)) != FAILED:
		return _failure("PluginUpdateHttpRequestService should return a deterministic missing-host error.", missing_host_result)

	return {"name": "plugin_update_http_request_service_contracts", "success": true, "error": ""}


func _verify_plugin_entrypoint_delegates_update_http_requests() -> String:
	var plugin_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin.gd")
	var service_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_http_request_service.gd")
	if plugin_source.is_empty() or service_source.is_empty():
		return "Plugin update HTTP request sources should be readable."
	for required in [
		"PluginUpdateHttpRequestServiceScript.new()",
		"_ensure_plugin_update_http_request_service().start_refs_request(",
		"_ensure_plugin_update_http_request_service().start_small_refs_request(",
		"_ensure_plugin_update_http_request_service().start_sync_archive_request(",
		"func _ensure_plugin_update_http_request_service()"
	]:
		if plugin_source.find(required) == -1:
			return "plugin.gd should delegate update HTTP request responsibility: %s" % required
	for forbidden in [
		"HTTPRequest.new()",
		"request_completed.connect(Callable(self, \"_on_update_refs_request_completed\")",
		"request_completed.connect(Callable(self, \"_on_update_archive_sync_request_attempt_completed\")"
	]:
		if plugin_source.find(forbidden) != -1:
			return "plugin.gd should not retain update HTTP request internals: %s" % forbidden
	for required_service in [
		"func start_refs_request(",
		"func start_small_refs_request(",
		"func start_sync_archive_request(",
		"func configure_request_node(",
		"func _free_completed_request("
	]:
		if service_source.find(required_service) == -1:
			return "PluginUpdateHttpRequestService should own update HTTP request member: %s" % required_service
	return ""


func _failure(message: String, details: Dictionary = {}) -> Dictionary:
	return {"name": "plugin_update_http_request_service_contracts", "success": false, "error": message, "details": details}
