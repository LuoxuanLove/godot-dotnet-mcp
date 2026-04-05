@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

const PluginRoslynServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_roslyn_service.gd")

var _plugin_roslyn_service = null


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"inspect":
			return _execute_inspect(args)
		"symbols":
			return _execute_symbols(args)
		"exports":
			return _execute_exports(args)
		_:
			return _error("Unknown script inspect tool: %s" % tool_name)


func _execute_inspect(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	if path.is_empty():
		return _error("Path is required")

	var parse_result = _parse_csharp_metadata_via_roslyn(path) if _normalize_res_path(path).ends_with(".cs") else _parse_script_metadata(path)
	if not parse_result.get("success", false):
		return parse_result

	var metadata = parse_result["data"]
	metadata["symbol_count"] = metadata.get("symbols", []).size()
	metadata["method_count"] = metadata.get("methods", []).size()
	metadata["export_count"] = metadata.get("exports", []).size()
	return _success(metadata)


func _execute_symbols(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	if path.is_empty():
		return _error("Path is required")

	var parse_result = _parse_csharp_metadata_via_roslyn(path) if _normalize_res_path(path).ends_with(".cs") else _parse_script_metadata(path)
	if not parse_result.get("success", false):
		return parse_result

	var kind_filter = str(args.get("kind", "")).strip_edges()
	var query = str(args.get("query", "")).to_lower()
	var symbols: Array = []

	for symbol in parse_result["data"].get("symbols", []):
		var symbol_kind = str(symbol.get("kind", ""))
		var symbol_name = str(symbol.get("name", ""))
		if not kind_filter.is_empty() and symbol_kind != kind_filter:
			continue
		if not query.is_empty() and symbol_name.to_lower().find(query) == -1:
			continue
		symbols.append(symbol)

	var payload := {
		"path": _normalize_res_path(path),
		"language": parse_result["data"].get("language", "unknown"),
		"count": symbols.size(),
		"symbols": symbols
	}
	if _normalize_res_path(path).ends_with(".cs"):
		payload["engine"] = str(parse_result["data"].get("engine", "roslyn"))
		payload["mode"] = str(parse_result["data"].get("mode", "syntax"))
		payload["source_hash"] = str(parse_result["data"].get("source_hash", ""))
		payload["degraded"] = bool(parse_result["data"].get("degraded", false))
	return _success(payload)


func _execute_exports(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	if path.is_empty():
		return _error("Path is required")

	var parse_result = _parse_csharp_metadata_via_roslyn(path) if _normalize_res_path(path).ends_with(".cs") else _parse_script_metadata(path)
	if not parse_result.get("success", false):
		return parse_result

	var metadata = parse_result["data"]
	var payload := {
		"path": str(metadata.get("path", _normalize_res_path(path))),
		"language": str(metadata.get("language", "unknown")),
		"class_name": metadata.get("class_name", ""),
		"count": metadata.get("exports", []).size(),
		"export_groups": metadata.get("export_groups", []),
		"exports": metadata.get("exports", [])
	}
	if _normalize_res_path(path).ends_with(".cs"):
		payload["engine"] = str(metadata.get("engine", "roslyn"))
		payload["mode"] = str(metadata.get("mode", "syntax"))
		payload["source_hash"] = str(metadata.get("source_hash", ""))
		payload["degraded"] = bool(metadata.get("degraded", false))
	return _success(payload)


func _parse_csharp_metadata_via_roslyn(path: String) -> Dictionary:
	var normalized_path := _normalize_res_path(path)
	var service = _get_plugin_roslyn_service()
	if service == null:
		return _error("Plugin Roslyn service is unavailable")
	var result = service.parse_file(normalized_path)
	if not bool(result.get("success", false)):
		return result
	return result


func _get_plugin_roslyn_service():
	if _plugin_roslyn_service == null:
		_ensure_service()
	return _plugin_roslyn_service


func _ensure_service() -> void:
	if _plugin_roslyn_service == null:
		_plugin_roslyn_service = PluginRoslynServiceScript.new()


func clear() -> void:
	if _plugin_roslyn_service != null:
		var service = _plugin_roslyn_service
		_plugin_roslyn_service = null
		if service.has_method("clear"):
			service.clear()
		if service is Node and is_instance_valid(service):
			service.free()
