extends RefCounted

const PluginDockCoordinator = preload("res://addons/godot_dotnet_mcp/plugin/plugin_dock_coordinator.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")

var _dock: FakeDock = null
var _base_control: Control = null
var _plugin = null
var _packed_scene: PackedScene = null


class FakeDock extends Control:
	signal start_requested
	signal copy_requested


class FakeEditorInterface extends RefCounted:
	var base_control: Control = null

	func _init(control: Control) -> void:
		base_control = control

	func get_base_control() -> Control:
		return base_control


class FakePlugin extends RefCounted:
	var base_control: Control = null
	var editor_interface = null
	var added_docks := 0
	var removed_docks := 0

	func _init(control: Control) -> void:
		base_control = control
		editor_interface = FakeEditorInterface.new(control)

	func get_editor_interface():
		return editor_interface

	func add_control_to_dock(_slot: int, dock: Control) -> void:
		added_docks += 1
		base_control.add_child(dock)

	func remove_control_from_docks(_dock: Control) -> void:
		removed_docks += 1


class Recorder extends RefCounted:
	var start_count := 0
	var copy_count := 0
	var reset_count := 0
	var incidents: Array[Dictionary] = []

	func on_start_requested() -> void:
		start_count += 1

	func on_copy_requested() -> void:
		copy_count += 1

	func on_reset() -> void:
		reset_count += 1

	func record_incident(
		severity: String,
		category: String,
		code: String,
		message: String,
		component: String,
		phase: String,
		resource_path: String,
		related_path: String,
		operation_id: String,
		visible: bool,
		resolution_hint: String,
		extra_context: Dictionary = {}
	) -> void:
		incidents.append({
			"severity": severity,
			"category": category,
			"code": code,
			"message": message,
			"component": component,
			"phase": phase,
			"resource_path": resource_path,
			"related_path": related_path,
			"operation_id": operation_id,
			"visible": visible,
			"resolution_hint": resolution_hint,
			"extra_context": extra_context
		})


