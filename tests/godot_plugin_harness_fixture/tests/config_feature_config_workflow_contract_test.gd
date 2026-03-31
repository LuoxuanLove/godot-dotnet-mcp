extends RefCounted

const ConfigFeatureConfigWorkflow = preload("res://addons/godot_dotnet_mcp/plugin/features/config_feature_config_workflow.gd")
const PluginConfigFeatureConfigWorkflowContext = preload("res://addons/godot_dotnet_mcp/plugin/plugin_config_feature_config_workflow_context.gd")


class FakeLocalization extends RefCounted:
	var _texts := {
		"msg_config_overwrite_confirm": "Overwrite %s",
		"msg_config_precheck_incompatible_mcp": "Incompatible MCP at %s",
		"msg_config_backup_notice": "Backup at %s",
		"msg_config_success": "Configured %s",
		"msg_config_verified": "Verified %s",
		"msg_config_backup_created": "Created backup %s",
		"msg_config_effect_hint": "Restart may be required",
		"msg_config_restart_cursor": "Restart Cursor",
		"msg_config_remove_noop_missing_entry": "No entry for %s",
	}

	func get_text(key: String) -> String:
		return str(_texts.get(key, key))


class FakeConfigService extends RefCounted:
	var preflight_calls := 0
	var write_calls := 0
	var remove_calls := 0

	func preflight_write_config(_config_type: String, filepath: String, _config: String) -> Dictionary:
		preflight_calls += 1
		return {
			"success": true,
			"requires_confirmation": true,
			"status": "incompatible_mcp",
			"path": filepath,
			"backup_path": filepath + ".bak",
		}

	func write_config_file(_config_type: String, filepath: String, _config: String, _options: Dictionary) -> Dictionary:
		write_calls += 1
		return {
			"success": true,
			"path": filepath,
			"backup_path": filepath + ".bak",
		}

	func inspect_config_entry(_config_type: String, _filepath: String) -> Dictionary:
		return {
			"success": true,
			"status": "missing_server",
			"noop_reason": "missing_server",
		}

	func remove_config_entry(_config_type: String, _filepath: String, _options: Dictionary) -> Dictionary:
		remove_calls += 1
		return {}


class Recorder extends RefCounted:
	var messages: Array[String] = []
	var confirmations: Array[String] = []
	var confirmed_count := 0
	var refresh_count := 0
	var invalidate_count := 0

	func show_message(message: String) -> void:
		messages.append(message)

	func show_confirmation(message: String, on_confirmed: Callable) -> void:
		confirmations.append(message)
		if on_confirmed.is_valid():
			confirmed_count += 1
			on_confirmed.call()

	func refresh_dock() -> void:
		refresh_count += 1

	func invalidate_cache() -> void:
		invalidate_count += 1


func run_case(_tree: SceneTree) -> Dictionary:
	var workflow = ConfigFeatureConfigWorkflow.new()
	var config_service = FakeConfigService.new()
	var recorder = Recorder.new()
	var status_provider := func() -> Dictionary:
		return {
			"cursor": {
				"runtime_status": {
					"status": "running"
				}
			}
		}
	var context = PluginConfigFeatureConfigWorkflowContext.new()
	context.localization = FakeLocalization.new()
	context.config_service = config_service
	context.get_statuses = status_provider
	context.show_message = Callable(recorder, "show_message")
	context.show_confirmation = Callable(recorder, "show_confirmation")
	context.refresh_dock = Callable(recorder, "refresh_dock")
	context.invalidate_client_install_status_cache = Callable(recorder, "invalidate_cache")
	workflow.configure(context)

	workflow.handle_write_requested("cursor", "C:/cursor/mcp.json", "{ }", "Cursor")
	if config_service.preflight_calls != 1:
		return _failure("Config workflow should preflight writes before execution.")
	if config_service.write_calls != 1:
		return _failure("Config workflow should perform the write after confirmation.")
	if recorder.confirmations.is_empty():
		return _failure("Config workflow should request confirmation for incompatible MCP overwrite.")
	var confirmation = recorder.confirmations[0]
	if confirmation.find("Overwrite Cursor") == -1 or confirmation.find("Incompatible MCP at C:/cursor/mcp.json") == -1:
		return _failure("Config workflow confirmation message is missing overwrite context.")
	if recorder.messages.is_empty():
		return _failure("Config workflow should emit a success message after a confirmed write.")
	var success_message = recorder.messages[0]
	if success_message.find("Configured Cursor") == -1 or success_message.find("Restart Cursor") == -1:
		return _failure("Config workflow success message should include the client follow-up hint.")
	if recorder.refresh_count != 1 or recorder.invalidate_count != 1:
		return _failure("Config workflow should refresh dock state and invalidate install cache after a successful write.")

	workflow.handle_remove_requested("cursor", "C:/cursor/mcp.json", "Cursor")
	if config_service.remove_calls != 0:
		return _failure("Config workflow should not call remove when the entry is already absent.")
	if recorder.messages.size() < 2 or recorder.messages[1].find("No entry for Cursor") == -1:
		return _failure("Config workflow should emit the noop remove message when no entry exists.")

	workflow.dispose()
	return {
		"name": "config_feature_config_workflow_contracts",
		"success": true,
		"error": "",
		"details": {
			"confirmation_count": recorder.confirmations.size(),
			"message_count": recorder.messages.size(),
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "config_feature_config_workflow_contracts",
		"success": false,
		"error": message,
	}
