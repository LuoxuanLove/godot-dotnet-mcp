extends RefCounted

const ConfigFeatureConfigWorkflow = preload("res://addons/godot_dotnet_mcp/plugin/features/config_feature_config_workflow.gd")
const ConfigFeatureClientWorkflow = preload("res://addons/godot_dotnet_mcp/plugin/features/config_feature_client_workflow.gd")
const PluginConfigFeatureConfigWorkflowContext = preload("res://addons/godot_dotnet_mcp/plugin/plugin_config_feature_config_workflow_context.gd")
const PluginConfigFeatureClientWorkflowContext = preload("res://addons/godot_dotnet_mcp/plugin/plugin_config_feature_client_workflow_context.gd")

var _show_message := Callable()
var _show_confirmation := Callable()
var _refresh_dock := Callable()
var _config_workflow = ConfigFeatureConfigWorkflow.new()
var _client_workflow = ConfigFeatureClientWorkflow.new()


func configure(context) -> void:
	if context == null:
		dispose()
		return
	_show_message = context.show_message
	_show_confirmation = context.show_confirmation
	_refresh_dock = context.refresh_dock
	_config_workflow.configure(_build_config_workflow_context(context))
	_client_workflow.configure(_build_client_workflow_context(context))


func dispose() -> void:
	_show_message = Callable()
	_show_confirmation = Callable()
	_refresh_dock = Callable()
	if _config_workflow != null:
		_config_workflow.dispose()
	if _client_workflow != null:
		_client_workflow.dispose()


func get_client_display_name(client_id: String) -> String:
	return _client_workflow.get_client_display_name(client_id) if _client_workflow != null else client_id


func handle_validate_requested() -> void:
	if _client_workflow != null:
		_client_workflow.handle_validate_requested()


func handle_client_action_requested(client_id: String) -> void:
	if _client_workflow != null:
		_client_workflow.handle_client_action_requested(client_id)


func handle_client_launch_requested(client_id: String) -> void:
	if _client_workflow != null:
		_client_workflow.handle_client_launch_requested(client_id)


func handle_client_path_pick_requested(client_id: String) -> void:
	if _client_workflow != null:
		_client_workflow.handle_client_path_pick_requested(client_id)


func handle_client_executable_file_selected(path: String) -> void:
	if _client_workflow != null:
		_client_workflow.handle_client_executable_file_selected(path)


func reset_client_path_request() -> void:
	if _client_workflow != null:
		_client_workflow.reset_client_path_request()


func handle_client_path_clear_requested(client_id: String) -> void:
	if _client_workflow != null:
		_client_workflow.handle_client_path_clear_requested(client_id)


func handle_client_open_config_dir_requested(client_id: String) -> void:
	if _client_workflow != null:
		_client_workflow.handle_client_open_config_dir_requested(client_id)


func handle_client_open_config_file_requested(client_id: String) -> void:
	if _client_workflow != null:
		_client_workflow.handle_client_open_config_file_requested(client_id)


func handle_write_requested(config_type: String, filepath: String, config: String, client_name: String) -> void:
	_config_workflow.handle_write_requested(config_type, filepath, config, client_name)


func handle_remove_requested(config_type: String, filepath: String, client_name: String) -> void:
	_config_workflow.handle_remove_requested(config_type, filepath, client_name)


func _get_statuses() -> Dictionary:
	if _client_workflow != null:
		return _client_workflow.get_statuses()
	return {}


func _call_invalidate_client_install_status_cache() -> void:
	if _client_workflow != null:
		_client_workflow.invalidate_client_install_status_cache()


func _build_config_workflow_context(context):
	var workflow_context = PluginConfigFeatureConfigWorkflowContext.new()
	workflow_context.localization = context.localization
	workflow_context.config_service = context.config_service
	workflow_context.get_statuses = Callable(self, "_get_statuses")
	workflow_context.show_message = _show_message
	workflow_context.show_confirmation = _show_confirmation
	workflow_context.refresh_dock = _refresh_dock
	workflow_context.invalidate_client_install_status_cache = Callable(self, "_call_invalidate_client_install_status_cache")
	return workflow_context


func _build_client_workflow_context(context):
	var workflow_context = PluginConfigFeatureClientWorkflowContext.new()
	workflow_context.settings = context.settings
	workflow_context.localization = context.localization
	workflow_context.config_service = context.config_service
	workflow_context.dock_presenter = context.dock_presenter
	workflow_context.central_server_process_service = context.central_server_process_service
	workflow_context.client_install_detection_service = context.client_install_detection_service
	workflow_context.show_message = _show_message
	workflow_context.refresh_dock = _refresh_dock
	workflow_context.save_settings = context.save_settings
	workflow_context.ensure_client_executable_dialog = context.ensure_client_executable_dialog
	workflow_context.get_client_executable_dialog = context.get_client_executable_dialog
	return workflow_context
