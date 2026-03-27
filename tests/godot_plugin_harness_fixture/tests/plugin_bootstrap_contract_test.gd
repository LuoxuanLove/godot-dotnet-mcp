extends RefCounted

const PluginBootstrap = preload("res://addons/godot_dotnet_mcp/plugin/plugin_bootstrap.gd")
const PluginActionRouter = preload("res://addons/godot_dotnet_mcp/plugin/plugin_action_router.gd")

var _bootstrap = null
var _plugin = null


class FakeState extends RefCounted:
	var settings: Dictionary = {}
	var current_tab := 0


class FakeServerController extends RefCounted:
	func get_all_tools_by_category() -> Dictionary:
		return {}

	func set_disabled_tools(_disabled: Dictionary) -> void:
		pass

	func is_running() -> bool:
		return false

	func get_connection_stats() -> Dictionary:
		return {}

	func get_tool_load_errors() -> Array:
		return []

	func get_reload_status() -> Dictionary:
		return {}

	func get_performance_summary() -> Dictionary:
		return {}

	func reload_all_domains() -> Dictionary:
		return {"success": true}


class FakePlugin extends RefCounted:
	var _state := FakeState.new()
	var _action_router = PluginActionRouter.new()
	var _server_controller = FakeServerController.new()
	var _localization = null
	var _settings_store = null
	var _runtime_state_service = null
	var _tool_bridge_service = null
	var _tool_catalog = null
	var _config_service = null
	var _client_install_detection_service = null
	var _server_feature = null
	var _config_feature = null
	var _user_tool_feature = null
	var _reload_feature = null
	var _tool_profile_feature = null
	var _tool_access_feature = null
	var _self_diagnostic_feature = null
	var _ui_state_feature = null
	var _dock_presenter = null
	var _dock_model_service = null
	var _user_tool_service = null
	var _user_tool_watch_service = null
	var _central_server_attach_service = null
	var _central_server_process_service = null
	var _dock = null

	func _build_dock_model() -> Dictionary:
		return {}

	func _get_dock():
		return _dock

	func _save_settings() -> void:
		pass

	func _ensure_client_executable_dialog() -> void:
		pass

	func _get_client_executable_dialog():
		return null

	func _capture_dock_focus_snapshot() -> Dictionary:
		return {}

	func _restore_runtime_dock_focus_snapshot(_snapshot: Dictionary) -> void:
		pass

	func _create_reload_coordinator():
		return RefCounted.new()

	func _runtime_reload_is_server_running() -> bool:
		return false

	func _runtime_reload_start_server(_reason: String) -> bool:
		return true

	func _runtime_reload_reinitialize_server(_reason: String) -> bool:
		return true

	func _refresh_service_instances() -> void:
		pass

	func _runtime_reload_reset_localization() -> void:
		pass

	func _recreate_server_controller() -> void:
		pass

	func _configure_central_server_process_service() -> void:
		pass

	func _configure_central_server_attach_service() -> void:
		pass

	func _configure_feature_workflows() -> void:
		pass

	func _recreate_dock() -> void:
		pass

	func _finish_self_operation(_operation: Dictionary, _success: bool, _component: String, _phase: String, _anomaly_codes: Array = [], _context: Dictionary = {}) -> void:
		pass

	func _count_dock_instances() -> int:
		return 1

	func _has_runtime_bridge_root_instance() -> bool:
		return false

	func _is_live_dock_present() -> bool:
		return false

	func _get_editor_scale() -> float:
		return 1.0


func run_case(_tree: SceneTree) -> Dictionary:
	_bootstrap = PluginBootstrap.new()
	_plugin = FakePlugin.new()

	_bootstrap.refresh_plugin_service_instances(_plugin)
	if _plugin._settings_store == null:
		return _failure("PluginBootstrap should populate settings_store during service refresh.")
	if _plugin._config_feature == null or _plugin._tool_access_feature == null:
		return _failure("PluginBootstrap should populate feature services during service refresh.")

	_bootstrap.configure_plugin_workflows(_plugin, _plugin._action_router, "RuntimeBridge", "res://runtime_bridge.gd")
	if _plugin._tool_bridge_service == null:
		return _failure("PluginBootstrap should keep the tool bridge service available after workflow configuration.")
	if _plugin._dock_model_service == null:
		return _failure("PluginBootstrap should configure the dock model service during workflow setup.")

	var bindings: Array[Dictionary] = _plugin._action_router.build_dock_signal_bindings()
	if bindings.size() < 10:
		return _failure("PluginBootstrap should reconfigure the action router with dock bindings after workflow setup.")
	var first_binding: Dictionary = bindings[0]
	var first_callable: Callable = first_binding.get("callable", Callable())
	if not first_callable.is_valid():
		return _failure("PluginBootstrap should attach valid action router callables after workflow setup.")

	_bootstrap.configure_plugin_dock_model_service(_plugin)
	if _plugin._dock_model_service == null:
		return _failure("PluginBootstrap should be able to reconfigure the dock model service independently.")

	return {
		"name": "plugin_bootstrap_contracts",
		"success": true,
		"error": "",
		"details": {
			"binding_count": bindings.size(),
			"has_tool_bridge_service": _plugin._tool_bridge_service != null,
			"has_dock_model_service": _plugin._dock_model_service != null
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	if _plugin != null:
		_plugin._action_router = null
		_plugin._state = null
		_plugin._server_controller = null
		_plugin._localization = null
		_plugin._settings_store = null
		_plugin._runtime_state_service = null
		_plugin._tool_bridge_service = null
		_plugin._tool_catalog = null
		_plugin._config_service = null
		_plugin._client_install_detection_service = null
		_plugin._server_feature = null
		_plugin._config_feature = null
		_plugin._user_tool_feature = null
		_plugin._reload_feature = null
		_plugin._tool_profile_feature = null
		_plugin._tool_access_feature = null
		_plugin._self_diagnostic_feature = null
		_plugin._ui_state_feature = null
		_plugin._dock_presenter = null
		_plugin._dock_model_service = null
		_plugin._user_tool_service = null
		_plugin._user_tool_watch_service = null
		_plugin._central_server_attach_service = null
		_plugin._central_server_process_service = null
		_plugin._dock = null
	_plugin = null
	_bootstrap = null


func _failure(message: String) -> Dictionary:
	return {
		"name": "plugin_bootstrap_contracts",
		"success": false,
		"error": message
	}
