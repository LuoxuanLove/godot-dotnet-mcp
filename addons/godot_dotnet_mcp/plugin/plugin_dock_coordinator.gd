@tool
extends RefCounted


func create_dock(context: Dictionary) -> Dictionary:
	var plugin = context.get("plugin", null)
	var dock_scene_path := str(context.get("dock_scene_path", ""))
	var dock_script_path := str(context.get("dock_script_path", ""))
	var dock_slot := int(context.get("dock_slot", 0))
	var operation_id := str(context.get("operation_id", ""))
	var load_packed_scene: Callable = context.get("load_packed_scene", Callable())
	var wire_dock_signals: Callable = context.get("wire_dock_signals", Callable())
	var count_dock_instances: Callable = context.get("count_dock_instances", Callable())
	var record_self_incident: Callable = context.get("record_self_incident", Callable())
	if plugin == null or not load_packed_scene.is_valid():
		return {"success": false, "dock": null}

	var dock_scene = load_packed_scene.call(dock_scene_path)
	if dock_scene == null:
		_record_incident(record_self_incident, "error", "resource_missing", "dock_scene_load_failed", "Failed to load dock scene", "plugin", "_create_dock", dock_scene_path, operation_id, "Inspect the dock scene resource and script dependencies.")
		return {"success": false, "dock": null}

	var dock = dock_scene.instantiate()
	if dock == null:
		_record_incident(record_self_incident, "error", "resource_missing", "dock_scene_load_failed", "Dock scene instantiation returned null", "plugin", "_create_dock", dock_scene_path, operation_id, "Inspect the dock scene resource and its script.")
		return {"success": false, "dock": null}

	if wire_dock_signals.is_valid() and not bool(wire_dock_signals.call(dock, operation_id)):
		if is_instance_valid(dock):
			dock.queue_free()
		return {"success": false, "dock": null}

	plugin.add_control_to_dock(dock_slot, dock)
	var dock_count := int(count_dock_instances.call()) if count_dock_instances.is_valid() else 0
	if dock_count > 1:
		_record_incident(record_self_incident, "warning", "reload_conflict", "dock_duplicate_instance", "More than one MCP dock instance is present after dock creation", "plugin", "_create_dock", dock_script_path, operation_id, "Inspect stale dock cleanup and plugin reload ordering.", {"dock_count": dock_count})

	return {"success": true, "dock": dock}


func remove_dock(context: Dictionary) -> Dictionary:
	var plugin = context.get("plugin", null)
	var dock = context.get("dock", null)
	var dock_script_path := str(context.get("dock_script_path", ""))
	var operation_id := str(context.get("operation_id", ""))
	var count_dock_instances: Callable = context.get("count_dock_instances", Callable())
	var record_self_incident: Callable = context.get("record_self_incident", Callable())

	if dock != null and is_instance_valid(dock):
		if dock.get_parent() != null:
			plugin.remove_control_from_docks(dock)
			dock.get_parent().remove_child(dock)
		dock.set_script(null)
		dock.free()

	var remaining_count := int(count_dock_instances.call()) if count_dock_instances.is_valid() else 0
	if remaining_count > 0:
		_record_incident(record_self_incident, "warning", "reload_conflict", "instance_cleanup_incomplete", "Dock instances remain after dock removal", "plugin", "_remove_dock", dock_script_path, operation_id, "Inspect dock cleanup and plugin reload ordering.", {"remaining_dock_instances": remaining_count})

	return {"dock": null}


func ensure_client_executable_dialog(current_dialog, base_control: Control, file_selected_callback: Callable):
	if current_dialog != null and is_instance_valid(current_dialog):
		return current_dialog
	if base_control == null:
		return current_dialog

	var dialog := FileDialog.new()
	dialog.name = "ClientExecutableDialog"
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray([
		"*.exe ; Executable",
		"*.cmd ; Command Script",
		"*.bat ; Batch Script",
		"* ; All Files"
	])
	if file_selected_callback.is_valid():
		dialog.file_selected.connect(file_selected_callback)
	base_control.add_child(dialog)
	return dialog


