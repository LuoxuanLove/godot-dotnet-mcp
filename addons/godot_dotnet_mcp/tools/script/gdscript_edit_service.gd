@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	var path = _normalize_res_path(args.get("path", ""))
	if path.is_empty():
		return _error("Path is required")
	if not path.ends_with(".gd"):
		return _error("script_edit_gd only supports .gd files")

	match action:
		"create":
			return _create_gdscript(path, args.get("extends", "Node"), args.get("class_name", ""))
		"write":
			return _write_gdscript(path, args.get("content", ""))
		"delete":
			return _delete_script_file(path)
		"add_function":
			return _add_gd_function(path, args)
		"remove_function":
			return _remove_gd_function(path, args.get("name", ""))
		"add_variable":
			return _add_gd_variable(path, args)
		"add_signal":
			return _add_gd_signal(path, args.get("name", ""), args.get("params", []))
		"add_export":
			return _add_gd_export(path, args)
		"get_functions":
			return _get_gd_functions(path)
		"get_variables":
			return _get_gd_variables(path)
		"replace_function_body":
			return _replace_gd_function_body(path, str(args.get("name", "")), str(args.get("body", "")))
		"remove_member":
			return _remove_gd_member(path, str(args.get("name", "")), str(args.get("member_type", "auto")))
		"rename_member":
			return _rename_gd_member(path, str(args.get("name", "")), str(args.get("new_name", "")))
		_:
			return _error("Unknown action: %s" % action)


func _create_gdscript(path: String, extends_class: String, class_name_str: String) -> Dictionary:
	if FileAccess.file_exists(path):
		return _error("Script already exists: %s" % path)

	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

	var lines: Array[String] = []
	if not class_name_str.is_empty():
		lines.append("class_name %s" % class_name_str)
	lines.append("extends %s" % extends_class)
	lines.append("")
	lines.append("func _ready() -> void:")
	lines.append("\tpass")

	return _write_gdscript(path, "\n".join(lines))


func _write_gdscript(path: String, content: String) -> Dictionary:
	if content.is_empty():
		return _error("Content is required")

	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return _error("Failed to write script")

	file.store_string(content)
	file.close()

	_scan_filesystem_if_available()

	return _success({
		"path": path,
		"language": "gdscript",
		"line_count": content.split("\n").size()
	}, "Script written: %s" % path)


func _delete_script_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _error("Script not found: %s" % path)

	var error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if error != OK:
		return _error("Failed to delete script: %s" % error_string(error))

	_scan_filesystem_if_available()

	return _success({"deleted": path}, "Script deleted")


func _add_gd_function(path: String, args: Dictionary) -> Dictionary:
	var name = str(args.get("name", ""))
	if name.is_empty():
		return _error("Function name is required")

	var read_result = _read_text_file(path)
	if not read_result.get("success", false):
		return read_result

	var content = read_result["data"]["content"] as String
	var params_str = ", ".join(args.get("params", []))
	var return_type = str(args.get("return_type", "")).strip_edges()
	var body = str(args.get("body", "pass"))
	var func_signature = "\n\nfunc %s(%s)" % [name, params_str]
	if not return_type.is_empty():
		func_signature += " -> %s" % return_type
	func_signature += ":\n"
	var func_code = func_signature

	for line in body.split("\n"):
		func_code += "\t%s\n" % line

	return _write_gdscript(path, content + func_code)


func _strip_gd_func_modifiers(stripped: String) -> String:
	var s := stripped
	var modifiers := ["static", "async"]
	var changed := true
	while changed:
		changed = false
		for mod in modifiers:
			if s.begins_with(mod + " ") or s.begins_with(mod + "\t"):
				s = s.substr(mod.length()).strip_edges(true, false)
				changed = true
	return s


func _remove_gd_function(path: String, name: String) -> Dictionary:
	if name.is_empty():
		return _error("Function name is required")

	var read_result = _read_text_file(path)
	if not read_result.get("success", false):
		return read_result

	var content = read_result["data"]["content"] as String
	var lines = content.split("\n")
	var new_lines: Array[String] = []
	var in_function = false
	var func_indent = 0

	for line in lines:
		var stripped = line.strip_edges()
		if _strip_gd_func_modifiers(stripped).begins_with("func %s" % name):
			in_function = true
			func_indent = line.length() - line.strip_edges(true, false).length()
			continue

		if in_function:
			var current_indent = line.length() - line.strip_edges(true, false).length()
			if not stripped.is_empty() and current_indent <= func_indent:
				in_function = false

		if not in_function:
			new_lines.append(line)

	return _write_gdscript(path, "\n".join(new_lines))


