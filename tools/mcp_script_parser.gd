@tool
extends RefCounted
class_name MCPScriptParser

const FileUtils = preload("res://addons/godot_dotnet_mcp/tools/mcp_file_utils.gd")

var _file_utils := FileUtils.new()
var _rx_cs_namespace: RegEx
var _rx_cs_class: RegEx
var _rx_cs_enum: RegEx
var _rx_cs_method: RegEx
var _rx_cs_property: RegEx
var _rx_cs_field: RegEx
var _rx_gd_classname: RegEx
var _rx_gd_extends: RegEx
var _rx_gd_method: RegEx
var _rx_gd_export: RegEx


func _init() -> void:
	_rx_cs_namespace = _compile_regex("namespace\\s+([A-Za-z0-9_.]+)")
	_rx_cs_class = _compile_regex("(?m)^\\s*(?:public|internal|private|protected)?\\s*((?:(?:partial|static|abstract|sealed)\\s+)*)class\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*(?::\\s*([^\\r\\n{]+))?")
	_rx_cs_enum = _compile_regex("(?:public|internal|private)?\\s*enum\\s+([A-Za-z_][A-Za-z0-9_]*)")
	_rx_cs_method = _compile_regex("(?m)^\\s*(?:public|protected|internal|private)\\s+(?:(?:static|async|override|virtual|sealed|new|partial)\\s+)*([A-Za-z0-9_<>.,?\\[\\]]+)\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*\\(([^)]*)\\)")
	_rx_cs_property = _compile_regex("(?:public|private|protected|internal)\\s+(?:(?:static|readonly|new)\\s+)*([A-Za-z0-9_<>.,?\\[\\]]+)\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*\\{")
	_rx_cs_field = _compile_regex("(?:public|private|protected|internal)\\s+(?:(?:static|readonly|new)\\s+)*([A-Za-z0-9_<>.,?\\[\\]]+)\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*(?:=|;)")
	_rx_gd_classname = _compile_regex("(?m)^\\s*class_name\\s+([A-Za-z_][A-Za-z0-9_]*)")
	_rx_gd_extends = _compile_regex("(?m)^\\s*extends\\s+(.+)$")
	_rx_gd_method = _compile_regex("(?m)^\\s*func\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*\\(([^)]*)\\)(?:\\s*->\\s*([A-Za-z0-9_]+))?")
	_rx_gd_export = _compile_regex("@export(?:_[a-z_]+)?\\s+var\\s+([A-Za-z_][A-Za-z0-9_]*)(?:\\s*:\\s*([^=]+))?")


func detect_script_language(path: String) -> String:
	var normalized = _file_utils.normalize_res_path(path).to_lower()
	if normalized.ends_with(".cs"):
		return "csharp"
	if normalized.ends_with(".gd"):
		return "gdscript"
	return "unknown"


func parse_script_metadata(path: String) -> Dictionary:
	var read_result = _file_utils.read_text_file(path)
	if not read_result.get("success", false):
		return read_result

	var normalized = read_result["data"]["path"]
	var content = read_result["data"]["content"]
	var language = detect_script_language(normalized)

	match language:
		"csharp":
			return _success(parse_csharp_metadata(normalized, content))
		"gdscript":
			return _success(parse_gdscript_metadata(normalized, content))
		_:
			return _error("Unsupported script type: %s" % normalized)


func parse_csharp_metadata(path: String, content: String) -> Dictionary:
	var result = {
		"path": path,
		"language": "csharp",
		"namespace": "",
		"class_name": "",
		"base_type": "",
		"is_partial": false,
		"classes": [],
		"methods": [],
		"symbols": [],
		"exports": [],
		"export_groups": []
	}

	var namespace_match = _rx_cs_namespace.search(content)
	if namespace_match:
		result["namespace"] = namespace_match.get_string(1)

	for class_match in _rx_cs_class.search_all(content):
		var modifiers = class_match.get_string(1)
		var class_info = {
			"kind": "class",
			"name": class_match.get_string(2),
			"base_type": class_match.get_string(3).strip_edges(),
			"partial": modifiers.contains("partial"),
			"static": modifiers.contains("static"),
			"abstract": modifiers.contains("abstract"),
			"sealed": modifiers.contains("sealed")
		}
		result["classes"].append(class_info)
		result["symbols"].append(class_info)

	if not result["classes"].is_empty():
		var primary_class = result["classes"][0]
		var file_basename = path.get_file().get_basename()
		for class_info in result["classes"]:
			if class_info.get("name", "") == file_basename:
				primary_class = class_info
				break
		result["class_name"] = primary_class["name"]
		result["base_type"] = primary_class["base_type"]
		result["is_partial"] = primary_class["partial"]

	for enum_match in _rx_cs_enum.search_all(content):
		result["symbols"].append({"kind": "enum", "name": enum_match.get_string(1)})

	for method_match in _rx_cs_method.search_all(content):
		var method_info = {
			"kind": "method",
			"name": method_match.get_string(2),
			"return_type": method_match.get_string(1).strip_edges(),
			"parameters": method_match.get_string(3).strip_edges()
		}
		result["methods"].append(method_info)
		result["symbols"].append(method_info)

	var current_group = ""
	var pending_export = false
	for raw_line in content.split("\n"):
		var line = raw_line.strip_edges()
		if line.is_empty():
			continue

		var has_export_group = line.contains("[ExportGroup(")
		var has_export = _line_has_csharp_export_attribute(line)

		if has_export_group:
			current_group = _extract_quoted_value(line)
			if not current_group.is_empty() and not result["export_groups"].has(current_group):
				result["export_groups"].append(current_group)

		var candidate_line = line
		if has_export:
			pending_export = true
			candidate_line = _strip_leading_csharp_attributes(candidate_line)
			if candidate_line.is_empty():
				continue
		elif pending_export:
			if line.begins_with("["):
				continue
			candidate_line = _strip_leading_csharp_attributes(candidate_line)

		if not pending_export:
			continue

		var export_info = _parse_csharp_export_line(candidate_line)
		if export_info.is_empty():
			pending_export = false
			continue

		export_info["group"] = current_group
		result["exports"].append(export_info)
		result["symbols"].append({
			"kind": "export",
			"name": export_info["name"],
			"type": export_info["type"],
			"group": current_group
		})
		pending_export = false

	return result


