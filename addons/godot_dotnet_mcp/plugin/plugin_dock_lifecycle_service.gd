@tool
extends RefCounted

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")


func create_plugin_dock(
	plugin,
	current_dock,
	dock_slot: int,
	dock_scene_path: String,
	dock_script_path: String,
	load_packed_scene: Callable,
	wire_dock_signals: Callable
) -> Dictionary:
	return _run_plugin_dock_operation(
		"create_dock",
		"_create_dock",
		plugin,
		current_dock,
		dock_slot,
		dock_scene_path,
		dock_script_path,
		load_packed_scene,
		wire_dock_signals
	)


func recreate_plugin_dock(
	plugin,
	current_dock,
	dock_slot: int,
	dock_scene_path: String,
	dock_script_path: String,
	load_packed_scene: Callable,
	wire_dock_signals: Callable
) -> Dictionary:
	return _run_plugin_dock_operation(
		"recreate_dock",
		"_recreate_dock",
		plugin,
		current_dock,
		dock_slot,
		dock_scene_path,
		dock_script_path,
		load_packed_scene,
		wire_dock_signals
	)


func remove_plugin_dock(plugin, current_dock, dock_script_path: String) -> Dictionary:
	var operation = PluginSelfDiagnosticStore.begin_operation("remove_dock", "_remove_dock")
	var operation_id := str(operation.get("operation_id", ""))
	_detach_and_free_dock(plugin, current_dock)
	_warn_if_duplicate_docks(
		plugin,
		dock_script_path,
		operation_id,
		"_remove_dock",
		"Dock instances remain after dock removal",
		{"remaining_dock_instances": count_plugin_dock_instances(plugin, dock_script_path)}
	)
	_finish_operation(operation, true, "_remove_dock")
	return {"dock": null}


func count_plugin_dock_instances(plugin, dock_script_path: String) -> int:
	var base_control = _resolve_base_control(plugin)
	if base_control == null:
		return 0

	var count := 0
	for child in base_control.find_children("*", "Control", true, false):
		if _is_matching_dock(child, dock_script_path):
			count += 1
	return count


func resolve_base_control(plugin) -> Control:
	return _resolve_base_control(plugin)


func _run_plugin_dock_operation(
	operation_name: String,
	phase_name: String,
	plugin,
	current_dock,
	dock_slot: int,
	dock_scene_path: String,
	dock_script_path: String,
	load_packed_scene: Callable,
	wire_dock_signals: Callable
) -> Dictionary:
	var operation = PluginSelfDiagnosticStore.begin_operation(operation_name, phase_name)
	var operation_id := str(operation.get("operation_id", ""))

	_detach_and_free_dock(plugin, current_dock)
	_remove_stale_docks(plugin, dock_script_path, operation_id)

	var result := _create_dock_instance(
		plugin,
		dock_slot,
		dock_scene_path,
		dock_script_path,
		operation_id,
		load_packed_scene if load_packed_scene.is_valid() else Callable(self, "_load_packed_scene"),
		wire_dock_signals
	)
	if not bool(result.get("success", false)):
		push_error("[Godot MCP] Failed to load dock scene: %s" % dock_scene_path)
		MCPDebugBuffer.record("error", "plugin", "Failed to load dock scene: %s" % dock_scene_path)

	_finish_operation(operation, bool(result.get("success", false)), phase_name)
	return result


func _create_dock_instance(
	plugin,
	dock_slot: int,
	dock_scene_path: String,
	dock_script_path: String,
	operation_id: String,
	load_packed_scene: Callable,
	wire_dock_signals: Callable
) -> Dictionary:
	if plugin == null or not load_packed_scene.is_valid():
		return {"success": false, "dock": null}

	var dock_scene = load_packed_scene.call(dock_scene_path) as PackedScene
	if dock_scene == null:
		_record_incident(
			"error",
			"resource_missing",
			"dock_scene_load_failed",
			"Failed to load dock scene",
			"_create_dock",
			dock_scene_path,
			operation_id,
			"Inspect the dock scene resource and script dependencies."
		)
		return {"success": false, "dock": null}

	var dock = dock_scene.instantiate()
	if dock == null:
		_record_incident(
			"error",
			"resource_missing",
			"dock_scene_load_failed",
			"Dock scene instantiation returned null",
			"_create_dock",
			dock_scene_path,
			operation_id,
			"Inspect the dock scene resource and its script."
		)
		return {"success": false, "dock": null}

	if wire_dock_signals.is_valid() and not bool(wire_dock_signals.call(dock, operation_id)):
		if is_instance_valid(dock):
			dock.queue_free()
		return {"success": false, "dock": null}

	plugin.add_control_to_dock(dock_slot, dock)
	_warn_if_duplicate_docks(
		plugin,
		dock_script_path,
		operation_id,
		"_create_dock",
		"More than one MCP dock instance is present after dock creation",
		{"dock_count": count_plugin_dock_instances(plugin, dock_script_path)},
		"dock_duplicate_instance"
	)
	return {"success": true, "dock": dock}


