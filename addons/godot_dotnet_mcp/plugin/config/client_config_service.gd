@tool
extends RefCounted
class_name ClientConfigService

const ConfigPathsScript = preload("res://addons/godot_dotnet_mcp/plugin/config/config_paths.gd")
const MCP_SERVER_KEY := "godot-mcp"


func get_claude_config_path() -> String:
	return ConfigPathsScript.get_claude_config_path()


func get_cursor_config_path() -> String:
	return ConfigPathsScript.get_cursor_config_path()


func get_trae_config_path() -> String:
	return ConfigPathsScript.get_trae_config_path()


func get_gemini_config_path() -> String:
	return ConfigPathsScript.get_gemini_config_path()


func get_codex_config_path() -> String:
	return ConfigPathsScript.get_codex_config_path()


func get_opencode_config_path() -> String:
	return ConfigPathsScript.get_opencode_config_path()


func get_url_config(host: String, port: int) -> String:
	return ConfigPathsScript.get_url_config(host, port)


func get_http_url_config(host: String, port: int) -> String:
	return ConfigPathsScript.get_http_url_config(host, port)


func get_command_config(command: String, args: Array) -> String:
	return ConfigPathsScript.get_command_config(command, args)


func get_opencode_local_config(command: String, args: Array) -> String:
	return ConfigPathsScript.get_opencode_local_config(command, args)


func get_opencode_remote_config(host: String, port: int) -> String:
	return ConfigPathsScript.get_opencode_remote_config(host, port)


func get_claude_code_command(scope: String, host: String, port: int) -> String:
	return ConfigPathsScript.get_claude_code_command(scope, host, port)


func get_codex_command(host: String, port: int) -> String:
	return ConfigPathsScript.get_codex_command(host, port)


func get_claude_code_stdio_command(scope: String, command: String, args: Array) -> String:
	return ConfigPathsScript.get_claude_code_stdio_command(scope, command, args)


func get_codex_stdio_command(command: String, args: Array) -> String:
	return ConfigPathsScript.get_codex_stdio_command(command, args)


func preflight_write_config(config_type: String, filepath: String, new_config: String) -> Dictionary:
	var prepared = _prepare_new_config(new_config, config_type)
	if not bool(prepared.get("success", false)):
		prepared["config_type"] = config_type
		prepared["path"] = filepath
		return prepared

	var result := {
		"success": true,
		"config_type": config_type,
		"path": filepath,
		"status": "missing",
		"requires_confirmation": false,
		"has_existing_file": FileAccess.file_exists(filepath),
		"backup_path": _get_backup_path(filepath),
		"server_names": prepared.get("server_names", PackedStringArray())
	}

	if not bool(result.get("has_existing_file", false)):
		return result

	var existing_read = _read_text_file(filepath)
	if not bool(existing_read.get("success", false)):
		return {
			"success": false,
			"config_type": config_type,
			"path": filepath,
			"error": "precheck_read_error"
		}

	var existing_text = str(existing_read.get("text", ""))
	if existing_text.strip_edges().is_empty():
		result["status"] = "empty"
		return result

	var json = JSON.new()
	if json.parse(existing_text) != OK:
		result["status"] = "invalid_json"
		result["requires_confirmation"] = true
		return result

	var existing_root = json.get_data()
	if not (existing_root is Dictionary):
		result["status"] = "incompatible_root"
		result["requires_confirmation"] = true
		return result

	var container_key = _get_server_container_key(config_type)
	if existing_root.has(container_key) and not (existing_root.get(container_key) is Dictionary):
		result["status"] = "incompatible_mcp" if config_type == "opencode" else "incompatible_mcp_servers"
		result["requires_confirmation"] = true
		return result

	result["status"] = "mergeable"
	return result