func parse_gdscript_metadata(path: String, content: String) -> Dictionary:
	var result = {
		"path": path,
		"language": "gdscript",
		"class_name": "",
		"base_type": "",
		"methods": [],
		"symbols": [],
		"exports": [],
		"export_groups": []
	}

	var class_match = _rx_gd_classname.search(content)
	if class_match:
		result["class_name"] = class_match.get_string(1)
		result["symbols"].append({"kind": "class", "name": result["class_name"]})

	var extends_match = _rx_gd_extends.search(content)
	if extends_match:
		result["base_type"] = extends_match.get_string(1).strip_edges().trim_suffix("\r")

	for method_match in _rx_gd_method.search_all(content):
		var method_info = {
			"kind": "method",
			"name": method_match.get_string(1),
			"parameters": method_match.get_string(2).strip_edges(),
			"return_type": method_match.get_string(3).strip_edges()
		}
		result["methods"].append(method_info)
		result["symbols"].append(method_info)

	var current_group = ""
	for raw_line in content.split("\n"):
		var line = raw_line.strip_edges()
		if line.begins_with("@export_group("):
			current_group = _extract_quoted_value(line)
			if not current_group.is_empty() and not result["export_groups"].has(current_group):
				result["export_groups"].append(current_group)
			continue
		if not line.begins_with("@export"):
			continue

		var export_info = _parse_gdscript_export_line(line)
		if export_info.is_empty():
			continue

		export_info["group"] = current_group
		result["exports"].append(export_info)
		result["symbols"].append({
			"kind": "export",
			"name": export_info["name"],
			"type": export_info["type"],
			"group": current_group
		})

	return result


func _line_has_csharp_export_attribute(line: String) -> bool:
	return line.contains("[Export]") or line.contains("[Export(")


func _strip_leading_csharp_attributes(line: String) -> String:
	var remaining = line.strip_edges()
	while remaining.begins_with("["):
		var closing_index = remaining.find("]")
		if closing_index == -1:
			break
		remaining = remaining.substr(closing_index + 1).strip_edges()
	return remaining


func _parse_csharp_export_line(line: String) -> Dictionary:
	var property_match = _rx_cs_property.search(line)
	if property_match:
		var property_type = property_match.get_string(1).strip_edges()
		return {
			"name": property_match.get_string(2),
			"type": property_type,
			"nullable": property_type.ends_with("?"),
			"member_kind": "property"
		}

	var field_match = _rx_cs_field.search(line)
	if field_match:
		var field_type = field_match.get_string(1).strip_edges()
		return {
			"name": field_match.get_string(2),
			"type": field_type,
			"nullable": field_type.ends_with("?"),
			"member_kind": "field"
		}

	return {}


func _parse_gdscript_export_line(line: String) -> Dictionary:
	var export_match = _rx_gd_export.search(line)
	if not export_match:
		return {}

	return {
		"name": export_match.get_string(1),
		"type": export_match.get_string(2).strip_edges(),
		"nullable": false,
		"member_kind": "variable"
	}


func _extract_quoted_value(line: String) -> String:
	var start = line.find("\"")
	if start == -1:
		return ""
	var finish = line.find("\"", start + 1)
	if finish == -1:
		return ""
	return line.substr(start + 1, finish - start - 1)


func _compile_regex(pattern: String) -> RegEx:
	var regex = RegEx.new()
	regex.compile(pattern)
	return regex


func _success(data = null, message: String = "") -> Dictionary:
	var result = {"success": true}
	if data != null:
		result["data"] = data
	if not message.is_empty():
		result["message"] = message
	return result


func _error(message: String, data = null, hints: Array = []) -> Dictionary:
	var result = {
		"success": false,
		"error": message
	}
	if data != null:
		result["data"] = data
	if not hints.is_empty():
		result["hints"] = hints
	return result
