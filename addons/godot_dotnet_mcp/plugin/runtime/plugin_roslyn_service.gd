@tool
extends Node

const RUNTIME_MANIFEST_PATH := "res://addons/godot_dotnet_mcp/plugin/runtime/roslyn_runtime/roslyn-runtime-manifest.json"
const RUNTIME_BRIDGE_DLL_PATH := "res://addons/godot_dotnet_mcp/plugin/runtime/roslyn_runtime/GodotDotnetMcp.PluginBridge.dll"
const LOAD_MODE_RUNTIME_PROCESS := "isolated_runtime_process"
const LOAD_MODE_PLACEHOLDER := "gdscript_placeholder"
const LOAD_MODE_TESTING := "testing_double"
const CACHE_LIMIT := 32
const RUNTIME_PROCESS_TIMEOUT_MS := 15000
const ERROR_TYPE_INVALID_ARGUMENT := "invalid_argument"
const ERROR_TYPE_SOURCE_UNAVAILABLE := "source_unavailable"
const ERROR_TYPE_RUNTIME_UNAVAILABLE := "runtime_unavailable"
const ERROR_TYPE_PROTOCOL_ERROR := "protocol_error"
const ERROR_TYPE_ROSLYN_FAILURE := "roslyn_failure"

var _facade = null
var _load_mode := LOAD_MODE_PLACEHOLDER
var _load_error := "Roslyn runtime source has not been evaluated yet"
var _cache_by_key: Dictionary = {}
var _cache_order: Array[String] = []
var _last_source_hash := ""


class PlaceholderRoslynFacade extends RefCounted:
	var _metadata := {}
	var _reason := ""

	func _init(metadata: Dictionary, reason: String) -> void:
		_metadata = metadata.duplicate(true)
		_reason = reason

	func get_capabilities() -> Dictionary:
		return {
			"success": true,
			"data": _metadata,
			"message": "Isolated Roslyn runtime is not active in this environment."
		}

	func parse_file(script_path: String, _source_text: String = "") -> Dictionary:
		var data := _metadata.duplicate(true)
		data["path"] = script_path
		data["degraded"] = true
		return {
			"success": false,
			"error": _reason,
			"data": data
		}


class RuntimeProcessRoslynFacade extends RefCounted:
	var _owner = null

	func _init(owner) -> void:
		_owner = owner

	func get_capabilities() -> Dictionary:
		return _owner._runtime_process_requires_async_result()

	func get_capabilities_async() -> Dictionary:
		return await _owner._execute_runtime_capabilities_async()

	func parse_file(script_path: String, source_text: String = "") -> Dictionary:
		return _owner._build_error_result(
			script_path,
			"",
			ERROR_TYPE_RUNTIME_UNAVAILABLE,
			"roslyn_runtime_process_requires_async",
			"Isolated Roslyn runtime process calls require parse_file_async."
		)

	func parse_file_async(script_path: String, source_text: String = "") -> Dictionary:
		var request: Dictionary = {
			"path": script_path
		}
		if not source_text.is_empty():
			request["sourceText"] = source_text
		var response: Dictionary = await _owner._execute_runtime_tool_async("cs_file_read", request)
		return _owner._convert_bridge_read_response(response, script_path)

	func patch_file(script_path: String, request: Dictionary) -> Dictionary:
		return _owner._build_error_result(
			script_path,
			"",
			ERROR_TYPE_RUNTIME_UNAVAILABLE,
			"roslyn_runtime_process_requires_async",
			"Isolated Roslyn runtime process calls require patch_file_async."
		)

	func patch_file_async(script_path: String, request: Dictionary) -> Dictionary:
		var bridge_request: Dictionary = request.duplicate(true)
		bridge_request["path"] = script_path
		var response: Dictionary = await _owner._execute_runtime_tool_async("cs_plugin_patch", bridge_request)
		return _owner._convert_bridge_patch_response(response, script_path)


func _init() -> void:
	_facade = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		clear()


func get_capabilities() -> Dictionary:
	_ensure_facade()
	if _facade == null:
		return _build_error_result(
			"",
			"",
			ERROR_TYPE_RUNTIME_UNAVAILABLE,
			"roslyn_runtime_unavailable",
			"PluginRoslynRuntimeFacade is unavailable"
		)
	var result = _facade.get_capabilities()
	return _normalize_capabilities_result(result)


