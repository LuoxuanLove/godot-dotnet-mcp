@tool
extends RefCounted
class_name ClientConfigLauncherAdapter


func execute_cli_command(executable_path: String, arguments: PackedStringArray) -> Dictionary:
	var command = executable_path.strip_edges()
	if command.is_empty():
		return {
			"success": false,
			"exit_code": -1,
			"output": [],
			"message": "CLI executable path is empty."
		}

	var invocation = build_cli_invocation(command, arguments)
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

	var invocation = build_cli_invocation(executable_path, arguments)
	var command_line := "& %s" % _to_powershell_literal(str(invocation.get("command", "")))
	for argument in invocation.get("arguments", PackedStringArray()):
		command_line += " %s" % _to_powershell_literal(str(argument))

	var script := "Set-Location -LiteralPath %s; %s" % [
		_to_powershell_literal(working_directory),
		command_line
	]
	return _launch_powershell_terminal(script)


func build_cli_invocation(executable_path: String, arguments: PackedStringArray) -> Dictionary:
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


func build_windows_cli_command_line(executable_path: String, arguments: PackedStringArray) -> String:
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
	var command_line = build_windows_cli_command_line(executable_path, arguments)
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