func remove_client_executable_dialog(current_dialog, reset_client_path_request: Callable):
	if current_dialog == null:
		return null
	if is_instance_valid(current_dialog):
		current_dialog.queue_free()
	if reset_client_path_request.is_valid():
		reset_client_path_request.call()
	return null


func remove_stale_docks(context: Dictionary) -> void:
	var plugin = context.get("plugin", null)
	var current_dock = context.get("current_dock", null)
	var dock_script_path := str(context.get("dock_script_path", ""))
	var operation_id := str(context.get("operation_id", ""))
	var count_dock_instances: Callable = context.get("count_dock_instances", Callable())
	var record_self_incident: Callable = context.get("record_self_incident", Callable())
	var record_debug: Callable = context.get("record_debug", Callable())
	var editor_interface = plugin.get_editor_interface() if plugin != null else null
	if editor_interface == null:
		return
	var base_control = editor_interface.get_base_control()
	if base_control == null:
		return

	for child in base_control.find_children("*", "Control", true, false):
		if child == null or not is_instance_valid(child):
			continue
		if child == current_dock:
			continue
		var script = child.get_script()
		var script_path := ""
		if script != null:
			script_path = str(script.resource_path)
		if child.name != "MCPDock" and script_path != dock_script_path:
			continue
		if child.get_parent() != null:
			plugin.remove_control_from_docks(child)
			child.get_parent().remove_child(child)
		child.set_script(null)
		child.free()
		if record_debug.is_valid():
			record_debug.call("Removed stale dock instance: %s path=%s" % [child.get_instance_id(), script_path])

	var remaining_count := int(count_dock_instances.call()) if count_dock_instances.is_valid() else 0
	if remaining_count > 1:
		_record_incident(record_self_incident, "warning", "reload_conflict", "dock_duplicate_instance", "More than one MCP dock instance remains after stale-dock cleanup", "plugin", "_remove_stale_docks", dock_script_path, operation_id, "Inspect stale dock cleanup and editor plugin reload ordering.", {"dock_count": remaining_count})


func wire_dock_signals(dock, signal_bindings: Array[Dictionary], operation_id: String, record_self_incident: Callable, dock_script_path: String) -> bool:
	if dock == null or not is_instance_valid(dock):
		_record_incident(record_self_incident, "error", "ui_binding_error", "dock_signal_binding_failed", "Dock signal wiring was requested before the dock instance was ready", "plugin", "_wire_dock_signals", dock_script_path, operation_id, "Inspect dock creation order.")
		return false

	for binding in signal_bindings:
		var signal_name := str(binding.get("signal", ""))
		var target_callable: Callable = binding.get("callable", Callable())
		if signal_name.is_empty() or not target_callable.is_valid():
			continue
		if not dock.has_signal(signal_name):
			_record_incident(record_self_incident, "error", "ui_binding_error", "dock_signal_binding_failed", "Dock signal is missing: %s" % signal_name, "plugin", "_wire_dock_signals", dock_script_path, operation_id, "Inspect the dock script signal declarations.")
			return false
		if dock.is_connected(signal_name, target_callable):
			continue
		var error = dock.connect(signal_name, target_callable)
		if error != OK:
			_record_incident(record_self_incident, "error", "ui_binding_error", "dock_signal_binding_failed", "Dock signal failed to connect: %s" % signal_name, "plugin", "_wire_dock_signals", dock_script_path, operation_id, "Inspect the dock script signal declarations and connection target.", {"error_code": error})
			return false

	return true


func _record_incident(record_self_incident: Callable, severity: String, category: String, code: String, message: String, component: String, phase: String, resource_path: String, operation_id: String, resolution_hint: String, extra_context: Dictionary = {}) -> void:
	if not record_self_incident.is_valid():
		return
	record_self_incident.call(
		severity,
		category,
		code,
		message,
		component,
		phase,
		resource_path,
		"",
		operation_id,
		true,
		resolution_hint,
		extra_context
	)
