@tool
extends "res://addons/godot_dotnet_mcp/tools/debug/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action := str(args.get("action", "")).strip_edges()
	if action != "build" and action != "restore":
		return _error("Unknown action: %s" % action)

	var timeout_sec := int(args.get("timeout_sec", DOTNET_DEFAULT_TIMEOUT_SEC))
	if timeout_sec <= 0:
		timeout_sec = DOTNET_DEFAULT_TIMEOUT_SEC

	var project_path := _resolve_csproj_path(str(args.get("path", "")))
	if project_path.is_empty():
		return _error("No .csproj file found under res://")

	var command_result := _run_dotnet_command(action, project_path, timeout_sec)
	if not bool(command_result.get("success", false)):
		return command_result

	var data: Dictionary = command_result.get("data", {})
	if action == "build":
		if int(data.get("exit_code", 1)) != 0:
			return _error("dotnet build failed", data)
		return _success(data, "dotnet build completed")

	if int(data.get("exit_code", 1)) != 0:
		return _error("dotnet restore failed", data)
	return _success(data, "dotnet restore completed")


func _resolve_csproj_path(requested_path: String) -> String:
	var normalized_path := _normalize_res_path(requested_path)
	if not normalized_path.is_empty():
		if not normalized_path.ends_with(".csproj"):
			return ""
		if not FileAccess.file_exists(normalized_path):
			return ""
		return normalized_path

	var project_paths := _find_csproj_files("res://")
	if project_paths.is_empty():
		return ""
	return project_paths[0]


func _find_csproj_files(dir_path: String) -> Array[String]:
	var results: Array[String] = []
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return results

	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry.begins_with("."):
			continue
		var child_path = "%s%s" % [dir_path, entry] if dir_path == "res://" else "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			results.append_array(_find_csproj_files(child_path))
		elif entry.ends_with(".csproj"):
			results.append(_normalize_res_path(child_path))
	dir.list_dir_end()

	results.sort()
	return results


func _run_dotnet_command(action: String, project_path: String, timeout_sec: int) -> Dictionary:
	var global_project_path := ProjectSettings.globalize_path(project_path)
	var args: Array[String] = [action, global_project_path, "--nologo", "-v:q"]
	if action == "build":
		args.append("--no-restore")

	var command_result := _execute_process_with_pipe("dotnet", args, timeout_sec)
	if not bool(command_result.get("success", false)):
		return command_result

	var data: Dictionary = command_result.get("data", {})
	var output_text := str(data.get("output_text", ""))
	if bool(data.get("timed_out", false)):
		return _error("dotnet %s timed out" % action, _build_dotnet_result_data(action, project_path, args, data, output_text))

	if _is_dotnet_missing(output_text):
		return _error("dotnet SDK not available", _build_dotnet_result_data(action, project_path, args, data, output_text))

	return {
		"success": true,
		"data": _build_dotnet_result_data(action, project_path, args, data, output_text)
	}


func _build_dotnet_result_data(action: String, project_path: String, args: Array[String], command_data: Dictionary, output_text: String) -> Dictionary:
	var diagnostics := _parse_msbuild_diagnostics(output_text)
	return {
		"action": action,
		"project_path": project_path,
		"project_path_global": ProjectSettings.globalize_path(project_path),
		"command": args.duplicate(),
		"exit_code": int(command_data.get("exit_code", -1)),
		"timed_out": bool(command_data.get("timed_out", false)),
		"duration_ms": int(command_data.get("duration_ms", 0)),
		"warning_count": diagnostics.get("warnings", []).size(),
		"warnings": diagnostics.get("warnings", []),
		"error_count": diagnostics.get("errors", []).size(),
		"errors": diagnostics.get("errors", []),
		"output_line_count": output_text.split("\n").size(),
		"output_excerpt": _build_output_excerpt(output_text, 80)
	}