func get_capabilities_async() -> Dictionary:
	await _ensure_facade_async()
	if _facade == null:
		return _build_error_result(
			"",
			"",
			ERROR_TYPE_RUNTIME_UNAVAILABLE,
			"roslyn_runtime_unavailable",
			"PluginRoslynRuntimeFacade is unavailable"
		)
	var result
	if _facade.has_method("get_capabilities_async"):
		result = await _facade.get_capabilities_async()
	else:
		result = _facade.get_capabilities()
	return _normalize_capabilities_result(result)


func parse_file(script_path: String, source_text: String = "") -> Dictionary:
	var normalized_path := _normalize_script_path(script_path)
	var source_resolution := _resolve_source(normalized_path, source_text)
	if not bool(source_resolution.get("success", false)):
		return _build_error_result(
			normalized_path,
			str(source_resolution.get("source_hash", "")),
			str(source_resolution.get("error_type", ERROR_TYPE_SOURCE_UNAVAILABLE)),
			str(source_resolution.get("error_code", "roslyn_source_unavailable")),
			str(source_resolution.get("error", "Failed to resolve Roslyn source"))
		)

	var resolved_source_text := str(source_resolution.get("source_text", ""))
	var source_hash := str(source_resolution.get("source_hash", ""))
	_last_source_hash = source_hash
	var cache_key := _make_key(normalized_path, source_hash)
	var cached_entry: Variant = _cache_by_key.get(cache_key, null)
	if cached_entry is Dictionary:
		var cached_result_raw: Variant = (cached_entry as Dictionary).get("result", {})
		if cached_result_raw is Dictionary:
			return (cached_result_raw as Dictionary).duplicate(true)

	_ensure_facade()
	if _facade == null:
		return _build_error_result(
			normalized_path,
			source_hash,
			ERROR_TYPE_RUNTIME_UNAVAILABLE,
			"roslyn_runtime_unavailable",
			"PluginRoslynRuntimeFacade is unavailable"
		)

	var result = _facade.parse_file(normalized_path, resolved_source_text)
	var normalized_result := _normalize_parse_result(result, normalized_path, source_hash)
	if bool(normalized_result.get("success", false)):
		_store_cache(cache_key, normalized_result)
	return normalized_result


func parse_file_async(script_path: String, source_text: String = "") -> Dictionary:
	var normalized_path := _normalize_script_path(script_path)
	var source_resolution := _resolve_source(normalized_path, source_text)
	if not bool(source_resolution.get("success", false)):
		return _build_error_result(
			normalized_path,
			str(source_resolution.get("source_hash", "")),
			str(source_resolution.get("error_type", ERROR_TYPE_SOURCE_UNAVAILABLE)),
			str(source_resolution.get("error_code", "roslyn_source_unavailable")),
			str(source_resolution.get("error", "Failed to resolve Roslyn source"))
		)

	var resolved_source_text := str(source_resolution.get("source_text", ""))
	var source_hash := str(source_resolution.get("source_hash", ""))
	_last_source_hash = source_hash
	var cache_key := _make_key(normalized_path, source_hash)
	var cached_entry: Variant = _cache_by_key.get(cache_key, null)
	if cached_entry is Dictionary:
		var cached_result_raw: Variant = (cached_entry as Dictionary).get("result", {})
		if cached_result_raw is Dictionary:
			return (cached_result_raw as Dictionary).duplicate(true)

	await _ensure_facade_async()
	if _facade == null:
		return _build_error_result(
			normalized_path,
			source_hash,
			ERROR_TYPE_RUNTIME_UNAVAILABLE,
			"roslyn_runtime_unavailable",
			"PluginRoslynRuntimeFacade is unavailable"
		)

	var result
	if _facade.has_method("parse_file_async"):
		result = await _facade.parse_file_async(normalized_path, resolved_source_text)
	else:
		result = _facade.parse_file(normalized_path, resolved_source_text)
	var normalized_result := _normalize_parse_result(result, normalized_path, source_hash)
	if bool(normalized_result.get("success", false)):
		_store_cache(cache_key, normalized_result)
	return normalized_result


