extends RefCounted

const PluginActionRouter = preload("res://addons/godot_dotnet_mcp/plugin/plugin_action_router.gd")
const PluginDockCoordinator = preload("res://addons/godot_dotnet_mcp/plugin/plugin_dock_coordinator.gd")

var _router = null
var _coordinator = null
var _plugin = null
var _dock: FakeDock = null
var _confirmation_count := 0


class FakeDock extends Control:
	signal current_tab_changed(index: int)
	signal update_source_changed(source: String)
	signal update_custom_branch_changed(branch: String)
	signal update_check_requested
	signal update_apply_requested
	signal full_reload_requested
	signal copy_requested(text: String, source: String)


class FakeServerController extends RefCounted:
	var reload_count := 0

	func reload_all_domains() -> Dictionary:
		reload_count += 1
		return {"success": true, "source": "server"}


class FakePlugin extends RefCounted:
	var current_tab_changes: Array[int] = []
	var update_source_changes: Array[String] = []
	var update_custom_branch_changes: Array[String] = []
	var update_check_count := 0
	var update_apply_count := 0
	var full_reload_count := 0
	var copy_events: Array[Dictionary] = []
	var show_message_count := 0
	var last_message := ""
	var confirmation_count := 0
	var server_controller := FakeServerController.new()

	func _on_current_tab_changed(index: int) -> void:
		current_tab_changes.append(index)

	func _on_update_source_changed(source: String) -> void:
		update_source_changes.append(source)

	func _on_update_custom_branch_changed(branch: String) -> void:
		update_custom_branch_changes.append(branch)

	func _on_update_check_requested() -> void:
		update_check_count += 1

	func _on_update_sync_requested() -> void:
		update_apply_count += 1

	func _on_full_reload_requested() -> void:
		full_reload_count += 1

	func _on_copy_requested(text: String, source: String) -> void:
		copy_events.append({"text": text, "source": source})

	func _show_message(message: String) -> void:
		show_message_count += 1
		last_message = message

	func _show_confirmation(_message: String, on_confirmed: Callable) -> void:
		confirmation_count += 1
		if on_confirmed.is_valid():
			on_confirmed.call()

	func get_server():
		return server_controller


class IncidentRecorder extends RefCounted:
	var incidents: Array[Dictionary] = []

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
	_router = PluginActionRouter.new()
	_coordinator = PluginDockCoordinator.new()
	_plugin = FakePlugin.new()
	var recorder = IncidentRecorder.new()
	_router.configure(_plugin, "RuntimeBridge", "res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_bridge.gd")

	var bindings = _coordinator.build_dock_signal_bindings(_router)
	if bindings.size() != 29:
		return _failure("PluginActionRouter should expose the full dock binding set.")
	var binding_map := _map_bindings_by_signal(bindings)
	for signal_name in ["current_tab_changed", "update_source_changed", "update_custom_branch_changed", "update_check_requested", "update_apply_requested", "full_reload_requested", "copy_requested", "config_write_requested"]:
		var binding: Dictionary = binding_map.get(signal_name, {})
		var callable: Callable = binding.get("callable", Callable())
		if not callable.is_valid():
			return _failure("PluginActionRouter should create valid dock callables for %s." % signal_name)

	_dock = FakeDock.new()
	var routed_bindings: Array[Dictionary] = [
		binding_map["current_tab_changed"],
		binding_map["update_source_changed"],
		binding_map["update_custom_branch_changed"],
		binding_map["update_check_requested"],
		binding_map["update_apply_requested"],
		binding_map["full_reload_requested"],
		binding_map["copy_requested"]
	]
	if not _coordinator.wire_dock_signals(_dock, routed_bindings, "plugin_action_router_contract", Callable(recorder, "record_incident"), PluginDockCoordinator.DEFAULT_DOCK_SCRIPT_PATH):
		return _failure("PluginActionRouter should wire valid dock bindings through the dock coordinator.")

	_router.show_message("Hello from router")
	if _plugin.show_message_count != 1 or _plugin.last_message != "Hello from router":
		return _failure("PluginActionRouter should forward show_message to the plugin surface.")

	var confirmation_hit := false
	_router.show_confirmation("Confirm", Callable(self, "_on_confirmation_confirmed"))
	confirmation_hit = _confirmation_count == 1
	if not confirmation_hit or _plugin.confirmation_count != 1:
		return _failure("PluginActionRouter should forward show_confirmation to the plugin surface.")

	var reload_result = _router.reload_all_tool_domains()
	if not (reload_result is Dictionary) or not bool(reload_result.get("success", false)):
		return _failure("PluginActionRouter should forward reload_all_tool_domains to the server controller.")
	if _plugin.server_controller.reload_count != 1:
		return _failure("PluginActionRouter should call the server controller exactly once for reload_all_tool_domains.")

	_dock.emit_signal("current_tab_changed", 7)
	_dock.emit_signal("update_source_changed", "custom_branch")
	_dock.emit_signal("update_custom_branch_changed", "feature/router")
	_dock.emit_signal("update_check_requested")
	_dock.emit_signal("update_apply_requested")
	_dock.emit_signal("full_reload_requested")
	_dock.emit_signal("copy_requested", "copy text", "clipboard")

	if _plugin.current_tab_changes != [7]:
		return _failure("PluginActionRouter should route current_tab_changed through the dock binding.")
	if _plugin.update_source_changes != ["custom_branch"] or _plugin.update_custom_branch_changes != ["feature/router"]:
		return _failure("PluginActionRouter should route update Settings changes to plugin handlers.")
	if _plugin.update_check_count != 1 or _plugin.update_apply_count != 1:
		return _failure("PluginActionRouter should route update discovery and sync requests to plugin handlers.")
	if _plugin.full_reload_count != 1:
		return _failure("PluginActionRouter should route full_reload_requested to the plugin UI reload handler.")
	if _plugin.copy_events.size() != 1 or str(_plugin.copy_events[0].get("text", "")) != "copy text":
		return _failure("PluginActionRouter should route copy_requested through the dock binding.")
	if not recorder.incidents.is_empty():
		return _failure("PluginActionRouter should not emit incidents for valid dock bindings.")

	return {
		"name": "plugin_action_router_contracts",
		"success": true,
		"error": "",
		"details": {
			"binding_count": bindings.size(),
			"server_reload_count": _plugin.server_controller.reload_count,
			"confirmation_count": _confirmation_count
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	_router = null
	_coordinator = null
	_plugin = null
	if _dock != null and is_instance_valid(_dock):
		_dock.free()
	_dock = null
	_confirmation_count = 0


func _on_confirmation_confirmed() -> void:
	_confirmation_count += 1


func _map_bindings_by_signal(bindings: Array[Dictionary]) -> Dictionary:
	var result := {}
	for binding in bindings:
		if binding is Dictionary:
			result[str(binding.get("signal", ""))] = binding
	return result


func _failure(message: String) -> Dictionary:
	return {
		"name": "plugin_action_router_contracts",
		"success": false,
		"error": message
	}
