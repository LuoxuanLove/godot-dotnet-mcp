extends RefCounted

# {"name": "plugin_runtime_reload_completion_service_contracts"}

const PluginRuntimeReloadCompletionServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_reload_completion_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var source_guard := _verify_plugin_entrypoint_delegates_runtime_reload_completion()
	if not source_guard.is_empty():
		return _failure(source_guard)

	var service = PluginRuntimeReloadCompletionServiceScript.new()
	var state = FakeState.new()
	var original_controller = FakeServerController.new("original")
	var active_controller = original_controller
	var recorder := {
		"calls": [],
		"active_controller": active_controller,
		"dock_generation": 0
	}
	var context := _build_context(state, original_controller, recorder)
	if not service.complete_server_restart(context):
		return _failure("Runtime reload completion service should start the server during restart.")
	if original_controller.calls != ["start:tool_runtime_restart"]:
		return _failure("Runtime reload completion service should use the active controller for restart.", {"calls": original_controller.calls})
	if not (recorder["calls"] as Array).has("refresh_dock"):
		return _failure("Runtime reload completion service should refresh dock after restart.")

	var soft_context := _build_context(state, original_controller, recorder)
	recorder["calls"] = []
	var soft_success := service.complete_soft_reload(soft_context, true, {"tab_index": 2, "focus_path": "Settings"})
	if not soft_success:
		return _failure("Runtime reload completion service should report successful soft reload.")
	var recreated_controller: FakeServerController = recorder.get("active_controller", null)
	if recreated_controller == original_controller or recreated_controller == null:
		return _failure("Runtime reload completion service should reload against a recreated controller.")
	if recreated_controller.calls != ["start:tool_soft_reload"]:
		return _failure("Runtime reload completion service should start the recreated controller when it was running.", {"calls": recreated_controller.calls})
	for expected in ["refresh_service_instances", "recreate_server_controller", "reset_localization", "recreate_dock", "refresh_dock"]:
		if not (recorder["calls"] as Array).has(expected):
			return _failure("Runtime reload completion service should preserve soft reload step: %s" % expected, {"calls": recorder["calls"]})
	if not (recorder["calls"] as Array).has("restore_focus_snapshot:2:dock1"):
		return _failure("Runtime reload completion service should restore focus on the recreated dock after soft reload.", {"calls": recorder["calls"]})

	var full_context := _build_context(state, original_controller, recorder)
	recorder["calls"] = []
	var full_success := service.complete_full_reload(full_context, false, {"tab_index": 5, "focus_path": "Update"})
	if not full_success:
		return _failure("Runtime reload completion service should report successful full reload.")
	var full_controller: FakeServerController = recorder.get("active_controller", null)
	if full_controller.calls != ["reinitialize:tool_full_reload"]:
		return _failure("Runtime reload completion service should reinitialize the recreated controller when it was stopped.", {"calls": full_controller.calls})
	if (recorder["calls"] as Array).has("ensure_update_refs_discovery_requested"):
		return _failure("Runtime reload completion service should not trigger update refs discovery when restoring update tab focus.", {"calls": recorder["calls"]})
	if not (recorder["calls"] as Array).has("restore_focus_snapshot:5:dock2"):
		return _failure("Runtime reload completion service should restore focus on the latest recreated dock after full reload.", {"calls": recorder["calls"]})

	var focus_snapshot = service.capture_dock_focus_snapshot(null, state)
	if int(focus_snapshot.get("tab_index", -1)) != int(state.current_tab):
		return _failure("Runtime reload completion service should fall back to current tab for focus capture.")
	_free_recorded_docks(recorder)

	return {"name": "plugin_runtime_reload_completion_service_contracts", "success": true, "error": ""}


func _build_context(state, server_controller, recorder: Dictionary) -> Dictionary:
	recorder["active_controller"] = server_controller
	var dock := FakeDock.new(recorder, "dock%d" % int(recorder.get("dock_generation", 0)))
	if not recorder.has("docks"):
		recorder["docks"] = []
	recorder["active_dock"] = dock
	(recorder["docks"] as Array).append(dock)
	return {
		"state": state,
		"dock": dock,
		"get_dock": Callable(self, "_get_active_dock").bind(recorder),
		"server_controller": server_controller,
		"get_server_controller": Callable(self, "_get_active_controller").bind(recorder),
		"refresh_service_instances": Callable(self, "_record_call").bind(recorder, "refresh_service_instances"),
		"recreate_server_controller": Callable(self, "_recreate_controller").bind(recorder),
		"reset_localization": Callable(self, "_record_call").bind(recorder, "reset_localization"),
		"recreate_dock": Callable(self, "_recreate_dock").bind(recorder),
		"refresh_dock": Callable(self, "_record_call").bind(recorder, "refresh_dock"),
		"ensure_update_refs_discovery_requested": Callable(self, "_record_call").bind(recorder, "ensure_update_refs_discovery_requested")
	}


