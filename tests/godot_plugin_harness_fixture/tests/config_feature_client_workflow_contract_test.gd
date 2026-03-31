extends RefCounted

const ConfigFeatureClientWorkflow = preload("res://addons/godot_dotnet_mcp/plugin/features/config_feature_client_workflow.gd")
const PluginConfigFeatureClientWorkflowContext = preload("res://addons/godot_dotnet_mcp/plugin/plugin_config_feature_client_workflow_context.gd")


class FakeLocalization extends RefCounted:
	var _texts := {
		"config_validate_success_http": "Transport HTTP ready",
		"config_client_cursor": "Cursor",
		"config_client_codex": "Codex",
		"msg_client_launch_success": "Launch success for %s",
		"msg_client_launch_workdir": "Workdir %s",
		"msg_client_action_success": "Action success for %s",
	}

	func get_text(key: String) -> String:
		return str(_texts.get(key, key))


class FakeConfigService extends RefCounted:
	var desktop_launch_calls := 0
	var execute_commands: Array[Dictionary] = []

	func launch_desktop_client(_executable_path: String, _arguments: PackedStringArray, _working_dir: String) -> Dictionary:
		desktop_launch_calls += 1
		return {"success": true, "message": "ok"}

	func launch_cli_client_in_terminal(_executable_path: String, _arguments: PackedStringArray, _working_dir: String) -> Dictionary:
		return {"success": true, "message": "ok"}

	func execute_cli_command(executable_path: String, arguments: PackedStringArray) -> Dictionary:
		execute_commands.append({
			"executable_path": executable_path,
			"arguments": arguments,
		})
		return {"success": true, "message": "ok"}

	func open_target_path(_path: String) -> Dictionary:
		return {"success": true}

	func open_text_file(_path: String) -> Dictionary:
		return {"success": true}


class FakeDockPresenter extends RefCounted:
	func build_client_transport_model(_settings: Dictionary, _process_status: Dictionary) -> Dictionary:
		return {
			"mode": "http",
			"host": "127.0.0.1",
			"port": 3000,
		}

	func get_client_install_message_text(client_id: String, status: String, _localization) -> String:
		return "%s:%s" % [client_id, status]


class FakeCentralServerProcessService extends RefCounted:
	func validate_client_transport(_host: String, _port: int) -> Dictionary:
		return {
			"success": true,
			"mode": "http",
			"message": "validated",
		}

	func get_status() -> Dictionary:
		return {}


class FakeClientInstallDetectionService extends RefCounted:
	var invalidate_calls := 0
	var configure_calls := 0
	var _statuses := {
		"cursor": {
			"status": "ready",
			"executable_path": "C:/tools/cursor.exe",
			"runtime_status": {"status": "running"},
		},
		"codex": {
			"status": "ready",
			"executable_path": "C:/tools/codex.exe",
			"runtime_status": {"status": "running"},
		}
	}

	func configure(_settings: Dictionary) -> void:
		configure_calls += 1

	func detect_all() -> Dictionary:
		return _statuses.duplicate(true)

	func invalidate_cache() -> void:
		invalidate_calls += 1


class Recorder extends RefCounted:
	var messages: Array[String] = []
	var refresh_calls := 0
	var save_calls := 0

	func show_message(message: String) -> void:
		messages.append(message)

	func refresh_dock() -> void:
		refresh_calls += 1

	func save_settings() -> void:
		save_calls += 1


func run_case(_tree: SceneTree) -> Dictionary:
	var workflow = ConfigFeatureClientWorkflow.new()
	var config_service = FakeConfigService.new()
	var detection_service = FakeClientInstallDetectionService.new()
	var recorder = Recorder.new()
	var settings := {
		"host": "127.0.0.1",
		"port": 3000,
	}
	var context = PluginConfigFeatureClientWorkflowContext.new()
	context.settings = settings
	context.localization = FakeLocalization.new()
	context.config_service = config_service
	context.dock_presenter = FakeDockPresenter.new()
	context.central_server_process_service = FakeCentralServerProcessService.new()
	context.client_install_detection_service = detection_service
	context.show_message = Callable(recorder, "show_message")
	context.refresh_dock = Callable(recorder, "refresh_dock")
	context.save_settings = Callable(recorder, "save_settings")

	workflow.configure(context)

	var statuses = workflow.get_statuses()
	if not statuses.has("cursor") or not statuses.has("codex"):
		return _failure("Client workflow should expose statuses through the public get_statuses API.")

	workflow.handle_validate_requested()
	if recorder.messages.is_empty() or recorder.messages[0].find("Transport HTTP ready") == -1:
		return _failure("Client workflow should emit validate success message when transport is ready.")

	workflow.handle_client_launch_requested("cursor")
	if config_service.desktop_launch_calls != 1:
		return _failure("Client workflow should launch desktop client for cursor.")

	workflow.handle_client_action_requested("codex")
	if config_service.execute_commands.size() != 2:
		return _failure("Client workflow should execute codex remove/add command sequence.")
	var add_arguments: PackedStringArray = config_service.execute_commands[1].get("arguments", PackedStringArray())
	if add_arguments.size() < 4 or add_arguments[0] != "mcp" or add_arguments[1] != "add":
		return _failure("Client workflow should build codex add arguments in expected format.")

	workflow.invalidate_client_install_status_cache()
	if detection_service.invalidate_calls < 3:
		return _failure("Client workflow should invalidate client install cache for launch/action and explicit invalidate.")
	if recorder.refresh_calls < 2:
		return _failure("Client workflow should refresh dock after launch/action success.")

	workflow.dispose()
	return {
		"name": "config_feature_client_workflow_contracts",
		"success": true,
		"error": "",
		"details": {
			"message_count": recorder.messages.size(),
			"invalidate_calls": detection_service.invalidate_calls,
			"refresh_calls": recorder.refresh_calls,
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "config_feature_client_workflow_contracts",
		"success": false,
		"error": message,
	}
