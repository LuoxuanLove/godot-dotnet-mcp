extends RefCounted

const PluginRuntimeReloadRequestServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_reload_request_service.gd")


class FakeServerController extends RefCounted:
	var calls: Array[Dictionary] = []
	var domain_status: Dictionary = {"failed_domains": []}
	var script_status: Dictionary = {"success": true, "runtime_state": [{"name": "demo"}]}
	var all_status: Dictionary = {"failed_domains": []}


	func reload_domain(domain_id: String) -> Dictionary:
		calls.append({"method": "reload_domain", "domain_id": domain_id})
		return domain_status


	func request_reload_by_script(script_path: String, reason: String = "manual") -> Dictionary:
		calls.append({"method": "request_reload_by_script", "script_path": script_path, "reason": reason})
		return script_status


	func reload_all_domains() -> Dictionary:
		calls.append({"method": "reload_all_domains"})
		return all_status


func run_case(_tree: SceneTree) -> Dictionary:
	var service = PluginRuntimeReloadRequestServiceScript.new()
	var source_guard_error := _assert_runtime_reload_boundaries()
	if not source_guard_error.is_empty():
		return _failure(source_guard_error)

	var missing_controller_status: Dictionary = service.request_reload("user", "manual", null)
	if bool(missing_controller_status.get("success", true)) or str(missing_controller_status.get("error", "")) != "Server runtime controller is unavailable":
		return _failure("Runtime reload service should preserve the missing controller error.")

	var controller := FakeServerController.new()
	var missing_domain_status: Dictionary = service.request_reload("", "manual", controller)
	if bool(missing_domain_status.get("success", true)) or str(missing_domain_status.get("error", "")) != "Missing reload domain":
		return _failure("Runtime reload service should reject an empty reload domain.")

	var domain_status: Dictionary = service.request_reload("user", "watcher_file_changed", controller)
	if not bool(domain_status.get("success", false)):
		return _failure("Runtime reload service should treat an empty failed_domains list as a successful domain reload.")
	if str(domain_status.get("mode", "")) != "domain" or str(domain_status.get("domain", "")) != "user" or str(domain_status.get("reason", "")) != "watcher_file_changed":
		return _failure("Domain reload response should preserve mode, domain, and reason metadata.")

	controller.domain_status = {"failed_domains": ["user"]}
	var failed_domain_status: Dictionary = service.request_reload("user", "manual", controller)
	if bool(failed_domain_status.get("success", true)):
		return _failure("Runtime reload service should use failed_domains to report domain reload failure.")

	var missing_script_status: Dictionary = service.request_reload_by_script("", "manual", controller)
	if bool(missing_script_status.get("success", true)) or str(missing_script_status.get("error", "")) != "Missing reload script path":
		return _failure("Runtime reload service should reject an empty script path.")

	var raw_script_path := " res://addons/godot_dotnet_mcp/custom_tools/demo.gd "
	var script_status: Dictionary = service.request_reload_by_script(raw_script_path, "external_watch", controller)
	if not bool(script_status.get("success", false)):
		return _failure("Runtime reload service should report script reload success from the controller status.")
	if str(script_status.get("mode", "")) != "script" or str(script_status.get("script_path", "")) != raw_script_path or str(script_status.get("reason", "")) != "external_watch":
		return _failure("Script reload response should preserve the raw script path and reason from the request.")
	var script_call: Dictionary = controller.calls[controller.calls.size() - 1]
	if str(script_call.get("script_path", "")) != raw_script_path:
		return _failure("Runtime reload service should leave script path normalization to the server controller.")

	controller.script_status = {"success": false, "error": "Tool loader does not support script reload requests"}
	var failed_script_status: Dictionary = service.request_reload_by_script("res://addons/tool.gd", "manual", controller)
	if bool(failed_script_status.get("success", true)):
		return _failure("Runtime reload service should report script reload failure from the controller status.")

	controller.all_status = {"failed_domains": []}
	var all_status: Dictionary = service.request_reload_all("manual", controller)
	if not bool(all_status.get("success", false)) or str(all_status.get("mode", "")) != "all":
		return _failure("Runtime reload service should support all-domain reload requests.")

	controller.all_status = {"failed_domains": ["user"]}
	var failed_all_status: Dictionary = service.request_reload_all("manual", controller)
	if bool(failed_all_status.get("success", true)):
		return _failure("Runtime reload service should use failed_domains to report all-domain reload failure.")

	return {
		"name": "plugin_runtime_reload_request_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"calls": controller.calls.duplicate(true)
		}
	}


func _assert_runtime_reload_boundaries() -> String:
	var coordinator_path := "res://addons/godot_dotnet_mcp/plugin/runtime/plugin_reload_coordinator.gd"
	if not FileAccess.file_exists(coordinator_path):
		return "PluginReloadCoordinator source should exist for reload boundary guards."
	var coordinator_source := FileAccess.get_file_as_string(coordinator_path)
	for forbidden in [
		"_server_controller",
		"func request_reload(",
		"func request_reload_by_script(",
		"func request_reload_all(",
		"reload_domain(",
		"reload_all_domains()"
	]:
		if coordinator_source.find(forbidden) != -1:
			return "PluginReloadCoordinator should stay lifecycle-only and not own runtime reload requests: %s" % forbidden

	var plugin_path := "res://addons/godot_dotnet_mcp/plugin.gd"
	if not FileAccess.file_exists(plugin_path):
		return "Plugin entrypoint source should exist for runtime reload request guards."
	var plugin_source := FileAccess.get_file_as_string(plugin_path)
	for required in [
		"PluginRuntimeReloadRequestServiceScript",
		"_runtime_reload_request_service.request_reload_by_script(",
		"_runtime_reload_request_service.request_reload("
	]:
		if plugin_source.find(required) == -1:
			return "Plugin entrypoint should route user-tool runtime reload requests through PluginRuntimeReloadRequestService: %s" % required
	for forbidden in [
		"coordinator.request_reload(",
		"coordinator.request_reload_by_script(",
		"coordinator.request_reload_all("
	]:
		if plugin_source.find(forbidden) != -1:
			return "Plugin entrypoint should not use PluginReloadCoordinator as a runtime reload request facade: %s" % forbidden
	return ""


func _failure(message: String, details: Dictionary = {}) -> Dictionary:
	return {
		"name": "plugin_runtime_reload_request_service_contracts",
		"success": false,
		"error": message,
		"details": details
	}