func patch_file(script_path: String, request: Dictionary) -> Dictionary:
	var normalized_path := _normalize_script_path(script_path)
	if normalized_path.is_empty():
		return _build_error_result(
			normalized_path,
			"",
			ERROR_TYPE_INVALID_ARGUMENT,
			"script_path_required",
			"script_path is required"
		)
	if request.is_empty():
		return _build_error_result(
			normalized_path,
			"",
			ERROR_TYPE_INVALID_ARGUMENT,
			"patch_request_required",
			"patch request is required"
		)

	_ensure_facade()
	if _facade == null:
		return _build_error_result(
			normalized_path,
			"",
			ERROR_TYPE_RUNTIME_UNAVAILABLE,
			"roslyn_runtime_unavailable",
			"PluginRoslynRuntimeFacade is unavailable"
		)
	if not _facade.has_method("patch_file"):
		return _build_error_result(
			normalized_path,
			"",
			ERROR_TYPE_PROTOCOL_ERROR,
			"roslyn_patch_unavailable",
			"PluginRoslynRuntimeFacade does not expose patch_file"
		)

	var result = _facade.patch_file(normalized_path, request.duplicate(true))
	var normalized_result := _normalize_patch_result(result, normalized_path)
	if bool(normalized_result.get("success", false)):
		_invalidate_cache_for_path(normalized_path)
	return normalized_result


func patch_file_async(script_path: String, request: Dictionary) -> Dictionary:
	var normalized_path := _normalize_script_path(script_path)
	if normalized_path.is_empty():
		return _build_error_result(
			normalized_path,
			"",
			ERROR_TYPE_INVALID_ARGUMENT,
			"script_path_required",
			"script_path is required"
		)
	if request.is_empty():
		return _build_error_result(
			normalized_path,
			"",
			ERROR_TYPE_INVALID_ARGUMENT,
			"patch_request_required",
			"patch request is required"
		)

	await _ensure_facade_async()
	if _facade == null:
		return _build_error_result(
			normalized_path,
			"",
			ERROR_TYPE_RUNTIME_UNAVAILABLE,
			"roslyn_runtime_unavailable",
			"PluginRoslynRuntimeFacade is unavailable"
		)
	if not _facade.has_method("patch_file") and not _facade.has_method("patch_file_async"):
		return _build_error_result(
			normalized_path,
			"",
			ERROR_TYPE_PROTOCOL_ERROR,
			"roslyn_patch_unavailable",
			"PluginRoslynRuntimeFacade does not expose patch_file"
		)

	var result
	if _facade.has_method("patch_file_async"):
		result = await _facade.patch_file_async(normalized_path, request.duplicate(true))
	else:
		result = _facade.patch_file(normalized_path, request.duplicate(true))
	var normalized_result := _normalize_patch_result(result, normalized_path)
	if bool(normalized_result.get("success", false)):
		_invalidate_cache_for_path(normalized_path)
	return normalized_result


func clear() -> void:
	_cache_by_key.clear()
	_cache_order.clear()
	_last_source_hash = ""
	var facade = _facade
	_facade = null
	if facade is Node:
		(facade as Node).free()


func get_debug_snapshot() -> Dictionary:
	return {
		"cache_entry_count": _cache_by_key.size(),
		"cache_keys": _cache_order.duplicate(),
		"load_mode": _load_mode,
		"load_error": _load_error,
		"last_source_hash": _last_source_hash
	}


func set_facade_for_testing(facade, load_mode: String = LOAD_MODE_TESTING, load_error: String = "") -> void:
	clear()
	_facade = facade
	_load_mode = load_mode
	_load_error = load_error


func _ensure_facade() -> void:
	if _facade != null:
		return
	_facade = _instantiate_facade()


func _ensure_facade_async() -> void:
	if _facade != null:
		return
	_facade = await _instantiate_facade_async()


func _instantiate_facade():
	var process_facade = _instantiate_runtime_process_facade("PluginRoslynRuntimeFacade in-process runtime is disabled for production installs")
	if process_facade != null:
		return process_facade
	return PlaceholderRoslynFacade.new(_base_metadata(true), _load_error)


