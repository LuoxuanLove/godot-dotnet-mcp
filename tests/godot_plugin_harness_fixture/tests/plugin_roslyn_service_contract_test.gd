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
	var isolation_guard := _assert_production_runtime_does_not_load_in_process_facade()
	if not bool(isolation_guard.get("success", false)):
		return isolation_guard

	_service = PluginRoslynServiceScript.new()
	var compatibility_guard := _assert_runtime_bridge_version_contract(_service)
	if not bool(compatibility_guard.get("success", false)):
		return compatibility_guard
	var temp_guard := _assert_runtime_temp_paths_are_isolated(_service)
	if not bool(temp_guard.get("success", false)):
		return temp_guard
	var link_guard := _assert_runtime_temp_root_link_guard(_service)
	if not bool(link_guard.get("success", false)):
		return link_guard
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
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
		"framework-dependent",
		".NET 8 runtime",
		"_parse_runtime_process_response",
		"_execute_runtime_process_async",
		"_write_runtime_request_file",
		"_cleanup_runtime_request_file",
		"RUNTIME_TEMP_ROOT",
		"GODOT_DOTNET_MCP_RESPONSE_ROOTS",
		"dir.is_link(entry)",
		"_runtime_temp_path_or_ancestor_is_link",
		"roslyn_runtime_temp_link",
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
	if service_source.find("user://godot_dotnet_mcp_roslyn_request") != -1 or service_source.find("user://godot_dotnet_mcp_roslyn_response") != -1:
		return _failure("PluginRoslynService should not create runtime JSON temp files in a shared user:// filename namespace.")
	var stale_cleanup := _extract_function_source(service_source, "_cleanup_stale_runtime_temp_dir")
	if stale_cleanup.find("_runtime_temp_path_or_ancestor_is_link(path)") == -1 or stale_cleanup.find("_runtime_temp_path_or_ancestor_is_link(absolute_path)") == -1:
		return _failure("PluginRoslynService stale cleanup should reject linked runtime temp roots before opening them.")
	if _index_or_large(stale_cleanup, "_runtime_temp_path_or_ancestor_is_link(path)") > _index_or_large(stale_cleanup, "DirAccess.open(absolute_path)"):
		return _failure("PluginRoslynService stale cleanup should check for linked roots before DirAccess.open.")
	var runtime_cleanup := _extract_function_source(service_source, "_cleanup_runtime_temp_dir")
	if runtime_cleanup.find("_runtime_temp_path_or_ancestor_is_link(path)") == -1 or runtime_cleanup.find("_runtime_temp_path_or_ancestor_is_link(absolute_path)") == -1:
		return _failure("PluginRoslynService runtime temp cleanup should reject linked roots before opening them.")
	if _index_or_large(runtime_cleanup, "_runtime_temp_path_or_ancestor_is_link(path)") > _index_or_large(runtime_cleanup, "DirAccess.open(absolute_path)"):
		return _failure("PluginRoslynService runtime temp cleanup should check for linked roots before DirAccess.open.")
	var ensure_temp := _extract_function_source(service_source, "_ensure_runtime_temp_dir")
	if _index_or_large(ensure_temp, "_runtime_temp_path_or_ancestor_is_link(temp_dir)") > _index_or_large(ensure_temp, "DirAccess.make_dir_recursive_absolute"):
		return _failure("PluginRoslynService should reject linked runtime temp roots before creating request/response files.")

	return {"success": true}


func _assert_production_runtime_does_not_load_in_process_facade() -> Dictionary:
	var service_source := _read_text(SERVICE_SOURCE_PATH)
	if service_source.is_empty():
		return _failure("PluginRoslynService source should be readable for isolation guard checks.")
	for blocked_text in [
		"ResourceLoader.load(FACADE_SCRIPT_PATH",
		"ClassDB.class_exists(\"PluginRoslynRuntimeFacade\")",
		"ClassDB.instantiate(\"PluginRoslynRuntimeFacade\")",
		"_load_mode = LOAD_MODE_RUNTIME\n",
		"const LOAD_MODE_RUNTIME :=",
		"\"runtime_csharp\""
	]:
		if service_source.find(blocked_text) != -1:
			return _failure("PluginRoslynService production path must not auto-load in-process Roslyn facade via '%s'." % blocked_text)
	if service_source.find("RUNTIME_BRIDGE_DLL_PATH") == -1:
		return _failure("PluginRoslynService should keep the isolated runtime bridge as the production entrypoint.")
	var manifest_source := _read_text("res://addons/godot_dotnet_mcp/plugin/runtime/roslyn_runtime/roslyn-runtime-manifest.json")
	if manifest_source.find("\"distribution\": \"framework-dependent\"") == -1 or manifest_source.find("\"framework\": \"Microsoft.NETCore.App\"") == -1 or manifest_source.find("\"version\": \"8.0.0\"") == -1:
		return _failure("PluginRoslynService runtime manifest should truthfully declare the framework-dependent .NET 8 runtime requirement.")
	if service_source.find("PluginRoslynRuntimeFacade in-process runtime is disabled for production installs") == -1:
		return _failure("PluginRoslynService should document why production uses the isolated runtime process.")
	return {"success": true}