func _add_gd_variable(path: String, args: Dictionary) -> Dictionary:
	var name = str(args.get("name", ""))
	if name.is_empty():
		return _error("Variable name is required")

	var read_result = _read_text_file(path)
	if not read_result.get("success", false):
		return read_result

	var content = read_result["data"]["content"] as String
	var lines = content.split("\n")
	var insert_index = 0
	for i in lines.size():
		var line = lines[i].strip_edges()
		if line.begins_with("extends ") or line.begins_with("class_name "):
			insert_index = i + 1
		elif not line.is_empty() and not line.begins_with("#"):
			break

	var var_type = str(args.get("type", ""))
	var value = str(args.get("value", ""))
	var var_line = "var %s" % name
	if not var_type.is_empty():
		var_line += ": %s" % var_type
	if not value.is_empty():
		var_line += " = %s" % value

	lines.insert(insert_index, var_line)
	return _write_gdscript(path, "\n".join(lines))


func _add_gd_signal(path: String, name: String, params: Array) -> Dictionary:
	if name.is_empty():
		return _error("Signal name is required")

	var read_result = _read_text_file(path)
	if not read_result.get("success", false):
		return read_result

	var content = read_result["data"]["content"] as String
	var lines = content.split("\n")
	var insert_index = 0
	for i in lines.size():
		var line = lines[i].strip_edges()
		if line.begins_with("extends ") or line.begins_with("class_name "):
			insert_index = i + 1
		elif not line.is_empty() and not line.begins_with("#") and not line.begins_with("signal "):
			break

	var signal_line = "signal %s" % name
	if not params.is_empty():
		signal_line += "(%s)" % ", ".join(params)

	lines.insert(insert_index, signal_line)
	return _write_gdscript(path, "\n".join(lines))


func _add_gd_export(path: String, args: Dictionary) -> Dictionary:
	var name = str(args.get("name", ""))
	if name.is_empty():
		return _error("Export variable name is required")

	var read_result = _read_text_file(path)
	if not read_result.get("success", false):
		return read_result

	var content = read_result["data"]["content"] as String
	var lines = content.split("\n")
	var insert_index = 0
	for i in lines.size():
		var line = lines[i].strip_edges()
		if line.begins_with("extends ") or line.begins_with("class_name ") or line.begins_with("signal "):
			insert_index = i + 1
		elif not line.is_empty() and not line.begins_with("#"):
			break

	var export_line = "@export var %s" % name
	var var_type = str(args.get("type", ""))
	var value = str(args.get("value", ""))
	if not var_type.is_empty():
		export_line += ": %s" % var_type
	if not value.is_empty():
		export_line += " = %s" % value

	lines.insert(insert_index, export_line)
	return _write_gdscript(path, "\n".join(lines))


func _get_gd_functions(path: String) -> Dictionary:
	var parse_result = _parse_script_metadata(path)
	if not parse_result.get("success", false):
		return parse_result
	if parse_result["data"].get("language") != "gdscript":
		return _error("get_functions only supports .gd files")

	return _success({
		"path": parse_result["data"]["path"],
		"count": parse_result["data"].get("methods", []).size(),
		"functions": parse_result["data"].get("methods", [])
	})


func _get_gd_variables(path: String) -> Dictionary:
	var read_result = _read_text_file(path)
	if not read_result.get("success", false):
		return read_result

	var content = read_result["data"]["content"] as String
	var variables: Array[Dictionary] = []
	var regex = RegEx.new()
	regex.compile("(?m)^(?:@export\\s+)?var\\s+([A-Za-z_][A-Za-z0-9_]*)(?:\\s*:\\s*([^=]+))?(?:\\s*=\\s*(.+))?")

	for match_result in regex.search_all(content):
		var var_info = {
			"name": match_result.get_string(1),
			"exported": str(match_result.get_string(0)).strip_edges().begins_with("@export")
		}
		if not match_result.get_string(2).is_empty():
			var var_type = match_result.get_string(2).strip_edges()
			if var_type.ends_with("\r"):
				var_type = var_type.trim_suffix("\r")
			var_info["type"] = var_type
		if not match_result.get_string(3).is_empty():
			var_info["default"] = match_result.get_string(3).strip_edges()
		variables.append(var_info)

	return _success({
		"path": _normalize_res_path(path),
		"count": variables.size(),
		"variables": variables
	})


