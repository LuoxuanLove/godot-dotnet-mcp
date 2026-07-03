extends RefCounted

## Contract test: defines the DTO contract for plugin-internal Roslyn C# analysis service.
## This test is RED (fails) until tasks 4-5-6 build the PluginRoslynService.
## After tasks 4-5-6 complete, this test should PASS.

const PluginRoslynServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_roslyn_service.gd")

var _temp_paths: Array[String] = []
var _service = null


func run_case(_tree: SceneTree) -> Dictionary:
	# Check if the service exists and is loadable
	_service = PluginRoslynServiceScript.new() if PluginRoslynServiceScript else null
	if _service == null:
		return _failure("PluginRoslynService not yet implemented at 'res://addons/godot_dotnet_mcp/plugin/runtime/plugin_roslyn_service.gd'")

	var capabilities: Dictionary = await _service.get_capabilities_async()
	if not bool(capabilities.get("success", false)):
		return _failure("Roslyn capabilities should resolve successfully before parse coverage runs: %s" % str(capabilities.get("error", capabilities.get("message", ""))))
	var capability_data: Dictionary = capabilities.get("data", {})
	if str(capability_data.get("engine", "")) != "roslyn":
		return _failure("Expected capabilities.engine='roslyn', got '%s'" % str(capability_data.get("engine", "")))
	if str(capability_data.get("mode", "")) != "syntax":
		return _failure("Expected capabilities.mode='syntax', got '%s'" % str(capability_data.get("mode", "")))
	if str(capability_data.get("transport", "")) != "process_json":
		return _failure("Expected capabilities.transport='process_json', got '%s'" % str(capability_data.get("transport", "")))
	if str(capability_data.get("entrypoint", "")).find("roslyn_runtime") == -1:
		return _failure("Expected isolated Roslyn runtime entrypoint metadata, got '%s'" % str(capability_data.get("entrypoint", "")))
	if str(capability_data.get("distribution", "")) != "framework-dependent":
		return _failure("Expected framework-dependent Roslyn runtime distribution metadata, got '%s'" % str(capability_data.get("distribution", "")))
	if str(capability_data.get("runtime_requirement", "")).find(".NET 8") == -1:
		return _failure("Expected .NET 8 runtime requirement metadata, got '%s'" % str(capability_data.get("runtime_requirement", "")))

	# --- Fixture 1: Valid C# with namespace, class, method ---
	var temp_dir := "res://tests_tmp/roslyn_parsing_contracts"
	_ensure_dir(temp_dir)
	var valid_cs_path := "%s/ValidClass.cs" % temp_dir
	_temp_paths.append(valid_cs_path)
	_temp_paths.append(temp_dir)

	var valid_cs := """using System;
using Godot;

namespace Game.Logic {
    public partial class ValidClass : Node {
        [Export] public float Speed = 1.0f;

        public void Update(float delta) {
            GD.Print(\"Update: \" + delta);
        }

        private int Calculate(int a, int b) {
            return a + b;
        }
    }
}"""

	_write_text(valid_cs_path, valid_cs)

	var result1: Dictionary = await _service.parse_file_async(valid_cs_path, "")
	if not bool(result1.get("success", false)):
		return _failure("Valid C# file should parse successfully: %s" % str(result1.get("error", "")))

	var data1: Dictionary = result1.get("data", {})
	if str(data1.get("engine", "")) != "roslyn":
		return _failure("Expected engine='roslyn', got '%s'" % str(data1.get("engine", "")))
	if str(data1.get("mode", "")) != "syntax":
		return _failure("Expected mode='syntax', got '%s'" % str(data1.get("mode", "")))
	if str(data1.get("transport", "")) != "process_json":
		return _failure("Expected transport='process_json', got '%s'" % str(data1.get("transport", "")))
	if str(data1.get("entrypoint", "")).find("roslyn_runtime") == -1:
		return _failure("Expected isolated parse entrypoint metadata, got '%s'" % str(data1.get("entrypoint", "")))
	if str(data1.get("source_hash", "")).is_empty():
		return _failure("Expected non-empty source_hash")
	if not (data1.get("types") is Array) or (data1.get("types") as Array).size() == 0:
		return _failure("Expected non-empty types[] for valid C#")
	if not (data1.get("methods") is Array) or (data1.get("methods") as Array).size() == 0:
		return _failure("Expected non-empty methods[] for valid C#")

	# --- Fixture 2: Malformed C# (syntax error) ---
	var malformed_cs_path := "%s/Malformed.cs" % temp_dir
	_temp_paths.append(malformed_cs_path)

	var malformed_cs := """using System
public class Malformed {
    public void Test() {
        GD.Print(
}"""

	_write_text(malformed_cs_path, malformed_cs)

	var result2: Dictionary = await _service.parse_file_async(malformed_cs_path, "")
	# Should return success=false OR parse_errors populated, not crash
	var data2: Dictionary = result2.get("data", {})
	var parse_errors2: Array = data2.get("parse_errors", []) if data2 is Dictionary else []
	if parse_errors2.size() == 0:
		return _failure("Malformed C# should return parse_errors[], got none. result=%s" % str(result2))

	# --- Fixture 3: Partial class file ---
	var partial_cs_path := "%s/PartialClass.cs" % temp_dir
	_temp_paths.append(partial_cs_path)

	var partial_cs := """using Godot;

public partial class PartialClass : Node {
    [Export] public int Value;
}"""

	_write_text(partial_cs_path, partial_cs)

	var result3: Dictionary = await _service.parse_file_async(partial_cs_path, "")
	if not bool(result3.get("success", false)):
		return _failure("Partial class C# should parse successfully: %s" % str(result3.get("error", "")))
	var data3: Dictionary = result3.get("data", {})
	if not (data3.get("types") is Array) or (data3.get("types") as Array).size() == 0:
		return _failure("Partial class should still return types[]")

	# --- Fixture 4: Missing file ---
	var result4: Dictionary = await _service.parse_file_async("res://NonExistent.cs", "")
	if bool(result4.get("success", false)):
		return _failure("Missing file should return success=false, got success=true")

	# --- Fixture 5: Unsaved source text (not from disk) ---
	var unsaved_cs := """using System;
public class UnsavedText : Node {
    public int UnsavedField = 42;
}"""

	var result5: Dictionary = await _service.parse_file_async("res://UnsavedText.cs", unsaved_cs)
	if not bool(result5.get("success", false)):
		return _failure("Unsaved source text should parse successfully: %s" % str(result5.get("error", "")))
	var data5: Dictionary = result5.get("data", {})
	var hash5 := str(data5.get("source_hash", ""))
	if hash5.is_empty():
		return _failure("Unsaved text should produce a non-empty source_hash")
	# Calling again with same unsaved text should hit cache (same hash)
	var result5b: Dictionary = await _service.parse_file_async("res://UnsavedText.cs", unsaved_cs)
	var data5b: Dictionary = result5b.get("data", {})
	if str(data5b.get("source_hash", "")) != hash5:
		return _failure("Same unsaved text should produce same source_hash (cache hit)")

	return {
		"name": "roslyn_parsing_contracts",
		"success": true,
		"error": "",
		"details": {
			"fixture_1_valid": true,
			"fixture_2_malformed_parse_errors": parse_errors2.size(),
			"fixture_3_partial_class": true,
			"fixture_4_missing_file_rejected": true,
			"fixture_5_unsaved_text_hash": str(data5.get("source_hash", ""))
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	if _service != null:
		if _service.has_method("clear"):
			_service.clear()
		_service.free()
		_service = null
	for path in _temp_paths:
		if path.ends_with(".gd") or path.ends_with(".cs"):
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for i in range(_temp_paths.size() - 1, -1, -1):
		var path = _temp_paths[i]
		if not path.ends_with(".gd") and not path.ends_with(".cs"):
			if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
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
		"name": "roslyn_parsing_contracts",
		"success": false,
		"error": message
	}
