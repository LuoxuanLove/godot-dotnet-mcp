extends RefCounted

## Contract test: constrains C# tool paths to use a single Roslyn engine.
## 5 paths MUST return engine=roslyn, mode=syntax after task 7.
## script_references MUST return engine=legacy_path_first (NOT roslyn) — non-goal boundary.

const ScriptToolsScript = preload("res://addons/godot_dotnet_mcp/tools/script/executor.gd")
const SystemScriptImplScript = preload("res://addons/godot_dotnet_mcp/tools/system/impl_script.gd")

var _temp_paths: Array[String] = []
var _executor = null
var _sys_impl = null
var _bridge = null


class ScriptToolBridge extends RefCounted:
	var _executor

	func _init(executor) -> void:
		_executor = executor

	func call_atomic(tool_name: String, args: Dictionary) -> Dictionary:
		match tool_name:
			"script_inspect":
				return _executor.execute("inspect", args)
			"script_symbols":
				return _executor.execute("symbols", args)
			"script_exports":
				return _executor.execute("exports", args)
			"script_references":
				return _executor.execute("references", args)
			"script_edit_cs":
				return _executor.execute("edit_cs", args)
			_:
				return error("Unsupported bridge call: %s" % tool_name)

	func extract_data(result: Dictionary) -> Dictionary:
		var data = result.get("data", {})
		return (data as Dictionary).duplicate(true) if data is Dictionary else {}

	func append_unique_issue(target: Array, issue: Dictionary) -> void:
		target.append(issue.duplicate(true))

	func build_issue(severity: String, issue_type: String, message: String, data: Dictionary = {}) -> Dictionary:
		return {"severity": severity, "type": issue_type, "message": message, "data": data.duplicate(true)}

	func success(data = {}, message: String = "") -> Dictionary:
		return {"success": true, "data": data, "message": message}

	func error(message: String, data = {}) -> Dictionary:
		return {"success": false, "error": message, "data": data}


