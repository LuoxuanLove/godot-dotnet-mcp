@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	var path = _normalize_res_path(str(args.get("path", "")))
	if path.is_empty():
		return _error("Path is required")
	if not path.ends_with(".cs"):
		return _error("script_edit_cs only supports .cs files")

	match action:
		"create":
			return _create_csharp_script(path, args)
		"write":
			return _write_csharp_script(path, str(args.get("content", "")))
		"add_field":
			return _add_csharp_field(path, args)
		"add_method":
			return _add_csharp_method(path, args)
		"replace_method_body":
			return _replace_csharp_method_body(path, str(args.get("name", "")), str(args.get("body", "")))
		"delete_member":
			return _remove_csharp_member(path, str(args.get("name", "")), str(args.get("member_type", "auto")))
		"rename_member":
			return _rename_csharp_member(path, str(args.get("name", "")), str(args.get("new_name", "")))
		_:
			return _error("Unknown action: %s" % action)


func _create_csharp_script(path: String, args: Dictionary) -> Dictionary:
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

	return _write_csharp_script(path, "\n".join(lines))


func _write_csharp_script(path: String, content: String) -> Dictionary:
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

	return _validate_csharp_script(path, content)


func _add_csharp_field(path: String, args: Dictionary) -> Dictionary:
	var field_name = str(args.get("name", "")).strip_edges()
	if field_name.is_empty():
		return _error("Field name is required")
	var member_code = _build_csharp_field_code(args)
	return _append_csharp_member(path, member_code)


func _add_csharp_method(path: String, args: Dictionary) -> Dictionary:
	var method_name = str(args.get("name", "")).strip_edges()
	if method_name.is_empty():
		return _error("Method name is required")
	var member_code = _build_csharp_method_code(args)
	return _append_csharp_member(path, member_code)


func _build_csharp_field_code(args: Dictionary) -> String:
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


func _build_csharp_method_code(args: Dictionary) -> String:
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


func _append_csharp_member(path: String, member_code: String) -> Dictionary:
	var read_result = _read_text_file(path)
	if not bool(read_result.get("success", false)):
		return read_result

	var content = str(read_result.get("data", {}).get("content", ""))
	var metadata = _parse_csharp_metadata(path, content)
	var expected_class_name = str(metadata.get("class_name", "")).strip_edges()
	if expected_class_name.is_empty():
		expected_class_name = path.get_file().trim_suffix(".cs")

	var class_close_index = _find_primary_csharp_class_close(content, expected_class_name)
	if class_close_index == -1:
		return _error("Failed to locate primary C# class body")

	var member_indent = _detect_csharp_member_indent(content, class_close_index)
	var indented_member = _indent_multiline_block(member_code, member_indent)
	var prefix = _trim_trailing_whitespace(content.substr(0, class_close_index))
	var suffix = content.substr(class_close_index)
	var new_content = "%s\n\n%s\n%s" % [prefix, indented_member, suffix]
	return _write_csharp_script(path, new_content)


func _find_primary_csharp_class_close(content: String, expected_class_name: String = "") -> int:
	var masked_content = _mask_csharp_non_code(content)
	var open_brace_index = _find_csharp_class_open_brace(masked_content, expected_class_name)
	if open_brace_index == -1 and not expected_class_name.is_empty():
		open_brace_index = _find_csharp_class_open_brace(masked_content)
	if open_brace_index == -1:
		return -1

	return _find_matching_brace(masked_content, open_brace_index)


func _find_csharp_class_open_brace(masked_content: String, expected_class_name: String = "") -> int:
	var regex = RegEx.new()
	var pattern = "(?m)^\\s*(?:public|internal|private|protected)?\\s*(?:(?:partial|static|abstract|sealed|new)\\s+)*class\\s+([A-Za-z_][A-Za-z0-9_]*)\\b"
	if not expected_class_name.is_empty():
		pattern = "(?m)^\\s*(?:public|internal|private|protected)?\\s*(?:(?:partial|static|abstract|sealed|new)\\s+)*class\\s+%s\\b" % expected_class_name
	var error = regex.compile(pattern)
	if error != OK:
		return -1

	var match = regex.search(masked_content)
	if match == null:
		return -1
	return _find_next_non_code_brace(masked_content, match.get_end(0))


