@tool
extends "res://addons/godot_dotnet_mcp/tools/system/script/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var script_path := str(args.get("script", "")).strip_edges()
	var ops_raw = args.get("ops", [])
	var dry_run := bool(args.get("dry_run", true))

	if script_path.is_empty():
		return bridge.error("script is required")
	if not (script_path.ends_with(".gd") or script_path.ends_with(".cs")):
		return bridge.error("script must be a .gd or .cs file")
	if not FileAccess.file_exists(script_path):
		MCPDebugBuffer.record("warning", "system", "script_patch: file not found: %s" % script_path)
		return bridge.error("Script file not found: %s" % script_path)
	if not (ops_raw is Array) or (ops_raw as Array).is_empty():
		return bridge.error("ops must be a non-empty array")

	var is_gd := script_path.ends_with(".gd")
	var atomic_tool := "script_edit_gd" if is_gd else "script_edit_cs"
	var inspect_data: Dictionary = bridge.extract_data(bridge.call_atomic("script_inspect", {"path": script_path}))
	if inspect_data.is_empty():
		return bridge.error("Failed to inspect script: %s" % script_path)

	var ops: Array = []
	for raw_op in ops_raw:
		if raw_op is Dictionary:
			ops.append((raw_op as Dictionary).duplicate(true))

	var op_previews: Array = []
	var op_errors: Array = []
	for op_item in ops:
		if not (op_item is Dictionary):
			op_errors.append("Invalid op: not a dictionary")
			continue
		var op_name := str((op_item as Dictionary).get("op", ""))
		var member_name := str((op_item as Dictionary).get("name", ""))
		if member_name.is_empty():
			op_errors.append("Op '%s': name is required" % op_name)
			op_previews.append({"op": op_name, "valid": false, "error": "name is required"})
			continue
		op_previews.append({
			"op": op_name,
			"valid": true,
			"name": member_name,
			"description": "Add %s '%s' to %s" % [op_name.replace("add_", ""), member_name, script_path.get_file()]
		})

	if dry_run:
		return bridge.success({
			"script": script_path,
			"language": str(inspect_data.get("language", "unknown")),
			"dry_run": true,
			"op_count": ops.size(),
			"op_previews": op_previews,
			"would_apply": op_errors.is_empty(),
			"errors": op_errors
		})

	if not op_errors.is_empty():
		return bridge.error("Cannot apply patch: %s" % "; ".join(op_errors), {"op_errors": op_errors})

	var applied_ops: Array = []
	var failed_ops: Array = []
	for op_item in ops:
		if not (op_item is Dictionary):
			continue
		var op_name := str((op_item as Dictionary).get("op", ""))
		var apply_result: Dictionary = _apply_patch_op(op_item as Dictionary, script_path, atomic_tool, is_gd)
		if bool(apply_result.get("success", false)):
			applied_ops.append({"op": op_name, "name": str((op_item as Dictionary).get("name", ""))})
		else:
			failed_ops.append({"op": op_name, "name": str((op_item as Dictionary).get("name", "")), "error": str(apply_result.get("error", ""))})

	return bridge.success({
		"script": script_path,
		"dry_run": false,
		"applied_count": applied_ops.size(),
		"failed_count": failed_ops.size(),
		"applied_ops": applied_ops,
		"failed_ops": failed_ops
	})


func _apply_patch_op(op: Dictionary, script_path: String, atomic_tool: String, is_gd: bool) -> Dictionary:
	var op_name := str(op.get("op", ""))
	var member_name := str(op.get("name", ""))
	match op_name:
		"add_method":
			if is_gd:
				return bridge.call_atomic(atomic_tool, {"action": "add_function", "path": script_path, "name": member_name, "params": op.get("params", []), "body": str(op.get("body", "\tpass"))})
			return bridge.call_atomic(atomic_tool, {"action": "add_method", "path": script_path, "name": member_name, "params": op.get("params", []), "return_type": str(op.get("type", "void")), "body": str(op.get("body", ""))})
		"add_export":
			if is_gd:
				return bridge.call_atomic(atomic_tool, {"action": "add_export", "path": script_path, "name": member_name, "type": str(op.get("type", "Variant")), "default_value": str(op.get("default_value", "")), "hint": str(op.get("hint", ""))})
			return bridge.call_atomic(atomic_tool, {"action": "add_field", "path": script_path, "name": member_name, "type": str(op.get("type", "Variant")), "export": true})
		"add_signal":
			if is_gd:
				return bridge.call_atomic(atomic_tool, {"action": "add_signal", "path": script_path, "name": member_name, "params": op.get("params", [])})
			return bridge.error("add_signal is not supported for C# scripts via script_patch")
		"add_variable":
			if is_gd:
				var variable_args: Dictionary = {"action": "add_variable", "path": script_path, "name": member_name, "type": str(op.get("type", ""))}
				if bool(op.get("onready", false)):
					variable_args["onready"] = true
				if not str(op.get("default_value", "")).is_empty():
					variable_args["default_value"] = str(op.get("default_value", ""))
				return bridge.call_atomic(atomic_tool, variable_args)
			return bridge.call_atomic(atomic_tool, {"action": "add_field", "path": script_path, "name": member_name, "type": str(op.get("type", "Variant")), "export": false})
		"replace_method_body":
			return bridge.call_atomic(atomic_tool, {"action": "replace_function_body" if is_gd else "replace_method_body", "path": script_path, "name": member_name, "body": str(op.get("body", ""))})
		"delete_member":
			return bridge.call_atomic(atomic_tool, {"action": "remove_member" if is_gd else "delete_member", "path": script_path, "name": member_name, "member_type": str(op.get("member_type", "auto"))})
		"rename_member":
			return bridge.call_atomic(atomic_tool, {"action": "rename_member", "path": script_path, "name": member_name, "new_name": str(op.get("new_name", ""))})
		_:
			return bridge.error("Unknown script patch op: %s" % op_name)
