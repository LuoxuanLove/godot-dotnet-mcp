@tool
extends RefCounted
class_name BridgeInstallService

const STATUS_NOT_CONFIGURED := "not_configured"
const STATUS_VALIDATING := "validating"
const STATUS_INSTALLED := "installed"
const STATUS_INVALID := "invalid"


static func build_snapshot(settings: Dictionary) -> Dictionary:
	var executable_path := _normalize_path(str(settings.get("bridge_executable_path", "")))
	var install_state := str(settings.get("bridge_install_state", STATUS_NOT_CONFIGURED))
	var install_source := str(settings.get("bridge_install_source", ""))
	var install_version := str(settings.get("bridge_install_version", ""))
	var install_message := str(settings.get("bridge_install_message", ""))

	if executable_path.is_empty():
		install_state = STATUS_NOT_CONFIGURED
		install_message = ""
	elif not FileAccess.file_exists(executable_path):
		install_state = STATUS_INVALID
		if install_message.is_empty():
			install_message = "Bridge executable is missing."
	elif install_state.is_empty():
		install_state = STATUS_INSTALLED

	return {
		"executable_path": executable_path,
		"install_state": install_state,
		"install_source": install_source,
		"install_version": install_version,
		"install_message": install_message,
		"installed": install_state == STATUS_INSTALLED and not executable_path.is_empty() and FileAccess.file_exists(executable_path),
		"launch_command": _build_launch_command(executable_path)
	}


static func validate_executable(executable_path: String) -> Dictionary:
	var normalized_path := _normalize_path(executable_path)
	if normalized_path.is_empty():
		return {
			"success": false,
			"error_code": "bridge_path_required",
			"message": "Bridge executable path is required."
		}
	if not FileAccess.file_exists(normalized_path):
		return {
			"success": false,
			"error_code": "bridge_path_missing",
			"message": "Bridge executable does not exist.",
			"executable_path": normalized_path
		}

	var version_result := _run_bridge_command(normalized_path, ["--version"])
	if not bool(version_result.get("success", false)):
		return version_result

	var health_result := _run_bridge_command(normalized_path, ["--health"])
	if bool(health_result.get("success", false)):
		health_result["version"] = str(version_result.get("output", health_result.get("version", ""))).strip_edges()
		health_result["launch_command"] = _build_launch_command(normalized_path)
		return health_result

	return {
		"success": false,
		"error_code": "bridge_health_failed",
		"message": "Bridge health check failed.",
		"executable_path": normalized_path,
		"version": str(version_result.get("output", "")).strip_edges(),
		"health": health_result.get("health", {}),
		"exit_code": health_result.get("exit_code", -1),
		"output": str(health_result.get("output", "")),
		"launch_command": _build_launch_command(normalized_path),
	}


static func register_executable(settings: Dictionary, executable_path: String, install_source: String = "manual_file") -> Dictionary:
	var validation = validate_executable(executable_path)
	if not bool(validation.get("success", false)):
		return validation

	var normalized_path := str(validation.get("executable_path", _normalize_path(executable_path)))
	settings["bridge_executable_path"] = normalized_path
	settings["bridge_install_source"] = install_source
	settings["bridge_install_state"] = STATUS_INSTALLED
	settings["bridge_install_version"] = str(validation.get("version", ""))
	settings["bridge_install_message"] = str(validation.get("message", "Bridge executable validated."))
	settings["bridge_install_checked_at"] = Time.get_datetime_string_from_system(true, true)

	return {
		"success": true,
		"settings": settings,
		"snapshot": build_snapshot(settings),
		"message": "Bridge executable registered."
	}


static func clear_executable(settings: Dictionary) -> Dictionary:
	settings["bridge_executable_path"] = ""
	settings["bridge_install_source"] = ""
	settings["bridge_install_state"] = STATUS_NOT_CONFIGURED
	settings["bridge_install_version"] = ""
	settings["bridge_install_message"] = ""
	settings.erase("bridge_install_checked_at")

	return {
		"success": true,
		"settings": settings,
		"snapshot": build_snapshot(settings),
		"message": "Bridge registration cleared."
	}


static func _run_bridge_command(executable_path: String, arguments: Array[String]) -> Dictionary:
	var output: Array = []
	var exit_code := OS.execute(executable_path, arguments, output, true, false)
	var stdout := ""
	for line in output:
		if stdout.is_empty():
			stdout = str(line)
		else:
			stdout += "\n%s" % str(line)
	stdout = stdout.strip_edges()

	var success := exit_code == 0
	var health_data := {}
	if arguments.has("--health") and not stdout.is_empty():
		var parsed = JSON.parse_string(stdout)
		if parsed is Dictionary:
			health_data = (parsed as Dictionary).duplicate(true)

	return {
		"success": success,
		"exit_code": exit_code,
		"output": stdout,
		"health": health_data,
		"executable_path": executable_path,
		"message": "Bridge command executed." if success else "Bridge command failed."
	}


static func _build_launch_command(executable_path: String) -> String:
	if executable_path.is_empty():
		return ""
	return "\"%s\" --health" % executable_path


static func _normalize_path(path_value: String) -> String:
	var normalized := path_value.strip_edges().replace("\\", "/")
	if normalized.begins_with("res://") or normalized.begins_with("user://"):
		return ProjectSettings.globalize_path(normalized).replace("\\", "/")
	return normalized
