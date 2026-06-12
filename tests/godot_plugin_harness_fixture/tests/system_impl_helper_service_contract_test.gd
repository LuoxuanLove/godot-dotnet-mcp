extends RefCounted

# {"name": "system_impl_helper_service_contracts"}

const SystemImplHelperServiceScript = preload("res://addons/godot_dotnet_mcp/tools/system/system_impl_helper_service.gd")

const SOURCE_PATH := "res://tests_tmp/system_impl_helper_service_contracts/scenes/Main.tscn"


class FakeBridge:
	extends RefCounted

	var calls: Array[Dictionary] = []

	func call_atomic(full_name: String, args: Dictionary = {}) -> Dictionary:
		calls.append({"full_name": full_name, "args": args.duplicate(true)})
		if bool(args.get("count_only", false)):
			if args.has("filters"):
				return {"success": true, "data": {"counts_by_filter": {"*.gd": 2, "*.cs": 1}}}
			return {"success": true, "data": {"count": 3}}
		return {"success": true, "data": {"files": ["res://A.gd", "res://B.gd"]}}


func run_case(_tree: SceneTree) -> Dictionary:
	var service = SystemImplHelperServiceScript.new()
	var bridge = FakeBridge.new()
	service.configure(bridge)

	var payload := {"data": {"items": [1, 2, 3], "value": "ok"}}
	if service.extract_data(payload).get("value", "") != "ok":
		return _failure("SystemImplHelperService should preserve dictionary data extraction.")
	if service.extract_array(payload, "items").size() != 3:
		return _failure("SystemImplHelperService should preserve array extraction.")

	var files := service.collect_files("*.gd")
	if files.size() != 2 or str(files[0]) != "res://A.gd":
		return _failure("SystemImplHelperService should collect files through the configured bridge.")
	if bridge.calls.size() != 1:
		return _failure("collect_files should call bridge.call_atomic exactly once.")
	var files_call: Dictionary = bridge.calls[0]
	if str(files_call.get("full_name", "")) != "filesystem_directory":
		return _failure("collect_files should use filesystem_directory atomic dispatch.")
	var files_args: Dictionary = files_call.get("args", {})
	if str(files_args.get("action", "")) != "get_files" or str(files_args.get("path", "")) != "res://":
		return _failure("collect_files should preserve action and root path arguments.")
	if str(files_args.get("filter", "")) != "*.gd" or not bool(files_args.get("recursive", false)):
		return _failure("collect_files should preserve filter and recursive arguments.")

	var count := service.collect_file_count("*.cs")
	if count != 3:
		return _failure("collect_file_count should extract the count field.")
	var count_args: Dictionary = bridge.calls[1].get("args", {})
	if str(count_args.get("filter", "")) != "*.cs" or not bool(count_args.get("count_only", false)):
		return _failure("collect_file_count should request count_only for one filter.")

	var counts := service.collect_file_counts(["*.gd", "*.cs"])
	if int(counts.get("*.gd", 0)) != 2 or int(counts.get("*.cs", 0)) != 1:
		return _failure("collect_file_counts should extract counts_by_filter.")
	var counts_args: Dictionary = bridge.calls[2].get("args", {})
	if not counts_args.has("filters") or not bool(counts_args.get("count_only", false)):
		return _failure("collect_file_counts should request count_only with filters.")

	var issue := service.build_issue("warning", "dependency_mismatch", "Dependency differs", {"file": "res://A.tscn"})
	if issue.get("file", "") != "res://A.tscn" or issue.get("type", "") != "dependency_mismatch":
		return _failure("SystemImplHelperService should build issues with extra metadata.")
	var issues := []
	service.append_unique_issue(issues, issue)
	service.append_unique_issue(issues, issue.duplicate(true))
	if issues.size() != 1:
		return _failure("SystemImplHelperService should deduplicate repeated issues.")
	if not service.has_severity(issues, "warning"):
		return _failure("SystemImplHelperService should find issue severities.")

	var normalized := service.normalize_resource_path("../Shared.cs", SOURCE_PATH)
	if normalized != "res://tests_tmp/system_impl_helper_service_contracts/Shared.cs":
		return _failure("SystemImplHelperService should normalize relative dependency paths.")

	var raw_reference := "uid://missing_impl_helper_contract::Script::../Missing.cs"
	var parsed: Dictionary = service.parse_dependency_reference(raw_reference, SOURCE_PATH)
	if not bool(parsed.get("has_uid_path_pair", false)):
		return _failure("SystemImplHelperService should preserve UID/path pair detection.")
	if parsed.get("declared_path", "") != "res://tests_tmp/system_impl_helper_service_contracts/Missing.cs":
		return _failure("SystemImplHelperService should normalize declared dependency paths.")
	if parsed.get("risk", "") != "error":
		return _failure("SystemImplHelperService should preserve dependency reference risk.")

	var source_guard := _verify_production_impl_helper_guard()
	if not bool(source_guard.get("success", false)):
		return source_guard

	return {"name": "system_impl_helper_service_contracts", "success": true, "error": ""}


func _verify_production_impl_helper_guard() -> Dictionary:
	var system_dir := "res://addons/godot_dotnet_mcp/tools/system"
	for path in _collect_impl_sources(system_dir):
		var source := FileAccess.get_file_as_string(path)
		if source.is_empty():
			return _failure("System impl source should be readable for helper guard: %s" % path)
		for forbidden in [
			"bridge.extract_data",
			"bridge.extract_array",
			"bridge.collect_files",
			"bridge.collect_file_count",
			"bridge.collect_file_counts",
			"bridge.build_issue",
			"bridge.append_unique_issue",
			"bridge.has_severity",
			"bridge.normalize_dependency_path",
			"bridge.normalize_resource_path",
			"bridge.parse_dependency_reference",
			"bridge.resource_path_exists"
		]:
			if source.find(forbidden) != -1:
				return _failure("System impls should use SystemImplHelperService for helper behavior, not AtomicBridge facade: %s in %s" % [forbidden, path])
	return {"success": true}


func _collect_impl_sources(root: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var path := "%s/%s" % [root, entry]
		if dir.current_is_dir():
			result.append_array(_collect_impl_sources(path))
		elif entry.begins_with("impl_") and entry.ends_with(".gd"):
			result.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	return result


func _failure(message: String) -> Dictionary:
	return {"name": "system_impl_helper_service_contracts", "success": false, "error": message}
