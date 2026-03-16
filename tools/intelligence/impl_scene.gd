@tool
extends RefCounted

## Intelligence implementation: scene_validate, scene_analyze, scene_patch

var bridge
const HANDLED_TOOLS := ["scene_validate", "scene_analyze", "scene_patch"]


func handles(tool_name: String) -> bool:
	return tool_name in HANDLED_TOOLS


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "scene_validate",
			"description": "SCENE VALIDATE: Validate a scene file for structural issues and missing dependencies.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"scene": {"type": "string", "description": "Scene path (res://..., .tscn)"}
				},
				"required": ["scene"]
			}
		},
		{
			"name": "scene_analyze",
			"description": "SCENE ANALYZE: Deep analysis of a scene: node hierarchy, scripts, bindings, and issues.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"scene": {"type": "string", "description": "Scene path (res://..., .tscn)"}
				},
				"required": ["scene"]
			}
		},
		{
			"name": "scene_patch",
			"description": "SCENE PATCH: Apply structured modifications to a scene. Supports add_node, remove_node, set_property, attach_script, reparent_node ops. Use dry_run:true (default) to preview first.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"scene": {"type": "string", "description": "Scene path (res://..., .tscn)"},
					"ops": {
						"type": "array",
						"description": "List of patch operations",
						"items": {
							"type": "object",
							"properties": {
								"op": {"type": "string", "enum": ["add_node", "remove_node", "set_property", "attach_script", "reparent_node"]},
								"name": {"type": "string"},
								"type": {"type": "string"},
								"parent_path": {"type": "string"},
								"node_path": {"type": "string"},
								"property": {"type": "string"},
								"value": {},
								"script": {"type": "string"},
								"new_parent": {"type": "string"}
							},
							"required": ["op"]
						}
					},
					"dry_run": {"type": "boolean", "description": "Preview without executing (default: true)"}
				},
				"required": ["scene", "ops"]
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	MCPDebugBuffer.record("debug", "intelligence", "tool: %s" % tool_name)
	match tool_name:
		"scene_validate": return _execute_scene_validate(args)
		"scene_analyze":  return _execute_scene_analyze(args)
		"scene_patch":    return _execute_scene_patch(args)
		_: return bridge.error("Unknown tool: %s" % tool_name)


# --- private helpers ---

func _apply_scene_patch_op(op: Dictionary) -> Dictionary:
	var op_name := str(op.get("op", ""))
	match op_name:
		"add_node":
			return bridge.call_atomic("node_lifecycle", {"action": "create", "parent_path": str(op.get("parent_path", ".")), "type": str(op.get("type", "Node")), "name": str(op.get("name", ""))})
		"remove_node":
			return bridge.call_atomic("node_lifecycle", {"action": "delete", "node_path": str(op.get("node_path", ""))})
		"set_property":
			var set_args: Dictionary = {"action": "set", "node_path": str(op.get("node_path", "")), "property": str(op.get("property", "")), "value": op.get("value", null)}
			return bridge.call_atomic("node_property", set_args)
		"attach_script":
			return bridge.call_atomic("node_lifecycle", {"action": "attach_script", "node_path": str(op.get("node_path", "")), "script_path": str(op.get("script", ""))})
		"reparent_node":
			return bridge.call_atomic("node_hierarchy", {"action": "reparent", "node_path": str(op.get("node_path", "")), "new_parent": str(op.get("new_parent", ""))})
		_:
			return bridge.error("Unknown scene patch op: %s" % op_name)


# --- tool implementations ---

func _execute_scene_validate(args: Dictionary) -> Dictionary:
	var scene_path := str(args.get("scene", "")).strip_edges()
	if scene_path.is_empty():
		return bridge.error("scene path is required")
	if not scene_path.ends_with(".tscn"):
		return bridge.error("scene must be a .tscn file")
	if not FileAccess.file_exists(scene_path):
		MCPDebugBuffer.record("warning", "intelligence",
			"scene_validate: file not found: %s" % scene_path)
		return bridge.error("Scene file not found: %s" % scene_path)
	MCPDebugBuffer.record("debug", "intelligence", "scene_validate: %s" % scene_path)
	var audit_result: Dictionary = bridge.call_atomic("scene_audit", {"action": "from_path", "path": scene_path})
	var audit_data: Dictionary = bridge.extract_data(audit_result)
	var dep_result: Dictionary = bridge.call_atomic("resource_query", {"action": "get_dependencies", "path": scene_path})
	var dep_data: Dictionary = bridge.extract_data(dep_result)
	var issues: Array = []
	for raw_issue in audit_data.get("issues", []):
		if raw_issue is Dictionary:
			var typed_issue: Dictionary = raw_issue
			bridge.append_unique_issue(issues, typed_issue.duplicate(true))
	var missing_deps: Array = []
	for raw_dep in dep_data.get("dependencies", []):
		var dep_path: String = bridge.normalize_dependency_path(str(raw_dep))
		if dep_path.is_empty():
			continue
		var is_tscn: bool = dep_path.ends_with(".tscn")
		var is_gd: bool = dep_path.ends_with(".gd")
		var is_cs: bool = dep_path.ends_with(".cs")
		if not (is_tscn or is_gd or is_cs):
			continue
		if FileAccess.file_exists(dep_path):
			continue
		missing_deps.append(dep_path)
		var msg: String = "Referenced file not found: %s" % dep_path
		var extra: Dictionary = {"path": dep_path, "scene": scene_path}
		var new_issue: Dictionary = bridge.build_issue("error", "missing_dependency", msg, extra)
		bridge.append_unique_issue(issues, new_issue)
	var is_valid: bool = not bridge.has_severity(issues, "error")
	var out: Dictionary = {"scene": scene_path, "valid": is_valid, "issue_count": issues.size(), "issues": issues, "missing_dependency_count": missing_deps.size(), "missing_dependencies": missing_deps}
	return bridge.success(out)


func _execute_scene_analyze(args: Dictionary) -> Dictionary:
	var scene_path := str(args.get("scene", "")).strip_edges()
	if scene_path.is_empty():
		return bridge.error("scene path is required")
	if not scene_path.ends_with(".tscn"):
		return bridge.error("scene must be a .tscn file")
	if not FileAccess.file_exists(scene_path):
		MCPDebugBuffer.record("warning", "intelligence",
			"scene_analyze: file not found: %s" % scene_path)
		return bridge.error("Scene file not found: %s" % scene_path)
	MCPDebugBuffer.record("debug", "intelligence", "scene_analyze: %s" % scene_path)
	var bindings_result: Dictionary = bridge.call_atomic("scene_bindings", {"action": "from_path", "path": scene_path})
	var bindings_data: Dictionary = bridge.extract_data(bindings_result)
	var audit_result: Dictionary = bridge.call_atomic("scene_audit", {"action": "from_path", "path": scene_path})
	var audit_data: Dictionary = bridge.extract_data(audit_result)
	var hierarchy_result: Dictionary = bridge.call_atomic("scene_hierarchy", {"path": scene_path})
	var hierarchy_data: Dictionary = bridge.extract_data(hierarchy_result)
	var issues: Array = []
	for raw_issue in audit_data.get("issues", []):
		if raw_issue is Dictionary:
			var typed_issue: Dictionary = raw_issue
			bridge.append_unique_issue(issues, typed_issue.duplicate(true))
	for raw_issue in bindings_data.get("issues", []):
		if raw_issue is Dictionary:
			var typed_issue: Dictionary = raw_issue
			bridge.append_unique_issue(issues, typed_issue.duplicate(true))
	var scripts: Array = []
	var sp_raw = bindings_data.get("script_path", "")
	if not str(sp_raw).is_empty():
		var sp: String = str(sp_raw)
		var inspect_result: Dictionary = bridge.call_atomic("script_inspect", {"path": sp})
		var inspect_data: Dictionary = bridge.extract_data(inspect_result)
		var sentry: Dictionary = {"path": sp, "class_name": str(inspect_data.get("class_name", "")), "base_type": str(inspect_data.get("base_type", ""))}
		scripts.append(sentry)
	var binding_count: int = int(bindings_data.get("binding_count", bindings_data.get("count", 0)))
	var node_count: int = int(hierarchy_data.get("node_count", 0))
	var out: Dictionary = {"scene": scene_path, "node_count": node_count, "binding_count": binding_count, "script_count": scripts.size(), "scripts": scripts, "issue_count": issues.size(), "issues": issues}
	return bridge.success(out)


func _execute_scene_patch(args: Dictionary) -> Dictionary:
	var scene_path := str(args.get("scene", "")).strip_edges()
	var ops_raw = args.get("ops", [])
	var dry_run := bool(args.get("dry_run", true))
	if scene_path.is_empty():
		return bridge.error("scene is required")
	if not scene_path.ends_with(".tscn"):
		return bridge.error("scene must be a .tscn file")
	if not FileAccess.file_exists(scene_path):
		MCPDebugBuffer.record("warning", "intelligence",
			"scene_patch: file not found: %s" % scene_path)
		return bridge.error("Scene file not found: %s" % scene_path)
	MCPDebugBuffer.record("debug", "intelligence",
		"scene_patch: %s, dry_run=%s, ops=%d" % [scene_path, str(dry_run), (ops_raw as Array).size() if ops_raw is Array else 0])
	if not (ops_raw is Array) or (ops_raw as Array).is_empty():
		return bridge.error("ops must be a non-empty array")
	var open_result: Dictionary = bridge.call_atomic("scene_management", {"action": "open", "path": scene_path})
	if not bool(open_result.get("success", false)):
		return bridge.error("Failed to open scene: %s" % scene_path)
	var ops: Array = []
	for raw_op in ops_raw:
		if raw_op is Dictionary:
			var typed_op: Dictionary = raw_op
			ops.append(typed_op.duplicate(true))
	var op_previews: Array = []
	for op_item in ops:
		if not (op_item is Dictionary):
			continue
		var typed_op: Dictionary = op_item
		var op_name: String = str(typed_op.get("op", ""))
		op_previews.append({"op": op_name, "valid": not op_name.is_empty()})
	if dry_run:
		var dry_out: Dictionary = {"scene": scene_path, "dry_run": true, "op_count": ops.size(), "op_previews": op_previews}
		return bridge.success(dry_out)
	var applied_ops: Array = []
	var failed_ops: Array = []
	for op_item in ops:
		if not (op_item is Dictionary):
			continue
		var typed_op: Dictionary = op_item
		var op_name: String = str(typed_op.get("op", ""))
		var apply_result: Dictionary = _apply_scene_patch_op(typed_op)
		if bool(apply_result.get("success", false)):
			applied_ops.append({"op": op_name})
		else:
			failed_ops.append({"op": op_name, "error": str(apply_result.get("error", ""))})
	if applied_ops.size() > 0:
		bridge.call_atomic("scene_management", {"action": "save"})
	var out: Dictionary = {"scene": scene_path, "dry_run": false, "applied_count": applied_ops.size(), "failed_count": failed_ops.size(), "applied_ops": applied_ops, "failed_ops": failed_ops}
	return bridge.success(out)
