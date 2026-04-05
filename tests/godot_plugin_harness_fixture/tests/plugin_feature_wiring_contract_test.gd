extends RefCounted

const PluginFeatureWiring = preload("res://addons/godot_dotnet_mcp/plugin/plugin_feature_wiring.gd")

var _wiring = null
var _plugin = null
var _bootstrap = null


class FakeState extends RefCounted:
	var settings := {}


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


class FakeServerFeature extends RefCounted:
	var context = null

	func configure(context_in) -> void:
		context = context_in


class FakeConfigFeature extends RefCounted:
	var context = null

	func configure(context_in) -> void:
		context = context_in


class FakeUiStateFeature extends RefCounted:
	var context = null

	func configure(context_in) -> void:
		context = context_in

	func handle_language_changed(_language_code: String) -> void:
		pass


class FakeToolAccessFeature extends RefCounted:
	var context = null

	func configure(context_in) -> void:
		context = context_in

	func cleanup_disabled_tools() -> void:
		pass

	func get_permission_level() -> String:
		return "developer"


class FakeUserToolFeature extends RefCounted:
	var context = null

	func configure(context_in) -> void:
		context = context_in


class FakeReloadFeature extends RefCounted:
	var context = null

	func configure(context_in) -> void:
		context = context_in


class FakeToolProfileFeature extends RefCounted:
	var context = null

	func configure(context_in) -> void:
		context = context_in


class FakeSelfDiagnosticFeature extends RefCounted:
	var context = null

	func configure(context_in) -> void:
		context = context_in


class FakeToolBridgeService extends RefCounted:
	var configured := []

	func configure(server_controller, reload_feature, self_diagnostic_feature, tool_access_feature, tool_profile_feature, user_tool_feature) -> void:
		configured = [
			server_controller,
			reload_feature,
			self_diagnostic_feature,
			tool_access_feature,
			tool_profile_feature,
			user_tool_feature
		]


class FakeActionRouter extends RefCounted:
	func show_message(_message: String) -> void:
		pass

	func show_confirmation(_message: String, _callback: Callable) -> void:
		pass

	func refresh_dock() -> void:
		pass

	func reload_all_tool_domains() -> Dictionary:
		return {"success": true}


class FakeDockCoordinator extends RefCounted:
	func count_plugin_dock_instances(_plugin, _dock_script_path: String) -> int:
		return 1


class FakeBootstrap extends RefCounted:
	func ensure_plugin_client_executable_dialog(_plugin) -> void:
		pass

	func get_plugin_client_executable_dialog(_plugin):
		return null

	func capture_plugin_dock_focus_snapshot(_plugin) -> Dictionary:
		return {}

	func restore_plugin_dock_focus_snapshot(_plugin, _snapshot: Dictionary) -> void:
		pass

	func refresh_plugin_service_instances(_plugin) -> void:
		pass

	func configure_plugin_workflows(_plugin, _action_router, _autoload_name: String, _autoload_path: String) -> void:
		pass


class FakePlugin extends RefCounted:
	var _server_controller = FakeServerController.new()
	var _state = FakeState.new()
	var _localization = RefCounted.new()
	var _settings_store = RefCounted.new()
	var _tool_catalog = RefCounted.new()
	var _config_service = RefCounted.new()
	var _dock_presenter = RefCounted.new()
	var _user_tool_service = RefCounted.new()
	var _client_install_detection_service = RefCounted.new()
	var _central_server_attach_service = RefCounted.new()
	var _runtime_process_service = RefCounted.new()
	var _server_feature = FakeServerFeature.new()
	var _config_feature = FakeConfigFeature.new()
	var _user_tool_feature = FakeUserToolFeature.new()
	var _reload_feature = FakeReloadFeature.new()
	var _tool_profile_feature = FakeToolProfileFeature.new()
	var _tool_access_feature = FakeToolAccessFeature.new()
	var _self_diagnostic_feature = FakeSelfDiagnosticFeature.new()
	var _ui_state_feature = FakeUiStateFeature.new()
	var _tool_bridge_service = FakeToolBridgeService.new()
	var _action_router = FakeActionRouter.new()
	var _dock_coordinator = FakeDockCoordinator.new()

	func _save_settings() -> void:
		pass

	func _create_reload_coordinator():
		return RefCounted.new()

	func _runtime_reload_is_server_running() -> bool:
		return false

	func _runtime_reload_start_server(_reason: String) -> bool:
		return true

	func _runtime_reload_reinitialize_server(_reason: String) -> bool:
		return true

	func _runtime_reload_reset_localization() -> void:
		pass

	func _recreate_server_controller() -> void:
		pass

	func _configure_runtime_process_service() -> void:
		pass

	func _configure_central_server_attach_service() -> void:
		pass

	func _recreate_dock() -> void:
		pass

	func _finish_self_operation(_operation: Dictionary, _success: bool, _component: String, _phase: String, _anomaly_codes: Array = [], _context: Dictionary = {}) -> void:
		pass

	func _has_runtime_bridge_root_instance() -> bool:
		return false

	func _is_live_dock_present() -> bool:
		return true


