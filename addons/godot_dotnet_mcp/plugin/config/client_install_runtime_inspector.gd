@tool
extends RefCounted
class_name ClientInstallRuntimeInspector

const RUNTIME_RUNNING := "running"
const RUNTIME_NOT_RUNNING := "not_running"
const RUNTIME_UNKNOWN := "unknown"


func build_runtime_state(executable_path: String, image_names: Array, running_processes: PackedStringArray) -> Dictionary:
	if image_names.is_empty():
		return {
			"status": RUNTIME_UNKNOWN,
			"is_running": false,
			"executable_path": executable_path,
			"image_names": image_names
		}

	var lowered_images: Array[String] = []
	for image_name in image_names:
		lowered_images.append(str(image_name).to_lower())

	for process_name in running_processes:
		var lowered_process = str(process_name).to_lower()
		for image_name in lowered_images:
			if lowered_process.find(image_name) != -1:
				return {
					"status": RUNTIME_RUNNING,
					"is_running": true,
					"executable_path": executable_path,
					"image_names": image_names
				}

	return {
		"status": RUNTIME_NOT_RUNNING,
		"is_running": false,
		"executable_path": executable_path,
		"image_names": image_names
	}
