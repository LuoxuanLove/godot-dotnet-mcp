extends RefCounted

# {"name": "system_atomic_bridge_support_contracts"}

const AtomicBridgeSupportScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_support.gd")

const SOURCE_PATH := "res://tests_tmp/system_atomic_bridge_support_contracts/scenes/Main.tscn"


func run_case(_tree: SceneTree) -> Dictionary:
	var support = AtomicBridgeSupportScript.new()

	if not support.is_protected_path("res://addons/godot_dotnet_mcp/plugin/plugin.gd"):
		return _failure("AtomicBridgeSupport should protect plugin implementation paths.")
	if support.is_protected_path("res://addons/godot_dotnet_mcp/custom_tools/user_tool.gd"):
		return _failure("AtomicBridgeSupport should not block custom_tools paths managed by UserToolService.")
	if support.is_protected_path("res://game/scripts/Player.gd"):
		return _failure("AtomicBridgeSupport should not protect normal project paths.")
	if not support.is_protected_path("res://ADDONS/godot_dotnet_mcp/../godot_dotnet_mcp/plugin/plugin.gd"):
		return _failure("AtomicBridgeSupport should normalize and protect plugin implementation paths.")

	if not support.is_write_action({"action": " save "}):
		return _failure("AtomicBridgeSupport should trim and classify mutating action names.")
	if support.is_write_action({"action": "get_files"}):
		return _failure("AtomicBridgeSupport should keep read-only actions out of the write set.")
	if not support.is_write_atomic_action("script_edit_gd", {}):
		return _failure("AtomicBridgeSupport should infer script_edit_* atomic calls as writes.")
	if support.is_write_atomic_action("project_info", {"action": "get_info"}):
		return _failure("AtomicBridgeSupport should not infer read-only project_info calls as writes.")

	var path_args := {
		"file_path": "res://Player.gd",
		"path": "res://Preferred.gd"
	}
	if support.find_path_in_args(path_args) != "res://Preferred.gd":
		return _failure("AtomicBridgeSupport should preserve AtomicBridge path lookup precedence.")
	if support.find_path_in_args({"source": "res://Source.tres", "dest": "res://Dest.tres"}) != "res://Source.tres":
		return _failure("AtomicBridgeSupport should inspect source/dest path arguments for write guards.")
	if support.find_path_in_args({"paths": ["res://One.gd", "res://Two.gd"]}) != "res://One.gd":
		return _failure("AtomicBridgeSupport should inspect path arrays for write guards.")

	var issue := support.build_issue("warning", "dependency_mismatch", "Dependency differs", {"file": "res://A.tscn"})
	if issue.get("file", "") != "res://A.tscn" or issue.get("type", "") != "dependency_mismatch":
		return _failure("AtomicBridgeSupport.build_issue should preserve extra issue metadata.")
	var issues := []
	support.append_unique_issue(issues, issue)
	support.append_unique_issue(issues, issue.duplicate(true))
	if issues.size() != 1:
		return _failure("AtomicBridgeSupport.append_unique_issue should deduplicate by type and message.")
	if not support.has_severity(issues, "warning"):
		return _failure("AtomicBridgeSupport.has_severity should find matching severities.")

	var normalized := support.normalize_resource_path("../Shared.cs", SOURCE_PATH)
	if normalized != "res://tests_tmp/system_atomic_bridge_support_contracts/Shared.cs":
		return _failure("AtomicBridgeSupport should normalize relative paths against the source resource directory: %s" % normalized)

	var raw_reference := "uid://missing_bridge_contract::Script::../Missing.cs"
	var support_reference: Dictionary = support.parse_dependency_reference(raw_reference, SOURCE_PATH)
	if not bool(support_reference.get("has_uid_path_pair", false)):
		return _failure("AtomicBridgeSupport should preserve UID/path pair detection.")
	if support_reference.get("declared_path", "") != "res://tests_tmp/system_atomic_bridge_support_contracts/Missing.cs":
		return _failure("AtomicBridgeSupport should normalize declared fallback dependency paths.")
	if support_reference.get("risk", "") != "error" or support_reference.get("consistency", "") != "missing_uid_and_path":
		return _failure("AtomicBridgeSupport should report missing UID/path dependency references as errors.")
	var invalid_reference: Dictionary = support.parse_dependency_reference("uid://missing_bridge_contract::Script::user://outside.cs", SOURCE_PATH)
	if invalid_reference.get("risk", "") != "error" or invalid_reference.get("consistency", "") != "invalid_path":
		return _failure("AtomicBridgeSupport should report invalid fallback dependency paths as invalid_path errors.")

	return {"name": "system_atomic_bridge_support_contracts", "success": true, "error": ""}


func _failure(message: String) -> Dictionary:
	return {"name": "system_atomic_bridge_support_contracts", "success": false, "error": message}
