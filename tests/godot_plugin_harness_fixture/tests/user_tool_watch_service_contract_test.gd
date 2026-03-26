extends RefCounted

const UserToolWatchService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_watch_service.gd")


class Recorder extends RefCounted:
	var calls: Array[Dictionary] = []

	func record(paths: Array[String], reason: String) -> void:
		calls.append({
			"paths": paths.duplicate(),
			"reason": reason
		})


func run_case(_tree: SceneTree) -> Dictionary:
	var service = UserToolWatchService.new()
	var recorder = Recorder.new()
	service.configure(
		RefCounted.new(),
		null,
		null,
		{"apply_external_user_tool_catalog_refresh": Callable(recorder, "record")}
	)

	var changed_path := "res://addons/godot_dotnet_mcp/custom_tools/sample_watch_target.gd"
	var result: Dictionary = service._apply_pending_changes({
		"removed": [],
		"added": [],
		"changed": [changed_path]
	})
	if not bool(result.get("success", false)):
		return _failure("User tool watcher should apply external refresh via callback.")
	if recorder.calls.size() != 1:
		return _failure("User tool watcher should invoke the external refresh callback once.")

	var call: Dictionary = recorder.calls[0]
	if str(call.get("reason", "")) != "watcher_file_changed":
		return _failure("User tool watcher should preserve the change reason.")

	var paths: Array = call.get("paths", [])
	if paths.size() != 1 or str(paths[0]) != changed_path:
		return _failure("User tool watcher should pass the changed path to the callback.")

	return {
		"name": "user_tool_watch_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"callback_count": recorder.calls.size(),
			"last_reason": str(call.get("reason", "")),
			"last_path": str((paths[0] if paths.size() > 0 else ""))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "user_tool_watch_service_contracts",
		"success": false,
		"error": message
	}