func _find_next_non_code_brace(masked_content: String, start_index: int) -> int:
	for index in range(start_index, masked_content.length()):
		if masked_content.substr(index, 1) == "{":
			return index
	return -1


func _mask_csharp_non_code(content: String) -> String:
	var masked := ""
	var index := 0
	while index < content.length():
		var current = content.substr(index, 1)
		var next = content.substr(index + 1, 1) if index + 1 < content.length() else ""
		var next_two = content.substr(index + 2, 1) if index + 2 < content.length() else ""

		if current == "/" and next == "/":
			masked += "  "
			index += 2
			while index < content.length():
				var comment_char = content.substr(index, 1)
				if comment_char == "\n":
					masked += "\n"
					index += 1
					break
				masked += " " if comment_char != "\r" else "\r"
				index += 1
			continue

		if current == "/" and next == "*":
			masked += "  "
			index += 2
			while index < content.length():
				var block_char = content.substr(index, 1)
				var block_next = content.substr(index + 1, 1) if index + 1 < content.length() else ""
				if block_char == "*" and block_next == "/":
					masked += "  "
					index += 2
					break
				masked += block_char if block_char == "\n" or block_char == "\r" else " "
				index += 1
			continue

		if current == "@" and next == "\"":
			var verbatim_result = _mask_csharp_verbatim_string(content, index, 2)
			masked += str(verbatim_result.get("masked", ""))
			index = int(verbatim_result.get("next_index", index + 2))
			continue

		if current == "$" and next == "@":
			if next_two == "\"":
				var interpolated_verbatim_result = _mask_csharp_verbatim_string(content, index, 3)
				masked += str(interpolated_verbatim_result.get("masked", ""))
				index = int(interpolated_verbatim_result.get("next_index", index + 3))
				continue
		elif current == "@" and next == "$":
			if next_two == "\"":
				var alternate_interpolated_result = _mask_csharp_verbatim_string(content, index, 3)
				masked += str(alternate_interpolated_result.get("masked", ""))
				index = int(alternate_interpolated_result.get("next_index", index + 3))
				continue

		if current == "$" and next == "\"":
			var interpolated_string_result = _mask_csharp_quoted_string(content, index, 2)
			masked += str(interpolated_string_result.get("masked", ""))
			index = int(interpolated_string_result.get("next_index", index + 2))
			continue

		if current == "\"":
			var string_result = _mask_csharp_quoted_string(content, index, 1)
			masked += str(string_result.get("masked", ""))
			index = int(string_result.get("next_index", index + 1))
			continue

		if current == "'":
			var char_result = _mask_csharp_char_literal(content, index)
			masked += str(char_result.get("masked", ""))
			index = int(char_result.get("next_index", index + 1))
			continue

		masked += current
		index += 1

	return masked


func _mask_csharp_quoted_string(content: String, start_index: int, prefix_length: int) -> Dictionary:
	var masked = " ".repeat(prefix_length)
	var index = start_index + prefix_length
	while index < content.length():
		var current = content.substr(index, 1)
		if current == "\\" and index + 1 < content.length():
			masked += "  "
			index += 2
			continue
		masked += current if current == "\n" or current == "\r" else " "
		index += 1
		if current == "\"":
			break
	return {
		"masked": masked,
		"next_index": index
	}


func _mask_csharp_verbatim_string(content: String, start_index: int, prefix_length: int) -> Dictionary:
	var masked = " ".repeat(prefix_length)
	var index = start_index + prefix_length
	while index < content.length():
		var current = content.substr(index, 1)
		var next = content.substr(index + 1, 1) if index + 1 < content.length() else ""
		if current == "\"" and next == "\"":
			masked += "  "
			index += 2
			continue
		masked += current if current == "\n" or current == "\r" else " "
		index += 1
		if current == "\"":
			break
	return {
		"masked": masked,
		"next_index": index
	}


func _mask_csharp_char_literal(content: String, start_index: int) -> Dictionary:
	var masked = " "
	var index = start_index + 1
	while index < content.length():
		var current = content.substr(index, 1)
		if current == "\\" and index + 1 < content.length():
			masked += "  "
			index += 2
			continue
		masked += current if current == "\n" or current == "\r" else " "
		index += 1
		if current == "'":
			break
	return {
		"masked": masked,
		"next_index": index
	}