func _instantiate_runtime_process_facade(reason: String):
	if not FileAccess.file_exists(RUNTIME_BRIDGE_DLL_PATH):
		_load_mode = LOAD_MODE_PLACEHOLDER
		_load_error = _build_runtime_unavailable_message("%s; isolated runtime bridge is missing at %s" % [reason, RUNTIME_BRIDGE_DLL_PATH])
		return null
	_load_mode = LOAD_MODE_RUNTIME_PROCESS
	_load_error = ""
	return RuntimeProcessRoslynFacade.new(self)


func _instantiate_facade_async():
	var facade = _instantiate_facade()
	if facade is RuntimeProcessRoslynFacade:
		var capabilities: Dictionary = await _execute_runtime_capabilities_async()
		if not bool(capabilities.get("success", false)):
			_load_mode = LOAD_MODE_PLACEHOLDER
			_load_error = str(capabilities.get("error", _build_runtime_unavailable_message("PluginRoslynRuntimeFacade isolated runtime process is unavailable")))
			return null
	return facade


func _build_runtime_unavailable_message(reason: String) -> String:
	var manifest_state := "missing"
	if FileAccess.file_exists(RUNTIME_MANIFEST_PATH):
		manifest_state = "present"
	return "%s. C# semantic support requires the isolated Roslyn runtime bundle at %s (manifest %s)." % [
		reason,
		RUNTIME_MANIFEST_PATH,
		manifest_state
	]


func _execute_runtime_capabilities() -> Dictionary:
	var result := _execute_runtime_process(["--capabilities"])
	if not bool(result.get("success", false)):
		return result
	var payload := _coerce_dictionary(result.get("payload", {}))
	var data := _base_metadata(false)
	data["component"] = str(payload.get("component", "godot-dotnet-mcp-roslyn-runtime"))
	data["version"] = str(payload.get("version", ""))
	data["mode"] = str(payload.get("mode", "syntax"))
	data["semantic_runtime"] = "Roslyn"
	data["tools"] = _coerce_array(payload.get("tools", []))
	return {
		"success": true,
		"data": data,
		"message": "Isolated Roslyn runtime bundle is ready."
	}


func _execute_runtime_capabilities_async() -> Dictionary:
	var result: Dictionary = await _execute_runtime_process_async(["--capabilities"])
	if not bool(result.get("success", false)):
		return result
	var payload := _coerce_dictionary(result.get("payload", {}))
	var data := _base_metadata(false)
	data["component"] = str(payload.get("component", "godot-dotnet-mcp-roslyn-runtime"))
	data["version"] = str(payload.get("version", ""))
	data["mode"] = str(payload.get("mode", "syntax"))
	data["semantic_runtime"] = "Roslyn"
	data["tools"] = _coerce_array(payload.get("tools", []))
	return {
		"success": true,
		"data": data,
		"message": "Isolated Roslyn runtime bundle is ready."
	}


func _execute_runtime_tool(tool_name: String, request: Dictionary) -> Dictionary:
	var request_path := _make_runtime_request_path(tool_name)
	var write_result := _write_runtime_request_file(request_path, request)
	if not bool(write_result.get("success", false)):
		return {
			"success": false,
			"error": str(write_result.get("error", "Failed to create Roslyn runtime request file: %s" % request_path))
		}
	var result := _execute_runtime_process(["--call-json-file", tool_name, ProjectSettings.globalize_path(request_path)])
	_cleanup_runtime_request_file(request_path)
	return result


func _execute_runtime_tool_async(tool_name: String, request: Dictionary) -> Dictionary:
	var request_path := _make_runtime_request_path(tool_name)
	var write_result := _write_runtime_request_file(request_path, request)
	if not bool(write_result.get("success", false)):
		return {
			"success": false,
			"error": str(write_result.get("error", "Failed to create Roslyn runtime request file: %s" % request_path))
		}
	var result: Dictionary = await _execute_runtime_process_async(["--call-json-file", tool_name, ProjectSettings.globalize_path(request_path)])
	_cleanup_runtime_request_file(request_path)
	return result


func _execute_runtime_process(args: Array[String]) -> Dictionary:
	return _runtime_process_requires_async_result()