func _replace_gd_function_body(path: String, name: String, new_body: String) -> Dictionary:
	if name.is_empty():
		return _error("Function name is required")

	var read_result = _read_text_file(path)
	if not bool(read_result.get("success", false)):
		return read_result

	var content := str(read_result.get("data", {}).get("content", ""))
	var lines := content.split("\n")
	var func_line := -1
	for i in range(lines.size()):
		var stripped := lines[i].strip_edges()
		var core := _strip_gd_func_modifiers(stripped)
		if core.begins_with("func %s(" % name) or core.begins_with("func %s (" % name):
			func_line = i
			break
	if func_line < 0:
		return _error("Function not found: %s" % name)

	var func_indent := lines[func_line].length() - lines[func_line].strip_edges(true, false).length()
	var body_start := func_line + 1
	var body_end := body_start
	while body_end < lines.size():
		var line := lines[body_end]
		var stripped := line.strip_edges()
		if not stripped.is_empty():
			var cur_indent := line.length() - line.strip_edges(true, false).length()
			if cur_indent <= func_indent:
				break
		body_end += 1

	var indent_str := ""
	for _i in func_indent:
		indent_str += "\t"
	var body_indent := indent_str + "\t"

	var actual_body_end := body_end
	while actual_body_end > body_start and lines[actual_body_end - 1].strip_edges().is_empty():
		actual_body_end -= 1

	var new_lines: Array[String] = []
	for i in range(body_start):
		new_lines.append(lines[i])
	for body_line in new_body.split("\n"):
		new_lines.append(body_indent + body_line)
	for i in range(actual_body_end, body_end):
		new_lines.append(lines[i])
	for i in range(body_end, lines.size()):
		new_lines.append(lines[i])

	return _write_gdscript(path, "\n".join(new_lines))


func _remove_gd_member(path: String, name: String, member_type: String) -> Dictionary:
	if name.is_empty():
		return _error("Member name is required")
	match member_type:
		"function", "method":
			return _remove_gd_function(path, name)
		"variable", "export", "signal":
			return _remove_gd_declaration_line(path, name, member_type)
		_:
			var fn_result := _remove_gd_function(path, name)
			if bool(fn_result.get("success", false)):
				return fn_result
			return _remove_gd_declaration_line(path, name, "auto")


func _remove_gd_declaration_line(path: String, name: String, member_type: String) -> Dictionary:
	var read_result := _read_text_file(path)
	if not bool(read_result.get("success", false)):
		return read_result

	var content := str(read_result.get("data", {}).get("content", ""))
	var lines := content.split("\n")
	var new_lines: Array[String] = []
	var removed := false

	for line in lines:
		var stripped := line.strip_edges()
		var matches := false
		if member_type == "signal" or member_type == "auto":
			if stripped == "signal %s" % name or stripped.begins_with("signal %s(" % name) or stripped.begins_with("signal %s (" % name):
				matches = true
		if not matches and member_type != "signal":
			if stripped.begins_with("var %s" % name) or \
			   stripped.begins_with("@export var %s" % name) or \
			   stripped.begins_with("@onready var %s" % name) or \
			   stripped.begins_with("@export_range") and (" var %s" % name) in stripped or \
			   stripped.begins_with("@export_group") and false:
				var after_var := ""
				if "var %s" % name in stripped:
					var idx := stripped.find("var %s" % name)
					after_var = stripped.substr(idx + ("var %s" % name).length())
					if after_var.is_empty() or after_var[0] in [":", "=", " ", "\t"]:
						matches = true
		if matches:
			removed = true
		else:
			new_lines.append(line)

	if not removed:
		return _error("Member not found: %s" % name)
	return _write_gdscript(path, "\n".join(new_lines))


func _rename_gd_member(path: String, old_name: String, new_name: String) -> Dictionary:
	if old_name.is_empty():
		return _error("Old name is required")
	if new_name.is_empty():
		return _error("New name is required")

	var read_result := _read_text_file(path)
	if not bool(read_result.get("success", false)):
		return read_result

	var content := str(read_result.get("data", {}).get("content", ""))
	var lines := content.split("\n")
	var new_lines: Array[String] = []
	var renamed := false

	for line in lines:
		var stripped := line.strip_edges()
		var new_line := line
		var core := _strip_gd_func_modifiers(stripped)
		if core.begins_with("func %s(" % old_name) or core.begins_with("func %s (" % old_name):
			new_line = line.replace("func %s(" % old_name, "func %s(" % new_name)
			new_line = new_line.replace("func %s (" % old_name, "func %s (" % new_name)
			renamed = true
		elif "var %s" % old_name in stripped:
			var after_idx := stripped.find("var %s" % old_name)
			var after := stripped.substr(after_idx + ("var %s" % old_name).length())
			if after.is_empty() or after[0] in [":", "=", " ", "\t"]:
				new_line = line.replace("var %s" % old_name, "var %s" % new_name)
				renamed = true
		elif stripped.begins_with("signal %s" % old_name):
			var after := stripped.substr(("signal %s" % old_name).length())
			if after.is_empty() or after[0] in ["(", " ", "\t"]:
				new_line = line.replace("signal %s" % old_name, "signal %s" % new_name)
				renamed = true
		new_lines.append(new_line)

	if not renamed:
		return _error("Member not found: %s" % old_name)
	return _write_gdscript(path, "\n".join(new_lines))


func _scan_filesystem_if_available() -> void:
	if not Engine.is_editor_hint():
		return
	var fs = _get_filesystem()
	if fs:
		fs.scan()
