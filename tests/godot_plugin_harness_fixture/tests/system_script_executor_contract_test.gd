extends RefCounted

const SystemScriptExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/system/script/executor.gd")
const TEMP_ROOT := "res://tests_tmp/system_script_executor_contracts"


class FakeDiagnosticsService extends RefCounted:
	func request_diagnostics(script_path: String, _source: String) -> Dictionary:
		return {
			"available": true,
			"pending": false,
			"finished": true,
			"state": "completed",
			"script": script_path,
			"parse_errors": [],
			"error_count": 0,
			"warning_count": 0
		}


class FakeBridge extends RefCounted:
	var diagnostics_service := FakeDiagnosticsService.new()

	func get_gdscript_lsp_diagnostics_service():
		return diagnostics_service

	func call_atomic(tool_name: String, args: Dictionary) -> Dictionary:
		match tool_name:
			"scene_bindings", "scene_audit":
				return success({"issues": [], "binding_count": 0})
			"script_inspect":
				return success({
					"language": "gdscript" if str(args.get("path", "")).ends_with(".gd") else "csharp",
					"class_name": "ContractScript",
					"base_type": "Node",
					"namespace": "",
					"exports": [],
					"signals": []
				})
			"script_symbols":
				return success({
					"symbols": [
						{"kind": "method", "name": "_ready"},
						{"kind": "variable", "name": "speed"},
						{"kind": "signal", "name": "triggered"}
					]
				})
			"script_exports":
				return success({"count": 1, "exports": [{"name": "speed"}]})
			"script_references":
				match str(args.get("action", "")):
					"get_scene_refs":
						return success({"scenes": ["res://tests/contract_scene.tscn"]})
					"get_base_type":
						return success({"base_type": "Node"})
					_:
						return error("Unsupported script_references action")
			"script_edit_gd", "script_edit_cs":
				return success({"applied": true})
			_:
				return error("Unsupported fake bridge call: %s" % tool_name)

	func collect_files(pattern: String) -> Array:
		if pattern == "*.cs":
			return ["res://tests/Contract.cs"]
		return []

	func extract_data(result: Dictionary) -> Dictionary:
		var data = result.get("data", {})
		return (data as Dictionary).duplicate(true) if data is Dictionary else {}

	func extract_array(result: Dictionary, key: String) -> Array:
		var data = result.get("data", {})
		if data is Dictionary:
			var value = (data as Dictionary).get(key, [])
			return (value as Array).duplicate(true) if value is Array else []
		return []

	func append_unique_issue(target: Array, issue: Dictionary) -> void:
		target.append(issue)

	func build_issue(severity: String, issue_type: String, message: String, data: Dictionary = {}) -> Dictionary:
		return {"severity": severity, "type": issue_type, "message": message, "data": data}

	func success(data = {}, message: String = "") -> Dictionary:
		return {"success": true, "data": data, "message": message}

	func error(message: String, data = {}) -> Dictionary:
		return {"success": false, "error": "bridge_error", "message": message, "data": data}


func run_case(_tree: SceneTree) -> Dictionary:
	if ResourceLoader.exists("res://addons/godot_dotnet_mcp/tools/system/impl_script.gd"):
		return _failure("impl_script.gd should be removed once system/script/executor.gd becomes the only script entry.")

	_prepare_temp_root()
	var gd_path := TEMP_ROOT.path_join("ContractScript.gd")
	var cs_path := TEMP_ROOT.path_join("ContractScript.cs")
	_write_text(gd_path, "extends Node\nclass_name ContractScript\n")
	_write_text(cs_path, "public partial class ContractScript : Godot.Node { }\n")

	var executor = SystemScriptExecutorScript.new()
	executor.bridge = FakeBridge.new()
	executor.configure_runtime({})

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 3:
		return _failure("System script executor should expose 3 tool definitions after the split.")

	var bindings_audit: Dictionary = executor.execute("bindings_audit", {"script": cs_path})
	if not bool(bindings_audit.get("success", false)):
		return _failure("bindings_audit did not succeed through the split system script executor.")

	var analyze: Dictionary = executor.execute("script_analyze", {
		"script": gd_path,
		"include_diagnostics": true
	})
	if not bool(analyze.get("success", false)):
		return _failure("script_analyze did not succeed through the split analyze service.")
	var analyze_data = analyze.get("data", {})
	if not (analyze_data is Dictionary):
		return _failure("script_analyze did not return a dictionary payload.")
	var diagnostics = (analyze_data as Dictionary).get("diagnostics", {})
	if not (diagnostics is Dictionary) or not bool((diagnostics as Dictionary).get("available", false)):
		return _failure("script_analyze should use the diagnostics service for .gd files.")

	var patch_preview: Dictionary = executor.execute("script_patch", {
		"script": gd_path,
		"ops": [{"op": "add_method", "name": "jump"}],
		"dry_run": true
	})
	if not bool(patch_preview.get("success", false)):
		return _failure("script_patch dry_run did not succeed through the split patch service.")

	var invalid_script: Dictionary = executor.execute("script_analyze", {"script": "res://bad.txt"})
	if bool(invalid_script.get("success", false)):
		return _failure("script_analyze should reject unsupported extensions.")

	return {
		"name": "system_script_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"bindings_target_count": int((bindings_audit.get("data", {}) as Dictionary).get("target_count", 0)),
			"diagnostics_available": bool((diagnostics as Dictionary).get("available", false))
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	_remove_tree(TEMP_ROOT)


func _prepare_temp_root() -> void:
	_remove_tree(TEMP_ROOT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))


func _write_text(path: String, content: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to create system script contract fixture: %s" % path)
		return
	file.store_string(content)
	file.close()


func _remove_tree(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	var dir = DirAccess.open(absolute_path)
	if dir == null:
		DirAccess.remove_absolute(absolute_path)
		return
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child_path := absolute_path.path_join(entry)
			if dir.current_is_dir():
				_remove_tree(ProjectSettings.localize_path(child_path))
			else:
				DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


func _failure(message: String) -> Dictionary:
	return {
		"name": "system_script_executor_contracts",
		"success": false,
		"error": message
	}