func _execute_runtime_process_async(args: Array[String]) -> Dictionary:
	var runtime_dll := ProjectSettings.globalize_path(RUNTIME_BRIDGE_DLL_PATH)
	var response_path := _make_runtime_response_path()
	var command_args: Array[String] = [runtime_dll]
	command_args.append_array(["--timeout-ms", str(RUNTIME_PROCESS_TIMEOUT_MS), "--response-json-file", ProjectSettings.globalize_path(response_path)])
	command_args.append_array(args)
	var pid := OS.create_process("dotnet", PackedStringArray(command_args), false)
	if pid <= 0:
		_remove_file_if_exists(response_path)
		return {
			"success": false,
			"error": "Failed to start isolated Roslyn runtime process.",
			"exit_code": -1,
			"stdout": "",
			"error_code": "roslyn_runtime_process_start_failed"
		}
	var started := Time.get_ticks_msec()
	while OS.is_process_running(pid):
		if Time.get_ticks_msec() - started > RUNTIME_PROCESS_TIMEOUT_MS:
			OS.kill(pid)
			_remove_file_if_exists(response_path)
			return {
				"success": false,
				"error": "Isolated Roslyn runtime timed out after %d ms." % RUNTIME_PROCESS_TIMEOUT_MS,
				"exit_code": -1,
				"stdout": "",
				"error_code": "roslyn_runtime_timeout",
				"timeout_ms": RUNTIME_PROCESS_TIMEOUT_MS
			}
		await _await_process_frame()
	var exit_code := OS.get_process_exit_code(pid)
	var stdout := ""
	if FileAccess.file_exists(response_path):
		var response_file := FileAccess.open(response_path, FileAccess.READ)
		if response_file != null:
			stdout = response_file.get_as_text().strip_edges()
			response_file.close()
		_remove_file_if_exists(response_path)
	return _parse_runtime_process_response(stdout, exit_code)


func _runtime_process_requires_async_result() -> Dictionary:
	return {
		"success": false,
		"error": "Isolated Roslyn runtime process calls require the async API.",
		"exit_code": -1,
		"stdout": "",
		"error_code": "roslyn_runtime_process_requires_async"
	}


func _await_process_frame() -> void:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		await (main_loop as SceneTree).process_frame
	else:
		await get_tree().process_frame


func _parse_runtime_process_response(stdout: String, exit_code: int) -> Dictionary:
	var json := JSON.new()
	var parse_error := json.parse(stdout)
	if parse_error == OK and json.data is Dictionary and (exit_code == 0 or _is_runtime_tool_response_payload(json.data)):
		return {
			"success": true,
			"payload": json.data,
			"exit_code": exit_code,
			"stdout": stdout
		}
	if exit_code != 0:
		return {
			"success": false,
			"error": "Isolated Roslyn runtime exited with code %d: %s" % [exit_code, stdout],
			"exit_code": exit_code,
			"stdout": stdout,
			"error_code": "roslyn_runtime_process_failed"
		}
	return {
		"success": false,
		"error": "Isolated Roslyn runtime returned invalid JSON.",
		"exit_code": exit_code,
		"stdout": stdout,
		"error_code": "roslyn_runtime_invalid_json"
	}


func _is_runtime_tool_response_payload(payload: Dictionary) -> bool:
	return payload.has("isError") or payload.has("structuredContent") or payload.has("content")


func _make_runtime_request_path(tool_name: String) -> String:
	var safe_tool_name := tool_name.replace("/", "_").replace("\\", "_").replace(":", "_")
	return "user://godot_dotnet_mcp_roslyn_%s_%d_%d.json" % [
		safe_tool_name,
		Time.get_ticks_msec(),
		randi()
	]


func _make_runtime_response_path() -> String:
	return "user://godot_dotnet_mcp_roslyn_response_%d_%d.json" % [
		Time.get_ticks_msec(),
		randi()
	]


func _remove_file_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_runtime_request_file(request_path: String, request: Dictionary) -> Dictionary:
	var file := FileAccess.open(request_path, FileAccess.WRITE)
	if file == null:
		return {
			"success": false,
			"error": "Failed to create Roslyn runtime request file: %s" % request_path
		}
	file.store_string(JSON.stringify(request))
	file.close()
	return {"success": true}


