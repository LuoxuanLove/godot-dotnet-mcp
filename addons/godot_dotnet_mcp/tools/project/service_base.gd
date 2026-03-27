@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"


func _find_csproj_files(dir_path: String) -> Array[String]:
	var results: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return results

	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry.begins_with("."):
			continue
		var child_path := "%s%s" % [dir_path, entry] if dir_path == "res://" else "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			results.append_array(_find_csproj_files(child_path))
		elif entry.ends_with(".csproj"):
			results.append(_normalize_res_path(child_path))
	dir.list_dir_end()

	results.sort()
	return results


func _extract_first_xml_tag(content: String, tag_name: String) -> String:
	var regex := RegEx.new()
	regex.compile("(?s)<%s>(.*?)</%s>" % [tag_name, tag_name])
	var match_result := regex.search(content)
	if match_result == null:
		return ""
	return str(match_result.get_string(1)).strip_edges()


func _extract_xml_attribute(attributes: String, attribute_name: String) -> String:
	var regex := RegEx.new()
	regex.compile("%s\\s*=\\s*\"([^\"]*)\"" % attribute_name)
	var match_result := regex.search(attributes)
	if match_result == null:
		return ""
	return str(match_result.get_string(1)).strip_edges()


func _split_semicolon_values(value: String) -> Array[String]:
	var items: Array[String] = []
	for entry in value.split(";"):
		var trimmed := entry.strip_edges()
		if not trimmed.is_empty():
			items.append(trimmed)
	return items


func _parse_package_references(content: String) -> Array[Dictionary]:
	var references: Array[Dictionary] = []

	var block_regex := RegEx.new()
	block_regex.compile("(?s)<PackageReference\\b([^>]*)>(.*?)</PackageReference>")
	for match_result in block_regex.search_all(content):
		var attributes := str(match_result.get_string(1))
		var body := str(match_result.get_string(2))
		var version := _extract_xml_attribute(attributes, "Version")
		if version.is_empty():
			version = _extract_first_xml_tag(body, "Version")
		references.append({
			"name": _extract_xml_attribute(attributes, "Include"),
			"version": version,
			"condition": _extract_xml_attribute(attributes, "Condition")
		})

	var self_closing_regex := RegEx.new()
	self_closing_regex.compile("(?m)<PackageReference\\b([^>]*)/>")
	for match_result in self_closing_regex.search_all(content):
		var attributes := str(match_result.get_string(1))
		references.append({
			"name": _extract_xml_attribute(attributes, "Include"),
			"version": _extract_xml_attribute(attributes, "Version"),
			"condition": _extract_xml_attribute(attributes, "Condition")
		})

	return references


func _parse_project_references(content: String) -> Array[Dictionary]:
	var references: Array[Dictionary] = []

	var block_regex := RegEx.new()
	block_regex.compile("(?s)<ProjectReference\\b([^>]*)>(.*?)</ProjectReference>")
	for match_result in block_regex.search_all(content):
		var attributes := str(match_result.get_string(1))
		references.append({
			"path": _extract_xml_attribute(attributes, "Include"),
			"name": _extract_first_xml_tag(str(match_result.get_string(2)), "Name"),
			"condition": _extract_xml_attribute(attributes, "Condition")
		})

	var self_closing_regex := RegEx.new()
	self_closing_regex.compile("(?m)<ProjectReference\\b([^>]*)/>")
	for match_result in self_closing_regex.search_all(content):
		var attributes := str(match_result.get_string(1))
		references.append({
			"path": _extract_xml_attribute(attributes, "Include"),
			"name": "",
			"condition": _extract_xml_attribute(attributes, "Condition")
		})

	return references


func _event_to_dict(event: InputEvent) -> Dictionary:
	var result = {"type": str(event.get_class())}

	if event is InputEventKey:
		result["keycode"] = event.keycode
		result["key_name"] = str(OS.get_keycode_string(event.keycode))
	elif event is InputEventMouseButton:
		result["button"] = event.button_index
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				result["button_name"] = "left"
			MOUSE_BUTTON_RIGHT:
				result["button_name"] = "right"
			MOUSE_BUTTON_MIDDLE:
				result["button_name"] = "middle"
	elif event is InputEventJoypadButton:
		result["button"] = event.button_index
	elif event is InputEventJoypadMotion:
		result["axis"] = event.axis
		result["axis_value"] = event.axis_value

	return result
