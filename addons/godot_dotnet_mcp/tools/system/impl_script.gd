@tool
extends RefCounted

## System implementation: bindings_audit, script_analyze, script_patch

const GDScriptLspDiagnosticsService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/gdscript_lsp_diagnostics_service.gd")
const GDScriptLspDiagnosticsServicePath = "res://addons/godot_dotnet_mcp/plugin/runtime/gdscript_lsp_diagnostics_service.gd"

var bridge
var _tool_loader_context

const HANDLED_TOOLS := ["bindings_audit", "script_analyze", "script_patch"]


func handles(tool_name: String) -> bool:
	return tool_name in HANDLED_TOOLS


func configure_runtime(_context: Dictionary) -> void:
	_tool_loader_context = _context.get("tool_loader", null)
	MCPDebugBuffer.record("info", "system",
		"impl_script configure_runtime tool_loader=%s" % str(_tool_loader_context != null))


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "bindings_audit",
			"description": "BINDINGS AUDIT: Audit C# [Export]/[Signal]/NodePath binding consistency against scene references. C# only (.cs). Provide script to audit one file, scene to audit its scripts, or omit both to scan all .cs in project. Returns: total_issues, results[]{kind, issues[]{severity, type, message}}. Use when runtime_diagnose shows C# binding errors.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"script": {"type": "string", "description": "C# script path (optional)"},
					"scene": {"type": "string", "description": "Scene path (optional)"},
					"include_warnings": {"type": "boolean", "description": "Include warnings (default: true)"}
				}
			}
		},
		{
			"name": "script_analyze",
			"description": "SCRIPT ANALYZE: Inspect a .gd or .cs script — class structure, methods, exports, signals, variables, and scene references. Returns: class_name, base_type, methods[], exports[], signals[], variables[], scene_refs[], issues[]. For .gd files: include_diagnostics=true adds background diagnostics{available, pending, parse_errors[]{severity, message, line, column}, error_count} via Godot LSP using the saved file content on disk. The first call may return pending while LSP work finishes in the background. Unsaved editor buffer changes are not included. Requires: script path.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"script": {"type": "string", "description": "Script path (res://..., .gd or .cs)"},
					"include_diagnostics": {"type": "boolean", "description": "Include GDScript static diagnostics via Godot LSP (default: false, .gd only)"}
				},
				"required": ["script"]
			}
		},
		{
			"name": "script_patch",
			"description": "SCRIPT PATCH: Add or edit members in a .gd or .cs script. Add ops: add_method, add_export, add_variable (both); add_signal (.gd only). Edit ops: replace_method_body (replace function body, keep signature), delete_member (remove declaration; member_type: function/variable/signal/auto), rename_member (rename declaration only, not references; new_name required). dry_run=true (default) previews — check op_previews[]{op, valid, name} before applying. Returns: applied_ops[], failed_ops[]{op, error} when dry_run=false. Requires: script and ops[].",
			"inputSchema": {
				"type": "object",
				"properties": {
					"script": {"type": "string", "description": "Script path (res://...)"},
					"ops": {
						"type": "array",
						"description": "List of patch operations",
						"items": {
							"type": "object",
							"properties": {
								"op": {"type": "string", "enum": ["add_method", "add_export", "add_signal", "add_variable", "replace_method_body", "delete_member", "rename_member"]},
								"name": {"type": "string", "description": "Member name (old name for rename_member)"},
								"type": {"type": "string", "description": "Type annotation"},
								"default_value": {"type": "string", "description": "Default value expression"},
								"body": {"type": "string", "description": "Method body (for add_method / replace_method_body)"},
								"params": {"type": "array", "description": "Parameters for add_method/add_signal"},
								"hint": {"type": "string", "description": "Export hint for add_export"},
								"onready": {"type": "boolean", "description": "Add @onready for add_variable"},
								"member_type": {"type": "string", "description": "Member type for delete_member: function, variable, signal, auto (default: auto)"},
								"new_name": {"type": "string", "description": "New name for rename_member"}
							},
							"required": ["op", "name"]
						}
					},
					"dry_run": {"type": "boolean", "description": "Preview without executing (default: true)"}
				},
				"required": ["script", "ops"]
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	MCPDebugBuffer.record("debug", "system", "tool: %s" % tool_name)
	match tool_name:
		"bindings_audit": return _execute_bindings_audit(args)
		"script_analyze": return _execute_script_analyze(args)
		"script_patch":   return _execute_script_patch(args)
		_: return bridge.error("Unknown tool: %s" % tool_name)


func tick(delta: float) -> void:
	MCPDebugBuffer.record("info", "system", "executor tick loader=%s" % str(_tool_loader_context != null))


# --- private helpers ---

func _audit_scene(scene_path: String, include_warnings: bool) -> Dictionary:
	var bindings_data: Dictionary = bridge.extract_data(bridge.call_atomic("scene_bindings", {
		"action": "from_path", "path": scene_path
	}))
	var audit_data: Dictionary = bridge.extract_data(bridge.call_atomic("scene_audit", {
		"action": "from_path", "path": scene_path
	}))
	var issues: Array = []
	for issue in audit_data.get("issues", []):
		if issue is Dictionary:
			bridge.append_unique_issue(issues, (issue as Dictionary).duplicate(true))
	for issue in bindings_data.get("issues", []):
		if issue is Dictionary:
			bridge.append_unique_issue(issues, (issue as Dictionary).duplicate(true))
	if include_warnings and issues.is_empty():
		bridge.append_unique_issue(issues, bridge.build_issue("info", "scene_clean",
			"Scene bindings and audit checks returned no issues.", {"scene": scene_path}))
	return {
		"kind": "scene", "scene": scene_path,
		"binding_count": int(bindings_data.get("binding_count", bindings_data.get("count", 0))),
		"issue_count": issues.size(), "issues": issues
	}


func _audit_script(script_path: String, include_warnings: bool) -> Dictionary:
	var inspect_data: Dictionary = bridge.extract_data(bridge.call_atomic("script_inspect", {"path": script_path}))
	var references_data: Dictionary = bridge.extract_data(bridge.call_atomic("script_references", {
		"action": "get_scene_refs", "path": script_path
	}))
	var base_type_data: Dictionary = bridge.extract_data(bridge.call_atomic("script_references", {
		"action": "get_base_type", "path": script_path
	}))

	var issues: Array = []
	var scenes: Array = []
	for sp in references_data.get("scenes", []):
		scenes.append(str(sp))

	if scenes.is_empty():
		bridge.append_unique_issue(issues, bridge.build_issue(
			"warning" if include_warnings else "info", "no_scene_reference",
			"Script is not referenced by any discovered scene.", {"script": script_path}))

	var exports = inspect_data.get("exports", [])
	if include_warnings and exports is Array and (exports as Array).is_empty():
		bridge.append_unique_issue(issues, bridge.build_issue("info", "no_exports",
			"Script declares no exported members.", {"script": script_path}))

	var signals_list = inspect_data.get("signals", [])
	if include_warnings and signals_list is Array and (signals_list as Array).is_empty():
		bridge.append_unique_issue(issues, bridge.build_issue("info", "no_signals",
			"Script declares no signals.", {"script": script_path}))

	for sp in scenes:
		var scene_audit := _audit_scene(sp, include_warnings)
		for issue in scene_audit.get("issues", []):
			if not (issue is Dictionary):
				continue
			var scene_issue: Dictionary = (issue as Dictionary).duplicate(true)
			scene_issue["script"] = script_path
			bridge.append_unique_issue(issues, scene_issue)

	return {
		"kind": "script", "script": script_path,
		"class_name": str(inspect_data.get("class_name", "")),
		"base_type": str(base_type_data.get("base_type", inspect_data.get("base_type", ""))),
		"language": str(inspect_data.get("language", "")),
		"scene_count": scenes.size(), "scenes": scenes,
		"issue_count": issues.size(), "issues": issues
	}


func _apply_patch_op(op: Dictionary, script_path: String, atomic_tool: String, is_gd: bool) -> Dictionary:
	var op_name := str(op.get("op", ""))
	var member_name := str(op.get("name", ""))
	match op_name:
		"add_method":
			if is_gd:
				return bridge.call_atomic(atomic_tool, {
					"action": "add_function",
					"path": script_path,
					"name": member_name,
					"params": op.get("params", []),
					"body": str(op.get("body", "\tpass"))
				})
			else:
				return bridge.call_atomic(atomic_tool, {
					"action": "add_method",
					"path": script_path,
					"name": member_name,
					"params": op.get("params", []),
					"return_type": str(op.get("type", "void")),
					"body": str(op.get("body", ""))
				})
		"add_export":
			if is_gd:
				return bridge.call_atomic(atomic_tool, {
					"action": "add_export",
					"path": script_path,
					"name": member_name,
					"type": str(op.get("type", "Variant")),
					"default_value": str(op.get("default_value", "")),
					"hint": str(op.get("hint", ""))
				})
			else:
				return bridge.call_atomic(atomic_tool, {
					"action": "add_field",
					"path": script_path,
					"name": member_name,
					"type": str(op.get("type", "Variant")),
					"export": true
				})
		"add_signal":
			if is_gd:
				return bridge.call_atomic(atomic_tool, {
					"action": "add_signal",
					"path": script_path,
					"name": member_name,
					"params": op.get("params", [])
				})
			else:
				return bridge.error("add_signal is not supported for C# scripts via script_patch")
		"add_variable":
			if is_gd:
				var var_args: Dictionary = {
					"action": "add_variable",
					"path": script_path,
					"name": member_name,
					"type": str(op.get("type", ""))
				}
				if bool(op.get("onready", false)):
					var_args["onready"] = true
				if not str(op.get("default_value", "")).is_empty():
					var_args["default_value"] = str(op.get("default_value", ""))
				return bridge.call_atomic(atomic_tool, var_args)
			else:
				return bridge.call_atomic(atomic_tool, {
					"action": "add_field",
					"path": script_path,
					"name": member_name,
					"type": str(op.get("type", "Variant")),
					"export": false
				})
		"replace_method_body":
			if is_gd:
				return bridge.call_atomic(atomic_tool, {
					"action": "replace_function_body",
					"path": script_path,
					"name": member_name,
					"body": str(op.get("body", ""))
				})
			else:
				return bridge.call_atomic(atomic_tool, {
					"action": "replace_method_body",
					"path": script_path,
					"name": member_name,
					"body": str(op.get("body", ""))
				})
		"delete_member":
			if is_gd:
				return bridge.call_atomic(atomic_tool, {
					"action": "remove_member",
					"path": script_path,
					"name": member_name,
					"member_type": str(op.get("member_type", "auto"))
				})
			else:
				return bridge.call_atomic(atomic_tool, {
					"action": "delete_member",
					"path": script_path,
					"name": member_name,
					"member_type": str(op.get("member_type", "auto"))
				})
		"rename_member":
			return bridge.call_atomic(atomic_tool, {
				"action": "rename_member",
				"path": script_path,
				"name": member_name,
				"new_name": str(op.get("new_name", ""))
			})
		_:
			return bridge.error("Unknown script patch op: %s" % op_name)


# --- tool implementations ---

func _execute_bindings_audit(args: Dictionary) -> Dictionary:
	var target_script := str(args.get("script", "")).strip_edges()
	var target_scene := str(args.get("scene", "")).strip_edges()
	var include_warnings := bool(args.get("include_warnings", true))
	var results: Array = []

	if not target_script.is_empty():
		if not target_script.ends_with(".cs"):
			return bridge.error("bindings_audit only supports C# scripts (.cs)")
		MCPDebugBuffer.record("debug", "system",
			"bindings_audit: script=%s" % target_script)
		results.append(_audit_script(target_script, include_warnings))
	elif not target_scene.is_empty():
		if not target_scene.ends_with(".tscn"):
			return bridge.error("scene must be a .tscn file")
		MCPDebugBuffer.record("debug", "system",
			"bindings_audit: scene=%s" % target_scene)
		results.append(_audit_scene(target_scene, include_warnings))
	else:
		var cs_scripts: Array = bridge.collect_files("*.cs")
		MCPDebugBuffer.record("debug", "system",
			"bindings_audit: scanning %d C# scripts" % cs_scripts.size())
		for sp in cs_scripts:
			results.append(_audit_script(str(sp), include_warnings))

	var total_issues := 0
	var targets_with_issues := 0
	for result in results:
		if not (result is Dictionary):
			continue
		var issue_count := int((result as Dictionary).get("issue_count", 0))
		total_issues += issue_count
		if issue_count > 0:
			targets_with_issues += 1

	return bridge.success({
		"script": target_script, "scene": target_scene,
		"target_count": results.size(), "targets_with_issues": targets_with_issues,
		"total_issues": total_issues, "results": results
	})


func _execute_script_analyze(args: Dictionary) -> Dictionary:
	var script_path := str(args.get("script", "")).strip_edges()
	var include_diagnostics := bool(args.get("include_diagnostics", false))
	if script_path.is_empty():
		return bridge.error("script path is required")
	if not (script_path.ends_with(".gd") or script_path.ends_with(".cs")):
		return bridge.error("script must be a .gd or .cs file")
	if not FileAccess.file_exists(script_path):
		MCPDebugBuffer.record("warning", "system",
			"script_analyze: file not found: %s" % script_path)
		return bridge.error("Script file not found: %s" % script_path)
	MCPDebugBuffer.record("debug", "system", "script_analyze: %s" % script_path)

	var inspect_data: Dictionary = bridge.extract_data(bridge.call_atomic("script_inspect", {"path": script_path}))
	var symbols_data: Dictionary = bridge.extract_data(bridge.call_atomic("script_symbols", {"path": script_path}))
	var exports_data: Dictionary = bridge.extract_data(bridge.call_atomic("script_exports", {"path": script_path}))
	var refs_data: Dictionary = bridge.extract_data(bridge.call_atomic("script_references", {
		"action": "get_scene_refs", "path": script_path
	}))
	var base_type_data: Dictionary = bridge.extract_data(bridge.call_atomic("script_references", {
		"action": "get_base_type", "path": script_path
	}))

	var methods: Array = []
	var variables: Array = []
	var constants: Array = []
	var signals: Array = []
	for sym in symbols_data.get("symbols", []):
		if not (sym is Dictionary):
			continue
		var kind := str((sym as Dictionary).get("kind", ""))
		match kind:
			"method", "function":
				methods.append((sym as Dictionary).duplicate(true))
			"variable", "member":
				variables.append((sym as Dictionary).duplicate(true))
			"constant":
				constants.append((sym as Dictionary).duplicate(true))
			"signal":
				signals.append((sym as Dictionary).duplicate(true))

	var scene_refs: Array = []
	for sp in refs_data.get("scenes", []):
		scene_refs.append(str(sp))

	var issues: Array = []
	if scene_refs.is_empty():
		issues.append(bridge.build_issue("info", "no_scene_reference",
			"Script is not referenced by any discovered scene.", {"script": script_path}))

	var result_data: Dictionary = {
		"script": script_path,
		"language": str(inspect_data.get("language", "unknown")),
		"class_name": str(inspect_data.get("class_name", "")),
		"base_type": str(base_type_data.get("base_type", inspect_data.get("base_type", ""))),
		"namespace": str(inspect_data.get("namespace", "")),
		"method_count": methods.size(),
		"export_count": exports_data.get("count", (exports_data.get("exports", []) as Array).size()),
		"signal_count": signals.size(),
		"variable_count": variables.size(),
		"scene_ref_count": scene_refs.size(),
		"methods": methods,
		"exports": exports_data.get("exports", []),
		"signals": signals,
		"variables": variables,
		"scene_refs": scene_refs,
		"issue_count": issues.size(),
		"issues": issues
	}

	if include_diagnostics and script_path.ends_with(".gd"):
		MCPDebugBuffer.record("info", "system",
			"script_analyze diagnostics branch entered: %s" % script_path)
		var diagnostics_source := FileAccess.get_file_as_string(script_path)
		var diagnostics_service = _get_gdscript_lsp_diagnostics_service()
		MCPDebugBuffer.record("info", "system",
			"script_analyze diagnostics loader=%s service=%s" % [
				str(bridge != null and bridge.has_method("get_tool_loader") and bridge.get_tool_loader() != null),
				str(diagnostics_service != null)
			])
		var diagnostics_result: Dictionary = {}
		if diagnostics_service != null and diagnostics_service.has_method("request_diagnostics"):
			var diagnostics_result_raw = diagnostics_service.request_diagnostics(
				script_path,
				diagnostics_source
			)
			if diagnostics_result_raw is Dictionary:
				diagnostics_result = (diagnostics_result_raw as Dictionary).duplicate(true)
		if diagnostics_result.is_empty():
			diagnostics_result = {
				"available": false,
				"pending": true,
				"finished": false,
				"state": "queued",
				"script": script_path,
				"source_hash": str(diagnostics_source.hash()),
				"parse_errors": [],
				"error_count": 0,
				"warning_count": 0,
				"note": "Diagnostics are being resolved in the background from saved file content on disk."
			}
		MCPDebugBuffer.record("info", "system",
			"script_analyze diagnostics state=%s pending=%s available=%s" % [
				str(diagnostics_result.get("state", "unknown")),
				str(bool(diagnostics_result.get("pending", false))),
				str(bool(diagnostics_result.get("available", false)))
			])
		result_data["diagnostics"] = diagnostics_result
		result_data["diagnostics_status"] = _build_diagnostics_status_summary(diagnostics_result)
		return bridge.success(result_data)

	return bridge.success(result_data)


func _execute_script_patch(args: Dictionary) -> Dictionary:
	var script_path := str(args.get("script", "")).strip_edges()
	var ops_raw = args.get("ops", [])
	var dry_run := bool(args.get("dry_run", true))

	if script_path.is_empty():
		return bridge.error("script is required")
	if not (script_path.ends_with(".gd") or script_path.ends_with(".cs")):
		return bridge.error("script must be a .gd or .cs file")
	if not FileAccess.file_exists(script_path):
		MCPDebugBuffer.record("warning", "system",
			"script_patch: file not found: %s" % script_path)
		return bridge.error("Script file not found: %s" % script_path)
	MCPDebugBuffer.record("debug", "system",
		"script_patch: %s, dry_run=%s, ops=%d" % [script_path, str(dry_run), (ops_raw as Array).size() if ops_raw is Array else 0])
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
		op_previews.append({"op": op_name, "valid": true, "name": member_name,
			"description": "Add %s '%s' to %s" % [op_name.replace("add_", ""), member_name, script_path.get_file()]})

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


func _get_gdscript_lsp_diagnostics_service():
	if bridge != null and bridge.has_method("get_tool_loader"):
		var loader = bridge.get_tool_loader()
		if loader != null and loader.has_method("get_gdscript_lsp_diagnostics_service"):
			var loader_service = loader.get_gdscript_lsp_diagnostics_service()
			if loader_service != null:
				return loader_service
	if bridge != null and bridge.has_method("get_gdscript_lsp_diagnostics_service"):
		var service = bridge.get_gdscript_lsp_diagnostics_service()
		if service != null:
			return service
	if _tool_loader_context != null and _tool_loader_context.has_method("get_gdscript_lsp_diagnostics_service"):
		return _tool_loader_context.get_gdscript_lsp_diagnostics_service()
	return GDScriptLspDiagnosticsService.get_singleton()


func _build_diagnostics_status_summary(diagnostics_result: Dictionary) -> Dictionary:
	return {
		"source": "godot_lsp",
		"available": bool(diagnostics_result.get("available", false)),
		"pending": bool(diagnostics_result.get("pending", false)),
		"finished": bool(diagnostics_result.get("finished", false)),
		"phase": str(diagnostics_result.get("phase", diagnostics_result.get("state", "unknown")))
	}
