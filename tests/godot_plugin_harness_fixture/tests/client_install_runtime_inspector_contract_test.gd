extends RefCounted

const ClientInstallRuntimeInspector = preload("res://addons/godot_dotnet_mcp/plugin/config/client_install_runtime_inspector.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var inspector = ClientInstallRuntimeInspector.new()
	var running_state = inspector.build_runtime_state(
		"C:/Programs/Cursor/Cursor.exe",
		["cursor.exe"],
		PackedStringArray(["cursor.exe", "godot.exe"])
	)
	if str(running_state.get("status", "")) != ClientInstallRuntimeInspector.RUNTIME_RUNNING:
		return _failure("Client install runtime inspector should report running when the process image matches.")

	var stopped_state = inspector.build_runtime_state(
		"C:/Programs/Cursor/Cursor.exe",
		["cursor.exe"],
		PackedStringArray(["godot.exe"])
	)
	if str(stopped_state.get("status", "")) != ClientInstallRuntimeInspector.RUNTIME_NOT_RUNNING:
		return _failure("Client install runtime inspector should report not_running when no process image matches.")

	var unknown_state = inspector.build_runtime_state(
		"",
		[],
		PackedStringArray(["godot.exe"])
	)
	if str(unknown_state.get("status", "")) != ClientInstallRuntimeInspector.RUNTIME_UNKNOWN:
		return _failure("Client install runtime inspector should report unknown when no runtime image names are provided.")

	return {
		"name": "client_install_runtime_inspector_contracts",
		"success": true,
		"error": "",
		"details": {
			"running_status": str(running_state.get("status", "")),
			"stopped_status": str(stopped_state.get("status", "")),
			"unknown_status": str(unknown_state.get("status", "")),
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "client_install_runtime_inspector_contracts",
		"success": false,
		"error": message,
	}
