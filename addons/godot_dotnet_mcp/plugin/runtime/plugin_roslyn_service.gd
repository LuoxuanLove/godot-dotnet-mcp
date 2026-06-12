@tool
extends Node

const FACADE_SCRIPT_PATH := "res://addons/godot_dotnet_mcp/plugin/runtime/roslyn/PluginRoslynRuntimeFacade.cs"
const RUNTIME_MANIFEST_PATH := "res://addons/godot_dotnet_mcp/plugin/runtime/roslyn_runtime/roslyn-runtime-manifest.json"
const RUNTIME_BRIDGE_DLL_PATH := "res://addons/godot_dotnet_mcp/plugin/runtime/roslyn_runtime/GodotDotnetMcp.PluginBridge.dll"
const LOAD_MODE_RUNTIME := "runtime_csharp"
const LOAD_MODE_RUNTIME_PROCESS := "isolated_runtime_process"
const LOAD_MODE_PLACEHOLDER := "gdscript_placeholder"
const LOAD_MODE_TESTING := "testing_double"
const CACHE_LIMIT := 32

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
			"message": "Plugin-internal Roslyn skeleton is present, but the runtime C# facade is not active in this environment."
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
		return _owner._execute_runtime_capabilities()

	func parse_file(script_path: String, source_text: String = "") -> Dictionary:
		var request := {
			"path": script_path
		}
		if not source_text.is_empty():
			request["sourceText"] = source_text
		var response := _owner._execute_runtime_tool("cs_file_read", request)
		return _owner._convert_bridge_read_response(response, script_path)

	func patch_file(script_path: String, request: Dictionary) -> Dictionary:
		var bridge_request := request.duplicate(true)
		bridge_request["path"] = script_path
		var response := _owner._execute_runtime_tool("cs_file_patch", bridge_request)
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


func _instantiate_facade():
	var script = ResourceLoader.load(FACADE_SCRIPT_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if script == null or not (script is Script):
		var process_facade = _instantiate_runtime_process_facade("PluginRoslynRuntimeFacade runtime source could not be loaded from res://")
		if process_facade != null:
			return process_facade
		return PlaceholderRoslynFacade.new(_base_metadata(true), _load_error)
	var script_resource := script as Script
	if script_resource.can_instantiate():
		var class_instance = script_resource.new()
		if class_instance != null:
			_load_mode = LOAD_MODE_RUNTIME
			_load_error = ""
			return class_instance
	if ClassDB.class_exists("PluginRoslynRuntimeFacade"):
		var class_instance = ClassDB.instantiate("PluginRoslynRuntimeFacade")
		if class_instance != null:
			_load_mode = LOAD_MODE_RUNTIME
			_load_error = ""
			return class_instance
	if not script_resource.can_instantiate():
		var process_facade = _instantiate_runtime_process_facade("PluginRoslynRuntimeFacade runtime source is present but not instantiable in the current Godot C# environment")
		if process_facade != null:
			return process_facade
		return PlaceholderRoslynFacade.new(_base_metadata(true), _load_error)
	var fallback_process_facade = _instantiate_runtime_process_facade("PluginRoslynRuntimeFacade runtime source is present but could not be instantiated")
	if fallback_process_facade != null:
		return fallback_process_facade
	return PlaceholderRoslynFacade.new(_base_metadata(true), _load_error)


func _instantiate_runtime_process_facade(reason: String):
	if not FileAccess.file_exists(RUNTIME_BRIDGE_DLL_PATH):
		_load_mode = LOAD_MODE_PLACEHOLDER
		_load_error = _build_runtime_unavailable_message("%s; isolated runtime bridge is missing at %s" % [reason, RUNTIME_BRIDGE_DLL_PATH])
		return null
	var capabilities := _execute_runtime_capabilities()
	if not bool(capabilities.get("success", false)):
		_load_mode = LOAD_MODE_PLACEHOLDER
		_load_error = str(capabilities.get("error", _build_runtime_unavailable_message(reason)))
		return null
	_load_mode = LOAD_MODE_RUNTIME_PROCESS
	_load_error = ""
	return RuntimeProcessRoslynFacade.new(self)


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


func _execute_runtime_tool(tool_name: String, request: Dictionary) -> Dictionary:
	var request_path := _make_runtime_request_path(tool_name)
	var file := FileAccess.open(request_path, FileAccess.WRITE)
	if file == null:
		return {
			"success": false,
			"error": "Failed to create Roslyn runtime request file: %s" % request_path
		}
	file.store_string(JSON.stringify(request))
	file.close()
	var result := _execute_runtime_process(["--call-json-file", tool_name, ProjectSettings.globalize_path(request_path)])
	if FileAccess.file_exists(request_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(request_path))
	return result


func _execute_runtime_process(args: Array[String]) -> Dictionary:
	var output: Array = []
	var runtime_dll := ProjectSettings.globalize_path(RUNTIME_BRIDGE_DLL_PATH)
	var command_args: Array[String] = [runtime_dll]
	command_args.append_array(args)
	var exit_code := OS.execute("dotnet", PackedStringArray(command_args), output, true, false)
	var stdout := ""
	if not output.is_empty():
		stdout = str(output[0]).strip_edges()
	if exit_code != 0:
		return {
			"success": false,
			"error": "Isolated Roslyn runtime exited with code %d: %s" % [exit_code, stdout],
			"exit_code": exit_code,
			"stdout": stdout
		}
	var parsed = JSON.parse_string(stdout)
	if not (parsed is Dictionary):
		return {
			"success": false,
			"error": "Isolated Roslyn runtime returned invalid JSON.",
			"exit_code": exit_code,
			"stdout": stdout
		}
	return {
		"success": true,
		"payload": parsed,
		"exit_code": exit_code,
		"stdout": stdout
	}


func _make_runtime_request_path(tool_name: String) -> String:
	var safe_tool_name := tool_name.replace("/", "_").replace("\\", "_").replace(":", "_")
	return "user://godot_dotnet_mcp_roslyn_%s_%d_%d.json" % [
		safe_tool_name,
		Time.get_ticks_msec(),
		randi()
	]


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
	data["exports"] = []
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
	data["source_hash"] = str(structured.get("contentHash", ""))
	data["operation"] = _first_operation(_coerce_array(structured.get("operations", [])))
	data["operations"] = _coerce_array(structured.get("operations", []))
	data["preview"] = str(structured.get("preview", ""))
	data["written"] = bool(structured.get("written", false))
	data["dry_run"] = bool(structured.get("dryRun", true))
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
		payload["message"] = "Plugin-internal Roslyn facade is ready."
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
	var transport := "in_process"
	var entrypoint := "plugin_internal_facade"
	if _load_mode == LOAD_MODE_RUNTIME_PROCESS:
		transport = "process_json"
		entrypoint = RUNTIME_BRIDGE_DLL_PATH
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