func run_case(_tree: SceneTree) -> Dictionary:
	_executor = ScriptToolsScript.new()
	_sys_impl = SystemScriptImplScript.new()
	_bridge = ScriptToolBridge.new(_executor)
	_sys_impl.bridge = _bridge

	var temp_dir := "res://tests_tmp/csharp_engine_contracts"
	_ensure_dir(temp_dir)
	var cs_path := "%s/TestEngine.cs" % temp_dir
	var gd_path := "%s/TestEngine.gd" % temp_dir
	_temp_paths.append_array([cs_path, gd_path, temp_dir])

	_write_text(cs_path, """using Godot;
public partial class TestEngine : Node {
    [Export] public float Speed = 1.0f;
    public void Update(float delta) { }
}""")

	_write_text(gd_path, """extends Node
@export var speed: float = 1.0
func _ready(): pass""")

	# --- C# tools that MUST return engine=roslyn, mode=syntax ---

	var inspect_result: Dictionary = _executor.execute("inspect", {"path": cs_path})
	if not bool(inspect_result.get("success", false)):
		return _failure("inspect(C#) should succeed")
	var inspect_data: Dictionary = inspect_result.get("data", {})
	if str(inspect_data.get("engine", "")) != "roslyn":
		return _failure("inspect(C#) MUST return engine='roslyn', got '%s'" % str(inspect_data.get("engine", "")))
	if str(inspect_data.get("mode", "")) != "syntax":
		return _failure("inspect(C#) MUST return mode='syntax', got '%s'" % str(inspect_data.get("mode", "")))

	var symbols_result: Dictionary = _executor.execute("symbols", {"path": cs_path})
	if not bool(symbols_result.get("success", false)):
		return _failure("symbols(C#) should succeed")
	var symbols_data: Dictionary = symbols_result.get("data", {})
	if str(symbols_data.get("engine", "")) != "roslyn":
		return _failure("symbols(C#) MUST return engine='roslyn', got '%s'" % str(symbols_data.get("engine", "")))
	if str(symbols_data.get("mode", "")) != "syntax":
		return _failure("symbols(C#) MUST return mode='syntax', got '%s'" % str(symbols_data.get("mode", "")))

	var exports_result: Dictionary = _executor.execute("exports", {"path": cs_path})
	if not bool(exports_result.get("success", false)):
		return _failure("exports(C#) should succeed")
	var exports_data: Dictionary = exports_result.get("data", {})
	if str(exports_data.get("engine", "")) != "roslyn":
		return _failure("exports(C#) MUST return engine='roslyn', got '%s'" % str(exports_data.get("engine", "")))
	if str(exports_data.get("mode", "")) != "syntax":
		return _failure("exports(C#) MUST return mode='syntax', got '%s'" % str(exports_data.get("mode", "")))

	var edit_cs_result: Dictionary = _executor.execute("edit_cs", {
		"action": "upsert_method",
		"path": cs_path,
		"type_name": "TestEngine",
		"member_name": "NewMethod",
		"return_type": "int",
		"parameters": ["float delta"],
		"body": "return 1;"
	})
	if not bool(edit_cs_result.get("success", false)):
		return _failure("edit_cs(C#) should succeed through Roslyn path")
	var edit_cs_data: Dictionary = edit_cs_result.get("data", {})
	if str(edit_cs_data.get("engine", "")) != "roslyn":
		return _failure("edit_cs(C#) MUST return engine='roslyn', got '%s'" % str(edit_cs_data.get("engine", "")))
	if str(edit_cs_data.get("mode", "")) != "syntax":
		return _failure("edit_cs(C#) MUST return mode='syntax', got '%s'" % str(edit_cs_data.get("mode", "")))
	if str(FileAccess.get_file_as_string(cs_path)).find("NewMethod") == -1:
		return _failure("edit_cs(C#) should write the upserted method to disk.")

	var replace_method_body: Dictionary = _executor.execute("edit_cs", {
		"action": "replace_method_body",
		"path": cs_path,
		"type_name": "TestEngine",
		"member_name": "NewMethod",
		"return_type": "int",
		"parameters": ["float delta"],
		"body": "return 2;"
	})
	if not bool(replace_method_body.get("success", false)):
		return _failure("replace_method_body(C#) should succeed through Roslyn path")
	if str(replace_method_body.get("data", {}).get("engine", "")) != "roslyn":
		return _failure("replace_method_body(C#) MUST return engine='roslyn'.")
	if str(FileAccess.get_file_as_string(cs_path)).find("return 2;") == -1:
		return _failure("replace_method_body(C#) should persist the replaced method body.")

	var upsert_field: Dictionary = _executor.execute("edit_cs", {
		"action": "upsert_field",
		"path": cs_path,
		"type_name": "TestEngine",
		"member_name": "Count",
		"field_type": "int",
		"value": "1"
	})
	if not bool(upsert_field.get("success", false)):
		return _failure("upsert_field(C#) should succeed through Roslyn path")
	if str(upsert_field.get("data", {}).get("mode", "")) != "syntax":
		return _failure("upsert_field(C#) MUST return mode='syntax'.")
	if str(FileAccess.get_file_as_string(cs_path)).find("Count") == -1:
		return _failure("upsert_field(C#) should persist the new field.")

	var delete_field: Dictionary = _executor.execute("edit_cs", {
		"action": "delete_member",
		"path": cs_path,
		"type_name": "TestEngine",
		"member_name": "Count",
		"member_type": "field"
	})
	if not bool(delete_field.get("success", false)):
		return _failure("delete_member(C#) should succeed through Roslyn path")
	if str(FileAccess.get_file_as_string(cs_path)).find("Count") != -1:
		return _failure("delete_member(C#) should remove the field from disk.")

	var invalid_edit: Dictionary = _executor.execute("edit_cs", {
		"action": "bogus_action",
		"path": cs_path
	})
	if bool(invalid_edit.get("success", true)):
		return _failure("edit_cs(C#) should reject unsupported actions.")

	var sys_analyze_cs: Dictionary = _sys_impl.execute("script_analyze", {
		"script": cs_path,
		"include_diagnostics": false
	})
	if not bool(sys_analyze_cs.get("success", false)):
		return _failure("system_script_analyze(C#) should succeed")
	var sys_analyze_cs_data: Dictionary = sys_analyze_cs.get("data", {})
	if str(sys_analyze_cs_data.get("engine", "")) != "roslyn":
		return _failure("system_script_analyze(C#) MUST return engine='roslyn', got '%s'" % str(sys_analyze_cs_data.get("engine", "")))
	if str(sys_analyze_cs_data.get("mode", "")) != "syntax":
		return _failure("system_script_analyze(C#) MUST return mode='syntax', got '%s'" % str(sys_analyze_cs_data.get("mode", "")))

	# --- script_references is NON-GOAL: must remain legacy ---
	var refs_result: Dictionary = _executor.execute("references", {
		"action": "get_class_map",
		"refresh": false
	})
	if not bool(refs_result.get("success", false)):
		return _failure("script_references should succeed")
	var refs_data: Dictionary = refs_result.get("data", {})
	var refs_engine := str(refs_data.get("engine", ""))
	if refs_engine == "roslyn":
		return _failure("script_references MUST NOT return engine='roslyn' — it is a non-goal legacy path. Got engine='%s'" % refs_engine)
	if refs_engine != "legacy_path_first":
		return _failure("script_references engine must be exactly legacy_path_first. Got '%s'" % refs_engine)
	if str(refs_data.get("mode", "")) != "path_first":
		return _failure("script_references mode must be exactly path_first. Got '%s'" % str(refs_data.get("mode", "")))

	# --- GDScript paths should NOT return engine=roslyn ---
	var gd_inspect: Dictionary = _executor.execute("inspect", {"path": gd_path})
	if not bool(gd_inspect.get("success", false)):
		return _failure("inspect(GD) should succeed")
	var gd_inspect_data: Dictionary = gd_inspect.get("data", {})
	var gd_engine := str(gd_inspect_data.get("engine", ""))
	if gd_engine == "roslyn":
		return _failure("GDScript inspect should NOT return engine='roslyn' — GDScript uses Godot LSP, got '%s'" % gd_engine)

	return {
		"name": "csharp_tool_engine_contracts",
		"success": true,
		"error": "",
		"details": {
			"inspect_cs_engine": str(inspect_data.get("engine", "")),
			"inspect_cs_mode": str(inspect_data.get("mode", "")),
			"symbols_cs_engine": str(symbols_data.get("engine", "")),
			"symbols_cs_mode": str(symbols_data.get("mode", "")),
			"exports_cs_engine": str(exports_data.get("engine", "")),
			"exports_cs_mode": str(exports_data.get("mode", "")),
			"edit_cs_engine": str(edit_cs_data.get("engine", "")),
			"edit_cs_mode": str(edit_cs_data.get("mode", "")),
			"sys_analyze_cs_engine": str(sys_analyze_cs_data.get("engine", "")),
			"sys_analyze_cs_mode": str(sys_analyze_cs_data.get("mode", "")),
			"references_engine": refs_engine,
			"references_mode": str(refs_data.get("mode", "")),
			"inspect_gd_engine": gd_engine
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	_cleanup_runtime()
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


func _cleanup_runtime() -> void:
	if _sys_impl != null:
		_sys_impl.bridge = null
	if _bridge != null:
		_bridge._executor = null
	if _executor != null and _executor.has_method("clear"):
		_executor.clear()
	_executor = null
	_bridge = null
	_sys_impl = null


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
		"name": "csharp_tool_engine_contracts",
		"success": false,
		"error": message
	}
