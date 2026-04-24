extends RefCounted

const ConfigTabActionServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/config/config_tab_action_service.gd")


class FakeLocalization extends RefCounted:
	func get_text(key: String) -> String:
		var texts := {
			"config_client_claude_code": "Claude Code CLI",
			"config_client_codex": "Codex CLI",
			"config_client_gemini": "Gemini CLI",
			"config_client_qwen": "Qwen Code CLI",
			"config_client_claude_desktop": "Claude Desktop",
			"msg_client_action_missing_executable": "Missing executable for %s",
			"msg_client_action_success": "%s connected successfully.",
			"msg_client_action_failed": "%s automatic setup failed.",
			"msg_config_remove_success": "Removed godot-mcp from %s.",
			"msg_config_remove_failed": "Remove failed.",
			"msg_client_launch_success": "%s launched.",
			"msg_client_launch_failed": "%s launch failed.",
			"msg_client_launch_workdir": "Workspace: %s",
			"msg_client_launch_terminal_hint": "Terminal kept open.",
			"msg_client_launch_unsupported": "Unsupported launch.",
			"scope_user": "User (Global)",
			"scope_project": "Project (Current Only)"
		}
		return str(texts.get(key, key))


class FakeConfigService extends RefCounted:
	var cli_calls: Array[Dictionary] = []
	var desktop_launches: Array[Dictionary] = []
	var cli_launches: Array[Dictionary] = []

	func execute_cli_command(executable_path: String, arguments: PackedStringArray) -> Dictionary:
		cli_calls.append({
			"executable_path": executable_path,
			"arguments": Array(arguments)
		})
		return {"success": true, "message": "ok"}

	func launch_desktop_client(executable_path: String, arguments: PackedStringArray, working_directory: String) -> Dictionary:
		desktop_launches.append({
			"executable_path": executable_path,
			"arguments": Array(arguments),
			"working_directory": working_directory
		})
		return {"success": true, "message": "ok"}

	func launch_cli_client_in_terminal(executable_path: String, arguments: PackedStringArray, working_directory: String) -> Dictionary:
		cli_launches.append({
			"executable_path": executable_path,
			"arguments": Array(arguments),
			"working_directory": working_directory
		})
		return {"success": true, "message": "ok"}


class FakeRecorder extends RefCounted:
	var statuses: Dictionary = {}
	var invalidated := 0
	var refreshed := 0
	var saved := 0
	var messages: Array[String] = []

	func get_statuses() -> Dictionary:
		return statuses

	func invalidate() -> void:
		invalidated += 1

	func refresh() -> void:
		refreshed += 1

	func save() -> void:
		saved += 1

	func show_message(message: String) -> void:
		messages.append(message)


class FakeState extends RefCounted:
	var settings := {
		"host": "127.0.0.1",
		"port": 3000,
		"client_manual_paths": {}
	}
	var current_cli_scope := "user"


class FakeContext extends RefCounted:
	var state
	var localization
	var config_service
	var client_install_detection_service
	var get_client_install_statuses := Callable()
	var invalidate_client_install_status_cache := Callable()
	var configure_client_install_detection_service := Callable()
	var refresh_dock := Callable()
	var save_settings := Callable()
	var show_message := Callable()
	var show_confirmation := Callable()
	var ensure_client_executable_dialog := Callable()
	var get_client_executable_dialog := Callable()