func _get_active_controller(recorder: Dictionary):
	return recorder.get("active_controller", null)


func _get_active_dock(recorder: Dictionary):
	return recorder.get("active_dock", null)


func _recreate_controller(recorder: Dictionary) -> void:
	_record_call(recorder, "recreate_server_controller")
	recorder["active_controller"] = FakeServerController.new("recreated")


func _recreate_dock(recorder: Dictionary) -> void:
	_record_call(recorder, "recreate_dock")
	recorder["dock_generation"] = int(recorder.get("dock_generation", 0)) + 1
	var dock := FakeDock.new(recorder, "dock%d" % int(recorder.get("dock_generation", 0)))
	if not recorder.has("docks"):
		recorder["docks"] = []
	(recorder["docks"] as Array).append(dock)
	recorder["active_dock"] = dock


func _record_call(recorder: Dictionary, name: String) -> bool:
	(recorder["calls"] as Array).append(name)
	return true


func _free_recorded_docks(recorder: Dictionary) -> void:
	for dock in recorder.get("docks", []):
		if dock != null and is_instance_valid(dock):
			dock.free()
	recorder["docks"] = []


func _verify_plugin_entrypoint_delegates_runtime_reload_completion() -> String:
	var plugin_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin.gd")
	var service_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_reload_completion_service.gd")
	if plugin_source.is_empty() or service_source.is_empty():
		return "Runtime reload completion sources should be readable."
	for required in [
		"PluginRuntimeReloadCompletionServiceScript.new()",
		"_ensure_runtime_reload_completion_service().complete_server_restart(",
		"_ensure_runtime_reload_completion_service().complete_soft_reload(",
		"_ensure_runtime_reload_completion_service().complete_full_reload(",
		"_ensure_runtime_reload_completion_service().capture_dock_focus_snapshot(",
		"_ensure_runtime_reload_completion_service().restore_dock_focus_snapshot(",
		"\"get_dock\": Callable(self, \"_get_dock\")"
	]:
		if plugin_source.find(required) == -1:
			return "plugin.gd should delegate runtime reload completion responsibility: %s" % required
	for forbidden in [
		"success = _server_controller.start(_state.settings, \"tool_soft_reload\")",
		"success = _server_controller.reinitialize(_state.settings, \"tool_full_reload\")",
		"LocalizationService.reset_instance()\n\t\t_localization = LocalizationService.get_instance()"
	]:
		if plugin_source.find(forbidden) != -1:
			return "plugin.gd should not retain runtime reload completion internals: %s" % forbidden
	for required_service in [
		"func complete_server_restart(context: Dictionary)",
		"func complete_soft_reload(context: Dictionary, was_running: bool, focus_snapshot: Dictionary = {})",
		"func complete_full_reload(context: Dictionary, was_running: bool, focus_snapshot: Dictionary = {})",
		"func restore_dock_focus_snapshot(context: Dictionary, snapshot: Dictionary)"
	]:
		if service_source.find(required_service) == -1:
			return "PluginRuntimeReloadCompletionService should own runtime reload method: %s" % required_service
	return ""


class FakeState:
	var settings := {"language": "en", "log_level": "debug"}
	var current_tab := 1


class FakeServerController:
	var id := ""
	var calls: Array[String] = []

	func _init(id_in: String) -> void:
		id = id_in

	func start(_settings: Dictionary, reason: String) -> bool:
		calls.append("start:%s" % reason)
		return true

	func reinitialize(_settings: Dictionary, reason: String) -> bool:
		calls.append("reinitialize:%s" % reason)
		return true


class FakeDock:
	extends Control

	var recorder: Dictionary
	var dock_id := ""

	func _init(recorder_in: Dictionary, dock_id_in: String) -> void:
		recorder = recorder_in
		dock_id = dock_id_in

	func activate_editor_dock_tab() -> void:
		(recorder["calls"] as Array).append("activate_editor_dock_tab")

	func restore_focus_snapshot(snapshot: Dictionary) -> void:
		(recorder["calls"] as Array).append("restore_focus_snapshot:%s:%s" % [str(snapshot.get("tab_index", "")), dock_id])

	func focus_active_panel() -> void:
		(recorder["calls"] as Array).append("focus_active_panel")


func _failure(message: String, details: Dictionary = {}) -> Dictionary:
	return {"name": "plugin_runtime_reload_completion_service_contracts", "success": false, "error": message, "details": details}