func _remove_stale_docks(plugin, dock_script_path: String, operation_id: String) -> void:
	var base_control = _resolve_base_control(plugin)
	if base_control == null:
		return

	for child in base_control.find_children("*", "Control", true, false):
		if not _is_matching_dock(child, dock_script_path):
			continue
		_detach_and_free_dock(plugin, child)
		MCPDebugBuffer.record("debug", "plugin", "Removed stale dock instance: %s" % child.get_instance_id())

	_warn_if_duplicate_docks(
		plugin,
		dock_script_path,
		operation_id,
		"_remove_stale_docks",
		"More than one MCP dock instance remains after stale-dock cleanup",
		{"dock_count": count_plugin_dock_instances(plugin, dock_script_path)},
		"dock_duplicate_instance",
		"Inspect stale dock cleanup and editor plugin reload ordering."
	)


func _warn_if_duplicate_docks(
	plugin,
	dock_script_path: String,
	operation_id: String,
	phase: String,
	message: String,
	context: Dictionary,
	code: String = "instance_cleanup_incomplete",
	suggested_action: String = "Inspect dock cleanup and plugin reload ordering."
) -> void:
	var dock_count = int(context.get("dock_count", context.get("remaining_dock_instances", 0)))
	if dock_count <= 0:
		dock_count = count_plugin_dock_instances(plugin, dock_script_path)
	if dock_count <= 0:
		return
	if phase == "_remove_dock" and dock_count == 0:
		return
	if phase != "_remove_dock" and dock_count <= 1:
		return
	_record_incident(
		"warning",
		"reload_conflict",
		code,
		message,
		phase,
		dock_script_path,
		operation_id,
		suggested_action,
		context
	)


func _detach_and_free_dock(plugin, dock) -> void:
	if dock == null or not is_instance_valid(dock):
		return
	var dock_parent = dock.get_parent()
	if dock_parent != null:
		if plugin != null and plugin.has_method("remove_control_from_docks"):
			plugin.remove_control_from_docks(dock)
			dock_parent = dock.get_parent()
		if dock_parent != null:
			dock_parent.remove_child(dock)
	dock.set_script(null)
	dock.free()


func _resolve_base_control(plugin) -> Control:
	if plugin == null or not plugin.has_method("get_editor_interface"):
		return null
	var editor_interface = plugin.get_editor_interface()
	if editor_interface == null:
		return null
	return editor_interface.get_base_control()


func _is_matching_dock(control, dock_script_path: String) -> bool:
	if control == null or not is_instance_valid(control):
		return false
	var script_path := ""
	var script = control.get_script()
	if script != null:
		script_path = str(script.resource_path)
	return control.name == "MCPDock" or script_path == dock_script_path


func _load_packed_scene(path: String) -> PackedScene:
	return ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE) as PackedScene


func _finish_operation(operation: Dictionary, success: bool, phase: String) -> void:
	if operation.is_empty():
		return
	var finished = PluginSelfDiagnosticStore.end_operation(
		str(operation.get("operation_id", "")),
		success,
		[],
		{
			"component": "plugin",
			"phase": phase
		}
	)
	PluginSelfDiagnosticStore.record_slow_operation(finished, "plugin", phase)


func _record_incident(
	severity: String,
	category: String,
	code: String,
	message: String,
	phase: String,
	resource_path: String,
	operation_id: String,
	suggested_action: String,
	context: Dictionary = {}
) -> void:
	PluginSelfDiagnosticStore.record_incident(
		severity,
		category,
		code,
		message,
		"plugin",
		phase,
		resource_path,
		"",
		operation_id,
		true,
		suggested_action,
		context
	)