func write_config_file(config_type: String, filepath: String, new_config: String, options: Dictionary = {}) -> Dictionary:
	var prepared = _prepare_new_config(new_config, config_type)
	if not bool(prepared.get("success", false)):
		prepared["config_type"] = config_type
		prepared["path"] = filepath
		return prepared

	var preflight = options.get("preflight", {})
	if not (preflight is Dictionary) or preflight.is_empty():
		preflight = preflight_write_config(config_type, filepath, new_config)
	if not bool(preflight.get("success", false)):
		return preflight

	var preflight_status = str(preflight.get("status", "missing"))
	var allow_incompatible_overwrite = bool(options.get("allow_incompatible_overwrite", false))
	if _preflight_requires_confirmation(preflight_status) and not allow_incompatible_overwrite:
		return {
			"success": false,
			"error": "precheck_confirmation_required",
			"path": filepath,
			"status": preflight_status,
			"backup_path": str(preflight.get("backup_path", _get_backup_path(filepath)))
		}

	var new_config_data: Dictionary = prepared.get("config_data", {})
	var new_servers: Dictionary = prepared.get("new_servers", {})
	var final_config: Dictionary = {}
	var had_existing_file = bool(preflight.get("has_existing_file", FileAccess.file_exists(filepath)))
	var backup_path := ""

	if had_existing_file:
		var backup_result = _backup_existing_file(filepath)
		if not bool(backup_result.get("success", false)):
			return {
				"success": false,
				"error": "backup_error",
				"path": filepath,
				"backup_path": str(backup_result.get("backup_path", _get_backup_path(filepath)))
			}
		backup_path = str(backup_result.get("backup_path", ""))

	if preflight_status == "mergeable":
		var existing_read = _read_text_file(filepath)
		if not bool(existing_read.get("success", false)):
			return {
				"success": false,
				"error": "precheck_read_error",
				"path": filepath
			}
		var existing_text = str(existing_read.get("text", ""))
		if not existing_text.strip_edges().is_empty():
			var json = JSON.new()
			if json.parse(existing_text) == OK and json.get_data() is Dictionary:
				final_config = json.get_data()

	if final_config.is_empty():
		final_config = {}

	var container_key = _get_server_container_key(config_type)
	var merged_servers = final_config.get(container_key, {})
	if not (merged_servers is Dictionary):
		merged_servers = {}

	for server_name in new_servers.keys():
		merged_servers[server_name] = new_servers[server_name]

	final_config[container_key] = merged_servers

	var dir_path = filepath.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var err = DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			return {"success": false, "error": "dir_error", "path": dir_path}

	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		var rollback_result = _rollback_config_write(filepath, backup_path, had_existing_file)
		return _merge_rollback_result({
			"success": false,
			"error": "write_error",
			"path": filepath,
			"backup_path": backup_path
		}, rollback_result)

	file.store_string(JSON.stringify(final_config, "  "))
	file.close()

	var verify_result = _verify_written_config(config_type, filepath, new_servers)
	if not bool(verify_result.get("success", false)):
		var rollback_result = _rollback_config_write(filepath, backup_path, had_existing_file)
		verify_result["config_type"] = config_type
		verify_result["path"] = filepath
		verify_result["backup_path"] = backup_path
		return _merge_rollback_result(verify_result, rollback_result)

	return {
		"success": true,
		"config_type": config_type,
		"path": filepath,
		"preflight_status": preflight_status,
		"backup_path": backup_path,
		"verified": true,
		"verified_servers": verify_result.get("verified_servers", [])
	}


