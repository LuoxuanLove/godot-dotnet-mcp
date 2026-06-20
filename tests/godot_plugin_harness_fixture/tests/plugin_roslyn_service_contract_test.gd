extends RefCounted

const PluginRoslynServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_roslyn_service.gd")
const SERVICE_SOURCE_PATH := "res://addons/godot_dotnet_mcp/plugin/runtime/plugin_roslyn_service.gd"

var _temp_paths: Array[String] = []
var _service: Node = null
var _fake: FakeRoslynFacade = null


class FakeRoslynFacade extends RefCounted:
	var parse_call_count := 0
	var last_script_path := ""
	var last_source_text := ""
	var invalid_parse_result := false

	func get_capabilities() -> Dictionary:
		return {
			"success": true,
			"data": {
				"engine": "roslyn",
				"mode": "syntax"
			}
		}

	func parse_file(script_path: String, source_text: String = ""):
		parse_call_count += 1
		last_script_path = script_path
		last_source_text = source_text
		if invalid_parse_result:
			return "invalid"
		return {
			"success": true,
			"data": {
				"path": script_path,
				"types": [{"name": _extract_class_name(source_text)}],
				"methods": [],
				"exports": [],
				"parse_errors": []
			},
			"message": "ok"
		}

	func _extract_class_name(source_text: String) -> String:
		var marker := "class "
		var start := source_text.find(marker)
		if start == -1:
			return "Unknown"
		start += marker.length()
		var end := source_text.find(" ", start)
		if end == -1:
			end = source_text.find("{", start)
		if end == -1:
			end = source_text.length()
		return source_text.substr(start, end - start).strip_edges()