func _cleanup_runtime_request_file(request_path: String) -> void:
	_remove_file_if_exists(request_path)


func _convert_bridge_read_response(response: Dictionary, script_path: String) -> Dictionary:
	if not bool(response.get("success", false)):
		return _build_error_result(
			script_path,
			"",
			ERROR_TYPE_RUNTIME_UNAVAILABLE,
			"roslyn_runtime_process_failed",
			str(response.get("error", "Isolated Roslyn runtime failed"))
		)
	var payload := _coerce_dictionary(response.get("payload", {}))
	if not bool(payload.get("success", false)):
		return _build_error_result(
			script_path,
			"",
			ERROR_TYPE_ROSLYN_FAILURE,
			"roslyn_parse_failed",
			str(payload.get("error", "Isolated Roslyn runtime parse failed"))
		)
	var structured := _coerce_dictionary(payload.get("structuredContent", {}))
	var data := _base_metadata(false)
	data["path"] = str(structured.get("path", script_path))
	data["namespace"] = str(structured.get("namespace", ""))
	data["usings"] = _coerce_array(structured.get("usings", []))
	data["types"] = _coerce_array(structured.get("types", []))
	data["methods"] = _coerce_array(structured.get("methods", []))
	data["exports"] = _coerce_array(structured.get("exports", []))
	data["parse_errors"] = _coerce_array(structured.get("parseErrors", structured.get("parse_errors", [])))
	data["semantic_runtime"] = str(structured.get("semanticRuntime", "Roslyn"))
	return {
		"success": true,
		"data": data,
		"message": "Syntax parsed successfully."
	}


func _convert_bridge_patch_response(response: Dictionary, script_path: String) -> Dictionary:
	if not bool(response.get("success", false)):
		return _build_error_result(
			script_path,
			"",
			ERROR_TYPE_RUNTIME_UNAVAILABLE,
			"roslyn_runtime_process_failed",
			str(response.get("error", "Isolated Roslyn runtime failed"))
		)
	var payload := _coerce_dictionary(response.get("payload", {}))
	if not bool(payload.get("success", false)):
		return _build_error_result(
			script_path,
			"",
			ERROR_TYPE_ROSLYN_FAILURE,
			"roslyn_patch_failed",
			str(payload.get("error", "Isolated Roslyn runtime patch failed"))
		)
	var structured := _coerce_dictionary(payload.get("structuredContent", {}))
	var data := _base_metadata(false)
	data["path"] = str(structured.get("path", script_path))
	data["source_hash"] = str(structured.get("sourceHash", structured.get("contentHash", "")))
	var operations := _coerce_array(structured.get("operations", []))
	if operations.is_empty() and structured.has("operation"):
		operations = [_coerce_dictionary(structured.get("operation", {}))]
	data["operation"] = _first_operation(operations)
	data["operations"] = operations
	data["preview"] = str(structured.get("preview", ""))
	data["written"] = bool(structured.get("written", true))
	data["dry_run"] = bool(structured.get("dryRun", false))
	data["action"] = str(structured.get("action", ""))
	data["type_name"] = str(structured.get("typeName", structured.get("type_name", "")))
	data["member_name"] = str(structured.get("memberName", structured.get("member_name", "")))
	data["types"] = _coerce_array(structured.get("types", []))
	data["methods"] = _coerce_array(structured.get("methods", []))
	data["exports"] = _coerce_array(structured.get("exports", []))
	data["parse_errors"] = _coerce_array(structured.get("parseErrors", structured.get("parse_errors", [])))
	data["semantic_runtime"] = str(structured.get("semanticRuntime", "Roslyn"))
	return {
		"success": true,
		"data": data,
		"message": "Syntax patch applied successfully."
	}


