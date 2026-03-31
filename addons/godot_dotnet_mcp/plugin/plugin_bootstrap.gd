@tool
extends RefCounted

const PluginRuntimeStateServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_state_service.gd")
const PluginServiceBundleFactory = preload("res://addons/godot_dotnet_mcp/plugin/plugin_service_bundle_factory.gd")
const PluginFeatureWiring = preload("res://addons/godot_dotnet_mcp/plugin/plugin_feature_wiring.gd")

var _service_bundle_factory = PluginServiceBundleFactory.new()
var _feature_wiring = PluginFeatureWiring.new()


func refresh_plugin_service_instances(plugin) -> void:
	if plugin == null:
		return
	_service_bundle_factory.refresh_plugin_service_instances(plugin)


func dispose_plugin_service_instances(plugin) -> void:
	if plugin == null:
		return
	var disposed := {}
	if plugin._action_router != null:
		_dispose_instance(plugin._action_router, disposed)
	for key in _feature_wiring.get_feature_result_keys():
		_dispose_instance(plugin.get("_%s" % key), disposed)
	for key in _service_bundle_factory.get_bundle_keys():
		_dispose_instance(plugin.get("_%s" % key), disposed)


func build_plugin_dock_model(plugin) -> Dictionary:
	if plugin == null:
		return {}
	if plugin._dock_model_service == null:
		configure_plugin_dock_model_service(plugin)
	if plugin._dock_model_service == null:
		return {}
	return plugin._dock_model_service.build_model()


func get_plugin_dock(plugin):
	if plugin == null:
		return null
	return plugin._dock


func apply_initial_tool_profile_if_needed(plugin) -> void:
	if plugin != null and plugin._tool_profile_feature != null:
		plugin._tool_profile_feature.apply_initial_tool_profile_if_needed()


func ensure_plugin_client_executable_dialog(plugin) -> void:
	if plugin == null or plugin._dock_coordinator == null:
		return
	plugin._client_executable_dialog = plugin._dock_coordinator.ensure_plugin_client_executable_dialog(
		plugin,
		plugin._client_executable_dialog,
		Callable(plugin._action_router, "handle_client_executable_file_selected")
	)


func get_plugin_client_executable_dialog(plugin):
	if plugin == null:
		return null
	return plugin._client_executable_dialog


func remove_plugin_client_executable_dialog(plugin) -> void:
	if plugin == null or plugin._dock_coordinator == null:
		return
	plugin._client_executable_dialog = plugin._dock_coordinator.remove_client_executable_dialog(
		plugin._client_executable_dialog,
		Callable(plugin._config_feature, "reset_client_path_request") if plugin._config_feature != null else Callable()
	)


func capture_plugin_dock_focus_snapshot(plugin) -> Dictionary:
	if plugin == null or plugin._dock_coordinator == null or plugin._state == null:
		return {}
	return plugin._dock_coordinator.capture_focus_snapshot(plugin._dock, int(plugin._state.current_tab))


func restore_plugin_dock_focus_snapshot(plugin, snapshot: Dictionary) -> void:
	if plugin == null or plugin._dock_coordinator == null:
		return
	plugin._dock_coordinator.restore_focus_snapshot(plugin._dock, snapshot)


func restore_pending_focus_snapshot_if_needed(plugin, snapshot_key: String) -> void:
	if plugin == null or plugin._state == null:
		return
	var snapshot = plugin._state.settings.get(snapshot_key, {})
	if not (snapshot is Dictionary):
		return
	restore_plugin_dock_focus_snapshot(plugin, snapshot)
	plugin._state.settings.erase(snapshot_key)
	save_settings(plugin._runtime_state_service, plugin._settings_store, plugin._state)


func configure_plugin_workflows(plugin, action_router, runtime_bridge_autoload_name: String, runtime_bridge_autoload_path: String) -> void:
	if plugin == null:
		return
	_configure_action_router(action_router, plugin)
	_feature_wiring.configure_feature_workflows(
		plugin,
		self,
		runtime_bridge_autoload_name,
		runtime_bridge_autoload_path
	)
	configure_plugin_dock_model_service(plugin)
	_configure_action_router(action_router, plugin)


func configure_plugin_dock_model_service(plugin):
	if plugin == null:
		return null
	return _feature_wiring.configure_dock_model_service(plugin)


func load_state(runtime_state_service, settings_store, state, client_install_detection_service) -> void:
	var state_service = runtime_state_service
	if state_service == null:
		state_service = PluginRuntimeStateServiceScript.new()
		state_service.configure(settings_store)
	state_service.load_into(state)
	if client_install_detection_service != null:
		client_install_detection_service.configure(state.settings)


func save_settings(runtime_state_service, settings_store, state) -> void:
	var state_service = runtime_state_service
	if state_service == null:
		state_service = PluginRuntimeStateServiceScript.new()
		state_service.configure(settings_store)
	state_service.save_settings(state)


func _configure_action_router(action_router, plugin) -> void:
	if action_router == null or plugin == null:
		return
	action_router.configure(
		plugin._server_controller,
		plugin._state,
		plugin._localization,
		plugin._server_feature,
		plugin._config_feature,
		plugin._user_tool_feature,
		plugin._tool_access_feature,
		plugin._self_diagnostic_feature,
		plugin._ui_state_feature,
		plugin._reload_feature,
		Callable(self, "build_plugin_dock_model").bind(plugin),
		Callable(self, "get_plugin_dock").bind(plugin)
	)


func _dispose_instance(instance, disposed: Dictionary) -> void:
	if instance == null or not is_instance_valid(instance):
		return
	var instance_id: int = instance.get_instance_id()
	if disposed.has(instance_id):
		return
	disposed[instance_id] = true
	if instance.has_method("dispose"):
		instance.dispose()