func inspect_config_entry(config_type: String, filepath: String, server_name: String = MCP_SERVER_KEY) -> Dictionary:
	if not FileAccess.file_exists(filepath):
		return {
			"success": true,
			"config_type": config_type,
			"path": filepath,
			"status": "missing_file",
			"has_server_entry": false,
			"backup_path": _get_backup_path(filepath),
			"server_name": server_name
		}

	var read_result = _read_text_file(filepath)
	if not bool(read_result.get("success", false)):
		return {
			"success": false,
			"config_type": config_type,
			"path": filepath,
			"error": "precheck_read_error",
			"server_name": server_name
		}

	var text = str(read_result.get("text", ""))
	if text.strip_edges().is_empty():
		return {
			"success": true,
			"config_type": config_type,
			"path": filepath,
			"status": "empty",
			"has_server_entry": false,
			"backup_path": _get_backup_path(filepath),
			"server_name": server_name
		}

	var json = JSON.new()
	if json.parse(text) != OK:
		return {
			"success": true,
			"config_type": config_type,
			"path": filepath,
			"status": "invalid_json",
			"has_server_entry": false,
			"backup_path": _get_backup_path(filepath),
			"server_name": server_name
		}

	var root = json.get_data()
	if not (root is Dictionary):
		return {
			"success": true,
			"config_type": config_type,
			"path": filepath,
			"status": "incompatible_root",
			"has_server_entry": false,
			"backup_path": _get_backup_path(filepath),
			"server_name": server_name
		}

	var container_key = _get_server_container_key(config_type)
	var incompatible_status = "incompatible_mcp" if config_type == "opencode" else "incompatible_mcp_servers"
	var mcp_servers = root.get(container_key, {})
	if not (mcp_servers is Dictionary):
		return {
			"success": true,
			"config_type": config_type,
			"path": filepath,
			"status": incompatible_status,
			"has_server_entry": false,
			"backup_path": _get_backup_path(filepath),
			"server_name": server_name
		}

	if not mcp_servers.has(server_name):
		return {
			"success": true,
			"config_type": config_type,
			"path": filepath,
			"status": "missing_server",
			"has_server_entry": false,
			"backup_path": _get_backup_path(filepath),
			"server_name": server_name
		}

	return {
		"success": true,
		"config_type": config_type,
		"path": filepath,
		"status": "present",
		"has_server_entry": true,
		"backup_path": _get_backup_path(filepath),
		"server_name": server_name
	}


func remove_config_entry(
	config_type: String,
	filepath: String,
	options: Dictionary = {},
	server_name: String = MCP_SERVER_KEY
) -> Dictionary:
	var inspection = options.get("inspection", {})
	if not (inspection is Dictionary) or inspection.is_empty():
		inspection = inspect_config_entry(config_type, filepath, server_name)
	if not bool(inspection.get("success", false)):
		return inspection

	var status = str(inspection.get("status", "missing_file"))
	if status == "missing_file" or status == "empty" or status == "missing_server":
		return {
			"success": true,
			"config_type": config_type,
			"path": filepath,
			"removed": false,
			"noop_reason": status,
			"server_name": server_name
		}

	if status == "invalid_json" or status == "incompatible_root" or status == "incompatible_mcp_servers" or status == "incompatible_mcp":
		return {
			"success": false,
			"config_type": config_type,
			"path": filepath,
			"error": "remove_blocked_%s" % status,
			"backup_path": str(inspection.get("backup_path", _get_backup_path(filepath))),
			"server_name": server_name
		}

	var read_result = _read_text_file(filepath)
	if not bool(read_result.get("success", false)):
		return {
			"success": false,
			"config_type": config_type,
			"path": filepath,
			"error": "precheck_read_error",
			"server_name": server_name
		}

	var json = JSON.new()
	if json.parse(str(read_result.get("text", ""))) != OK:
		return {
			"success": false,
			"config_type": config_type,
			"path": filepath,
			"error": "remove_blocked_invalid_json",
			"server_name": server_name
		}
	var root = json.get_data()
	if not (root is Dictionary):
		return {
			"success": false,
			"config_type": config_type,
			"path": filepath,
			"error": "remove_blocked_incompatible_root",
			"server_name": server_name
		}
	var container_key = _get_server_container_key(config_type)
	var incompatible_error = "remove_blocked_incompatible_mcp" if config_type == "opencode" else "remove_blocked_incompatible_mcp_servers"
	var mcp_servers = root.get(container_key, {})
	if not (mcp_servers is Dictionary):
		return {
			"success": false,
			"config_type": config_type,
			"path": filepath,
			"error": incompatible_error,
			"server_name": server_name
		}

	var backup_result = _backup_existing_file(filepath)
	if not bool(backup_result.get("success", false)):
		return {
			"success": false,
			"config_type": config_type,
			"path": filepath,
			"error": "backup_error",
			"backup_path": str(backup_result.get("backup_path", _get_backup_path(filepath))),
			"server_name": server_name
		}
	var backup_path = str(backup_result.get("backup_path", ""))

	mcp_servers.erase(server_name)
	if mcp_servers.is_empty():
		root.erase(container_key)
	else:
		root[container_key] = mcp_servers

	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		var rollback_result = _rollback_config_write(filepath, backup_path, true)
		return _merge_rollback_result({
			"success": false,
			"config_type": config_type,
			"path": filepath,
			"error": "write_error",
			"backup_path": backup_path,
			"server_name": server_name
		}, rollback_result)
	file.store_string(JSON.stringify(root, "  "))
	file.close()

	var verify_result = _verify_removed_config(config_type, filepath, server_name)
	if not bool(verify_result.get("success", false)):
		var rollback_result = _rollback_config_write(filepath, backup_path, true)
		verify_result["config_type"] = config_type
		verify_result["path"] = filepath
		verify_result["backup_path"] = backup_path
		verify_result["server_name"] = server_name
		return _merge_rollback_result(verify_result, rollback_result)

	return {
		"success": true,
		"config_type": config_type,
		"path": filepath,
		"removed": true,
		"backup_path": backup_path,
		"server_name": server_name
	}