func _normalize_capabilities_result(result) -> Dictionary:
	if not (result is Dictionary):
		return _build_error_result(
			"",
			"",
			ERROR_TYPE_PROTOCOL_ERROR,
			"roslyn_invalid_capabilities_result",
			"Failed to fetch Roslyn capabilities"
		)
	var payload := (result as Dictionary).duplicate(true)
	var data := _coerce_dictionary(payload.get("data", {}))
	data.merge(_base_metadata(false), false)
	data["degraded"] = bool(data.get("degraded", false))
	payload["success"] = bool(payload.get("success", false))
	payload["data"] = data
	if not payload.has("message"):
		payload["message"] = "Isolated Roslyn runtime facade is ready."
	if not bool(payload.get("success", false)):
		return _build_error_result(
			"",
			"",
			ERROR_TYPE_ROSLYN_FAILURE,
			"roslyn_capabilities_failed",
			str(payload.get("error", payload.get("message", "Failed to fetch Roslyn capabilities")))
		)
	return payload


func _normalize_parse_result(result, script_path: String, source_hash: String) -> Dictionary:
	if not (result is Dictionary):
		return _build_error_result(
			script_path,
			source_hash,
			ERROR_TYPE_PROTOCOL_ERROR,
			"roslyn_invalid_parse_result",
			"PluginRoslynRuntimeFacade returned an invalid parse result"
		)

	var payload := (result as Dictionary).duplicate(true)
	var data := _coerce_dictionary(payload.get("data", {}))
	data.merge(_base_metadata(false), false)
	if str(data.get("path", "")).is_empty():
		data["path"] = script_path
	if str(data.get("source_hash", "")).is_empty():
		data["source_hash"] = source_hash
	data["degraded"] = bool(data.get("degraded", false))
	data["types"] = _coerce_array(data.get("types", []))
	data["methods"] = _coerce_array(data.get("methods", []))
	data["exports"] = _coerce_array(data.get("exports", []))
	data["parse_errors"] = _coerce_array(data.get("parse_errors", []))
	payload["data"] = data
	payload["success"] = bool(payload.get("success", false))
	if bool(payload.get("success", false)):
		if not payload.has("message"):
			payload["message"] = "Syntax parsed successfully."
		return payload

	var error_type := str(data.get("error_type", ERROR_TYPE_ROSLYN_FAILURE))
	var error_code := str(data.get("error_code", "roslyn_parse_failed"))
	var message := str(payload.get("error", payload.get("message", "Roslyn parsing failed")))
	return _build_error_result(script_path, data["source_hash"], error_type, error_code, message, data)


func _normalize_patch_result(result, script_path: String) -> Dictionary:
	if not (result is Dictionary):
		return _build_error_result(
			script_path,
			"",
			ERROR_TYPE_PROTOCOL_ERROR,
			"roslyn_invalid_patch_result",
			"PluginRoslynRuntimeFacade returned an invalid patch result"
		)

	var payload := (result as Dictionary).duplicate(true)
	var data := _coerce_dictionary(payload.get("data", {}))
	data.merge(_base_metadata(false), false)
	if str(data.get("path", "")).is_empty():
		data["path"] = script_path
	data["source_hash"] = str(data.get("source_hash", ""))
	data["degraded"] = bool(data.get("degraded", false))
	data["types"] = _coerce_array(data.get("types", []))
	data["methods"] = _coerce_array(data.get("methods", []))
	data["exports"] = _coerce_array(data.get("exports", []))
	data["parse_errors"] = _coerce_array(data.get("parse_errors", []))
	var operation = data.get("operation", {})
	data["operation"] = _coerce_dictionary(operation)
	payload["data"] = data
	payload["success"] = bool(payload.get("success", false))
	if bool(payload.get("success", false)):
		if not payload.has("message"):
			payload["message"] = "Syntax patch applied successfully."
		return payload

	var error_type := str(data.get("error_type", ERROR_TYPE_ROSLYN_FAILURE))
	var error_code := str(data.get("error_code", "roslyn_patch_failed"))
	var message := str(payload.get("error", payload.get("message", "Roslyn patch failed")))
	return _build_error_result(script_path, data["source_hash"], error_type, error_code, message, data)


