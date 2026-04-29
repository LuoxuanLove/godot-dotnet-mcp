@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"read":
			return _execute_read(args)
		"open":
			return _execute_open(args)
		_:
			return _error("Unknown script read tool: %s" % tool_name)


func _execute_read(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	if path.is_empty():
		return _error("Path is required")

	var read_result = _read_text_file(path)
	if not read_result.get("success", false):
		return read_result

	var data = read_result["data"]
	data["language"] = _detect_script_language(data["path"])
	return _success(data)


func _execute_open(args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	match action:
		"open":
			return _open_script(args.get("path", ""))
		"open_at_line":
			return _open_script_at_line(args.get("path", ""), args.get("line", 1))
		"get_open_scripts":
			return _get_open_scripts()
		_:
			return _error("Unknown action: %s" % action)


func _open_script(path: String) -> Dictionary:
	var normalized = _normalize_res_path(path)
	if normalized.is_empty():
		return _error("Path is required")
	if not ResourceLoader.exists(normalized):
		return _error("Script not found: %s" % normalized)

	var script = load(normalized)
	if not script:
		return _error("Failed to load script")

	var ei = _get_editor_interface()
	if ei:
		ei.edit_script(script)

	return _success({"path": normalized}, "Script opened in editor")


func _open_script_at_line(path: String, line: int) -> Dictionary:
	var normalized = _normalize_res_path(path)
	if normalized.is_empty():
		return _error("Path is required")
	if not ResourceLoader.exists(normalized):
		return _error("Script not found: %s" % normalized)

	var script = load(normalized)
	if not script:
		return _error("Failed to load script")

	var ei = _get_editor_interface()
	if ei:
		ei.edit_script(script, line)

	return _success({
		"path": normalized,
		"line": line
	}, "Script opened at line %d" % line)


func _get_open_scripts() -> Dictionary:
	var ei = _get_editor_interface()
	if not ei:
		return _error("Editor interface not available")

	var script_editor = ei.get_script_editor()
	if not script_editor:
		return _error("Script editor not available")

	var open_scripts = script_editor.get_open_scripts()
	var scripts: Array[Dictionary] = []

	for script in open_scripts:
		scripts.append({
			"path": str(script.resource_path),
			"type": str(script.get_class()),
			"language": _detect_script_language(str(script.resource_path))
		})

	return _success({
		"count": scripts.size(),
		"scripts": scripts
	})
