@tool
extends RefCounted

## System implementation: scene_validate, scene_analyze, scene_tree, scene_patch

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")

var bridge
const HANDLED_TOOLS := ["scene_validate", "scene_analyze", "scene_tree", "scene_patch"]


func handles(tool_name: String) -> bool:
	return tool_name in HANDLED_TOOLS


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "scene_validate",
			"description": "SCENE VALIDATE: Quick integrity check of a .tscn file — structural errors, missing file references, and UID/fallback path consistency hints. Lighter than scene_analyze; use first to confirm a scene is loadable. Returns: valid, issues[]{severity, type, message}, missing_dependencies[], dependency_reference_issues[]. Requires: scene (.tscn path).",
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
			"description": "SCENE ANALYZE: Deep inspection of a .tscn — node count, attached scripts with class_name/base_type, signal bindings, and structural issues. Use after scene_validate passes, or when debugging binding mismatches. Returns: node_count, binding_count, scripts[]{path, class_name, base_type}, issues[]. Requires: scene (.tscn path).",
			"inputSchema": {
				"type": "object",
				"properties": {
					"scene": {"type": "string", "description": "Scene path (res://..., .tscn)"}
				},
				"required": ["scene"]
			}
		},
		{
			"name": "scene_tree",
			"description": "SCENE TREE: High-level edited-scene tree operations. Actions: get_tree, get_selected, select, add_node, remove_node, rename_node, reparent_node, reorder_node, attach_script, set_property, get_property, set_transform. Use this for common Scene dock modifications before falling back to lower-level node tools.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["get_tree", "get_selected", "select", "add_node", "remove_node", "rename_node", "reparent_node", "reorder_node", "attach_script", "set_property", "get_property", "set_transform"], "description": "Scene tree action"},
					"depth": {"type": "integer", "description": "Tree depth for get_tree"},
					"include_internal": {"type": "boolean", "description": "Include internal nodes for get_tree"},
					"paths": {"type": "array", "items": {"type": "string"}, "description": "Node paths for select"},
					"node_path": {"type": "string", "description": "Target node path"},
					"parent_path": {"type": "string", "description": "Parent node path for add_node"},
					"type": {"type": "string", "description": "Node type for add_node"},
					"name": {"type": "string", "description": "Node name for add_node"},
					"new_name": {"type": "string", "description": "New node name"},
					"new_parent": {"type": "string", "description": "New parent node path"},
					"index": {"type": "integer", "description": "Sibling index for reorder_node"},
					"script": {"type": "string", "description": "Script path for attach_script"},
					"property": {"type": "string", "description": "Property name"},
					"value": {},
					"x": {"type": "number"},
					"y": {"type": "number"},
					"z": {"type": "number"},
					"global": {"type": "boolean", "description": "Use global coordinates for set_transform"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "scene_patch",
			"description": "SCENE PATCH: Apply structured edits to a .tscn file. Ops: add_node, remove_node, set_property, attach_script, reparent_node, rename_node, update_property. dry_run=true (default) previews without saving — always confirm first. Returns: op_previews[]{op, valid} (dry_run), applied_ops[], failed_ops[] (applied). Note: update_property verifies the property exists before writing (use set_property to force-write). Requires: scene and ops[].",
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
								"op": {"type": "string", "enum": ["add_node", "remove_node", "set_property", "attach_script", "reparent_node", "rename_node", "update_property"]},
								"name": {"type": "string"},
								"type": {"type": "string"},
								"parent_path": {"type": "string"},
								"node_path": {"type": "string"},
								"property": {"type": "string"},
								"value": {},
								"script": {"type": "string"},
								"new_parent": {"type": "string"},
								"new_name": {"type": "string", "description": "New name (used by rename_node)"}
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
	MCPDebugBuffer.record("debug", "system", "tool: %s" % tool_name)
	match tool_name:
		"scene_validate": return _execute_scene_validate(args)
		"scene_analyze":  return _execute_scene_analyze(args)
		"scene_tree":     return _execute_scene_tree(args)
		"scene_patch":    return _execute_scene_patch(args)
		_: return bridge.error("Unknown tool: %s" % tool_name)


# --- private helpers ---

func _apply_scene_patch_op(op: Dictionary) -> Dictionary:
	var op_name := str(op.get("op", ""))
	match op_name:
		"add_node":
			return bridge.call_atomic("node_lifecycle", {"action": "create", "parent_path": str(op.get("parent_path", ".")), "type": str(op.get("type", "Node")), "name": str(op.get("name", ""))})
		"remove_node":
			return bridge.call_atomic("node_lifecycle", {"action": "delete", "path": str(op.get("node_path", ""))})
		"set_property":
			var set_args: Dictionary = {"action": "set", "path": str(op.get("node_path", "")), "property": str(op.get("property", "")), "value": op.get("value", null)}
			return bridge.call_atomic("node_property", set_args)
		"attach_script":
			return bridge.call_atomic("node_lifecycle", {"action": "attach_script", "node_path": str(op.get("node_path", "")), "script_path": str(op.get("script", ""))})
		"reparent_node":
			return bridge.call_atomic("node_hierarchy", {"action": "reparent", "path": str(op.get("node_path", "")), "new_parent": str(op.get("new_parent", ""))})
		"rename_node":
			return bridge.call_atomic("node_lifecycle", {"action": "rename", "node_path": str(op.get("node_path", "")), "new_name": str(op.get("new_name", ""))})
		"update_property":
			var prop := str(op.get("property", ""))
			var node_path := str(op.get("node_path", ""))
			var read_result: Dictionary = bridge.call_atomic("node_property", {"action": "get", "path": node_path, "property": prop})
			if not bool(read_result.get("success", false)):
				return bridge.error("Property '%s' does not exist on node '%s'" % [prop, node_path])
			return bridge.call_atomic("node_property", {"action": "set", "path": node_path, "property": prop, "value": op.get("value", null)})
		_:
			return bridge.error("Unknown scene patch op: %s" % op_name)


func _execute_scene_tree(args: Dictionary) -> Dictionary:
	var action := str(args.get("action", "")).strip_edges()
	match action:
		"get_tree":
			return bridge.call_atomic("scene_hierarchy", {
				"action": "get_tree",
				"depth": int(args.get("depth", -1)),
				"include_internal": bool(args.get("include_internal", false))
			})
		"get_selected":
			return bridge.call_atomic("scene_hierarchy", {"action": "get_selected"})
		"select":
			return bridge.call_atomic("scene_hierarchy", {"action": "select", "paths": args.get("paths", [])})
		"add_node":
			return bridge.call_atomic("node_lifecycle", {
				"action": "create",
				"parent_path": str(args.get("parent_path", "")),
				"type": str(args.get("type", "Node")),
				"name": str(args.get("name", ""))
			})
		"remove_node":
			return bridge.call_atomic("node_lifecycle", {"action": "delete", "path": str(args.get("node_path", ""))})
		"rename_node":
			return bridge.call_atomic("node_lifecycle", {
				"action": "rename",
				"node_path": str(args.get("node_path", "")),
				"new_name": str(args.get("new_name", ""))
			})
		"reparent_node":
			return bridge.call_atomic("node_hierarchy", {
				"action": "reparent",
				"path": str(args.get("node_path", "")),
				"new_parent": str(args.get("new_parent", ""))
			})
		"reorder_node":
			return bridge.call_atomic("node_hierarchy", {
				"action": "reorder",
				"path": str(args.get("node_path", "")),
				"index": int(args.get("index", 0))
			})
		"attach_script":
			return bridge.call_atomic("node_lifecycle", {
				"action": "attach_script",
				"node_path": str(args.get("node_path", "")),
				"script_path": str(args.get("script", ""))
			})
		"set_property":
			return bridge.call_atomic("node_property", {
				"action": "set",
				"path": str(args.get("node_path", "")),
				"property": str(args.get("property", "")),
				"value": args.get("value", null)
			})
		"get_property":
			return bridge.call_atomic("node_property", {
				"action": "get",
				"path": str(args.get("node_path", "")),
				"property": str(args.get("property", ""))
			})
		"set_transform":
			return bridge.call_atomic("node_transform", {
				"action": "set_position",
				"path": str(args.get("node_path", "")),
				"x": args.get("x", 0.0),
				"y": args.get("y", 0.0),
				"z": args.get("z", 0.0),
				"global": bool(args.get("global", false))
			})
		_:
			return bridge.error("Unknown scene_tree action: %s" % action)


# --- tool implementations ---

func _execute_scene_validate(args: Dictionary) -> Dictionary:
	var scene_path := str(args.get("scene", "")).strip_edges()
	if scene_path.is_empty():
		return bridge.error("scene path is required")
	if not scene_path.ends_with(".tscn"):
		return bridge.error("scene must be a .tscn file")
	if not FileAccess.file_exists(scene_path):
		MCPDebugBuffer.record("warning", "system",
			"scene_validate: file not found: %s" % scene_path)
		return bridge.error("Scene file not found: %s" % scene_path)
	MCPDebugBuffer.record("debug", "system", "scene_validate: %s" % scene_path)
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
	var dependency_reference_issues: Array = []
	for raw_dep in dep_data.get("dependencies", []):
		var dep_ref: Dictionary = bridge.parse_dependency_reference(str(raw_dep), scene_path) if bridge.has_method("parse_dependency_reference") else {"normalized_path": bridge.normalize_dependency_path(str(raw_dep)), "risk": "none"}
		var dep_path: String = str(dep_ref.get("normalized_path", ""))
		if dep_path.is_empty():
			continue
		var ref_risk := str(dep_ref.get("risk", "none"))
		if ref_risk == "warning" or ref_risk == "error":
			var ref_issue_type := str(dep_ref.get("consistency", "dependency_reference_inconsistent"))
			var ref_message := _build_dependency_reference_message(dep_ref)
			var ref_issue: Dictionary = bridge.build_issue(ref_risk, ref_issue_type, ref_message, {
				"scene": scene_path,
				"raw": str(dep_ref.get("raw", str(raw_dep))),
				"uid": str(dep_ref.get("uid", "")),
				"path": dep_path,
				"declared_path": str(dep_ref.get("declared_path", "")),
				"resolved_uid_path": str(dep_ref.get("resolved_uid_path", "")),
				"hint": str(dep_ref.get("hint", "")),
				"build_status": "build_may_pass"
			})
			dependency_reference_issues.append(ref_issue.duplicate(true))
			bridge.append_unique_issue(issues, ref_issue)
		var is_tscn: bool = dep_path.ends_with(".tscn")
		var is_gd: bool = dep_path.ends_with(".gd")
		var is_cs: bool = dep_path.ends_with(".cs")
		if not (is_tscn or is_gd or is_cs):
			continue
		if FileAccess.file_exists(dep_path):
			continue
		missing_deps.append(dep_path)
		var msg: String = "Referenced file not found: %s" % dep_path
		var extra: Dictionary = {"path": dep_path, "scene": scene_path, "build_status": "build_may_pass"}
		if str(dep_ref.get("uid", "")).begins_with("uid://"):
			msg = "Referenced file not found: %s. This dependency came from a UID/fallback path reference; the UID cache or fallback path may be stale." % dep_path
			extra["uid"] = str(dep_ref.get("uid", ""))
			extra["declared_path"] = str(dep_ref.get("declared_path", ""))
			extra["resolved_uid_path"] = str(dep_ref.get("resolved_uid_path", ""))
			extra["hint"] = "Reimport, fix the resource path, or re-save the scene/resource to normalize UID references."
		var new_issue: Dictionary = bridge.build_issue("error", "missing_dependency", msg, extra)
		bridge.append_unique_issue(issues, new_issue)
	var is_valid: bool = not bridge.has_severity(issues, "error")
	var out: Dictionary = {"scene": scene_path, "valid": is_valid, "issue_count": issues.size(), "issues": issues, "missing_dependency_count": missing_deps.size(), "missing_dependencies": missing_deps, "dependency_reference_issue_count": dependency_reference_issues.size(), "dependency_reference_issues": dependency_reference_issues}
	return bridge.success(out)


func _build_dependency_reference_message(dep_ref: Dictionary) -> String:
	var consistency := str(dep_ref.get("consistency", "dependency_reference_inconsistent"))
	var uid := str(dep_ref.get("uid", ""))
	var declared_path := str(dep_ref.get("declared_path", ""))
	var resolved_uid_path := str(dep_ref.get("resolved_uid_path", ""))
	match consistency:
		"stale_fallback_path":
			return "UID %s resolves to %s, but the fallback path is stale: %s." % [uid, resolved_uid_path, declared_path]
		"stale_uid":
			return "Fallback path exists but UID is stale or unknown: %s -> %s." % [uid, declared_path]
		"uid_path_mismatch":
			return "UID %s resolves to %s, which differs from fallback path %s." % [uid, resolved_uid_path, declared_path]
		"missing_uid_and_path":
			return "Neither UID nor fallback path can be resolved: %s -> %s." % [uid, declared_path]
		"missing_path":
			return "Referenced path does not exist: %s." % declared_path
		_:
			return "Dependency reference may be inconsistent: %s." % str(dep_ref.get("raw", ""))


func _execute_scene_analyze(args: Dictionary) -> Dictionary:
	var scene_path := str(args.get("scene", "")).strip_edges()
	if scene_path.is_empty():
		return bridge.error("scene path is required")
	if not scene_path.ends_with(".tscn"):
		return bridge.error("scene must be a .tscn file")
	if not FileAccess.file_exists(scene_path):
		MCPDebugBuffer.record("warning", "system",
			"scene_analyze: file not found: %s" % scene_path)
		return bridge.error("Scene file not found: %s" % scene_path)
	MCPDebugBuffer.record("debug", "system", "scene_analyze: %s" % scene_path)
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
		MCPDebugBuffer.record("warning", "system",
			"scene_patch: file not found: %s" % scene_path)
		return bridge.error("Scene file not found: %s" % scene_path)
	MCPDebugBuffer.record("debug", "system",
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