func run_case(_tree: SceneTree) -> Dictionary:
	var runtime_guard := _assert_isolated_runtime_process_has_timeout_guards()
	if not bool(runtime_guard.get("success", false)):
		return runtime_guard

	_service = PluginRoslynServiceScript.new()
	_fake = FakeRoslynFacade.new()
	_service.set_facade_for_testing(_fake)

	var temp_dir := "res://tests_tmp/plugin_roslyn_service_contracts"
	_ensure_dir(temp_dir)
	_temp_paths.append("%s/DiskBacked.cs" % temp_dir)
	_temp_paths.append(temp_dir)

	var disk_path := _temp_paths[0]
	var disk_source := "public partial class DiskBacked { }"
	var unsaved_source_a := "public partial class UnsavedA { }"
	var unsaved_source_b := "public partial class UnsavedB { }"
	_write_text(disk_path, disk_source)

	var first: Dictionary = _service.parse_file(disk_path, unsaved_source_a)
	if not bool(first.get("success", false)):
		return _failure("Roslyn service should parse unsaved source text successfully.")
	if _fake.parse_call_count != 1:
		return _failure("Roslyn service should call the façade exactly once for the first unsaved buffer request.")
	if _fake.last_source_text != unsaved_source_a:
		return _failure("Roslyn service must prefer unsaved source_text over disk content when provided.")
	var first_data: Dictionary = first.get("data", {})
	var first_types: Array = first_data.get("types", [])
	if first_types.is_empty() or str((first_types[0] as Dictionary).get("name", "")) != "UnsavedA":
		return _failure("Roslyn service should return results derived from the unsaved text, not the disk file.")

	var cached: Dictionary = _service.parse_file(disk_path, unsaved_source_a)
	if _fake.parse_call_count != 1:
		return _failure("Roslyn service should reuse the cached result when path and source_hash are unchanged.")
	if str(cached.get("data", {}).get("source_hash", "")) != str(first_data.get("source_hash", "")):
		return _failure("Roslyn service cache hit should preserve the same source_hash.")

	var second: Dictionary = _service.parse_file(disk_path, unsaved_source_b)
	if _fake.parse_call_count != 2:
		return _failure("Roslyn service should bypass cache when the same path is analyzed with different source text.")
	var second_data: Dictionary = second.get("data", {})
	if str(second_data.get("source_hash", "")) == str(first_data.get("source_hash", "")):
		return _failure("Roslyn service should compute a different source_hash for different unsaved content.")

	var missing: Dictionary = _service.parse_file("res://tests_tmp/plugin_roslyn_service_contracts/Missing.cs", "")
	if bool(missing.get("success", true)):
		return _failure("Roslyn service should return success=false for a missing disk path.")
	var missing_data: Dictionary = missing.get("data", {})
	if str(missing_data.get("error_code", "")) != "script_path_missing":
		return _failure("Roslyn service should map missing-file failures to error_code=script_path_missing.")
	if str(missing_data.get("engine", "")) != "roslyn" or str(missing_data.get("mode", "")) != "syntax":
		return _failure("Roslyn service failure DTO should still include engine/mode metadata.")

	_fake.invalid_parse_result = true
	_service.clear()
	_service.set_facade_for_testing(_fake)
	var invalid: Dictionary = _service.parse_file("", "public partial class InlineText { }")
	if bool(invalid.get("success", true)):
		return _failure("Roslyn service should normalize invalid façade responses into structured failures.")
	var invalid_data: Dictionary = invalid.get("data", {})
	if str(invalid_data.get("error_type", "")) != "protocol_error":
		return _failure("Roslyn service should map invalid façade responses to error_type=protocol_error.")
	if str(invalid_data.get("source_hash", "")).is_empty():
		return _failure("Roslyn service should preserve source_hash even when the façade response is invalid.")

	var structured_exit_failure: Dictionary = _service._parse_runtime_process_response(JSON.stringify({
		"success": false,
		"isError": true,
		"error": "Bridge reported a structured tool failure.",
		"structuredContent": {
			"errorCode": "cs_file_read_failed"
		},
		"content": "Bridge reported a structured tool failure."
	}), 2)
	if not bool(structured_exit_failure.get("success", false)):
		return _failure("Roslyn service should parse structured runtime JSON before treating non-zero exit codes as process failures.")
	if int(structured_exit_failure.get("exit_code", 0)) != 2:
		return _failure("Roslyn service should preserve the runtime process exit code with structured responses.")
	var structured_payload: Dictionary = structured_exit_failure.get("payload", {})
	if bool(structured_payload.get("success", true)):
		return _failure("Roslyn service should preserve structured tool failure payloads.")

	var converted_exit_failure: Dictionary = _service._convert_bridge_read_response(structured_exit_failure, "res://tests_tmp/plugin_roslyn_service_contracts/BridgeFailure.cs")
	if bool(converted_exit_failure.get("success", true)):
		return _failure("Roslyn service should convert structured runtime tool failures to parse failures.")
	var converted_data: Dictionary = converted_exit_failure.get("data", {})
	if str(converted_data.get("error_type", "")) != "roslyn_failure":
		return _failure("Structured runtime tool failures should map to error_type=roslyn_failure, not runtime_unavailable.")
	if str(converted_data.get("error_code", "")) != "roslyn_parse_failed":
		return _failure("Structured runtime read failures should keep the parse failure error code.")

	var bridge_process_failure: Dictionary = _service._parse_runtime_process_response(JSON.stringify({
		"success": false,
		"error": "Usage: DotnetBridge --capabilities | --call <tool_name> <json_arguments> | --call-json-file <tool_name> <json_file>"
	}), 64)
	if bool(bridge_process_failure.get("success", true)):
		return _failure("Bridge-level JSON failures without tool response shape should remain process failures.")
	if str(bridge_process_failure.get("error_code", "")) != "roslyn_runtime_process_failed":
		return _failure("Bridge-level JSON failures should keep error_code=roslyn_runtime_process_failed.")

	var unstructured_exit_failure: Dictionary = _service._parse_runtime_process_response("fatal bridge crash", 2)
	if bool(unstructured_exit_failure.get("success", true)):
		return _failure("Roslyn service should still report non-JSON non-zero exits as process failures.")
	if str(unstructured_exit_failure.get("error_code", "")) != "roslyn_runtime_process_failed":
		return _failure("Unstructured non-zero runtime exits should keep error_code=roslyn_runtime_process_failed.")

	return {
		"name": "plugin_roslyn_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"cached_parse_calls": _fake.parse_call_count,
			"first_source_hash": str(first_data.get("source_hash", "")),
			"second_source_hash": str(second_data.get("source_hash", "")),
			"missing_error_code": str(missing_data.get("error_code", ""))
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	_cleanup_service()
	for path in _temp_paths:
		if path.ends_with(".cs"):
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for i in range(_temp_paths.size() - 1, -1, -1):
		var path = _temp_paths[i]
		if not path.ends_with(".cs"):
			if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_temp_paths.clear()


func _cleanup_service() -> void:
	if _service != null:
		_service.clear()
		if is_instance_valid(_service):
			_service.free()
	_service = null
	_fake = null


func _ensure_dir(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		DirAccess.make_dir_recursive_absolute(absolute_path)


func _write_text(path: String, content: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to create fixture: %s" % path)
		return
	file.store_string(content)
	file.close()


func _assert_isolated_runtime_process_has_timeout_guards() -> Dictionary:
	var service_source := _read_text(SERVICE_SOURCE_PATH)
	if service_source.is_empty():
		return _failure("PluginRoslynService source should be readable for timeout guard checks.")
	for required_text in [
		"RUNTIME_PROCESS_TIMEOUT_MS",
		"OS.create_process",
		"OS.kill(pid)",
		"--timeout-ms",
		"--response-json-file",
		"roslyn_runtime_timeout",
		"_parse_runtime_process_response",
		"_execute_runtime_process_async",
		"_write_runtime_request_file",
		"_cleanup_runtime_request_file",
		"await _await_process_frame()",
		"roslyn_runtime_process_requires_async"
	]:
		if service_source.find(required_text) == -1:
			return _failure("PluginRoslynService isolated process guard is missing '%s'." % required_text)
	if service_source.find("OS.execute(\"dotnet\"") != -1:
		return _failure("PluginRoslynService must not use blocking OS.execute for isolated Roslyn runtime calls.")
	if service_source.find("OS.delay_usec") != -1:
		return _failure("PluginRoslynService isolated runtime process must yield frames instead of busy-wait polling.")
	if service_source.find("DirAccess.remove_absolute(ProjectSettings.globalize_path(request_path))") != -1:
		return _failure("PluginRoslynService should cleanup runtime request files through the shared cleanup helper.")

	return {"success": true}


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _failure(message: String) -> Dictionary:
	return {
		"name": "plugin_roslyn_service_contracts",
		"success": false,
		"error": message
	}