func run_case(_tree: SceneTree) -> Dictionary:
	var coordinator = PluginDockCoordinator.new()
	var recorder = Recorder.new()
	PluginSelfDiagnosticStore.clear()
	_dock = FakeDock.new()
	var connected = coordinator.wire_dock_signals(
		_dock,
		[
			{"signal": "start_requested", "callable": Callable(recorder, "on_start_requested")},
			{"signal": "copy_requested", "callable": Callable(recorder, "on_copy_requested")}
		],
		"dock_contract_case",
		Callable(recorder, "record_incident"),
		"res://addons/godot_dotnet_mcp/ui/mcp_dock.gd"
	)
	if not connected:
		return _failure("Dock coordinator should connect declared signals.")
	_dock.emit_signal("start_requested")
	_dock.emit_signal("copy_requested")
	if recorder.start_count != 1 or recorder.copy_count != 1:
		return _failure("Dock coordinator did not connect signal callbacks correctly.")

	var missing_signal_result = coordinator.wire_dock_signals(
		_dock,
		[
			{"signal": "missing_signal", "callable": Callable(recorder, "on_start_requested")}
		],
		"dock_contract_missing",
		Callable(recorder, "record_incident"),
		"res://addons/godot_dotnet_mcp/ui/mcp_dock.gd"
	)
	if missing_signal_result:
		return _failure("Dock coordinator should reject missing dock signals.")
	if recorder.incidents.is_empty():
		return _failure("Dock coordinator should record an incident for missing signals.")

	_base_control = Control.new()
	var dialog = coordinator.ensure_client_executable_dialog(null, _base_control, Callable())
	if dialog == null or dialog.get_parent() != _base_control:
		return _failure("Dock coordinator should create and parent the client executable dialog.")
	if dialog.name != "ClientExecutableDialog":
		return _failure("Dock coordinator should preserve the dialog name.")
	var removed = coordinator.remove_client_executable_dialog(dialog, Callable(recorder, "on_reset"))
	if removed != null:
		return _failure("Dock coordinator should clear the dialog reference on remove.")
	if recorder.reset_count != 1:
		return _failure("Dock coordinator should reset the pending client path request on remove.")

	var bindings: Array[Dictionary] = coordinator.build_dock_signal_bindings(recorder)
	if not bindings.is_empty():
		return _failure("Dock coordinator should return an empty binding list when the action router cannot build bindings.")

	var focus_snapshot = coordinator.capture_focus_snapshot(null, 2)
	if int(focus_snapshot.get("tab_index", -1)) != 2:
		return _failure("Dock coordinator should preserve the fallback tab index when no dock is available.")

	_plugin = FakePlugin.new(_base_control)
	_packed_scene = PackedScene.new()
	var dock_template := FakeDock.new()
	dock_template.name = "MCPDock"
	var pack_error := _packed_scene.pack(dock_template)
	dock_template.free()
	if pack_error != OK:
		return _failure("Dock coordinator contract setup failed to pack a fake dock scene.")

	var create_result = coordinator.create_plugin_dock(
		_plugin,
		null,
		recorder,
		0,
		"res://tests/fake_mcp_dock.tscn",
		PluginDockCoordinator.DEFAULT_DOCK_SCRIPT_PATH,
		Callable(self, "_load_fake_dock_scene")
	)
	if not bool(create_result.get("success", false)):
		return _failure("Dock coordinator should create a plugin dock through the high-level API.")
	var created_dock = create_result.get("dock", null)
	if created_dock == null or created_dock.get_parent() != _base_control:
		return _failure("Created plugin dock should be parented under the editor base control.")
	if coordinator.count_plugin_dock_instances(_plugin, PluginDockCoordinator.DEFAULT_DOCK_SCRIPT_PATH) != 1:
		return _failure("Dock coordinator should count the newly created plugin dock.")

	var recreate_result = coordinator.recreate_plugin_dock(
		_plugin,
		created_dock,
		recorder,
		0,
		"res://tests/fake_mcp_dock.tscn",
		PluginDockCoordinator.DEFAULT_DOCK_SCRIPT_PATH,
		Callable(self, "_load_fake_dock_scene")
	)
	if not bool(recreate_result.get("success", false)):
		return _failure("Dock coordinator should recreate the plugin dock through the high-level API.")
	var recreated_dock = recreate_result.get("dock", null)
	if recreated_dock == null or recreated_dock == created_dock:
		return _failure("Recreated plugin dock should replace the previous dock instance.")

	var remove_result = coordinator.remove_plugin_dock(_plugin, recreated_dock, PluginDockCoordinator.DEFAULT_DOCK_SCRIPT_PATH)
	if remove_result.get("dock", null) != null:
		return _failure("Dock coordinator should clear the dock reference when removing the plugin dock.")
	if coordinator.count_plugin_dock_instances(_plugin, PluginDockCoordinator.DEFAULT_DOCK_SCRIPT_PATH) != 0:
		return _failure("Dock coordinator should report zero live docks after removal.")

	return {
		"name": "plugin_dock_coordinator_contracts",
		"success": true,
		"error": "",
		"details": {
			"incident_count": recorder.incidents.size(),
			"dialog_filter_count": dialog.filters.size(),
			"added_docks": _plugin.added_docks,
			"removed_docks": _plugin.removed_docks
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	PluginSelfDiagnosticStore.clear()
	if _dock != null and is_instance_valid(_dock):
		_dock.free()
	_dock = null
	if _base_control != null and is_instance_valid(_base_control):
		_base_control.free()
	_base_control = null
	_plugin = null
	_packed_scene = null


func _load_fake_dock_scene(_path: String) -> PackedScene:
	return _packed_scene


func _failure(message: String) -> Dictionary:
	return {
		"name": "plugin_dock_coordinator_contracts",
		"success": false,
		"error": message
	}
