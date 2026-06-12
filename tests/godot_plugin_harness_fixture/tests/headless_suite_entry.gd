extends Node

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const HeadlessCaseSupport = preload("res://tests/headless_case_support.gd")
const ListCasesEnvVar := "GODOT_PLUGIN_HARNESS_LIST_CASES"
const OnlyCaseEnvVar := "GODOT_PLUGIN_HARNESS_ONLY_CASE"
const SelectedCasesEnvVar := "GODOT_PLUGIN_HARNESS_SELECTED_CASES"


func _ready() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	var success := true
	var results: Array[Dictionary] = []
	var suite_started_at := Time.get_ticks_msec()
	var only_case := OS.get_environment(OnlyCaseEnvVar).strip_edges()
	var selected_case_names := _parse_selected_case_names(OS.get_environment(SelectedCasesEnvVar))
	var list_cases_only := OS.get_environment(ListCasesEnvVar).strip_edges() == "1"

	var discovered_cases: Array[Dictionary] = HeadlessCaseSupport.discover_test_cases("res://tests/")
	var selected_cases: Array[Dictionary] = []
	var discovered_selected_case_names := {}
	for case_info in discovered_cases:
		var case_name := str(case_info.get("name", ""))
		var mode := str(case_info.get("mode", "headless"))
		if only_case != "" and case_name != only_case:
			continue
		if only_case == "" and not selected_case_names.is_empty() and not selected_case_names.has(case_name):
			continue
		if only_case == "" and mode != "headless" and selected_case_names.is_empty():
			continue
		if not selected_case_names.is_empty():
			discovered_selected_case_names[case_name] = true
		selected_cases.append(case_info)

	var validation_manifest: Array[Dictionary] = []
	var validation_by_path := {}

	for case_info in selected_cases:
		var case_name := str(case_info.get("name", "unknown_case"))
		var case_path := str(case_info.get("path", ""))
		var mode := str(case_info.get("mode", "headless"))
		var validation: Dictionary = {"status": "valid", "error": "", "warning": ""}
		if mode != "headless" and only_case != case_name:
			validation = {
				"status": "editor_probe_required",
				"error": "Selected harness case requires editor probe mode: %s" % mode,
				"warning": ""
			}
		else:
			validation = HeadlessCaseSupport.validate_case(case_path)
		var item := {
			"name": case_name,
			"path": case_path,
			"mode": mode,
			"status": str(validation.get("status", "load_error")),
			"error": str(validation.get("error", "")),
			"warning": str(validation.get("warning", ""))
		}
		validation_manifest.append(item)
		validation_by_path[case_path] = item

	print("HARNESS_VALIDATION_MANIFEST:%s" % JSON.stringify(validation_manifest))

	if list_cases_only:
		var valid_count := _count_valid_cases(validation_manifest)
		print("HARNESS_LIST_CASES_MANIFEST:%s" % JSON.stringify({
			"discovered": validation_manifest,
			"total": validation_manifest.size(),
			"valid": valid_count,
			"invalid": validation_manifest.size() - valid_count
		}))
		await _suite_final_cleanup()
		get_tree().quit(0)
		return

	if only_case == "" and not selected_case_names.is_empty():
		for selected_case_name in selected_case_names.keys():
			if discovered_selected_case_names.has(selected_case_name):
				continue
			results.append({
				"name": selected_case_name,
				"success": false,
				"error": "Selected harness case was not discovered."
			})
			success = false

	for case_info in selected_cases:
		var case_name := str(case_info.get("name", "unknown_case"))
		var case_script_path := str(case_info.get("path", ""))
		if case_script_path.is_empty():
			continue

		var validation: Dictionary = validation_by_path.get(case_script_path, {})
		var status := str(validation.get("status", "load_error"))
		if not _is_runnable_status(status):
			results.append({
				"name": case_name,
				"success": false,
				"error": str(validation.get("error", "Validation failed."))
			})
			success = false
			continue

		var warning := str(validation.get("warning", ""))
		if not warning.is_empty():
			print("HARNESS_CASE_WARNING:%s:%s" % [case_name, warning])

		var mode := str(case_info.get("mode", "headless"))
		if mode != "headless" and only_case != case_name:
			if not selected_case_names.is_empty():
				results.append({
					"name": case_name,
					"success": false,
					"error": "Selected harness case requires editor probe mode: %s" % mode
				})
				success = false
			continue

		var case_script = load(case_script_path)
		if case_script == null:
			results.append({
				"name": case_name,
				"success": false,
				"error": "Failed to load test script: %s" % case_script_path
			})
			success = false
			continue

		var case_instance = case_script.new()
		if case_instance == null or not case_instance.has_method("run_case"):
			results.append({
				"name": case_name,
				"success": false,
				"error": "run_case(SceneTree) is not available: %s" % case_script_path
			})
			success = false
			continue

		print("HARNESS_CASE_START:%s" % case_name)
		var case_started_at := Time.get_ticks_msec()
		var result: Dictionary = await case_instance.run_case(get_tree())
		if case_instance.has_method("cleanup_case"):
			await case_instance.cleanup_case(get_tree())
		var case_duration_ms := Time.get_ticks_msec() - case_started_at
		result["duration_ms"] = case_duration_ms
		case_instance = null
		await get_tree().process_frame
		await get_tree().process_frame
		results.append(result)
		if not bool(result.get("success", false)):
			success = false
		print("HARNESS_CASE_DONE:%s:%s:%d" % [case_name, str(bool(result.get("success", false))), case_duration_ms])

	await _suite_final_cleanup()
	print(JSON.stringify({
		"success": success,
		"duration_ms": Time.get_ticks_msec() - suite_started_at,
		"results": results
	}))
	get_tree().quit(0 if success else 1)


func _parse_selected_case_names(raw_value: String) -> Dictionary:
	var names := {}
	for raw_name in raw_value.split(",", false):
		var case_name := raw_name.strip_edges()
		if case_name.is_empty():
			continue
		names[case_name] = true
	return names


func _count_valid_cases(items: Array[Dictionary]) -> int:
	var count := 0
	for item in items:
		if _is_runnable_status(str(item.get("status", ""))):
			count += 1
	return count


func _is_runnable_status(status: String) -> bool:
	return status == "valid" or status == "user_path_warning"


func _suite_final_cleanup() -> void:
	MCPDebugBuffer.clear()
	await get_tree().process_frame
	await get_tree().process_frame