func run_case(_tree: SceneTree) -> Dictionary:
	_wiring = PluginFeatureWiring.new()
	_plugin = FakePlugin.new()
	_bootstrap = FakeBootstrap.new()

	_wiring.configure_feature_workflows(
		_plugin,
		_bootstrap,
		"RuntimeBridge",
		"res://runtime_bridge.gd"
	)

	if _plugin._tool_access_feature == null:
		return _failure("PluginFeatureWiring should keep the tool access feature available on the plugin.")
	if _plugin._server_feature.context == null or not _plugin._server_feature.context.show_confirmation.is_valid():
		return _failure("PluginFeatureWiring should pass a typed server feature context with confirmation wiring.")
	if _plugin._config_feature.context == null or not _plugin._config_feature.context.save_settings.is_valid():
		return _failure("PluginFeatureWiring should pass a typed config feature context with save wiring.")
	if _plugin._ui_state_feature.context == null or not _plugin._ui_state_feature.context.capture_dock_focus_snapshot.is_valid():
		return _failure("PluginFeatureWiring should pass a typed UI state context with focus snapshot wiring.")
	if _plugin._tool_access_feature.context == null or not _plugin._tool_access_feature.context.change_language.is_valid():
		return _failure("PluginFeatureWiring should pass a typed tool access context with a valid language callback.")
	if _plugin._user_tool_feature.context == null or not _plugin._user_tool_feature.context.reload_all_domains.is_valid():
		return _failure("PluginFeatureWiring should pass a typed user tool context with reload wiring.")
	if _plugin._tool_profile_feature.context == null or not _plugin._tool_profile_feature.context.cleanup_disabled_tools.is_valid():
		return _failure("PluginFeatureWiring should pass a typed tool profile context with cleanup wiring.")
	if _plugin._self_diagnostic_feature.context == null or not _plugin._self_diagnostic_feature.context.get_permission_level.is_valid():
		return _failure("PluginFeatureWiring should pass a typed self diagnostic context with permission access.")
	if _plugin._reload_feature.context == null or not _plugin._reload_feature.context.start_server.is_valid():
		return _failure("PluginFeatureWiring should forward the typed reload runtime context to the reload feature.")
	if _plugin._tool_bridge_service.configured.size() != 6:
		return _failure("PluginFeatureWiring should keep tool bridge wiring intact after the typed-context refactor.")

	return {
		"name": "plugin_feature_wiring_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_bridge_arg_count": _plugin._tool_bridge_service.configured.size()
		}
	}


func cleanup_case(tree: SceneTree) -> void:
	if _plugin != null:
		if _plugin._server_feature != null:
			_plugin._server_feature.context = null
		if _plugin._config_feature != null:
			_plugin._config_feature.context = null
		if _plugin._ui_state_feature != null:
			_plugin._ui_state_feature.context = null
		if _plugin._tool_access_feature != null:
			_plugin._tool_access_feature.context = null
		if _plugin._user_tool_feature != null:
			_plugin._user_tool_feature.context = null
		if _plugin._reload_feature != null:
			_plugin._reload_feature.context = null
		if _plugin._tool_profile_feature != null:
			_plugin._tool_profile_feature.context = null
		if _plugin._self_diagnostic_feature != null:
			_plugin._self_diagnostic_feature.context = null
		if _plugin._tool_bridge_service != null:
			_plugin._tool_bridge_service.configured = []
		_plugin._server_controller = null
		_plugin._state = null
		_plugin._localization = null
		_plugin._settings_store = null
		_plugin._tool_catalog = null
		_plugin._config_service = null
		_plugin._dock_presenter = null
		_plugin._user_tool_service = null
		_plugin._client_install_detection_service = null
		_plugin._central_server_attach_service = null
		_plugin._runtime_process_service = null
		_plugin._server_feature = null
		_plugin._config_feature = null
		_plugin._user_tool_feature = null
		_plugin._reload_feature = null
		_plugin._tool_profile_feature = null
		_plugin._tool_access_feature = null
		_plugin._self_diagnostic_feature = null
		_plugin._ui_state_feature = null
		_plugin._tool_bridge_service = null
		_plugin._action_router = null
		_plugin._dock_coordinator = null
	_wiring = null
	_bootstrap = null
	_plugin = null
	await tree.process_frame
	await tree.process_frame


func _failure(message: String) -> Dictionary:
	return {
		"name": "plugin_feature_wiring_contracts",
		"success": false,
		"error": message
	}
