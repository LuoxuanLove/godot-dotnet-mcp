@tool
extends RefCounted
class_name ClientInstallRuntimeInspector

const RUNTIME_RUNNING := "running"
const RUNTIME_NOT_RUNNING := "not_running"
const RUNTIME_UNKNOWN := "unknown"


func collect_running_process_names() -> PackedStringArray:
	var command_result = _run_process("tasklist.exe", PackedStringArray(["/FO", "CSV", "/NH"]))
	if int(command_result.get("exit_code", -1)) != 0:
		return PackedStringArray()

	var process_names := PackedStringArray()
	for chunk in command_result.get("output", []):
		var text = str(chunk).replace("\r", "\n")
		for line in text.split("\n", false):
			var trimmed = line.strip_edges()
			if trimmed.is_empty():
				continue
			if trimmed.begins_with("\""):
				var closing = trimmed.find("\",")
				if closing > 1:
					process_names.append(trimmed.substr(1, closing - 1).to_lower())
	return process_names


func build_runtime_state(executable_path: String, image_names: Array[String], running_processes: PackedStringArray) -> Dictionary:
	if image_names.is_empty():
		return {
			"status": RUNTIME_UNKNOWN,
			"is_running": false
		}

	var candidates: Array[String] = []
	for image_name in image_names:
		var normalized = str(image_name).to_lower().strip_edges()
		if not normalized.is_empty() and not candidates.has(normalized):
			candidates.append(normalized)

	var executable_file = executable_path.get_file().to_lower()
	if not executable_file.is_empty() and executable_file.ends_with(".exe") and not candidates.has(executable_file):
		candidates.append(executable_file)

	for process_name in running_processes:
		if candidates.has(str(process_name).to_lower()):
			return {
				"status": RUNTIME_RUNNING,
				"is_running": true,
				"matched_image": str(process_name)
			}

	return {
		"status": RUNTIME_NOT_RUNNING,
		"is_running": false
	}


func _run_process(executable: String, arguments: PackedStringArray) -> Dictionary:
	var output: Array = []
	var exit_code = OS.execute(executable, arguments, output, true, false)
	return {
		"exit_code": exit_code,
		"output": output
	}
