@tool
extends RefCounted

const PluginDockLifecycleService = preload("res://addons/godot_dotnet_mcp/plugin/plugin_dock_lifecycle_service.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")

const DEFAULT_DOCK_SCENE_PATH := "res://addons/godot_dotnet_mcp/ui/mcp_dock.tscn"
const DEFAULT_DOCK_SCRIPT_PATH := "res://addons/godot_dotnet_mcp/ui/mcp_dock.gd"

var _dock_lifecycle = PluginDockLifecycleService.new()


func create_plugin_dock(
	plugin,
	current_dock,
	action_router,
	dock_slot: int,
	dock_scene_path: String = DEFAULT_DOCK_SCENE_PATH,
	dock_script_path: String = DEFAULT_DOCK_SCRIPT_PATH,
	load_packed_scene: Callable = Callable()
) -> Dictionary:
	return _dock_lifecycle.create_plugin_dock(
		plugin,
		current_dock,
		dock_slot,
		dock_scene_path,
		dock_script_path,
		load_packed_scene,
		Callable(self, "_wire_plugin_dock_signals").bind(action_router, dock_script_path)
	)


func remove_plugin_dock(plugin, current_dock, dock_script_path: String = DEFAULT_DOCK_SCRIPT_PATH) -> Dictionary:
	return _dock_lifecycle.remove_plugin_dock(plugin, current_dock, dock_script_path)


func recreate_plugin_dock(
	plugin,
	current_dock,
	action_router,
	dock_slot: int,
	dock_scene_path: String = DEFAULT_DOCK_SCENE_PATH,
	dock_script_path: String = DEFAULT_DOCK_SCRIPT_PATH,
	load_packed_scene: Callable = Callable()
) -> Dictionary:
	return _dock_lifecycle.recreate_plugin_dock(
		plugin,
		current_dock,
		dock_slot,
		dock_scene_path,
		dock_script_path,
		load_packed_scene,
		Callable(self, "_wire_plugin_dock_signals").bind(action_router, dock_script_path)
	)


func count_plugin_dock_instances(plugin, dock_script_path: String = DEFAULT_DOCK_SCRIPT_PATH) -> int:
	return _dock_lifecycle.count_plugin_dock_instances(plugin, dock_script_path)


func build_dock_signal_bindings(action_router) -> Array[Dictionary]:
	if action_router != null and action_router.has_method("build_dock_signal_bindings"):
		var bindings = action_router.build_dock_signal_bindings()
		if bindings is Array:
			return bindings
	return []


func ensure_plugin_client_executable_dialog(plugin, current_dialog, file_selected_callback: Callable):
	if current_dialog != null and is_instance_valid(current_dialog):
		return current_dialog
	var base_control = _resolve_base_control(plugin)
	return ensure_client_executable_dialog(current_dialog, base_control, file_selected_callback)


func capture_focus_snapshot(dock, fallback_tab: int) -> Dictionary:
	if dock != null and is_instance_valid(dock) and dock.has_method("capture_focus_snapshot"):
		return dock.capture_focus_snapshot()
	return {"tab_index": fallback_tab, "focus_path": ""}


func restore_focus_snapshot(dock, snapshot: Dictionary) -> void:
	if dock == null or not is_instance_valid(dock):
		return
	if dock.has_method("activate_host_dock_tab"):
		dock.activate_host_dock_tab()
	if dock.has_method("restore_focus_snapshot"):
		dock.restore_focus_snapshot(snapshot)


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


func wire_dock_signals(dock, signal_bindings: Array[Dictionary], operation_id: String, record_self_incident: Callable, dock_script_path: String) -> bool:
	if dock == null or not is_instance_valid(dock):
		_record_incident(record_self_incident, "Dock signal wiring was requested before the dock instance was ready", dock_script_path, operation_id, "Inspect dock creation order.")
		return false

	for binding in signal_bindings:
		var signal_name := str(binding.get("signal", ""))
		var target_callable: Callable = binding.get("callable", Callable())
		if signal_name.is_empty() or not target_callable.is_valid():
			continue
		if not dock.has_signal(signal_name):
			_record_incident(record_self_incident, "Dock signal is missing: %s" % signal_name, dock_script_path, operation_id, "Inspect the dock script signal declarations.")
			return false
		if dock.is_connected(signal_name, target_callable):
			continue
		var error = dock.connect(signal_name, target_callable)
		if error != OK:
			_record_incident(
				record_self_incident,
				"Dock signal failed to connect: %s" % signal_name,
				dock_script_path,
				operation_id,
				"Inspect the dock script signal declarations and connection target.",
				{"error_code": error}
			)
			return false

	return true


func _wire_plugin_dock_signals(dock, operation_id: String, action_router, dock_script_path: String) -> bool:
	return wire_dock_signals(
		dock,
		build_dock_signal_bindings(action_router),
		operation_id,
		Callable(self, "_record_plugin_incident"),
		dock_script_path
	)


func _resolve_base_control(plugin) -> Control:
	return _dock_lifecycle.resolve_base_control(plugin)


func _record_plugin_incident(
	severity: String,
	category: String,
	code: String,
	message: String,
	component: String,
	phase: String,
	file_path: String = "",
	line = "",
	operation_id: String = "",
	recoverable: bool = true,
	suggested_action: String = "",
	context: Dictionary = {}
) -> void:
	PluginSelfDiagnosticStore.record_incident(
		severity,
		category,
		code,
		message,
		component,
		phase,
		file_path,
		line,
		operation_id,
		recoverable,
		suggested_action,
		context
	)


func _record_incident(record_self_incident: Callable, message: String, resource_path: String, operation_id: String, resolution_hint: String, extra_context: Dictionary = {}) -> void:
	if not record_self_incident.is_valid():
		return
	record_self_incident.call(
		"error",
		"ui_binding_error",
		"dock_signal_binding_failed",
		message,
		"plugin",
		"_wire_dock_signals",
		resource_path,
		"",
		operation_id,
		true,
		resolution_hint,
		extra_context
	)
