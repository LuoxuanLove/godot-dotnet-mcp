extends RefCounted

const PluginDockCoordinator = preload("res://addons/godot_dotnet_mcp/plugin/plugin_dock_coordinator.gd")

var _dock: FakeDock = null
var _base_control: Control = null


class FakeDock extends Control:
	signal start_requested
	signal copy_requested


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

	return {
		"name": "plugin_dock_coordinator_contracts",
		"success": true,
		"error": "",
		"details": {
			"incident_count": recorder.incidents.size(),
			"dialog_filter_count": dialog.filters.size()
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	if _dock != null and is_instance_valid(_dock):
		_dock.free()
	_dock = null
	if _base_control != null and is_instance_valid(_base_control):
		_base_control.free()
	_base_control = null


func _failure(message: String) -> Dictionary:
	return {
		"name": "plugin_dock_coordinator_contracts",
		"success": false,
		"error": message
	}
