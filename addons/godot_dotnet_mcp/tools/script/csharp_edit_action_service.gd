@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

const CSharpEditHelper = preload("res://addons/godot_dotnet_mcp/tools/script/csharp_edit_helper.gd")

var _edit_helper := CSharpEditHelper.new()


func create_script(path: String, args: Dictionary) -> Dictionary:
	if FileAccess.file_exists(path):
		return _error("Script already exists: %s" % path)

	var class_name_str := str(args.get("class_name", "")).strip_edges()
	if class_name_str.is_empty():
		class_name_str = path.get_file().trim_suffix(".cs")
	var namespace_str := str(args.get("namespace", "")).strip_edges()
	var base_type := str(args.get("base_type", "Node")).strip_edges()
	if base_type.is_empty():
		base_type = "Node"

	var lines: Array[String] = []
	lines.append("using Godot;")
	lines.append("")
	if not namespace_str.is_empty():
		lines.append("namespace %s;" % namespace_str)
		lines.append("")
	lines.append("public partial class %s : %s" % [class_name_str, base_type])
	lines.append("{")
	lines.append("}")

	return write_script(path, "\n".join(lines))


func write_script(path: String, content: String) -> Dictionary:
	if content.is_empty():
		return _error("Content is required")

	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _error("Failed to write script")

	file.store_string(content)
	file.close()
	_scan_filesystem_if_available()
	return _edit_helper.validate_written_script(path, content)


func add_field(path: String, args: Dictionary) -> Dictionary:
	var field_name = str(args.get("name", "")).strip_edges()
	if field_name.is_empty():
		return _error("Field name is required")
	return _append_member(path, _build_field_code(args))


func add_method(path: String, args: Dictionary) -> Dictionary:
	var method_name = str(args.get("name", "")).strip_edges()
	if method_name.is_empty():
		return _error("Method name is required")
	return _append_member(path, _build_method_code(args))


func replace_method_body(path: String, name: String, new_body: String) -> Dictionary:
	if name.is_empty():
		return _error("Method name is required")

	var read_result := _read_text_file(path)
	if not bool(read_result.get("success", false)):
		return read_result

	var content := str(read_result.get("data", {}).get("content", ""))
	var masked := _edit_helper.mask_non_code(content)
	var search_pattern := "(?m)^[^\\S\\n]*(?:(?:public|private|protected|internal|static|virtual|override|async|partial|abstract|sealed|new)\\s+)*[A-Za-z_][A-Za-z0-9_<>\\[\\]?,\\s]*\\s+%s\\s*\\(" % name
	var regex := RegEx.new()
	if regex.compile(search_pattern) != OK:
		return _error("Failed to compile method search pattern")

	var method_match := regex.search(masked)
	if method_match == null:
		return _error("Method not found in C# file: %s" % name)

	var open_brace := _edit_helper.find_next_non_code_brace(masked, method_match.get_end(0))
	if open_brace == -1:
		return _error("Method body opening brace not found for: %s" % name)

	var close_brace := _edit_helper.find_matching_brace(masked, open_brace)
	if close_brace == -1:
		return _error("Method body closing brace not found for: %s" % name)

	var line_start := content.rfind("\n", open_brace)
	var method_line := content.substr(line_start + 1, open_brace - line_start - 1)
	var body_indent := _edit_helper.leading_whitespace(method_line) + "\t"
	var indented_body := _edit_helper.indent_multiline_block(new_body.strip_edges(), body_indent)
	var new_content := content.substr(0, open_brace + 1) + "\n" + indented_body + "\n" + _edit_helper.leading_whitespace(method_line) + content.substr(close_brace)
	return write_script(path, new_content)


func remove_member(path: String, name: String, member_type: String) -> Dictionary:
	if name.is_empty():
		return _error("Member name is required")

	var read_result := _read_text_file(path)
	if not bool(read_result.get("success", false)):
		return read_result

	var content := str(read_result.get("data", {}).get("content", ""))
	var masked := _edit_helper.mask_non_code(content)

	if member_type in ["method", "function", "auto", ""]:
		var method_pattern := "(?m)^[^\\S\\n]*(?:(?:public|private|protected|internal|static|virtual|override|async|partial|abstract|sealed|new)\\s+)*[A-Za-z_][A-Za-z0-9_<>\\[\\]?,\\s]*\\s+%s\\s*\\(" % name
		var method_regex := RegEx.new()
		if method_regex.compile(method_pattern) == OK:
			var mm := method_regex.search(masked)
			if mm != null:
				var open_brace := _edit_helper.find_next_non_code_brace(masked, mm.get_end(0))
				if open_brace != -1:
					var close_brace := _edit_helper.find_matching_brace(masked, open_brace)
					if close_brace != -1:
						var member_start := _edit_helper.find_member_block_start(content, mm.get_start(0))
						var member_end := close_brace + 1
						while member_end < content.length() and content.substr(member_end, 1) == "\n":
							member_end += 1
						return write_script(path, content.substr(0, member_start) + content.substr(member_end))

	if member_type in ["field", "property", "variable", "auto", ""]:
		var field_pattern := "(?m)^[^\\S\\n]*(?:\\[[^\\]]+\\]\\s*\\n[^\\S\\n]*)?(?:(?:public|private|protected|internal|static|readonly|const|new)\\s+)+[A-Za-z_][A-Za-z0-9_<>\\[\\]?,\\s]*\\s+%s\\s*[;=]" % name
		var field_regex := RegEx.new()
		if field_regex.compile(field_pattern) == OK:
			var fm := field_regex.search(masked)
			if fm != null:
				var member_start := _edit_helper.find_member_block_start(content, fm.get_start(0))
				var line_end := content.find("\n", fm.get_end(0))
				if line_end == -1:
					line_end = content.length()
				else:
					line_end += 1
				return write_script(path, content.substr(0, member_start) + content.substr(line_end))

	return _error("Member not found in C# file: %s" % name)


