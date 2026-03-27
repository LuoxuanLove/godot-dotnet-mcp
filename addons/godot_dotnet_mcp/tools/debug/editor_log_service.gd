@tool
extends "res://addons/godot_dotnet_mcp/tools/debug/service_base.gd"

var _editor_log_rtl_cache: WeakRef = null


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action := str(args.get("action", ""))
	match action:
		"get_output":
			return _editor_log_get_output(args)
		"get_errors":
			return _editor_log_get_errors(args)
		"clear":
			return _editor_log_clear()
		_:
			return _error("Unknown action: %s" % action)


func _editor_log_get_output(args: Dictionary) -> Dictionary:
	var rtl := _get_editor_log_rtl()
	if rtl == null:
		return _error("EditorLog not accessible — ensure plugin is running inside the Godot editor")
	var limit := int(args.get("limit", 100))
	var raw_text := rtl.get_parsed_text()
	var all_lines := raw_text.split("\n")
	var lines: Array[String] = []
	for raw_line in all_lines:
		var line := raw_line.strip_edges()
		if not line.is_empty():
			lines.append(line)
	if limit > 0 and lines.size() > limit:
		lines = lines.slice(lines.size() - limit)
	return _success({
		"lines": lines,
		"line_count": lines.size(),
		"source": "editor_log",
		"note": "Content reflects current EditorLog filter state in the Output panel."
	})


func _editor_log_get_errors(args: Dictionary) -> Dictionary:
	var rtl := _get_editor_log_rtl()
	if rtl == null:
		return _error("EditorLog not accessible — ensure plugin is running inside the Godot editor")
	var limit := int(args.get("limit", 50))
	var include_warnings := bool(args.get("include_warnings", true))
	var raw_text := rtl.get_parsed_text()
	var all_lines := raw_text.split("\n")
	var errors: Array = []
	var error_prefixes: Array[String] = ["ERROR:", "SCRIPT ERROR:", "USER ERROR:", "Parse Error:", "Invalid"]
	var warning_prefixes: Array[String] = ["WARNING:", "USER WARNING:", "SCRIPT WARNING:"]

	for raw_line in all_lines:
		var line := raw_line.strip_edges()
		if line.is_empty():
			continue
		var is_error := false
		for prefix in error_prefixes:
			if line.begins_with(prefix):
				is_error = true
				break
		if is_error:
			errors.append(_parse_editor_log_error_line(line, "error"))
			continue
		if include_warnings:
			for prefix in warning_prefixes:
				if line.begins_with(prefix):
					errors.append(_parse_editor_log_error_line(line, "warning"))
					break

	if limit > 0 and errors.size() > limit:
		errors = errors.slice(errors.size() - limit)
	return _success({
		"errors": errors,
		"error_count": errors.size()
	})


func _editor_log_clear() -> Dictionary:
	var rtl := _get_editor_log_rtl()
	if rtl == null:
		return _error("EditorLog not accessible — ensure plugin is running inside the Godot editor")
	rtl.clear()
	return _success({"cleared": true})


func _get_editor_log_rtl() -> RichTextLabel:
	if _editor_log_rtl_cache != null:
		var cached = _editor_log_rtl_cache.get_ref()
		if cached != null and is_instance_valid(cached):
			return cached as RichTextLabel

	var main_loop = Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return null
	var root := (main_loop as SceneTree).root
	if root == null:
		return null
	var rtl := _find_editor_log_rtl(root)
	if rtl != null:
		_editor_log_rtl_cache = weakref(rtl)
	return rtl


func _find_editor_log_rtl(node: Node) -> RichTextLabel:
	if node.get_class() == "EditorLog":
		for i in range(node.get_child_count()):
			var child := node.get_child(i)
			if child is RichTextLabel:
				return child as RichTextLabel
	for i in range(node.get_child_count()):
		var result := _find_editor_log_rtl(node.get_child(i))
		if result != null:
			return result
	return null


func _parse_editor_log_error_line(line: String, severity: String) -> Dictionary:
	var entry: Dictionary = {
		"message": line,
		"severity": severity,
		"file": "",
		"line": -1
	}
	var res_idx := line.find("res://")
	if res_idx >= 0:
		var rest := line.substr(res_idx)
		var colon_idx := rest.rfind(":")
		if colon_idx > 0:
			var path_part := rest.substr(0, colon_idx)
			var after_colon := rest.substr(colon_idx + 1)
			var line_num_str := ""
			for ch in after_colon:
				if ch.is_valid_int() or (line_num_str.is_empty() and ch == "-"):
					line_num_str += ch
				else:
					break
			if not line_num_str.is_empty():
				entry["file"] = path_part
				entry["line"] = int(line_num_str)
	return entry