func _execute_process_with_pipe(executable_name: String, args: Array[String], timeout_sec: int) -> Dictionary:
	var process = OS.execute_with_pipe(executable_name, PackedStringArray(args), false)
	if process.is_empty():
		return _error("Failed to start dotnet process", {
			"command": args.duplicate()
		})

	var pid := int(process.get("pid", -1))
	if pid <= 0:
		return _error("Failed to start dotnet process", {
			"command": args.duplicate(),
			"pid": pid
		})

	var stdio = process.get("stdio")
	var stderr = process.get("stderr")
	var stdout_chunks: Array[String] = []
	var stderr_chunks: Array[String] = []
	var started_msec := Time.get_ticks_msec()
	var timed_out := false

	while OS.is_process_running(pid):
		_read_pipe_chunks(stdio, stdout_chunks)
		_read_pipe_chunks(stderr, stderr_chunks)
		if Time.get_ticks_msec() - started_msec > timeout_sec * 1000:
			timed_out = true
			OS.kill(pid)
			break
		OS.delay_msec(50)

	_read_pipe_chunks(stdio, stdout_chunks)
	_read_pipe_chunks(stderr, stderr_chunks)
	if stdio is FileAccess:
		(stdio as FileAccess).close()
	if stderr is FileAccess:
		(stderr as FileAccess).close()

	var exit_code := -1
	if not timed_out:
		exit_code = OS.get_process_exit_code(pid)

	var output_parts = stdout_chunks.duplicate()
	output_parts.append_array(stderr_chunks)
	return {
		"success": true,
		"data": {
			"exit_code": exit_code,
			"timed_out": timed_out,
			"duration_ms": int(Time.get_ticks_msec() - started_msec),
			"output_text": "\n".join(output_parts).strip_edges()
		}
	}


func _read_pipe_chunks(pipe: Variant, chunks: Array[String]) -> void:
	if not (pipe is FileAccess):
		return

	while true:
		var buffer = (pipe as FileAccess).get_buffer(4096)
		if buffer.is_empty():
			break
		chunks.append(buffer.get_string_from_utf8())
		if buffer.size() < 4096:
			break


func _is_dotnet_missing(output_text: String) -> bool:
	var lowered := output_text.to_lower()
	return lowered.contains("is not recognized as an internal or external command") \
		or lowered.contains("command not found") \
		or lowered.contains("could not execute because the specified command or file was not found")


func _parse_msbuild_diagnostics(output_text: String) -> Dictionary:
	var warnings: Array[Dictionary] = []
	var errors: Array[Dictionary] = []
	var seen_keys := {}
	var regex := RegEx.new()
	regex.compile("^(.*)\\((\\d+)(?:,(\\d+))?\\):\\s+(error|warning)\\s+([A-Za-z]+\\d+):\\s+(.*?)(?:\\s+\\[.*\\])?$")

	for raw_line in output_text.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty():
			continue
		var match_result = regex.search(line)
		if match_result == null:
			continue

		var source_file := str(match_result.get_string(1)).replace("\\", "/")
		var source_line := int(match_result.get_string(2))
		var source_column := 0
		if not str(match_result.get_string(3)).is_empty():
			source_column = int(match_result.get_string(3))
		var severity := str(match_result.get_string(4))
		var code := str(match_result.get_string(5))
		var message := str(match_result.get_string(6)).strip_edges()
		var res_path := _absolute_path_to_res(source_file)
		var dedupe_key := "%s|%d|%d|%s|%s|%s" % [source_file, source_line, source_column, severity, code, message]
		if seen_keys.has(dedupe_key):
			continue
		seen_keys[dedupe_key] = true

		var diagnostic = {
			"severity": severity,
			"code": code,
			"message": message,
			"source_file": source_file,
			"source_path": res_path,
			"source_line": source_line,
			"source_column": source_column,
			"open_command": null if res_path.is_empty() else {
				"path": res_path,
				"line": source_line
			}
		}

		if severity == "warning":
			warnings.append(diagnostic)
		else:
			errors.append(diagnostic)

	return {
		"warnings": warnings,
		"errors": errors
	}


func _absolute_path_to_res(source_file: String) -> String:
	var project_root := ProjectSettings.globalize_path("res://").replace("\\", "/")
	var normalized_source := source_file.replace("\\", "/")
	if OS.get_name() == "Windows":
		project_root = project_root.to_lower()
		normalized_source = normalized_source.to_lower()

	if not normalized_source.begins_with(project_root):
		return ""

	var relative_path = source_file.replace("\\", "/").substr(ProjectSettings.globalize_path("res://").replace("\\", "/").length())
	relative_path = relative_path.trim_prefix("/")
	return "res://%s" % relative_path


func _build_output_excerpt(output_text: String, max_lines: int) -> String:
	var lines = output_text.split("\n")
	if lines.size() <= max_lines:
		return output_text.strip_edges()
	return "\n".join(lines.slice(lines.size() - max_lines)).strip_edges()
