extends RefCounted

const CONTRACT_TEST_SUFFIX := "_contract_test.gd"
const USER_PATH_WARNING := "user_path_warning"


static func discover_test_cases(root_path: String = "res://tests/") -> Array[Dictionary]:
	var script_paths: Array[String] = scan_directory(root_path)
	script_paths.sort()
	var discovered: Array[Dictionary] = []
	for script_path in script_paths:
		discovered.append({
			"name": _derive_case_name(script_path),
			"path": script_path,
			"mode": _derive_case_mode(script_path)
		})
	return discovered


static func validate_case(script_path: String) -> Dictionary:
	var source_result := _read_text(script_path)
	if not bool(source_result.get("ok", false)):
		return {
			"status": "load_error",
			"error": str(source_result.get("error", "Failed to read script.")),
			"warning": ""
		}

	var source_text := str(source_result.get("text", ""))
	var warning := ""
	if source_text.find("user://") != -1:
		warning = USER_PATH_WARNING

	if _is_headless_incompatible(source_text):
		return {
			"status": "headless_incompatible",
			"error": "Script extends an editor-bound base that is not headless-safe.",
			"warning": warning
		}

	var script_resource = load(script_path)
	if script_resource == null:
		return {
			"status": "load_error",
			"error": "Failed to load test script: %s" % script_path,
			"warning": warning
		}

	if not _has_run_case(source_text):
		return {
			"status": "missing_run_case",
			"error": "Missing required run_case(SceneTree) function.",
			"warning": warning
		}

	return {
		"status": "valid" if warning.is_empty() else USER_PATH_WARNING,
		"error": "",
		"warning": warning
	}


static func scan_directory(root_path: String) -> Array[String]:
	var normalized_root := root_path.trim_suffix("/")
	var found: Array[String] = []
	_scan_directory_recursive(normalized_root, found)
	return found


static func _scan_directory_recursive(current_path: String, out_paths: Array[String]) -> void:
	var dir := DirAccess.open(current_path)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry in [".", ".."]:
			continue

		var child_path := "%s/%s" % [current_path, entry]
		if dir.current_is_dir():
			if entry == "_fixtures" or entry == "testdata":
				continue
			_scan_directory_recursive(child_path, out_paths)
			continue

		if not entry.ends_with(CONTRACT_TEST_SUFFIX):
			continue
		if entry == "headless_suite_runner.gd":
			continue
		out_paths.append(child_path)

	dir.list_dir_end()


static func _derive_case_name(script_path: String) -> String:
	var source_result := _read_text(script_path)
	if bool(source_result.get("ok", false)):
		var source_text := str(source_result.get("text", ""))
		var name_match := _match_first_group(source_text, '(?m)"name"\\s*:\\s*"([^"]+)"')
		if not name_match.is_empty():
			return name_match

	var file_name := script_path.get_file().trim_suffix(".gd")
	if file_name.ends_with("_contract_test"):
		file_name = file_name.substr(0, file_name.length() - "_contract_test".length())
	return "%s_contracts" % file_name


static func _derive_case_mode(script_path: String) -> String:
	if script_path.get_file() == "plugin_entrypoint_contract_test.gd":
		return "editor_probe"
	return "headless"


static func _is_headless_incompatible(source_text: String) -> bool:
	var extends_token := _extract_top_level_extends(source_text)
	if extends_token.is_empty():
		return false

	if extends_token.begins_with('"') and extends_token.ends_with('"'):
		var extends_path := extends_token.substr(1, extends_token.length() - 2)
		return _is_editor_only_path(extends_path)

	if extends_token == "CentralServerAttachService":
		return true

	var preload_regex := RegEx.new()
	var preload_err := preload_regex.compile('(?m)^\\s*const\\s+(\\w+)\\s*=\\s*preload\\("([^"]+)"\\)')
	if preload_err != OK:
		return false

	for preload_match in preload_regex.search_all(source_text):
		var symbol := preload_match.get_string(1)
		var preload_path := preload_match.get_string(2)
		if not _is_editor_only_path(preload_path):
			continue
		if symbol == extends_token or symbol == "%sScript" % extends_token or symbol.begins_with(extends_token):
			return true

	return false


static func _is_editor_only_path(path: String) -> bool:
	return path.find("/plugin/runtime/") != -1 and path.find("/test_safe/") == -1


static func _extract_top_level_extends(source_text: String) -> String:
	for raw_line in source_text.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("extends "):
			return line.substr("extends ".length()).strip_edges()
		return ""
	return ""


static func _has_run_case(source_text: String) -> bool:
	var run_case_regex := RegEx.new()
	var regex_err := run_case_regex.compile("(?m)^\\s*func\\s+run_case\\s*\\(")
	if regex_err != OK:
		return source_text.find("func run_case(") != -1
	return run_case_regex.search(source_text) != null


static func _match_first_group(text: String, pattern: String) -> String:
	var regex := RegEx.new()
	var regex_err := regex.compile(pattern)
	if regex_err != OK:
		return ""
	var result := regex.search(text)
	if result == null:
		return ""
	return result.get_string(1)


static func _read_text(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"text": "",
			"error": "Failed to open script: %s" % path
		}

	return {
		"ok": true,
		"text": file.get_as_text(),
		"error": ""
	}