func _resolve_source(script_path: String, source_text: String) -> Dictionary:
	if not source_text.is_empty():
		var unsaved_hash := _hash_source(source_text)
		return {
			"success": true,
			"source_text": source_text,
			"source_hash": unsaved_hash,
			"source_origin": "provided"
		}

	if script_path.is_empty():
		return {
			"success": false,
			"error": "script_path is required when source_text is empty",
			"error_type": ERROR_TYPE_INVALID_ARGUMENT,
			"error_code": "script_path_required",
			"source_hash": ""
		}

	if not FileAccess.file_exists(script_path):
		return {
			"success": false,
			"error": "Script file not found: %s" % script_path,
			"error_type": ERROR_TYPE_SOURCE_UNAVAILABLE,
			"error_code": "script_path_missing",
			"source_hash": ""
		}

	var file := FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		return {
			"success": false,
			"error": "Failed to open script file: %s" % script_path,
			"error_type": ERROR_TYPE_SOURCE_UNAVAILABLE,
			"error_code": "script_read_failed",
			"source_hash": ""
		}
	var disk_source := file.get_as_text()
	file.close()
	return {
		"success": true,
		"source_text": disk_source,
		"source_hash": _hash_source(disk_source),
		"source_origin": "disk"
	}


func _build_error_result(
		script_path: String,
		source_hash: String,
		error_type: String,
		error_code: String,
		message: String,
		extra_data: Dictionary = {}
	) -> Dictionary:
	var data := _base_metadata(true)
	data["path"] = script_path
	data["source_hash"] = source_hash
	data["error_type"] = error_type
	data["error_code"] = error_code
	if not extra_data.is_empty():
		data.merge(extra_data, true)
		data["path"] = str(data.get("path", script_path))
		data["source_hash"] = str(data.get("source_hash", source_hash))
		data["error_type"] = str(data.get("error_type", error_type))
		data["error_code"] = str(data.get("error_code", error_code))
		data["types"] = _coerce_array(data.get("types", []))
		data["methods"] = _coerce_array(data.get("methods", []))
		data["exports"] = _coerce_array(data.get("exports", []))
		data["parse_errors"] = _coerce_array(data.get("parse_errors", []))
	return {
		"success": false,
		"error": message,
		"data": data
	}


func _store_cache(key: String, result: Dictionary) -> void:
	_cache_by_key[key] = {
		"result": result.duplicate(true),
		"stored_at_unix": int(Time.get_unix_time_from_system())
	}
	_cache_order.erase(key)
	_cache_order.append(key)
	while _cache_order.size() > CACHE_LIMIT:
		var removed_key := _cache_order[0]
		_cache_order.remove_at(0)
		_cache_by_key.erase(removed_key)


func _invalidate_cache_for_path(script_path: String) -> void:
	var remaining_keys: Array[String] = []
	for key in _cache_order:
		if key.begins_with("%s|" % script_path):
			_cache_by_key.erase(key)
			continue
		remaining_keys.append(key)
	_cache_order = remaining_keys


func _normalize_script_path(script_path: String) -> String:
	return script_path.strip_edges()


func _hash_source(source_text: String) -> String:
	var ctx := HashingContext.new()
	var err := ctx.start(HashingContext.HASH_SHA256)
	if err != OK:
		return str(source_text.hash())
	ctx.update(source_text.to_utf8_buffer())
	return ctx.finish().hex_encode()


func _make_key(script_path: String, source_hash: String) -> String:
	return "%s|%s" % [script_path, source_hash]


func _coerce_dictionary(value) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _coerce_array(value) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []


func _first_operation(operations: Array) -> Dictionary:
	if operations.is_empty():
		return {}
	var first = operations[0]
	if first is Dictionary:
		return (first as Dictionary).duplicate(true)
	return {}


func _base_metadata(degraded: bool) -> Dictionary:
	var transport := "isolated_runtime_unavailable"
	var entrypoint := RUNTIME_BRIDGE_DLL_PATH
	if _load_mode == LOAD_MODE_RUNTIME_PROCESS:
		transport = "process_json"
	return {
		"engine": "roslyn",
		"mode": "syntax",
		"semantic_runtime": "Roslyn",
		"transport": transport,
		"entrypoint": entrypoint,
		"runtime_manifest_path": RUNTIME_MANIFEST_PATH,
		"runtime_manifest_present": FileAccess.file_exists(RUNTIME_MANIFEST_PATH),
		"load_mode": _load_mode,
		"load_error": _load_error,
		"degraded": degraded,
		"source_hash": "",
		"types": [],
		"methods": [],
		"exports": [],
		"parse_errors": []
	}