func _find_matching_brace(content: String, open_brace_index: int) -> int:
	var depth = 0
	for index in range(open_brace_index, content.length()):
		var char_value = content.substr(index, 1)
		if char_value == "{":
			depth += 1
		elif char_value == "}":
			depth -= 1
			if depth == 0:
				return index
	return -1


func _detect_csharp_member_indent(content: String, class_close_index: int) -> String:
	var line_start_index = content.rfind("\n", class_close_index)
	if line_start_index == -1:
		return "    "

	var closing_line = content.substr(line_start_index + 1, class_close_index - line_start_index - 1)
	return "%s    " % _leading_whitespace(closing_line)


func _indent_multiline_block(content: String, indent: String) -> String:
	var lines: Array[String] = []
	for raw_line in content.split("\n"):
		lines.append("%s%s" % [indent, raw_line])
	return "\n".join(lines)


func _leading_whitespace(line: String) -> String:
	var index = 0
	while index < line.length():
		var char_value = line.substr(index, 1)
		if char_value != " " and char_value != "\t":
			break
		index += 1
	return line.substr(0, index)


func _trim_trailing_whitespace(value: String) -> String:
	var end_index = value.length()
	while end_index > 0:
		var char_value = value.substr(end_index - 1, 1)
		if char_value != " " and char_value != "\t" and char_value != "\n" and char_value != "\r":
			break
		end_index -= 1
	return value.substr(0, end_index)


func _validate_csharp_script(path: String, content: String) -> Dictionary:
	var parse_result = _parse_script_metadata(path)
	if not bool(parse_result.get("success", false)):
		return _error("C# script validation failed", {
			"path": path,
			"line_count": content.split("\n").size(),
			"parse_result": parse_result
		})

	var metadata := parse_result.get("data", {})
	if str(metadata.get("class_name", "")).strip_edges().is_empty():
		return _error("C# script validation failed: class declaration not found", {
			"path": path,
			"line_count": content.split("\n").size()
		})

	return _success({
		"path": path,
		"language": "csharp",
		"class_name": metadata.get("class_name", ""),
		"namespace": metadata.get("namespace", ""),
		"line_count": content.split("\n").size(),
		"method_count": metadata.get("methods", []).size(),
		"export_count": metadata.get("exports", []).size()
	}, "C# script written: %s" % path)


func _replace_csharp_method_body(path: String, name: String, new_body: String) -> Dictionary:
	if name.is_empty():
		return _error("Method name is required")

	var read_result := _read_text_file(path)
	if not bool(read_result.get("success", false)):
		return read_result

	var content := str(read_result.get("data", {}).get("content", ""))
	var masked := _mask_csharp_non_code(content)
	var search_pattern := "(?m)^[^\\S\\n]*(?:(?:public|private|protected|internal|static|virtual|override|async|partial|abstract|sealed|new)\\s+)*[A-Za-z_][A-Za-z0-9_<>\\[\\]?,\\s]*\\s+%s\\s*\\(" % name
	var regex := RegEx.new()
	if regex.compile(search_pattern) != OK:
		return _error("Failed to compile method search pattern")

	var method_match := regex.search(masked)
	if method_match == null:
		return _error("Method not found in C# file: %s" % name)

	var open_brace := _find_next_non_code_brace(masked, method_match.get_end(0))
	if open_brace == -1:
		return _error("Method body opening brace not found for: %s" % name)

	var close_brace := _find_matching_brace(masked, open_brace)
	if close_brace == -1:
		return _error("Method body closing brace not found for: %s" % name)

	var line_start := content.rfind("\n", open_brace)
	var method_line := content.substr(line_start + 1, open_brace - line_start - 1)
	var body_indent := _leading_whitespace(method_line) + "\t"

	var indented_body := _indent_multiline_block(new_body.strip_edges(), body_indent)
	var new_content := content.substr(0, open_brace + 1) + "\n" + indented_body + "\n" + _leading_whitespace(method_line) + content.substr(close_brace)
	return _write_csharp_script(path, new_content)