func execute_cli_command(executable_path: String, arguments: PackedStringArray) -> Dictionary:
	var command = executable_path.strip_edges()
	if command.is_empty():
		return {
			"success": false,
			"exit_code": -1,
			"output": [],
			"message": "CLI executable path is empty."
		}

	var invocation = _build_cli_invocation(command, arguments)
	var output: Array = []
	var exit_code = OS.execute(
		str(invocation.get("command", "")),
		invocation.get("arguments", PackedStringArray()),
		output,
		true,
		false
	)
	return {
		"success": exit_code == 0,
		"exit_code": exit_code,
		"output": output,
		"message": "\n".join(output)
	}


func launch_desktop_client(executable_path: String, arguments: PackedStringArray, working_directory: String) -> Dictionary:
	if executable_path.strip_edges().is_empty():
		return {
			"success": false,
			"error": "missing_executable",
			"message": "Client executable path is empty."
		}

	if working_directory.strip_edges().is_empty() or not DirAccess.dir_exists_absolute(working_directory):
		return {
			"success": false,
			"error": "invalid_working_directory",
			"message": "The target project directory does not exist."
		}

	var arg_literals: PackedStringArray = PackedStringArray()
	for argument in arguments:
		arg_literals.append(_to_powershell_literal(str(argument)))

	var script := "$argList = @(%s); Start-Process -FilePath %s -WorkingDirectory %s -ArgumentList $argList | Out-Null" % [
		", ".join(arg_literals),
		_to_powershell_literal(executable_path),
		_to_powershell_literal(working_directory)
	]
	return _launch_powershell_background(script)


func launch_cli_client_in_terminal(executable_path: String, arguments: PackedStringArray, working_directory: String) -> Dictionary:
	if executable_path.strip_edges().is_empty():
		return {
			"success": false,
			"error": "missing_executable",
			"message": "CLI executable path is empty."
		}

	if working_directory.strip_edges().is_empty() or not DirAccess.dir_exists_absolute(working_directory):
		return {
			"success": false,
			"error": "invalid_working_directory",
			"message": "The target project directory does not exist."
		}

	if OS.get_name() == "Windows":
		return _launch_windows_cli_terminal(executable_path, arguments, working_directory)

	var invocation = _build_cli_invocation(executable_path, arguments)
	var command_line := "& %s" % _to_powershell_literal(str(invocation.get("command", "")))
	for argument in invocation.get("arguments", PackedStringArray()):
		command_line += " %s" % _to_powershell_literal(str(argument))

	var script := "Set-Location -LiteralPath %s; %s" % [
		_to_powershell_literal(working_directory),
		command_line
	]
	return _launch_powershell_terminal(script)


