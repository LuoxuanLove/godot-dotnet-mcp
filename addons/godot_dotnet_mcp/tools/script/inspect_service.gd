@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"


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

	var parse_result = _parse_script_metadata(path)
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

	var parse_result = _parse_script_metadata(path)
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

	return _success({
		"path": _normalize_res_path(path),
		"language": parse_result["data"].get("language", "unknown"),
		"count": symbols.size(),
		"symbols": symbols
	})


func _execute_exports(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	if path.is_empty():
		return _error("Path is required")

	var parse_result = _parse_script_metadata(path)
	if not parse_result.get("success", false):
		return parse_result

	var metadata = parse_result["data"]
	return _success({
		"path": metadata["path"],
		"language": metadata["language"],
		"class_name": metadata.get("class_name", ""),
		"count": metadata.get("exports", []).size(),
		"export_groups": metadata.get("export_groups", []),
		"exports": metadata.get("exports", [])
	})