func rename_member(path: String, old_name: String, new_name: String) -> Dictionary:
	if old_name.is_empty():
		return _error("Old name is required")
	if new_name.is_empty():
		return _error("New name is required")

	var read_result := _read_text_file(path)
	if not bool(read_result.get("success", false)):
		return read_result

	var content := str(read_result.get("data", {}).get("content", ""))
	var masked := _edit_helper.mask_non_code(content)

	var method_pattern := "(?m)^[^\\S\\n]*(?:(?:public|private|protected|internal|static|virtual|override|async|partial|abstract|sealed|new)\\s+)*[A-Za-z_][A-Za-z0-9_<>\\[\\]?,\\s]*\\s+(%s)\\s*\\(" % old_name
	var regex := RegEx.new()
	if regex.compile(method_pattern) == OK:
		var mm := regex.search(masked)
		if mm != null:
			return write_script(path, content.substr(0, mm.get_start(1)) + new_name + content.substr(mm.get_end(1)))

	var field_pattern := "(?m)^[^\\S\\n]*(?:(?:public|private|protected|internal|static|readonly|const|new)\\s+)+[A-Za-z_][A-Za-z0-9_<>\\[\\]?,\\s]*\\s+(%s)\\s*[;={]" % old_name
	regex = RegEx.new()
	if regex.compile(field_pattern) == OK:
		var fm := regex.search(masked)
		if fm != null:
			return write_script(path, content.substr(0, fm.get_start(1)) + new_name + content.substr(fm.get_end(1)))

	return _error("Member not found in C# file: %s" % old_name)


func _build_field_code(args: Dictionary) -> String:
	var access = str(args.get("access", "public")).strip_edges()
	if access.is_empty():
		access = "public"
	var type_name = str(args.get("type", "Variant")).strip_edges()
	if type_name.is_empty():
		type_name = "Variant"
	var field_name = str(args.get("name", "")).strip_edges()
	var value = str(args.get("value", "")).strip_edges()
	var exported = bool(args.get("exported", false))
	var modifiers = args.get("modifiers", [])

	var parts: Array[String] = []
	parts.append(access)
	if modifiers is Array:
		for modifier in modifiers:
			var modifier_text = str(modifier).strip_edges()
			if not modifier_text.is_empty():
				parts.append(modifier_text)
	parts.append(type_name)
	parts.append(field_name)

	var declaration = " ".join(parts)
	if not value.is_empty():
		declaration += " = %s" % value
	declaration += ";"
	if exported:
		return "[Export]\n%s" % declaration
	return declaration


func _build_method_code(args: Dictionary) -> String:
	var access = str(args.get("access", "public")).strip_edges()
	if access.is_empty():
		access = "public"
	var return_type = str(args.get("return_type", "void")).strip_edges()
	if return_type.is_empty():
		return_type = "void"
	var method_name = str(args.get("name", "")).strip_edges()
	var modifiers = args.get("modifiers", [])
	var params_value = args.get("params", [])
	var body = str(args.get("body", "")).strip_edges()
	if body.is_empty():
		body = "// TODO: implement"
		if return_type != "void":
			body += "\nreturn default;"

	var signature_parts: Array[String] = []
	signature_parts.append(access)
	if modifiers is Array:
		for modifier in modifiers:
			var modifier_text = str(modifier).strip_edges()
			if not modifier_text.is_empty():
				signature_parts.append(modifier_text)
	signature_parts.append(return_type)

	var params_list: Array[String] = []
	if params_value is Array:
		for item in params_value:
			var param_text = str(item).strip_edges()
			if not param_text.is_empty():
				params_list.append(param_text)
	signature_parts.append("%s(%s)" % [method_name, ", ".join(params_list)])

	var lines: Array[String] = []
	lines.append(" ".join(signature_parts))
	lines.append("{")
	for body_line in body.split("\n"):
		lines.append("    %s" % body_line)
	lines.append("}")
	return "\n".join(lines)


func _append_member(path: String, member_code: String) -> Dictionary:
	var read_result = _read_text_file(path)
	if not bool(read_result.get("success", false)):
		return read_result

	var content = str(read_result.get("data", {}).get("content", ""))
	var metadata = _parse_csharp_metadata(path, content)
	var expected_class_name = str(metadata.get("class_name", "")).strip_edges()
	if expected_class_name.is_empty():
		expected_class_name = path.get_file().trim_suffix(".cs")

	var class_close_index = _edit_helper.find_primary_class_close(content, expected_class_name)
	if class_close_index == -1:
		return _error("Failed to locate primary C# class body")

	var member_indent = _edit_helper.detect_member_indent(content, class_close_index)
	var indented_member = _edit_helper.indent_multiline_block(member_code, member_indent)
	var prefix = _edit_helper.trim_trailing_whitespace(content.substr(0, class_close_index))
	var suffix = content.substr(class_close_index)
	var new_content = "%s\n\n%s\n%s" % [prefix, indented_member, suffix]
	return write_script(path, new_content)


func _scan_filesystem_if_available() -> void:
	if not Engine.is_editor_hint():
		return
	var fs = _get_filesystem()
	if fs:
		fs.scan()