func _build_cli_invocation(executable_path: String, arguments: PackedStringArray) -> Dictionary:
	var lower_path = executable_path.to_lower()
	if lower_path.ends_with(".cmd") or lower_path.ends_with(".bat"):
		var wrapped_args := PackedStringArray(["/c", executable_path])
		wrapped_args.append_array(arguments)
		return {
			"command": "cmd.exe",
			"arguments": wrapped_args
		}

	return {
		"command": executable_path,
		"arguments": arguments
	}


func _launch_powershell_background(script: String) -> Dictionary:
	var pid = OS.create_process(
		"powershell.exe",
		PackedStringArray([
			"-NoProfile",
			"-ExecutionPolicy",
			"Bypass",
			"-Command",
			script
		]),
		false
	)
	return {
		"success": pid > 0,
		"pid": pid,
		"message": "Client process launched." if pid > 0 else "Failed to launch client process."
	}


func _launch_powershell_terminal(script: String) -> Dictionary:
	var pid = OS.create_process(
		"powershell.exe",
		PackedStringArray([
			"-NoExit",
			"-NoProfile",
			"-ExecutionPolicy",
			"Bypass",
			"-Command",
			script
		]),
		true
	)
	return {
		"success": pid > 0,
		"pid": pid,
		"message": "CLI client terminal launched." if pid > 0 else "Failed to launch CLI client terminal."
	}


func _launch_windows_cli_terminal(executable_path: String, arguments: PackedStringArray, working_directory: String) -> Dictionary:
	var command_line = _build_windows_cli_command_line(executable_path, arguments)
	var cmd_script = "cd /d %s && %s" % [
		_to_cmd_literal(working_directory),
		command_line
	]
	var pid = OS.create_process(
		"cmd.exe",
		PackedStringArray([
			"/k",
			cmd_script
		]),
		true
	)
	return {
		"success": pid > 0,
		"pid": pid,
		"message": "CLI client terminal launched." if pid > 0 else "Failed to launch CLI client terminal."
	}


func _build_windows_cli_command_line(executable_path: String, arguments: PackedStringArray) -> String:
	var lower_path = executable_path.to_lower()
	var command_parts := PackedStringArray()
	if lower_path.ends_with(".cmd") or lower_path.ends_with(".bat"):
		command_parts.append("call")
	command_parts.append(_to_cmd_literal(executable_path))
	for argument in arguments:
		command_parts.append(_to_cmd_literal(str(argument)))
	return " ".join(command_parts)


func open_target_path(target_path: String) -> Dictionary:
	var normalized_path = str(target_path).strip_edges()
	if normalized_path.is_empty():
		return {
			"success": false,
			"message": "Target path is empty."
		}
	var windows_result = _open_target_path_windows(normalized_path)
	if bool(windows_result.get("handled", false)):
		return windows_result

	var open_error = OS.shell_open(normalized_path)
	if open_error != OK:
		return {
			"success": false,
			"message": "Failed to open the requested path.",
			"path": normalized_path
		}
	return {
		"success": true,
		"message": "Opened the requested path.",
		"path": normalized_path
	}


