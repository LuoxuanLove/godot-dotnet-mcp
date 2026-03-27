@tool
extends RefCounted

const UserToolWatchService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_watch_service.gd")
const CentralServerAttachServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/central_server_attach_service.gd")
const CentralServerProcessServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/central_server_process_service.gd")
const MCPEditorDebuggerBridge = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_editor_debugger_bridge.gd")
const MCPRuntimeDebugStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_debug_store.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")
const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")


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


func ensure_runtime_bridge_autoload(plugin, autoload_name: String, autoload_path: String) -> void:
	var operation = PluginSelfDiagnosticStore.begin_operation("runtime_bridge_autoload", "_ensure_runtime_bridge_autoload")
	if not ResourceLoader.exists(autoload_path):
		MCPRuntimeDebugStore.set_bridge_status(false, autoload_name, autoload_path, "Runtime bridge script missing")
		push_error("[Godot MCP] Runtime bridge autoload script not found: %s" % autoload_path)
		MCPDebugBuffer.record("error", "plugin", "Runtime bridge script not found: %s" % autoload_path)
		_record_incident(
			"error",
			"resource_missing",
			"runtime_bridge_script_missing",
			"Runtime bridge autoload script not found",
			"plugin",
			"_ensure_runtime_bridge_autoload",
			autoload_path,
			str(operation.get("operation_id", "")),
			"Verify that the runtime bridge script exists and is enabled."
		)
		_finish_operation(operation, false, "plugin", "_ensure_runtime_bridge_autoload")
		return
	var setting_key := "autoload/%s" % autoload_name
	var current_path := str(ProjectSettings.get_setting(setting_key, ""))
	if is_runtime_bridge_autoload_path(autoload_path, current_path):
		MCPRuntimeDebugStore.set_bridge_status(true, autoload_name, autoload_path, "Runtime bridge autoload already installed")
		_finish_operation(operation, true, "plugin", "_ensure_runtime_bridge_autoload")
		return
	if not current_path.is_empty():
		MCPRuntimeDebugStore.set_bridge_status(false, autoload_name, current_path, "Autoload name is occupied by another script")
		push_warning("[Godot MCP] Runtime bridge autoload name is already used: %s" % current_path)
		MCPDebugBuffer.record("warning", "plugin", "Runtime bridge autoload name conflict: %s" % current_path)
		_record_incident(
			"warning",
			"autoload_conflict",
			"autoload_name_occupied",
			"Runtime bridge autoload name is already occupied",
			"plugin",
			"_ensure_runtime_bridge_autoload",
			current_path,
			str(operation.get("operation_id", "")),
			"Resolve the conflicting autoload entry before enabling the runtime bridge.",
			{"setting_key": setting_key}
		)
		_finish_operation(operation, false, "plugin", "_ensure_runtime_bridge_autoload")
		return
	_clear_runtime_bridge_root_instance(plugin, autoload_name)
	if plugin != null and plugin.has_method("add_autoload_singleton"):
		plugin.add_autoload_singleton(autoload_name, autoload_path)
	ProjectSettings.save()
	MCPRuntimeDebugStore.set_bridge_status(true, autoload_name, autoload_path, "Runtime bridge autoload installed")
	_record_runtime_bridge_stale_instance(plugin, autoload_name, autoload_path, "_ensure_runtime_bridge_autoload", str(operation.get("operation_id", "")))
	_finish_operation(operation, true, "plugin", "_ensure_runtime_bridge_autoload")
	MCPDebugBuffer.record("info", "plugin", "Runtime bridge autoload registered")


func is_runtime_bridge_autoload_path(autoload_path: String, setting_value: String) -> bool:
	var normalized := setting_value.trim_prefix("*")
	if normalized == autoload_path:
		return true
	if normalized.is_empty() or not ResourceLoader.exists(normalized):
		return false
	var resource = ResourceLoader.load(normalized)
	return resource != null and str(resource.resource_path) == autoload_path


func has_runtime_bridge_root_instance(plugin, autoload_name: String) -> bool:
	var tree = plugin.get_tree() if plugin != null and plugin.has_method("get_tree") else null
	if tree == null or tree.root == null:
		return false
	var runtime_bridge = tree.root.get_node_or_null(NodePath(autoload_name))
	return runtime_bridge != null and is_instance_valid(runtime_bridge)


