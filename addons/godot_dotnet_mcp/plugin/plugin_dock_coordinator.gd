@tool
extends RefCounted
class_name PluginDockCoordinator

const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")

const DEFAULT_DOCK_SCRIPT_PATH := "res://addons/godot_dotnet_mcp/ui/mcp_dock.gd"
const DOCK_VISIBLE_NAME := "MCP"
const DOCK_LEGACY_NAME := "MCPDock"


func wire_dock_signals(dock: Control, bindings: Array[Dictionary], operation_id: String, incident_sink: Callable, dock_script_path: String) -> bool:
	if dock == null or not is_instance_valid(dock):
		_record_incident(incident_sink, "error", "ui_binding_error", "dock_signal_binding_failed", "Dock instance is unavailable", operation_id, dock_script_path, "", {})
		return false

	var connected := true
	for binding in bindings:
		if not (binding is Dictionary):
			connected = false
			continue
		var signal_name = str(binding.get("signal", "")).strip_edges()
		var callable: Callable = binding.get("callable", Callable())
		if signal_name.is_empty() or not callable.is_valid():
			_record_incident(incident_sink, "error", "ui_binding_error", "dock_signal_binding_failed", "Dock signal binding is invalid", operation_id, dock_script_path, signal_name, {"binding": binding.duplicate(true)})
			connected = false
			continue
		if not dock.has_signal(signal_name):
			_record_incident(incident_sink, "error", "ui_binding_error", "dock_signal_binding_failed", "Dock signal is missing: %s" % signal_name, operation_id, dock_script_path, signal_name, {})
			connected = false
			continue
		if dock.is_connected(signal_name, callable):
			continue
		var error = dock.connect(signal_name, callable)
		if error != OK:
			_record_incident(incident_sink, "error", "ui_binding_error", "dock_signal_binding_failed", "Dock signal failed to connect: %s" % signal_name, operation_id, dock_script_path, signal_name, {"error_code": error})
			connected = false
	return connected


func build_dock_signal_bindings(action_router) -> Array[Dictionary]:
	if action_router != null and action_router.has_method("build_dock_signal_bindings"):
		var bindings = action_router.build_dock_signal_bindings()
		if bindings is Array:
			return bindings
	return []


func ensure_client_executable_dialog(dialog, base_control: Control, _reset_callback: Callable) -> FileDialog:
	if dialog != null and is_instance_valid(dialog):
		return dialog
	var client_dialog := FileDialog.new()
	client_dialog.name = "ClientExecutableDialog"
	client_dialog.access = FileDialog.ACCESS_FILESYSTEM
	client_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	client_dialog.title = "Select Runtime Executable"
	client_dialog.filters = PackedStringArray(["*.exe ; Executable", "*.cmd ; Command Script", "*.bat ; Batch Script", "* ; All Files"])
	if base_control != null:
		base_control.add_child(client_dialog)
	return client_dialog


func remove_client_executable_dialog(dialog, reset_callback: Callable):
	if dialog != null and is_instance_valid(dialog):
		var parent = dialog.get_parent()
		if parent != null:
			parent.remove_child(dialog)
		dialog.queue_free()
	if reset_callback.is_valid():
		reset_callback.call()
	return null


func capture_focus_snapshot(dock, fallback_tab_index: int) -> Dictionary:
	if dock != null and is_instance_valid(dock) and dock.has_method("capture_focus_snapshot"):
		var snapshot = dock.capture_focus_snapshot()
		if snapshot is Dictionary:
			return snapshot
	return {"tab_index": fallback_tab_index, "focus_path": ""}


