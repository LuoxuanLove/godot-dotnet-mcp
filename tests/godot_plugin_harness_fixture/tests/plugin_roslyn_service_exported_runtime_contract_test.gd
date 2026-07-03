extends RefCounted

const CASE_NAME := "plugin_roslyn_service_exported_runtime_contracts"
const PluginRoslynServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_roslyn_service.gd")

var _temp_paths: Array[String] = []
var _service: Node = null


func run_case(_tree: SceneTree) -> Dictionary:
	_service = PluginRoslynServiceScript.new()

	var snapshot_before: Dictionary = _service.get_debug_snapshot()
	if str(snapshot_before.get("load_mode", "")) != "gdscript_placeholder":
		return _failure("Roslyn service should start before runtime evaluation.")

	var temp_dir := "res://tests_tmp/plugin_roslyn_service_exported_runtime_contracts"
	_ensure_dir(temp_dir)
	var script_path := "%s/ExportedRuntimeProbe.cs" % temp_dir
	_temp_paths.append(script_path)
	_temp_paths.append(temp_dir)
	_write_text(script_path, "using Godot;\npublic partial class ExportedRuntimeProbe : Node { [Export] public int Speed = 3; public void Run() { } }")

	var result: Dictionary = await _service.parse_file_async(script_path)
	if not bool(result.get("success", false)):
		return _failure("Exported PluginRoslynService should parse C# through isolated runtime process: %s" % str(result.get("error", "")))

	var data: Dictionary = result.get("data", {})
	if str(data.get("engine", "")) != "roslyn":
		return _failure("Exported PluginRoslynService should report engine=roslyn.")
	if str(data.get("semantic_runtime", "")) != "Roslyn":
		return _failure("Exported PluginRoslynService should report semantic_runtime=Roslyn.")
	var types: Array = data.get("types", [])
	if types.is_empty() or str((types[0] as Dictionary).get("name", "")) != "ExportedRuntimeProbe":
		return _failure("Exported PluginRoslynService should return type metadata from cs_file_read.")
	var exports: Array = data.get("exports", [])
	if exports.is_empty() or str((exports[0] as Dictionary).get("name", "")) != "Speed":
		return _failure("Exported PluginRoslynService should return exported property metadata from cs_file_read.")

	var patch_result: Dictionary = await _service.patch_file_async(script_path, {
		"action": "replace_method_body",
		"type_name": "ExportedRuntimeProbe",
		"member_name": "Run",
		"body": "GD.Print(\"patched\");"
	})
	if not bool(patch_result.get("success", false)):
		return _failure("Exported PluginRoslynService should patch C# through isolated runtime process: %s" % str(patch_result.get("error", "")))
	if FileAccess.get_file_as_string(script_path).find("patched") == -1:
		return _failure("Exported PluginRoslynService patch_file_async should write the patched body to disk.")

	var snapshot_after: Dictionary = _service.get_debug_snapshot()
	var load_mode := str(snapshot_after.get("load_mode", ""))
	if load_mode != "isolated_runtime_process":
		return _failure("Exported PluginRoslynService should use isolated runtime process, got '%s'." % load_mode)
	var metadata: Dictionary = _service.get_capabilities()
	var metadata_data: Dictionary = metadata.get("data", {})
	if str(metadata_data.get("transport", "")) != "process_json":
		return _failure("Exported PluginRoslynService should report process_json transport.")
	if str(metadata_data.get("distribution", "")) != "framework-dependent":
		return _failure("Exported PluginRoslynService should report framework-dependent Roslyn runtime distribution.")
	if str(metadata_data.get("runtime_requirement", "")).find(".NET 8") == -1:
		return _failure("Exported PluginRoslynService should report the .NET 8 runtime requirement.")

	return {
		"name": CASE_NAME,
		"success": true,
		"error": "",
		"details": {
			"load_mode": load_mode,
			"transport": str(metadata_data.get("transport", "")),
			"type_count": types.size(),
			"export_count": exports.size(),
			"patched": true
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	if _service != null:
		_service.clear()
		if is_instance_valid(_service):
			_service.free()
	_service = null
	for path in _temp_paths:
		if path.ends_with(".cs") and FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for i in range(_temp_paths.size() - 1, -1, -1):
		var path = _temp_paths[i]
		if not path.ends_with(".cs") and DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_temp_paths.clear()


func _ensure_dir(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		DirAccess.make_dir_recursive_absolute(absolute_path)


func _write_text(path: String, content: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to create fixture: %s" % path)
		return
	file.store_string(content)
	file.close()


func _failure(message: String) -> Dictionary:
	return {
		"name": CASE_NAME,
		"success": false,
		"error": message
	}