func install_editor_debugger_bridge(plugin, current_bridge, create_bridge: Callable = Callable()):
	var operation = PluginSelfDiagnosticStore.begin_operation("install_editor_debugger_bridge", "_install_editor_debugger_bridge")
	if current_bridge != null:
		_finish_operation(operation, true, "plugin", "_install_editor_debugger_bridge")
		return current_bridge
	var bridge = create_bridge.call() if create_bridge.is_valid() else MCPEditorDebuggerBridge.new()
	if bridge == null:
		_record_incident(
			"error",
			"lifecycle_error",
			"editor_debugger_bridge_create_failed",
			"Failed to instantiate the editor debugger bridge",
			"plugin",
			"_install_editor_debugger_bridge",
			"",
			str(operation.get("operation_id", "")),
			"Inspect the editor debugger bridge script and plugin lifecycle output."
		)
		_finish_operation(operation, false, "plugin", "_install_editor_debugger_bridge")
		return current_bridge
	if plugin != null and plugin.has_method("add_debugger_plugin"):
		plugin.add_debugger_plugin(bridge)
	_finish_operation(operation, true, "plugin", "_install_editor_debugger_bridge")
	return bridge


func uninstall_editor_debugger_bridge(plugin, current_bridge):
	var operation = PluginSelfDiagnosticStore.begin_operation("uninstall_editor_debugger_bridge", "_uninstall_editor_debugger_bridge")
	if current_bridge == null:
		_finish_operation(operation, true, "plugin", "_uninstall_editor_debugger_bridge")
		return null
	if plugin != null and plugin.has_method("remove_debugger_plugin"):
		plugin.remove_debugger_plugin(current_bridge)
	current_bridge.set_script(null)
	_finish_operation(operation, true, "plugin", "_uninstall_editor_debugger_bridge")
	return null


func _clear_runtime_bridge_root_instance(plugin, autoload_name: String) -> void:
	var tree = plugin.get_tree() if plugin != null and plugin.has_method("get_tree") else null
	if tree == null or tree.root == null:
		return
	var runtime_bridge = tree.root.get_node_or_null(NodePath(autoload_name))
	if runtime_bridge == null or not is_instance_valid(runtime_bridge):
		return
	if runtime_bridge.get_parent() != null:
		runtime_bridge.get_parent().remove_child(runtime_bridge)
	runtime_bridge.set_script(null)
	runtime_bridge.free()


func _record_runtime_bridge_stale_instance(plugin, autoload_name: String, autoload_path: String, phase: String, operation_id: String) -> void:
	var setting_key := "autoload/%s" % autoload_name
	var current_path := str(ProjectSettings.get_setting(setting_key, ""))
	var root_present = has_runtime_bridge_root_instance(plugin, autoload_name)
	var autoload_owned = is_runtime_bridge_autoload_path(autoload_path, current_path)
	if root_present and not autoload_owned:
		_record_incident(
			"warning",
			"autoload_conflict",
			"runtime_bridge_stale_instance",
			"Runtime bridge root instance is still present after autoload ownership changed",
			"plugin",
			phase,
			autoload_path,
			operation_id,
			"Inspect autoload cleanup and editor reload ordering.",
			{"current_path": current_path}
		)


func _record_incident(severity: String, category: String, code: String, message: String, component: String, phase: String, file_path: String, operation_id: String, suggested_action: String, context: Dictionary = {}) -> void:
	PluginSelfDiagnosticStore.record_incident(
		severity,
		category,
		code,
		message,
		component,
		phase,
		file_path,
		"",
		operation_id,
		true,
		suggested_action,
		context
	)


func _finish_operation(operation: Dictionary, success: bool, component: String, phase: String, anomaly_codes: Array = [], context: Dictionary = {}) -> void:
	if operation.is_empty():
		return
	var merged_context = context.duplicate(true)
	merged_context["component"] = component
	merged_context["phase"] = phase
	var finished = PluginSelfDiagnosticStore.end_operation(str(operation.get("operation_id", "")), success, anomaly_codes, merged_context)
	PluginSelfDiagnosticStore.record_slow_operation(finished, component, phase)