func run_case(_tree: SceneTree) -> Dictionary:
	var action_service = ConfigTabActionServiceScript.new()
	var state = FakeState.new()
	var config_service = FakeConfigService.new()
	var recorder = FakeRecorder.new()
	var context = FakeContext.new()
	context.state = state
	context.localization = FakeLocalization.new()
	context.config_service = config_service
	context.client_install_detection_service = RefCounted.new()
	context.get_client_install_statuses = Callable(recorder, "get_statuses")
	context.invalidate_client_install_status_cache = Callable(recorder, "invalidate")
	context.configure_client_install_detection_service = Callable(recorder, "refresh")
	context.refresh_dock = Callable(recorder, "refresh")
	context.save_settings = Callable(recorder, "save")
	context.show_message = Callable(recorder, "show_message")
	action_service.configure(context)

	recorder.statuses = {
		"claude_code": {
			"status": "ready",
			"executable_path": "C:/Tools/claude.exe",
			"config_entry_status": {"status": "missing_server"}
		}
	}
	action_service.handle_config_client_action_requested("claude_code")
	if config_service.cli_calls.is_empty():
		return _failure("Config tab action service should execute Claude Code CLI commands for one-click install.")
	var claude_add = config_service.cli_calls[0]
	if claude_add["arguments"] != ["mcp", "add", "--transport", "http", "--scope", "user", "godot-mcp", "http://127.0.0.1:3000/mcp"]:
		return _failure("Claude Code one-click install should use the documented `claude mcp add --transport http --scope ...` arguments.")

	recorder.statuses["claude_code"]["config_entry_status"] = {"status": "present"}
	action_service.handle_config_client_action_requested("claude_code")
	var claude_remove = config_service.cli_calls[1]
	if claude_remove["arguments"] != ["mcp", "remove", "godot-mcp"]:
		return _failure("Claude Code one-click removal should use `claude mcp remove godot-mcp`.")

	recorder.statuses["codex"] = {
		"status": "ready",
		"executable_path": "C:/Tools/codex.exe",
		"config_entry_status": {"status": "missing_server"}
	}
	action_service.handle_config_client_action_requested("codex")
	var codex_add = config_service.cli_calls[2]
	if codex_add["arguments"] != ["mcp", "add", "godot-mcp", "--url", "http://127.0.0.1:3000/mcp"]:
		return _failure("Codex one-click install should use the documented `codex mcp add godot-mcp --url ...` arguments.")

	recorder.statuses["codex"]["config_entry_status"] = {"status": "present"}
	action_service.handle_config_client_action_requested("codex")
	var codex_remove = config_service.cli_calls[3]
	if codex_remove["arguments"] != ["mcp", "remove", "godot-mcp"]:
		return _failure("Codex one-click removal should use `codex mcp remove godot-mcp`.")

	recorder.statuses["gemini"] = {
		"status": "ready",
		"executable_path": "C:/Tools/gemini.cmd",
		"config_entry_status": {"status": "missing_server"}
	}
	action_service.handle_config_client_action_requested("gemini")
	var gemini_add = config_service.cli_calls[4]
	if gemini_add["arguments"] != ["mcp", "add", "--transport", "http", "--scope", "user", "godot-mcp", "http://127.0.0.1:3000/mcp"]:
		return _failure("Gemini one-click install should use the documented `gemini mcp add --transport http --scope ...` arguments.")

	recorder.statuses["gemini"]["config_entry_status"] = {"status": "present"}
	action_service.handle_config_client_action_requested("gemini")
	var gemini_remove = config_service.cli_calls[5]
	if gemini_remove["arguments"] != ["mcp", "remove", "godot-mcp"]:
		return _failure("Gemini one-click removal should use `gemini mcp remove godot-mcp`.")

	recorder.statuses["qwen"] = {
		"status": "ready",
		"executable_path": "C:/Tools/qwen.cmd",
		"config_entry_status": {"status": "missing_server"}
	}
	action_service.handle_config_client_action_requested("qwen")
	var qwen_add = config_service.cli_calls[6]
	if qwen_add["arguments"] != ["mcp", "add", "--transport", "http", "--scope", "user", "godot-mcp", "http://127.0.0.1:3000/mcp"]:
		return _failure("Qwen Code one-click install should use the documented `qwen mcp add --transport http --scope ...` arguments.")

	recorder.statuses["qwen"]["config_entry_status"] = {"status": "present"}
	action_service.handle_config_client_action_requested("qwen")
	var qwen_remove = config_service.cli_calls[7]
	if qwen_remove["arguments"] != ["mcp", "remove", "godot-mcp"]:
		return _failure("Qwen Code one-click removal should use `qwen mcp remove godot-mcp`.")

	recorder.statuses["claude_desktop"] = {
		"status": "ready",
		"executable_path": "C:/Apps/Claude/Claude.exe"
	}
	action_service.handle_config_client_launch_requested("claude_desktop")
	if config_service.desktop_launches.is_empty():
		return _failure("Config tab action service should allow launching detected desktop clients from the config page.")
	var claude_launch = config_service.desktop_launches[0]
	if claude_launch["executable_path"] != "C:/Apps/Claude/Claude.exe":
		return _failure("Desktop launch should preserve the detected executable path.")
	if claude_launch["arguments"].size() != 0:
		return _failure("Claude Desktop launch should not inject unsupported extra command-line arguments.")

	action_service.handle_config_client_launch_requested("gemini")
	if config_service.cli_launches.is_empty():
		return _failure("Gemini should launch through the CLI terminal flow once the executable path is detected.")
	var gemini_launch = config_service.cli_launches[0]
	if gemini_launch["executable_path"] != "C:/Tools/gemini.cmd":
		return _failure("Gemini CLI launch should preserve the detected executable path.")

	return {
		"name": "config_tab_action_service_contracts",
		"success": true,
		"error": "",
		"details": {
		"cli_call_count": config_service.cli_calls.size(),
			"desktop_launch_count": config_service.desktop_launches.size(),
			"message_count": recorder.messages.size()
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "config_tab_action_service_contracts",
		"success": false,
		"error": message
	}