func _remove_csharp_member(path: String, name: String, member_type: String) -> Dictionary:
	if name.is_empty():
		return _error("Member name is required")

	var read_result := _read_text_file(path)
	if not bool(read_result.get("success", false)):
		return read_result

	var content := str(read_result.get("data", {}).get("content", ""))
	var masked := _mask_csharp_non_code(content)

	if member_type in ["method", "function", "auto", ""]:
		var method_pattern := "(?m)^[^\\S\\n]*(?:(?:public|private|protected|internal|static|virtual|override|async|partial|abstract|sealed|new)\\s+)*[A-Za-z_][A-Za-z0-9_<>\\[\\]?,\\s]*\\s+%s\\s*\\(" % name
		var regex := RegEx.new()
		if regex.compile(method_pattern) == OK:
			var mm := regex.search(masked)
			if mm != null:
				var open_brace := _find_next_non_code_brace(masked, mm.get_end(0))
				if open_brace != -1:
					var close_brace := _find_matching_brace(masked, open_brace)
					if close_brace != -1:
						var member_start := _find_member_block_start(content, mm.get_start(0))
						var member_end := close_brace + 1
						while member_end < content.length() and content.substr(member_end, 1) == "\n":
							member_end += 1
						var new_content := content.substr(0, member_start) + content.substr(member_end)
						return _write_csharp_script(path, new_content)

	if member_type in ["field", "property", "variable", "auto", ""]:
		var field_pattern := "(?m)^[^\\S\\n]*(?:\\[[^\\]]+\\]\\s*\\n[^\\S\\n]*)?(?:(?:public|private|protected|internal|static|readonly|const|new)\\s+)+[A-Za-z_][A-Za-z0-9_<>\\[\\]?,\\s]*\\s+%s\\s*[;=]" % name
		var regex := RegEx.new()
		if regex.compile(field_pattern) == OK:
			var fm := regex.search(masked)
			if fm != null:
				var member_start := _find_member_block_start(content, fm.get_start(0))
				var line_end := content.find("\n", fm.get_end(0))
				if line_end == -1:
					line_end = content.length()
				else:
					line_end += 1
				var new_content := content.substr(0, member_start) + content.substr(line_end)
				return _write_csharp_script(path, new_content)

	return _error("Member not found in C# file: %s" % name)


func _find_member_block_start(content: String, member_pos: int) -> int:
	var line_start := content.rfind("\n", member_pos - 1)
	if line_start == -1:
		return 0
	var prev_line_start := content.rfind("\n", line_start - 1)
	if prev_line_start == -1:
		prev_line_start = -1
	var prev_line := content.substr(prev_line_start + 1, line_start - prev_line_start - 1).strip_edges()
	if prev_line.begins_with("[") and prev_line.ends_with("]"):
		return prev_line_start + 1
	return line_start + 1


func _rename_csharp_member(path: String, old_name: String, new_name: String) -> Dictionary:
	if old_name.is_empty():
		return _error("Old name is required")
	if new_name.is_empty():
		return _error("New name is required")

	var read_result := _read_text_file(path)
	if not bool(read_result.get("success", false)):
		return read_result

	var content := str(read_result.get("data", {}).get("content", ""))
	var masked := _mask_csharp_non_code(content)

	var method_pattern := "(?m)^[^\\S\\n]*(?:(?:public|private|protected|internal|static|virtual|override|async|partial|abstract|sealed|new)\\s+)*[A-Za-z_][A-Za-z0-9_<>\\[\\]?,\\s]*\\s+(%s)\\s*\\(" % old_name
	var regex := RegEx.new()
	if regex.compile(method_pattern) == OK:
		var mm := regex.search(masked)
		if mm != null:
			var name_start := mm.get_start(1)
			var name_end := mm.get_end(1)
			var new_content := content.substr(0, name_start) + new_name + content.substr(name_end)
			return _write_csharp_script(path, new_content)

	var field_pattern := "(?m)^[^\\S\\n]*(?:(?:public|private|protected|internal|static|readonly|const|new)\\s+)+[A-Za-z_][A-Za-z0-9_<>\\[\\]?,\\s]*\\s+(%s)\\s*[;={]" % old_name
	regex = RegEx.new()
	if regex.compile(field_pattern) == OK:
		var fm := regex.search(masked)
		if fm != null:
			var name_start := fm.get_start(1)
			var name_end := fm.get_end(1)
			var new_content := content.substr(0, name_start) + new_name + content.substr(name_end)
			return _write_csharp_script(path, new_content)

	return _error("Member not found in C# file: %s" % old_name)


func _scan_filesystem_if_available() -> void:
	if not Engine.is_editor_hint():
		return
	var fs = _get_filesystem()
	if fs:
		fs.scan()