func open_text_file(target_path: String) -> Dictionary:
	var normalized_path = str(target_path).strip_edges()
	if normalized_path.is_empty():
		return {
			"success": false,
			"message": "Target path is empty."
		}

	var absolute_path = ProjectSettings.globalize_path(normalized_path)
	if not FileAccess.file_exists(absolute_path):
		return {
			"success": false,
			"message": "The requested path does not exist.",
			"path": absolute_path
		}

	if OS.get_name() == "Windows":
		var notepad_pid = OS.create_process("notepad.exe", PackedStringArray([absolute_path]), false)
		return {
			"success": notepad_pid > 0,
			"message": "Opened the requested file." if notepad_pid > 0 else "Failed to open the requested file.",
			"path": absolute_path
		}

	var open_error = OS.shell_open(absolute_path)
	if open_error != OK:
		return {
			"success": false,
			"message": "Failed to open the requested file.",
			"path": absolute_path
		}
	return {
		"success": true,
		"message": "Opened the requested file.",
		"path": absolute_path
	}


func _open_target_path_windows(normalized_path: String) -> Dictionary:
	if OS.get_name() != "Windows":
		return {"handled": false}

	var absolute_path = ProjectSettings.globalize_path(normalized_path)
	if FileAccess.file_exists(absolute_path):
		var file_pid = OS.create_process(
			"explorer.exe",
			PackedStringArray(["/select,%s" % absolute_path]),
			false
		)
		return {
			"handled": true,
			"success": file_pid > 0,
			"message": "Opened the requested path." if file_pid > 0 else "Failed to open the requested path.",
			"path": absolute_path
		}

	if DirAccess.dir_exists_absolute(absolute_path):
		var dir_pid = OS.create_process(
			"explorer.exe",
			PackedStringArray([absolute_path]),
			false
		)
		return {
			"handled": true,
			"success": dir_pid > 0,
			"message": "Opened the requested path." if dir_pid > 0 else "Failed to open the requested path.",
			"path": absolute_path
		}

	return {
		"handled": true,
		"success": false,
		"message": "The requested path does not exist.",
		"path": absolute_path
	}


func _to_powershell_literal(value: String) -> String:
	return "'%s'" % value.replace("'", "''")


func _to_cmd_literal(value: String) -> String:
	return "\"%s\"" % value.replace("\"", "\"\"")


func _prepare_new_config(new_config: String, config_type: String = "") -> Dictionary:
	var json = JSON.new()
	if json.parse(new_config) != OK:
		return {"success": false, "error": "parse_error"}

	var new_config_data = json.get_data()
	if not (new_config_data is Dictionary):
		return {"success": false, "error": "parse_error"}

	var new_servers = new_config_data.get(_get_server_container_key(config_type), {})
	if not (new_servers is Dictionary):
		return {"success": false, "error": "parse_error"}

	var server_names := PackedStringArray()
	for server_name in new_servers.keys():
		server_names.append(str(server_name))

	return {
		"success": true,
		"config_data": new_config_data,
		"new_servers": new_servers,
		"server_names": server_names
	}


func _preflight_requires_confirmation(status: String) -> bool:
	return status == "invalid_json" or status == "incompatible_root" or status == "incompatible_mcp_servers"


func _get_backup_path(filepath: String) -> String:
	return "%s.bak" % filepath


func _backup_existing_file(filepath: String) -> Dictionary:
	var backup_path = _get_backup_path(filepath)
	var copy_result = _copy_text_file(filepath, backup_path)
	if not bool(copy_result.get("success", false)):
		return {
			"success": false,
			"backup_path": backup_path
		}
	return {
		"success": true,
		"backup_path": backup_path
	}


func _rollback_config_write(filepath: String, backup_path: String, had_existing_file: bool) -> Dictionary:
	if had_existing_file and not backup_path.is_empty() and FileAccess.file_exists(backup_path):
		var restore_result = _copy_text_file(backup_path, filepath)
		if not bool(restore_result.get("success", false)):
			return {
				"rollback_restored": false,
				"rollback_error": "restore_failed",
				"rollback_path": filepath,
				"backup_path": backup_path
			}
		return {
			"rollback_restored": true,
			"backup_path": backup_path
		}

	if FileAccess.file_exists(filepath):
		DirAccess.remove_absolute(filepath)
	return {
		"rollback_restored": false,
		"backup_path": backup_path
	}