func _assert_runtime_bridge_version_contract(service: Node) -> Dictionary:
	var ok: Dictionary = service._validate_runtime_capabilities_payload({
		"component": "godot-dotnet-mcp-roslyn-runtime",
		"version": "2.0.0"
	})
	if not bool(ok.get("success", false)):
		return _failure("PluginRoslynService should accept the packaged bridge component and version.")
	var mismatch: Dictionary = service._validate_runtime_capabilities_payload({
		"component": "godot-dotnet-mcp-roslyn-runtime",
		"version": "1.9.0"
	})
	if bool(mismatch.get("success", true)):
		return _failure("PluginRoslynService should reject mismatched bridge versions.")
	var mismatch_data: Dictionary = mismatch.get("data", {})
	if str(mismatch_data.get("error_code", "")) != "bridge_version_mismatch":
		return _failure("PluginRoslynService bridge mismatch should preserve error_code=bridge_version_mismatch.")
	if str(mismatch_data.get("expected_version", "")) != "2.0.0" or str(mismatch_data.get("version", "")) != "1.9.0":
		return _failure("PluginRoslynService bridge mismatch should report expected and actual versions.")

	var normalized: Dictionary = service._normalize_capabilities_result(mismatch)
	if bool(normalized.get("success", true)):
		return _failure("PluginRoslynService should normalize bridge mismatches into failed capabilities.")
	var normalized_data: Dictionary = normalized.get("data", {})
	if str(normalized_data.get("error_code", "")) != "bridge_version_mismatch":
		return _failure("PluginRoslynService normalized capabilities should preserve bridge_version_mismatch.")
	return {"success": true}


func _assert_runtime_temp_paths_are_isolated(service: Node) -> Dictionary:
	var request_path: String = service._make_runtime_request_path("cs/file:read")
	var response_path: String = service._make_runtime_response_path()
	if not request_path.begins_with("user://godot_dotnet_mcp/tmp/roslyn_runtime/"):
		return _failure("PluginRoslynService request temp files should live under the scoped Roslyn runtime temp root.")
	if not response_path.begins_with("user://godot_dotnet_mcp/tmp/roslyn_runtime/"):
		return _failure("PluginRoslynService response temp files should live under the scoped Roslyn runtime temp root.")
	if request_path.find("/request_cs_file_read_") == -1:
		return _failure("PluginRoslynService request temp files should sanitize tool names.")
	if response_path.find("/response_") == -1:
		return _failure("PluginRoslynService response temp files should use response-prefixed filenames.")
	if request_path == response_path:
		return _failure("PluginRoslynService request and response temp paths should be unique.")
	return {"success": true}


func _assert_runtime_temp_root_link_guard(service: Node) -> Dictionary:
	var temp_root := "user://godot_dotnet_mcp/tmp/roslyn_runtime"
	var outside_root := "user://godot_dotnet_mcp/tests/roslyn_runtime_link_target"
	_remove_tree(temp_root)
	_remove_tree(outside_root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(outside_root))
	_write_text(outside_root.path_join("sentinel.txt"), "keep")
	if not _create_directory_link(temp_root, outside_root):
		_remove_tree(temp_root)
		_remove_tree(outside_root)
		return {"success": true}
	var ensure_result: Dictionary = service._ensure_runtime_temp_dir()
	if bool(ensure_result.get("success", true)):
		_remove_tree(temp_root)
		_remove_tree(outside_root)
		return _failure("PluginRoslynService should reject linked Roslyn runtime temp roots before creating request/response files.")
	if str(ensure_result.get("error_code", "")) != "roslyn_runtime_temp_link":
		_remove_tree(temp_root)
		_remove_tree(outside_root)
		return _failure("PluginRoslynService linked temp root rejection should report error_code=roslyn_runtime_temp_link.")
	service._cleanup_stale_runtime_temp_files()
	service._cleanup_runtime_temp_dir(temp_root)
	if not FileAccess.file_exists(outside_root.path_join("sentinel.txt")):
		_remove_tree(temp_root)
		_remove_tree(outside_root)
		return _failure("PluginRoslynService cleanup should not recurse through a linked Roslyn runtime temp root.")
	_remove_tree(temp_root)
	_remove_tree(outside_root)
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


func _create_directory_link(link_path: String, target_path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(link_path.get_base_dir()))
	var absolute_link := ProjectSettings.globalize_path(link_path)
	var absolute_target := ProjectSettings.globalize_path(target_path)
	var output: Array = []
	var exit_code := -1
	if OS.get_name() == "Windows":
		exit_code = OS.execute("cmd", ["/c", "mklink", "/D", absolute_link, absolute_target], output, true)
		if exit_code != 0:
			output.clear()
			exit_code = OS.execute("cmd", ["/c", "mklink", "/J", absolute_link, absolute_target], output, true)
	else:
		exit_code = OS.execute("ln", ["-s", absolute_target, absolute_link], output, true)
	if exit_code != 0:
		return false
	if _is_link_path(link_path):
		return true
	DirAccess.remove_absolute(absolute_link)
	return false


func _is_link_path(path: String) -> bool:
	var parent_path := path.get_base_dir()
	var name := path.get_file()
	if parent_path.is_empty() or name.is_empty():
		return false
	var parent := DirAccess.open(parent_path)
	if parent == null:
		return false
	return parent.is_link(name)


func _remove_tree(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute_path)
		return
	var dir := DirAccess.open(absolute_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := absolute_path.path_join(entry)
			if dir.is_link(entry):
				DirAccess.remove_absolute(child)
			elif dir.current_is_dir():
				_remove_tree(ProjectSettings.localize_path(child))
			else:
				DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


func _extract_function_source(source: String, function_name: String) -> String:
	var marker := "func %s(" % function_name
	var start := source.find(marker)
	if start == -1:
		return ""
	var next := source.find("\n\nfunc ", start + marker.length())
	if next == -1:
		return source.substr(start)
	return source.substr(start, next - start)


func _index_or_large(source: String, text: String) -> int:
	var index := source.find(text)
	if index == -1:
		return 1000000000
	return index


func _failure(message: String) -> Dictionary:
	return {
		"name": "plugin_roslyn_service_contracts",
		"success": false,
		"error": message
	}