func create_plugin_dock(plugin, current_dock, incident_sink: Callable, dock_slot: int, scene_path: String, dock_script_path: String, load_scene_callable: Callable) -> Dictionary:
	if current_dock != null and is_instance_valid(current_dock):
		remove_plugin_dock(plugin, current_dock, dock_script_path)

	var base_control = _get_base_control(plugin)
	if base_control == null:
		_record_incident(incident_sink, "error", "ui_binding_error", "dock_scene_load_failed", "Editor base control is unavailable", "create_plugin_dock", dock_script_path, scene_path, {"dock_slot": dock_slot})
		return {"success": false, "error": "Editor base control is unavailable", "dock": null}

	if not load_scene_callable.is_valid():
		_record_incident(incident_sink, "error", "resource_missing", "dock_scene_load_failed", "Dock scene loader is unavailable", "create_plugin_dock", dock_script_path, scene_path, {"dock_slot": dock_slot})
		return {"success": false, "error": "Dock scene loader is unavailable", "dock": null}

	var dock_scene = load_scene_callable.call(scene_path)
	if not (dock_scene is PackedScene):
		_record_incident(incident_sink, "error", "resource_missing", "dock_scene_load_failed", "Dock scene load returned an invalid resource", "create_plugin_dock", dock_script_path, scene_path, {"dock_slot": dock_slot})
		return {"success": false, "error": "Dock scene load returned an invalid resource", "dock": null}

	var dock = (dock_scene as PackedScene).instantiate()
	if dock == null:
		_record_incident(incident_sink, "error", "resource_missing", "dock_scene_load_failed", "Dock scene instantiation returned null", "create_plugin_dock", dock_script_path, scene_path, {"dock_slot": dock_slot})
		return {"success": false, "error": "Dock scene instantiation returned null", "dock": null}

	dock.name = DOCK_VISIBLE_NAME
	if plugin != null and plugin.has_method("add_control_to_dock"):
		plugin.add_control_to_dock(dock_slot, dock)
	else:
		base_control.add_child(dock)

	return {"success": true, "dock": dock}


func recreate_plugin_dock(plugin, current_dock, incident_sink: Callable, dock_slot: int, scene_path: String, dock_script_path: String, load_scene_callable: Callable) -> Dictionary:
	remove_plugin_dock(plugin, current_dock, dock_script_path)
	return create_plugin_dock(plugin, null, incident_sink, dock_slot, scene_path, dock_script_path, load_scene_callable)


func remove_plugin_dock(plugin, dock, dock_script_path: String) -> Dictionary:
	if dock != null and is_instance_valid(dock):
		if plugin != null and plugin.has_method("remove_control_from_docks"):
			plugin.remove_control_from_docks(dock)
		var parent = dock.get_parent()
		if parent != null:
			parent.remove_child(dock)
		dock.set_script(null)
		dock.queue_free()
	return {"success": true, "dock": null, "dock_script_path": dock_script_path}


func remove_stale_plugin_docks(plugin, current_dock, incident_sink: Callable, dock_script_path: String) -> Dictionary:
	var base_control = _get_base_control(plugin)
	if base_control == null:
		return {"success": true, "removed_count": 0}

	var removed_count := 0
	for child in base_control.find_children("*", "Control", true, false):
		if child == null or not is_instance_valid(child):
			continue
		if child == current_dock:
			continue
		var script_path := ""
		var script = child.get_script()
		if script != null:
			script_path = str(script.resource_path)
		if not _is_plugin_dock_name(str(child.name)) and script_path != dock_script_path:
			continue
		if child.get_parent() != null:
			if plugin != null and plugin.has_method("remove_control_from_docks"):
				plugin.remove_control_from_docks(child)
			child.get_parent().remove_child(child)
		child.set_script(null)
		child.queue_free()
		removed_count += 1
		_record_incident(incident_sink, "debug", "reload_conflict", "stale_dock_removed", "Removed stale dock instance", "remove_stale_plugin_docks", dock_script_path, script_path, {"instance_id": child.get_instance_id()})

	return {"success": true, "removed_count": removed_count}


func count_plugin_dock_instances(plugin, dock_script_path: String) -> int:
	var base_control = _get_base_control(plugin)
	if base_control == null:
		return 0
	var count := 0
	for child in base_control.find_children("*", "Control", true, false):
		if child == null or not is_instance_valid(child):
			continue
		var script_path := ""
		var script = child.get_script()
		if script != null:
			script_path = str(script.resource_path)
		if _is_plugin_dock_name(str(child.name)) or script_path == dock_script_path:
			count += 1
	return count


func _is_plugin_dock_name(dock_name: String) -> bool:
	return dock_name == DOCK_VISIBLE_NAME or dock_name == DOCK_LEGACY_NAME


func _get_base_control(plugin):
	if plugin == null:
		return null
	if plugin.has_method("get_editor_interface"):
		var editor_interface = plugin.get_editor_interface()
		if editor_interface != null and editor_interface.has_method("get_base_control"):
			return editor_interface.get_base_control()
	return null


func _record_incident(incident_sink: Callable, severity: String, category: String, code: String, message: String, phase: String, resource_path: String, related_path: String, extra_context: Dictionary) -> void:
	if incident_sink.is_valid():
		incident_sink.call(severity, category, code, message, "plugin", phase, resource_path, related_path, "", true, message, extra_context)
		return
	PluginSelfDiagnosticStore.record_incident(
		severity,
		category,
		code,
		message,
		"plugin",
		phase,
		resource_path,
		related_path,
		"",
		true,
		message,
		extra_context
	)