func _merge_rollback_result(result: Dictionary, rollback_result: Dictionary) -> Dictionary:
	for key in rollback_result.keys():
		result[key] = rollback_result[key]
	return result


func _copy_text_file(from_path: String, to_path: String) -> Dictionary:
	var read_result = _read_text_file(from_path)
	if not bool(read_result.get("success", false)):
		return {"success": false}

	var dir_path = to_path.get_base_dir()
	if not dir_path.is_empty() and not DirAccess.dir_exists_absolute(dir_path):
		var dir_error = DirAccess.make_dir_recursive_absolute(dir_path)
		if dir_error != OK:
			return {"success": false}

	var file = FileAccess.open(to_path, FileAccess.WRITE)
	if file == null:
		return {"success": false}
	file.store_string(str(read_result.get("text", "")))
	file.close()
	return {"success": true}


func _read_text_file(filepath: String) -> Dictionary:
	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		return {"success": false}
	var text = file.get_as_text()
	file.close()
	return {
		"success": true,
		"text": text
	}


func _verify_removed_config(config_type: String, filepath: String, server_name: String) -> Dictionary:
	if not FileAccess.file_exists(filepath):
		return {
			"success": false,
			"error": "readback_missing_file"
		}

	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		return {
			"success": false,
			"error": "readback_open_error"
		}
	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(text) != OK:
		return {
			"success": false,
			"error": "readback_parse_error"
		}
	var root = json.get_data()
	if not (root is Dictionary):
		return {
			"success": false,
			"error": "readback_parse_error"
		}

	var container_key = _get_server_container_key(config_type)
	if not root.has(container_key):
		return {
			"success": true
		}

	var actual_servers = root.get(container_key, {})
	if not (actual_servers is Dictionary):
		return {
			"success": false,
			"error": "readback_missing_servers"
		}
	if actual_servers.has(server_name):
		return {
			"success": false,
			"error": "readback_remove_mismatch",
			"server_name": server_name
		}
	return {
		"success": true
	}


func _verify_written_config(config_type: String, filepath: String, expected_servers: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(filepath):
		return {
			"success": false,
			"error": "readback_missing_file"
		}

	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		return {
			"success": false,
			"error": "readback_open_error"
		}

	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(text) != OK:
		return {
			"success": false,
			"error": "readback_parse_error"
		}

	var root = json.get_data()
	if not (root is Dictionary):
		return {
			"success": false,
			"error": "readback_parse_error"
		}

	var actual_servers = root.get(_get_server_container_key(config_type), {})
	if not (actual_servers is Dictionary):
		return {
			"success": false,
			"error": "readback_missing_servers"
		}

	var verified_servers: Array[String] = []
	for server_name in expected_servers.keys():
		if not actual_servers.has(server_name):
			return {
				"success": false,
				"error": "readback_missing_server",
				"server_name": str(server_name)
			}
		if not _variants_equal_deep(actual_servers[server_name], expected_servers[server_name]):
			return {
				"success": false,
				"error": "readback_mismatch",
				"server_name": str(server_name)
			}
		verified_servers.append(str(server_name))

	return {
		"success": true,
		"verified_servers": verified_servers
	}


func _get_server_container_key(config_type: String) -> String:
	return "mcp" if config_type == "opencode" else "mcpServers"


func _variants_equal_deep(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		return false

	match typeof(left):
		TYPE_DICTIONARY:
			var left_dict: Dictionary = left
			var right_dict: Dictionary = right
			if left_dict.size() != right_dict.size():
				return false
			for key in left_dict.keys():
				if not right_dict.has(key):
					return false
				if not _variants_equal_deep(left_dict[key], right_dict[key]):
					return false
			return true
		TYPE_ARRAY:
			var left_array: Array = left
			var right_array: Array = right
			if left_array.size() != right_array.size():
				return false
			for index in range(left_array.size()):
				if not _variants_equal_deep(left_array[index], right_array[index]):
					return false
			return true
		_:
			return left == right
