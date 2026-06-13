extends RefCounted

const CASE_NAME := "plugin_roslyn_service_exported_runtime_contracts"
const FACADE_SCRIPT_PATH := "res://addons/godot_dotnet_mcp/plugin/runtime/roslyn/PluginRoslynRuntimeFacade.cs"
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

	var result: Dictionary = _service.parse_file(script_path)
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

	var snapshot_after: Dictionary = _service.get_debug_snapshot()
	var load_mode := str(snapshot_after.get("load_mode", ""))
	var facade_source_present := FileAccess.file_exists(FACADE_SCRIPT_PATH)
	if facade_source_present:
		if load_mode != "runtime_csharp" and load_mode != "isolated_runtime_process":
			return _failure("Source-tree PluginRoslynService should use a semantic Roslyn runtime, got '%s'." % load_mode)
	elif load_mode != "isolated_runtime_process":
		return _failure("Exported PluginRoslynService should use isolated runtime process, got '%s'." % load_mode)

	return {
		"name": CASE_NAME,
		"success": true,
		"error": "",
		"details": {
			"facade_source_present": facade_source_present,
			"load_mode": load_mode,
			"type_count": types.size(),
			"export_count": exports.size()
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
