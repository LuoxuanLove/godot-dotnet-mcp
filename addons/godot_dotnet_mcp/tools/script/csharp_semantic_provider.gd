@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"


func validate_written_script(path: String, content: String) -> Dictionary:
	var metadata = _parse_csharp_metadata(path, content)
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


func find_primary_class_close(content: String, expected_class_name: String = "") -> int:
	var masked_content = mask_non_code(content)
	var open_brace_index = _find_csharp_class_open_brace(masked_content, expected_class_name)
	if open_brace_index == -1 and not expected_class_name.is_empty():
		open_brace_index = _find_csharp_class_open_brace(masked_content)
	if open_brace_index == -1:
		return -1

	return find_matching_brace(masked_content, open_brace_index)


func find_next_non_code_brace(masked_content: String, start_index: int) -> int:
	for index in range(start_index, masked_content.length()):
		if masked_content.substr(index, 1) == "{":
			return index
	return -1


func mask_non_code(content: String) -> String:
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
			var interpolated_verbatim_result = _mask_csharp_verbatim_string(content, index, 2)
			masked += str(interpolated_verbatim_result.get("masked", ""))
			index = int(interpolated_verbatim_result.get("next_index", index + 2))
			continue

		if current == "@" and next == "$":
			var interpolated_alt_result = _mask_csharp_verbatim_string(content, index, 2)
			masked += str(interpolated_alt_result.get("masked", ""))
			index = int(interpolated_alt_result.get("next_index", index + 2))
			continue

		if current == "$" and next == "\"":
			var interpolated_result = _mask_csharp_quoted_string(content, index, 2)
			masked += str(interpolated_result.get("masked", ""))
			index = int(interpolated_result.get("next_index", index + 2))
			continue

		if current == "\"":
			var quoted_result = _mask_csharp_quoted_string(content, index, 1)
			masked += str(quoted_result.get("masked", ""))
			index = int(quoted_result.get("next_index", index + 1))
			continue

		if current == "'":
			var char_result = _mask_csharp_char_literal(content, index)
			masked += str(char_result.get("masked", ""))
			index = int(char_result.get("next_index", index + 1))
			continue

		if current == "<" and next == "<" and next_two == "<":
			masked += "<<<"
			index += 3
			continue

		masked += current
		index += 1
	return masked


func find_matching_brace(content: String, open_brace_index: int) -> int:
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


func detect_member_indent(content: String, class_close_index: int) -> String:
	var line_start_index = content.rfind("\n", class_close_index)
	if line_start_index == -1:
		return "    "

	var closing_line = content.substr(line_start_index + 1, class_close_index - line_start_index - 1)
	return "%s    " % leading_whitespace(closing_line)


func indent_multiline_block(content: String, indent: String) -> String:
	var lines: Array[String] = []
	for raw_line in content.split("\n"):
		lines.append("%s%s" % [indent, raw_line])
	return "\n".join(lines)


func leading_whitespace(line: String) -> String:
	var index = 0
	while index < line.length():
		var char_value = line.substr(index, 1)
		if char_value != " " and char_value != "\t":
			break
		index += 1
	return line.substr(0, index)


func trim_trailing_whitespace(value: String) -> String:
	var end_index = value.length()
	while end_index > 0:
		var char_value = value.substr(end_index - 1, 1)
		if char_value != " " and char_value != "\t" and char_value != "\n" and char_value != "\r":
			break
		end_index -= 1
	return value.substr(0, end_index)


func find_member_block_start(content: String, member_pos: int) -> int:
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
	return find_next_non_code_brace(masked_content, match.get_end(0))


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
