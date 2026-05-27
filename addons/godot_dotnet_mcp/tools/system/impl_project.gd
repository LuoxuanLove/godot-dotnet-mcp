@tool
extends RefCounted

## System implementation: project_state, editor_state, plugin_reload, plugin_update,
## project_configure, userdata_maintenance, project_files, project_run,
## project_stop, runtime_diagnose

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")
const PluginInstanceFreshness = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_instance_freshness.gd")
const MCPUserDataPaths = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_user_data_paths.gd")
const MCPEditorSessionIdentity = preload("res://addons/godot_dotnet_mcp/plugin/runtime/editor_session_identity.gd")

var bridge
var _runtime_context: Dictionary = {}

const _PROJECT_FILE_SCAN_ROOT := "res://"
const _RESOURCE_AUDIT_SCAN_GLOBS: Array[String] = ["*.tscn", "*.tres"]
const _PROJECT_STATE_SCAN_GLOBS: Array[String] = ["*.gd", "*.cs", "*.tscn", "*.tres", "*.res"]
const _SCAN_RECOVERY_SUGGESTIONS: Array[String] = [
	"Call system_project_files(action=scan) to refresh the Godot FileSystem.",
	"Reload the MCP plugin and retry the project-level scan.",
	"Verify the project path and scan glob match the expected resources.",
	"Retry resource_reference_audit with an explicit .tscn or .tres path."
]
const _RUN_LOG_MARKER_DEFAULT_TIMEOUT_MS := 10000
const _RUN_LOG_MARKER_MAX_TIMEOUT_MS := 300000
const _RUN_LOG_MARKER_DEFAULT_POLL_INTERVAL_MS := 100
const _RUN_LOG_MARKER_MIN_POLL_INTERVAL_MS := 50
const _RUN_LOG_MARKER_MAX_POLL_INTERVAL_MS := 5000
const _RUN_LOG_MARKER_DEFAULT_LOG_TAIL := 100
const _RUN_LOG_MARKER_MAX_LOG_TAIL := 500
const _RUN_LOG_MARKER_MAX_COUNT := 32
const _RUN_LOG_MARKER_MAX_LENGTH := 256
var _project_run_timeout_token := 0

const HANDLED_TOOLS := [
	"project_state", "editor_state", "project_configure",
	"project_files", "project_run", "project_stop", "runtime_diagnose", "userdata_maintenance", "plugin_reload", "plugin_update", "resource_reference_audit"
]


func configure_runtime(context: Dictionary) -> void:
	_runtime_context = context.duplicate(true)


func handles(tool_name: String) -> bool:
	return tool_name in HANDLED_TOOLS


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "project_state",
			"description": "PROJECT STATE: Snapshot of current project health — file counts, runtime errors, compile errors, bridge status, runtime capability bits, and file enumeration validity. Use first to orient before diagnosing. For large projects, pass summary=true for a compact payload or sections=[summary, project, files, runtime, capabilities, health] to read only selected sections. Default behavior returns the full flat payload. Returns: error_count, compile_error_count, recent_errors[], has_dotnet, running, runtime_bridge_status, runtime_capabilities{can_start_project, can_control_runtime, can_capture_runtime, headless_logic_ok, visible_capture_required, can_run_without_focus, no_focus_launch_supported, foreground_window_policy, foreground_window_fallbacks[], blocking_reasons[]}, scene_paths[], script_paths[], file_enumeration_status, valid_file_enumeration, file_enumeration, enumeration_diagnostics[]. Optional: error_limit (default 10).",
			"inputSchema": {
				"type": "object",
				"properties": {
					"error_limit": {
						"type": "integer",
						"description": "Max errors to include (default: 10)"
					},
					"include_runtime_health": {
						"type": "boolean",
						"description": "Include lightweight plugin runtime health summary, including self_diagnostics, lsp_diagnostics, and tool_loader health (default: false)"
					},
					"summary": {
						"type": "boolean",
						"description": "Return a compact project state summary with key counts, statuses, runtime capabilities, and available section keys instead of the full payload (default: false)"
					},
					"sections": {
						"type": "array",
						"items": {"type": "string", "enum": ["summary", "project", "files", "runtime", "capabilities", "health"]},
						"description": "Optional section keys to return instead of the full payload. Use summary first, then request project/files/runtime/capabilities/health as needed. The health section is included when requested even if include_runtime_health is false."
					}
				}
			}
		},
		{
			"name": "resource_reference_audit",
			"description": "RESOURCE REFERENCE AUDIT: Project-level scan for .tscn/.tres UID + fallback path consistency and C# [GlobalClass] Resource script references. Reports stale UID/cache/path issues separately from C# build errors so agents can fix scenes/resources even when dotnet build passes. Empty project-level scans are reported with scan_status=invalid_scan_scope, valid_scan_scope=false, and enumeration_diagnostics instead of being treated as clean. Optional path limits the audit to one .tscn/.tres file; include_warnings defaults to true.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Optional .tscn/.tres path to audit; omit to scan the project"},
					"include_warnings": {"type": "boolean", "description": "Include warning-level stale UID/path and C# resource script risks (default: true)"}
				}
			}
		},
		{
			"name": "editor_state",
			"description": "EDITOR STATE: Unified read-only editor session snapshot. Aggregates current editor UI state, Inspector summary, FileSystem selection, project runtime summary, runtime control status, and runtime_capabilities into one payload for agent orientation.",
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		},
		{
			"name": "plugin_reload",
			"description": "PLUGIN RELOAD: Stable Agent-callable plugin lifecycle reload entry and freshness check. action=get_freshness reports running instance vs disk state; action=full_reload_plugin schedules a Godot plugin disable/enable lifecycle reload without relying on MCPDock visibility. The MCP transport may disconnect during reload; reconnect and fetch tools again.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["get_freshness", "full_reload_plugin"], "description": "Plugin reload action"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "plugin_update",
			"description": "PLUGIN UPDATE: Inspect the local plugin version/fingerprint and coordinate the built-in async update sync flow. Actions: get_current reads local version/hash-like metadata and lifecycle reload state; get_status reports selected source, discovered refs, compare, sync and reload progress; set_source selects latest_stable, latest_release or custom_branch; discover_refs starts async ref discovery; start_sync starts async archive sync and lifecycle reload scheduling. Network/archive work is asynchronous and returns accepted/loading/status immediately.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["get_current", "get_status", "set_source", "discover_refs", "start_sync"], "description": "Plugin update action"},
					"source": {"type": "string", "enum": ["latest_stable", "latest_release", "custom_branch", "latest_dev", "branch", "release_tag"], "description": "Update source for set_source"},
					"custom_branch": {"type": "string", "description": "Branch name used when source is custom_branch"},
					"release_tag": {"type": "string", "description": "Optional release/tag selector saved with latest_release source"},
					"force_refresh": {"type": "boolean", "description": "Force ref discovery refresh for discover_refs (default: true)"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "project_configure",
			"description": "PROJECT CONFIGURE: Read or modify project settings, autoloads, and input actions. Read actions: get_settings (requires: setting), list_autoloads, list_input_actions. Write actions: set_setting (requires: setting, value), add_autoload (requires: name, path), remove_autoload (requires: name). Call get_settings to inspect a path before modifying.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["get_settings", "set_setting", "list_autoloads", "add_autoload", "remove_autoload", "list_input_actions"],
						"description": "Configuration action to perform"
					},
					"setting": {"type": "string", "description": "Setting path for get_settings/set_setting"},
					"value": {"description": "New value for set_setting"},
					"name": {"type": "string", "description": "Autoload name for add/remove_autoload"},
					"path": {"type": "string", "description": "Script path for add_autoload"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "userdata_maintenance",
			"description": "USERDATA MAINTENANCE: Manually inspect or clean Godot MCP files in user://. Actions: ensure_layout creates the current layered directories; list_capture_cache reports managed editor/control/runtime screenshots; cleanup_capture_cache previews or removes current managed capture files while skipping symlinks, junctions, and reparse points; cleanup_legacy_cache finds or applies cleanup for old root-level MCP screenshots/logs/events. cleanup_* defaults to dry_run=true and must be explicitly run by an Agent/user; plugin startup does not auto-clean.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["ensure_layout", "list_capture_cache", "cleanup_capture_cache", "cleanup_legacy_cache"], "description": "Maintenance action"},
					"dry_run": {"type": "boolean", "description": "Preview cleanup without changing files (default: true)"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "project_files",
			"description": "PROJECT FILES: High-level project FileSystem tree operations. Actions: list_dir, create_dir, delete_dir, read_file, write_file, delete_file, copy_file, move_file, select_file, get_selected, get_current_path, scan, reimport. Use this for common FileSystem dock and project file-tree changes before falling back to atomic filesystem tools.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["list_dir", "create_dir", "delete_dir", "read_file", "write_file", "delete_file", "copy_file", "move_file", "select_file", "get_selected", "get_current_path", "scan", "reimport"], "description": "Project file-tree action"},
					"path": {"type": "string", "description": "Project path (res://...)"},
					"content": {"type": "string", "description": "Content for write_file"},
					"source": {"type": "string", "description": "Source path for copy_file/move_file"},
					"dest": {"type": "string", "description": "Destination path for copy_file/move_file"},
					"paths": {"type": "array", "items": {"type": "string"}, "description": "Paths for reimport"},
					"filter": {"type": "string", "description": "Filter for list_dir (default *)"},
					"recursive": {"type": "boolean", "description": "Recursive list_dir traversal"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "project_run",
			"description": "PROJECT RUN: Launch the project in the Godot editor. Runs the main scene by default; provide scene (.tscn path) to run a specific scene. Recommend checking project_state.runtime_capabilities before running. Pair with project_stop. On failure, returns editor/project/scene/runtime_control context. Optional timeout_ms schedules an automatic stop when no log markers are supplied. When success_markers or failure_markers are supplied, project_run waits for matching structured runtime bridge log events; timeout_ms becomes the marker wait timeout, failure markers take precedence, and auto_stop defaults to true. background/minimized/no_focus are currently unsupported and return requires_foreground_window with fallback guidance.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"scene": {"type": "string", "description": "Custom scene to run (optional, runs main scene if omitted)"},
					"timeout_ms": {"type": "integer", "description": "Without markers: optional auto-stop timeout in milliseconds. With markers: marker wait timeout in milliseconds (default 10000)."},
					"success_markers": {"type": "array", "items": {"type": "string"}, "description": "Structured runtime bridge event text markers that indicate validation success. If omitted or empty with failure_markers empty, project_run returns immediately as before."},
					"failure_markers": {"type": "array", "items": {"type": "string"}, "description": "Structured runtime bridge event text markers that indicate validation failure. Failure markers take precedence over success markers."},
					"auto_stop": {"type": "boolean", "description": "Marker wait mode only: stop the running scene through scene_run stop after success, failure, or timeout (default true). Does not kill processes."},
					"poll_interval_ms": {"type": "integer", "description": "Marker wait mode only: runtime bridge poll interval in milliseconds (default 100)."},
					"log_tail": {"type": "integer", "description": "Marker wait mode only: number of recent structured runtime bridge events to inspect per poll (default 100, max 500)."},
					"background": {"type": "boolean", "description": "Request non-foreground launch. Currently unsupported; returns requires_foreground_window instead of starting."},
					"minimized": {"type": "boolean", "description": "Request minimized launch. Currently unsupported; returns requires_foreground_window instead of starting."},
					"no_focus": {"type": "boolean", "description": "Request launch without taking focus. Currently unsupported; returns requires_foreground_window instead of starting."}
				}
			}
		},
		{
			"name": "project_stop",
			"description": "PROJECT STOP: Stop the currently running project in the editor. No parameters. Returns: stopped=true on success.",
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		},
		{
			"name": "runtime_diagnose",
			"description": "RUNTIME DIAGNOSE: Full error report with stacktraces — use when project_state shows error_count > 0 or compile_error_count > 0. Returns: has_errors, runtime_errors[]{message, script, line, stacktrace}, compile_errors[]{message, source_file, source_line}. Key options: tail (default 20, limits runtime error count), include_gd_errors=true adds GDScript Output panel errors (gd_errors[]{severity, message, file, line}), include_performance=true adds fps/memory snapshot.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"include_compile_errors": {
						"type": "boolean",
						"description": "Include .NET compile errors (default: true)"
					},
					"include_performance": {
						"type": "boolean",
						"description": "Include performance snapshot: FPS, memory, render info (default: false)"
					},
					"tail": {
						"type": "integer",
						"description": "Number of recent runtime errors to include (default: 20)"
					},
					"include_gd_errors": {
						"type": "boolean",
						"description": "Include GDScript errors/warnings from the editor Output panel (default: false)"
					}
				}
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	MCPDebugBuffer.record("debug", "system", "tool: %s" % tool_name)
	match tool_name:
		"project_state":     return _execute_project_state(args)
		"editor_state":      return _execute_editor_state(args)
		"plugin_reload":     return _execute_plugin_reload(args)
		"plugin_update":     return _execute_plugin_update(args)
		"resource_reference_audit": return _execute_resource_reference_audit(args)
		"project_configure": return _execute_project_configure(args)
		"project_files":     return _execute_project_files(args)
		"project_run":       return _execute_project_run(args)
		"project_stop":      return _execute_project_stop(args)
		"runtime_diagnose":  return _execute_runtime_diagnose(args)
		"userdata_maintenance": return _execute_userdata_maintenance(args)
		_: return bridge.error("Unknown tool: %s" % tool_name)


func execute_async(tool_name: String, args: Dictionary) -> Dictionary:
	MCPDebugBuffer.record("debug", "system", "tool_async: %s" % tool_name)
	if tool_name == "project_run" and _has_run_log_markers(args):
		return await _execute_project_run_with_log_markers(args)
	return execute(tool_name, args)


# --- private helpers ---


func _execute_resource_reference_audit(args: Dictionary) -> Dictionary:
	var target_path := str(args.get("path", "")).strip_edges()
	var include_warnings := bool(args.get("include_warnings", true))
	var paths: Array[String] = []
	var scan_globs: Array[String] = []
	var enumeration_diagnostics: Array = []
	var scan_status := "ok"
	var valid_scan_scope := true
	var scan_counts := {}
	if not target_path.is_empty():
		if not (target_path.ends_with(".tscn") or target_path.ends_with(".tres")):
			return bridge.error("resource_reference_audit path must be a .tscn or .tres file")
		if not FileAccess.file_exists(target_path):
			return bridge.error("Resource file not found: %s" % target_path)
		paths.append(target_path)
		scan_status = "explicit_path"
	else:
		scan_globs = _RESOURCE_AUDIT_SCAN_GLOBS.duplicate()
		for scene_path in _collect_project_files("*.tscn"):
			paths.append(str(scene_path))
		for resource_path in _collect_project_files("*.tres"):
			paths.append(str(resource_path))
		scan_counts = {"*.tscn": _count_matching_paths(paths, ".tscn"), "*.tres": _count_matching_paths(paths, ".tres")}
		if paths.is_empty():
			valid_scan_scope = false
			scan_status = "invalid_scan_scope"
			enumeration_diagnostics.append(_build_file_enumeration_diagnostic(
				"resource_reference_scan_scope_empty",
				"Project-level resource reference audit found no .tscn or .tres files, so the result cannot prove resource references are clean.",
				scan_globs,
				scan_counts
			))
	paths.sort()

	var issues: Array = []
	var file_results: Array = []
	var files_with_issues := 0
	var error_count := 0
	var warning_count := 0
	for path in paths:
		var file_result := _audit_resource_reference_file(path, include_warnings)
		file_results.append(file_result)
		var file_issue_count := int(file_result.get("issue_count", 0))
		if file_issue_count > 0:
			files_with_issues += 1
		for raw_issue in file_result.get("issues", []):
			if not (raw_issue is Dictionary):
				continue
			var issue: Dictionary = (raw_issue as Dictionary).duplicate(true)
			if str(issue.get("severity", "")) == "error":
				error_count += 1
			elif str(issue.get("severity", "")) == "warning":
				warning_count += 1
			bridge.append_unique_issue(issues, issue)

	var risk_level := "clean"
	if error_count > 0:
		risk_level = "error"
	elif warning_count > 0 or not valid_scan_scope:
		risk_level = "warning"
	var scan_warning_count := enumeration_diagnostics.size()
	return bridge.success({
		"path": target_path,
		"scanned_file_count": paths.size(),
		"files_with_issues": files_with_issues,
		"issue_count": issues.size(),
		"error_count": error_count,
		"warning_count": warning_count + scan_warning_count,
		"resource_warning_count": warning_count,
		"scan_warning_count": scan_warning_count,
		"risk_level": risk_level,
		"scan_status": scan_status,
		"valid_scan_scope": valid_scan_scope,
		"scan_root": _PROJECT_FILE_SCAN_ROOT,
		"scan_globs": scan_globs,
		"project_path": ProjectSettings.globalize_path(_PROJECT_FILE_SCAN_ROOT),
		"enumeration_diagnostics": enumeration_diagnostics,
		"recovery_suggestions": _SCAN_RECOVERY_SUGGESTIONS.duplicate(),
		"build_status": "dotnet_build_may_pass",
		"summary": _build_resource_reference_summary(risk_level, error_count, warning_count + scan_warning_count, valid_scan_scope),
		"issues": issues,
		"files": file_results
	})


func _audit_resource_reference_file(path: String, include_warnings: bool) -> Dictionary:
	var issues: Array = []
	var ext_resource_count := 0
	var csharp_resource_script_count := 0
	var read_text := FileAccess.get_file_as_string(path)
	if read_text.is_empty() and FileAccess.get_open_error() != OK:
		var read_issue: Dictionary = bridge.build_issue("error", "resource_reference_read_failed", "Failed to read resource text: %s" % path, {"file": path})
		return {"file": path, "issue_count": 1, "issues": [read_issue], "ext_resource_count": 0, "csharp_resource_script_count": 0}

	var header := _extract_resource_header(read_text)
	var ext_resources_by_id := {}
	var script_resources := {}
	var used_script_ids := {}
	var lines := read_text.split("\n")
	for index in range(lines.size()):
		var line_no := index + 1
		var line := str(lines[index]).strip_edges()
		if line.begins_with("[ext_resource"):
			ext_resource_count += 1
			var ref_data := _parse_ext_resource_line(path, line, line_no)
			var ref_issues := _build_ext_resource_issues(path, ref_data, include_warnings)
			for ref_issue in ref_issues:
				bridge.append_unique_issue(issues, ref_issue)
			var resource_id := str(ref_data.get("id", ""))
			if not resource_id.is_empty():
				ext_resources_by_id[resource_id] = ref_data
			if str(ref_data.get("type", "")) == "Script":
				if not resource_id.is_empty():
					script_resources[resource_id] = ref_data
		var script_marker := "script = ExtResource(\""
		var script_marker_index := line.find(script_marker)
		if script_marker_index != -1:
			var id_start := script_marker_index + script_marker.length()
			var id_end := line.find("\")", id_start)
			if id_end != -1:
				used_script_ids[line.substr(id_start, id_end - id_start)] = line_no

	if path.ends_with(".tres"):
		for resource_id in used_script_ids.keys():
			if not ext_resources_by_id.has(resource_id):
				var unresolved_issue: Dictionary = bridge.build_issue("error", "resource_script_ext_resource_missing", "Resource script ExtResource id is used but not declared: %s" % resource_id, {"file": path, "line": int(used_script_ids[resource_id]), "id": str(resource_id), "build_status": "dotnet_build_may_pass"})
				bridge.append_unique_issue(issues, unresolved_issue)
				continue
			if not script_resources.has(resource_id):
				var non_script_ref: Dictionary = ext_resources_by_id[resource_id]
				var non_script_issue: Dictionary = bridge.build_issue("error", "resource_script_ext_resource_not_script", "Resource script ExtResource id does not declare a Script resource: %s" % resource_id, {"file": path, "line": int(used_script_ids[resource_id]), "id": str(resource_id), "declared_type": str(non_script_ref.get("type", "")), "build_status": "dotnet_build_may_pass"})
				bridge.append_unique_issue(issues, non_script_issue)
				continue
			var script_ref: Dictionary = script_resources[resource_id]
			var script_path := str(script_ref.get("normalized_path", ""))
			if script_path.ends_with(".cs") or str(script_ref.get("declared_path", "")).ends_with(".cs"):
				csharp_resource_script_count += 1
				var script_issues := _audit_csharp_resource_script_reference(path, int(used_script_ids[resource_id]), script_ref, header, include_warnings)
				for script_issue in script_issues:
					bridge.append_unique_issue(issues, script_issue)

	var dep_result: Dictionary = bridge.call_atomic("resource_query", {"action": "get_dependencies", "path": path})
	var dep_data: Dictionary = bridge.extract_data(dep_result)
	for raw_dep in dep_data.get("dependencies", []):
		var dep_ref: Dictionary = bridge.parse_dependency_reference(str(raw_dep), path) if bridge.has_method("parse_dependency_reference") else {"risk": "none"}
		var risk := str(dep_ref.get("risk", "none"))
		if risk == "error" or (include_warnings and risk == "warning"):
			var dep_issue := _build_dependency_issue(path, dep_ref, 0, "resource_loader_dependencies")
			bridge.append_unique_issue(issues, dep_issue)

	return {
		"file": path,
		"issue_count": issues.size(),
		"issues": issues,
		"ext_resource_count": ext_resource_count,
		"csharp_resource_script_count": csharp_resource_script_count
	}


func _parse_ext_resource_line(source_path: String, line: String, line_no: int) -> Dictionary:
	var resource_type := _extract_resource_attribute(line, "type")
	var uid_text := _extract_resource_attribute(line, "uid")
	var declared_path := _extract_resource_attribute(line, "path")
	var resource_id := _extract_resource_attribute(line, "id")
	var raw_ref := declared_path
	if not uid_text.is_empty():
		raw_ref = "%s::%s::%s" % [uid_text, resource_type, declared_path]
	var parsed: Dictionary = bridge.parse_dependency_reference(raw_ref, source_path) if bridge.has_method("parse_dependency_reference") else {"normalized_path": declared_path, "risk": "none"}
	parsed["file"] = source_path
	parsed["line"] = line_no
	parsed["type"] = resource_type
	parsed["id"] = resource_id
	parsed["source"] = "ext_resource"
	return parsed


func _build_ext_resource_issues(file_path: String, ref_data: Dictionary, include_warnings: bool) -> Array:
	var issues: Array = []
	var risk := str(ref_data.get("risk", "none"))
	if risk == "error" or (include_warnings and risk == "warning"):
		issues.append(_build_dependency_issue(file_path, ref_data, int(ref_data.get("line", 0)), "ext_resource"))
	return issues


func _build_dependency_issue(file_path: String, dep_ref: Dictionary, line_no: int, source: String) -> Dictionary:
	var consistency := str(dep_ref.get("consistency", "dependency_reference_inconsistent"))
	var severity := str(dep_ref.get("risk", "warning"))
	var uid_text := str(dep_ref.get("uid", ""))
	var declared_path := str(dep_ref.get("declared_path", ""))
	var resolved_uid_path := str(dep_ref.get("resolved_uid_path", ""))
	var message := "Resource reference may be inconsistent: %s" % str(dep_ref.get("raw", ""))
	match consistency:
		"stale_fallback_path":
			message = "UID resolves to %s, but the fallback path is stale: %s." % [resolved_uid_path, declared_path]
		"stale_uid":
			message = "Fallback path exists but UID is stale or unknown: %s -> %s." % [uid_text, declared_path]
		"uid_path_mismatch":
			message = "UID resolves to %s, which differs from fallback path %s." % [resolved_uid_path, declared_path]
		"missing_uid_and_path":
			message = "Neither UID nor fallback path can be resolved: %s -> %s." % [uid_text, declared_path]
		"missing_path":
			message = "Referenced path does not exist: %s." % declared_path
	return bridge.build_issue(severity, consistency, message, {
		"file": file_path,
		"line": line_no,
		"source": source,
		"uid": uid_text,
		"declared_path": declared_path,
		"resolved_uid_path": resolved_uid_path,
		"path": str(dep_ref.get("normalized_path", "")),
		"hint": str(dep_ref.get("hint", "Reimport, fix the path, or re-save the scene/resource to normalize references.")),
		"build_status": "dotnet_build_may_pass"
	})


func _audit_csharp_resource_script_reference(file_path: String, line_no: int, script_ref: Dictionary, header: Dictionary, include_warnings: bool) -> Array:
	var issues: Array = []
	var script_path := str(script_ref.get("normalized_path", ""))
	var declared_path := str(script_ref.get("declared_path", ""))
	if script_path.is_empty():
		script_path = declared_path
	if script_path.is_empty() or not FileAccess.file_exists(script_path):
		issues.append(bridge.build_issue("error", "missing_resource_script_path", "C# Resource script path is missing: %s" % declared_path, {"file": file_path, "line": line_no, "script": declared_path, "id": str(script_ref.get("id", "")), "build_status": "dotnet_build_may_pass", "hint": "Fix the .tres script ExtResource path or re-save the resource after moving the script."}))
		return issues

	var inspect_data: Dictionary = bridge.extract_data(bridge.call_atomic("script_inspect", {"path": script_path}))
	var header_script_class := str(header.get("script_class", ""))
	var file_class_name := script_path.get_file().get_basename()
	var resolved_type := _resolve_csharp_resource_type(inspect_data, header_script_class, file_class_name)
	var script_class_name := str(resolved_type.get("class_name", ""))
	var base_type := str(resolved_type.get("base_type", ""))
	if script_class_name.is_empty():
		issues.append(bridge.build_issue("error", "resource_script_class_unresolved", "C# Resource script could not be resolved to a class: %s" % script_path, {"file": file_path, "line": line_no, "script": script_path, "script_file_exists": true, "roslyn_class_found": false, "build_status": "dotnet_build_may_pass"}))
		return issues
	if not header_script_class.is_empty() and header_script_class != script_class_name:
		issues.append(bridge.build_issue("error", "resource_script_class_name_mismatch", "Resource script_class %s does not match C# class %s." % [header_script_class, script_class_name], {"file": file_path, "line": line_no, "script": script_path, "script_class": header_script_class, "class_name": script_class_name, "resolution_source": str(resolved_type.get("resolution_source", "")), "build_status": "dotnet_build_may_pass"}))
	if include_warnings and file_class_name != script_class_name:
		issues.append(bridge.build_issue("warning", "global_class_file_name_mismatch", "C# GlobalClass file name should match class name: %s vs %s." % [file_class_name, script_class_name], {"file": file_path, "line": line_no, "script": script_path, "class_name": script_class_name, "file_class_name": file_class_name, "resolution_source": str(resolved_type.get("resolution_source", "")), "hint": "Godot C# global classes require a case-sensitive file name and class name match."}))
	if include_warnings and not _is_resource_base_type(base_type):
		issues.append(bridge.build_issue("warning", "resource_script_base_type_unconfirmed", "C# script referenced by a .tres resource does not directly inherit Godot.Resource: %s : %s." % [script_class_name, base_type], {"file": file_path, "line": line_no, "script": script_path, "class_name": script_class_name, "base_type": base_type, "resolution_source": str(resolved_type.get("resolution_source", "")), "roslyn_class_found": bool(resolved_type.get("roslyn_class_found", false)), "hint": "Verify the script is a Resource-derived [GlobalClass]; dotnet build can pass even when .tres resource loading is inconsistent."}))
	if include_warnings and not _csharp_script_has_global_class_attribute(script_path):
		issues.append(bridge.build_issue("warning", "resource_script_missing_global_class_attribute", "C# Resource script referenced by .tres does not declare [GlobalClass]: %s" % script_path, {"file": file_path, "line": line_no, "script": script_path, "class_name": script_class_name, "global_class_attribute_found": false, "hint": "Add [GlobalClass] when the resource should be registered as an editor-visible custom Resource."}))
	return issues


func _resolve_csharp_resource_type(inspect_data: Dictionary, header_script_class: String, file_class_name: String) -> Dictionary:
	var direct_class_name := str(inspect_data.get("class_name", ""))
	var types: Array = inspect_data.get("types", []) if inspect_data.get("types", []) is Array else []
	var fallback_type: Dictionary = {}
	for raw_type in types:
		if not (raw_type is Dictionary):
			continue
		var type_data: Dictionary = raw_type
		var type_name := str(type_data.get("name", ""))
		if type_name.is_empty():
			continue
		if not header_script_class.is_empty() and type_name == header_script_class:
			return _build_resolved_csharp_type(type_data, "roslyn_types_script_class")
		if type_name == file_class_name:
			fallback_type = type_data
	if not fallback_type.is_empty():
		return _build_resolved_csharp_type(fallback_type, "roslyn_types_file_name")
	for raw_type in types:
		if raw_type is Dictionary and _is_resource_base_type(str((raw_type as Dictionary).get("base_type", ""))):
			return _build_resolved_csharp_type(raw_type as Dictionary, "roslyn_types_resource_base")
	if not direct_class_name.is_empty():
		return {
			"class_name": direct_class_name,
			"base_type": str(inspect_data.get("base_type", "")),
			"resolution_source": "script_inspect_top_level",
			"roslyn_class_found": true
		}
	return {"class_name": "", "base_type": "", "resolution_source": "unresolved", "roslyn_class_found": false}


func _build_resolved_csharp_type(type_data: Dictionary, resolution_source: String) -> Dictionary:
	return {
		"class_name": str(type_data.get("name", "")),
		"base_type": str(type_data.get("base_type", "")),
		"resolution_source": resolution_source,
		"roslyn_class_found": true
	}


func _extract_resource_header(content: String) -> Dictionary:
	for raw_line in content.split("\n"):
		var line := str(raw_line).strip_edges()
		if line.begins_with("[gd_resource"):
			return {
				"type": _extract_resource_attribute(line, "type"),
				"script_class": _extract_resource_attribute(line, "script_class"),
				"uid": _extract_resource_attribute(line, "uid")
			}
	return {}


func _extract_resource_attribute(line: String, attribute_name: String) -> String:
	var marker := "%s=" % attribute_name
	var start := _find_resource_attribute_start(line, marker)
	if start == -1:
		return ""
	start += marker.length()
	if start >= line.length():
		return ""
	if line.substr(start, 1) == "\"":
		start += 1
		var quoted_finish := line.find("\"", start)
		if quoted_finish == -1:
			return ""
		return line.substr(start, quoted_finish - start).strip_edges()
	var finish := start
	while finish < line.length():
		var current := line.substr(finish, 1)
		if current == " " or current == "]" or current == "\t":
			break
		finish += 1
	return line.substr(start, finish - start).strip_edges()


func _find_resource_attribute_start(line: String, marker: String) -> int:
	var in_quote := false
	var index := 0
	while index <= line.length() - marker.length():
		var current := line.substr(index, 1)
		if current == "\"" and (index == 0 or line.substr(index - 1, 1) != "\\"):
			in_quote = not in_quote
			index += 1
			continue
		if not in_quote and line.substr(index, marker.length()) == marker:
			if index == 0:
				return index
			var previous := line.substr(index - 1, 1)
			if previous == " " or previous == "\t" or previous == "[":
				return index
		index += 1
	return -1


func _is_resource_base_type(base_type: String) -> bool:
	var normalized := base_type.strip_edges()
	return normalized == "Resource" or normalized == "Godot.Resource" or normalized.ends_with(".Resource")


func _csharp_script_has_global_class_attribute(script_path: String) -> bool:
	if script_path.is_empty() or not FileAccess.file_exists(script_path):
		return false
	var content := FileAccess.get_file_as_string(script_path)
	return content.find("[GlobalClass") != -1 or content.find("GlobalClassAttribute") != -1


func _collect_project_files(pattern: String) -> Array[String]:
	var collected: Array[String] = []
	for raw_path in bridge.collect_files(pattern):
		collected.append(str(raw_path))
	collected.sort()
	return collected


func _count_matching_paths(paths: Array[String], extension: String) -> int:
	var count := 0
	for path in paths:
		if str(path).ends_with(extension):
			count += 1
	return count


func _build_file_enumeration_diagnostic(code: String, message: String, scan_globs: Array, counts: Dictionary = {}) -> Dictionary:
	return {
		"severity": "warning",
		"code": code,
		"type": code,
		"message": message,
		"source": "filesystem_directory.get_files",
		"scan_root": _PROJECT_FILE_SCAN_ROOT,
		"project_path": ProjectSettings.globalize_path(_PROJECT_FILE_SCAN_ROOT),
		"scan_globs": scan_globs.duplicate(),
		"counts": counts.duplicate(true),
		"recovery_suggestions": _SCAN_RECOVERY_SUGGESTIONS.duplicate()
	}


func _build_file_enumeration_status(gd_scripts: Array, cs_scripts: Array, scene_paths: Array, resource_paths: Array) -> Dictionary:
	var counts := {
		"gd_scripts": gd_scripts.size(),
		"cs_scripts": cs_scripts.size(),
		"scripts": gd_scripts.size() + cs_scripts.size(),
		"scenes": scene_paths.size(),
		"resources": resource_paths.size()
	}
	var diagnostics: Array = []
	if int(counts.get("scripts", 0)) == 0 and int(counts.get("scenes", 0)) == 0:
		diagnostics.append(_build_file_enumeration_diagnostic(
			"project_file_enumeration_empty",
			"Project file enumeration found no scripts or scenes, so project_state file counts may be incomplete even if explicit path tools still work.",
			_PROJECT_STATE_SCAN_GLOBS,
			counts
		))
	return {
		"status": "suspect" if not diagnostics.is_empty() else "ok",
		"valid": diagnostics.is_empty(),
		"scan_root": _PROJECT_FILE_SCAN_ROOT,
		"project_path": ProjectSettings.globalize_path(_PROJECT_FILE_SCAN_ROOT),
		"scan_globs": _PROJECT_STATE_SCAN_GLOBS.duplicate(),
		"counts": counts,
		"diagnostics": diagnostics,
		"recovery_suggestions": _SCAN_RECOVERY_SUGGESTIONS.duplicate()
	}


func _build_resource_reference_summary(risk_level: String, error_count: int, warning_count: int, valid_scan_scope: bool = true) -> String:
	if not valid_scan_scope:
		return "Resource reference audit scanned no project files; the result is inconclusive rather than clean. Refresh the Godot FileSystem or retry with an explicit resource path."
	if risk_level == "error":
		return "Resource references contain %d error(s); scene/resource loading may fail even if dotnet build passes." % error_count
	if risk_level == "warning":
		return "Resource references contain %d warning(s); reimport or re-save resources to refresh UID/path metadata." % warning_count
	return "No resource reference consistency issues were found."


func _execute_plugin_reload(args: Dictionary) -> Dictionary:
	var action := str(args.get("action", "")).strip_edges()
	match action:
		"get_freshness":
			return bridge.success(PluginInstanceFreshness.get_freshness_snapshot(), "Plugin freshness fetched")
		"full_reload_plugin":
			var plugin = _get_plugin_from_runtime_context()
			if plugin == null or not plugin.has_method("request_plugin_lifecycle_reload_from_tools"):
				return bridge.error("Plugin lifecycle reload bridge is unavailable", {"freshness": PluginInstanceFreshness.get_freshness_snapshot()})
			var result = plugin.request_plugin_lifecycle_reload_from_tools()
			if result is Dictionary:
				return result
			return bridge.error("Plugin lifecycle reload returned an invalid response", {"freshness": PluginInstanceFreshness.get_freshness_snapshot()})
		_:
			return bridge.error("Unknown plugin_reload action: %s" % action)


func _execute_plugin_update(args: Dictionary) -> Dictionary:
	var action := str(args.get("action", "")).strip_edges()
	var plugin = _get_plugin_from_runtime_context()
	match action:
		"get_current":
			if plugin != null and plugin.has_method("get_plugin_update_current_from_tools"):
				return _normalize_plugin_update_result(plugin.get_plugin_update_current_from_tools(), "Plugin update current fetched")
			return _plugin_update_unavailable_response(action)
		"get_status":
			if plugin != null and plugin.has_method("get_plugin_update_status_from_tools"):
				return _normalize_plugin_update_result(plugin.get_plugin_update_status_from_tools(), "Plugin update status fetched")
			return _plugin_update_unavailable_response(action)
		"set_source":
			if plugin == null or not plugin.has_method("set_plugin_update_source_from_tools"):
				return _plugin_update_unavailable_response(action)
			var source := str(args.get("source", args.get("update_source", ""))).strip_edges()
			var custom_branch := str(args.get("custom_branch", args.get("branch", ""))).strip_edges()
			var release_tag := str(args.get("release_tag", args.get("tag", ""))).strip_edges()
			return _normalize_plugin_update_result(plugin.set_plugin_update_source_from_tools(source, custom_branch, release_tag), "Plugin update source selected")
		"discover_refs":
			if plugin == null or not plugin.has_method("discover_plugin_update_refs_from_tools"):
				return _plugin_update_unavailable_response(action)
			var force_refresh := bool(args.get("force_refresh", true))
			return _normalize_plugin_update_result(plugin.discover_plugin_update_refs_from_tools(force_refresh), "Plugin update ref discovery requested")
		"start_sync":
			if plugin == null or not plugin.has_method("start_plugin_update_sync_from_tools"):
				return _plugin_update_unavailable_response(action)
			return _normalize_plugin_update_result(plugin.start_plugin_update_sync_from_tools(), "Plugin update sync requested")
		_:
			return bridge.error("Unknown plugin_update action: %s" % action)


func _normalize_plugin_update_result(result, fallback_message: String) -> Dictionary:
	if result is Dictionary:
		return result
	return bridge.error("Plugin update bridge returned an invalid response", {"freshness": PluginInstanceFreshness.get_freshness_snapshot(), "fallback_message": fallback_message})


func _plugin_update_unavailable_response(action: String) -> Dictionary:
	return bridge.success({
		"action": action,
		"status": "unavailable",
		"accepted": false,
		"loading": false,
		"reason": "Plugin update bridge is unavailable",
		"freshness": PluginInstanceFreshness.get_freshness_snapshot()
	}, "Plugin update bridge is unavailable")


func _get_plugin_from_runtime_context():
	var server = _runtime_context.get("server", null)
	if server == null or not is_instance_valid(server):
		return null
	return server.get_parent()


func _execute_userdata_maintenance(args: Dictionary) -> Dictionary:
	var action := str(args.get("action", "")).strip_edges()
	match action:
		"ensure_layout":
			return bridge.success(MCPUserDataPaths.initialize_layout(false), "User data layout ensured")
		"list_capture_cache":
			return bridge.success(MCPUserDataPaths.list_capture_cache(), "Capture cache listed")
		"cleanup_capture_cache":
			var dry_run_current := bool(args.get("dry_run", true))
			return bridge.success(MCPUserDataPaths.cleanup_capture_cache(dry_run_current), "Capture cache cleanup previewed" if dry_run_current else "Capture cache cleanup applied")
		"cleanup_legacy_cache":
			var dry_run := bool(args.get("dry_run", true))
			return bridge.success(MCPUserDataPaths.cleanup_legacy_cache(dry_run), "Legacy user data cleanup previewed" if dry_run else "Legacy user data cleanup applied")
		_:
			return bridge.error("Unknown userdata_maintenance action: %s" % action)

func _get_runtime_summary() -> Dictionary:
	return bridge.extract_data(bridge.call_atomic("debug_runtime_bridge", {"action": "get_summary"}))


func _safe_extract_data(result: Dictionary) -> Dictionary:
	if result is Dictionary and bool(result.get("success", false)):
		return bridge.extract_data(result)
	return {}


func _result_error_text(result: Dictionary, fallback: String) -> String:
	if result is Dictionary:
		var message := str(result.get("message", "")).strip_edges()
		if not message.is_empty():
			return message
		var error_code := str(result.get("error", "")).strip_edges()
		if not error_code.is_empty():
			return error_code
	return fallback


func _section_success(data: Dictionary) -> Dictionary:
	var out := {"available": true, "error": ""}
	for key in data.keys():
		out[key] = data[key]
	return out


func _section_failure(fallback: String, result: Dictionary = {}, data: Dictionary = {}) -> Dictionary:
	var out := {
		"available": false,
		"error": _result_error_text(result, fallback)
	}
	for key in data.keys():
		out[key] = data[key]
	return out


func _build_editor_state_section() -> Dictionary:
	var info_result: Dictionary = bridge.call_atomic("editor_status", {"action": "get_info"})
	var main_screen_result: Dictionary = bridge.call_atomic("editor_status", {"action": "get_main_screen"})
	var focus_context_result: Dictionary = bridge.call_atomic("editor_status", {"action": "get_focus_context"})
	var distraction_free_result: Dictionary = bridge.call_atomic("editor_status", {"action": "get_distraction_free"})
	var godot_path_result: Dictionary = bridge.call_atomic("editor_status", {"action": "get_godot_path"})
	var failed_result := {}
	for result in [info_result, main_screen_result, focus_context_result, distraction_free_result, godot_path_result]:
		if result is Dictionary and not bool(result.get("success", false)):
			failed_result = result
			break
	var info := _safe_extract_data(info_result)
	var main_screen := _safe_extract_data(main_screen_result)
	var focus_context := _safe_extract_data(focus_context_result)
	var distraction_free := _safe_extract_data(distraction_free_result)
	var godot_path := _safe_extract_data(godot_path_result)
	var session_identity := _enrich_editor_session_identity(godot_path.get("editor_session_identity", {}))
	var payload := {
		"godot_version": str(info.get("godot_version", "")),
		"version_string": str(info.get("version_string", "")),
		"os": str(info.get("os", "")),
		"editor_scale": float(info.get("editor_scale", 0.0)),
		"main_screen": str(main_screen.get("current_screen", "")),
		"available_screens": main_screen.get("available", []),
		"focus_context": focus_context,
		"distraction_free": bool(distraction_free.get("enabled", false)),
		"godot_executable_path": str(godot_path.get("godot_executable_path", "")),
		"project_root_path": str(godot_path.get("project_root_path", "")),
		"editor_session_identity": session_identity
	}
	if failed_result is Dictionary and not failed_result.is_empty():
		return _section_failure("Editor status is unavailable.", failed_result, payload)
	return _section_success(payload)


func _build_inspector_state_section() -> Dictionary:
	var edited_result: Dictionary = bridge.call_atomic("editor_inspector", {"action": "get_edited"})
	var selected_property_result: Dictionary = bridge.call_atomic("editor_inspector", {"action": "get_selected_property"})
	var edited := _safe_extract_data(edited_result)
	var selected_property := _safe_extract_data(selected_property_result)
	var payload := {
		"editing": edited.get("editing", null),
		"class": str(edited.get("class", "")),
		"path": str(edited.get("path", "")),
		"name": str(edited.get("name", "")),
		"resource_path": str(edited.get("resource_path", "")),
		"selected_property": str(selected_property.get("selected_path", ""))
	}
	if not bool(edited_result.get("success", false)):
		return _section_failure("Inspector state is unavailable.", edited_result, payload)
	if not bool(selected_property_result.get("success", false)):
		return _section_failure("Inspector property selection is unavailable.", selected_property_result, payload)
	return _section_success(payload)


func _build_filesystem_state_section() -> Dictionary:
	var selected_result: Dictionary = bridge.call_atomic("editor_filesystem", {"action": "get_selected"})
	var current_result: Dictionary = bridge.call_atomic("editor_filesystem", {"action": "get_current_path"})
	var selected := _safe_extract_data(selected_result)
	var current := _safe_extract_data(current_result)
	var payload := {
		"selected_count": int(selected.get("count", 0)),
		"selected_paths": selected.get("paths", []),
		"current_path": str(current.get("current_path", "")),
		"current_directory": str(current.get("current_directory", ""))
	}
	if not bool(selected_result.get("success", false)):
		return _section_failure("Editor filesystem selection is unavailable.", selected_result, payload)
	if not bool(current_result.get("success", false)):
		return _section_failure("Editor filesystem current path is unavailable.", current_result, payload)
	return _section_success(payload)


func _resolve_runtime_control_service():
	if _runtime_context.has("runtime_control_service"):
		return _runtime_context.get("runtime_control_service", null)
	var server = _runtime_context.get("server", null)
	if server != null and server.has_method("get_runtime_control_service"):
		return server.get_runtime_control_service()
	if bridge != null and bridge.has_method("get_runtime_control_service"):
		return bridge.get_runtime_control_service()
	return null


func _build_runtime_control_state_section() -> Dictionary:
	var service = _resolve_runtime_control_service()
	if service == null or not service.has_method("get_status"):
		return _section_failure("Runtime control service is unavailable.", {}, {
			"armed": false,
			"message": "Runtime control service is unavailable.",
			"can_enable_runtime_control": false,
			"can_control_runtime": false,
			"can_capture_runtime": false
		})
	var status = service.get_status()
	if status is Dictionary:
		var copied: Dictionary = (status as Dictionary).duplicate(true)
		if not copied.has("available"):
			copied["available"] = true
		if not copied.has("error"):
			copied["error"] = ""
		_enrich_runtime_control_capabilities(copied)
		return copied
	return _section_failure("Runtime control status is unavailable.", {}, {
		"armed": false,
		"message": "Runtime control status is unavailable.",
		"can_enable_runtime_control": false,
		"can_control_runtime": false,
		"can_capture_runtime": false
	})


func _enrich_runtime_control_capabilities(status: Dictionary) -> void:
	var available := bool(status.get("available", false))
	var armed := bool(status.get("armed", false))
	var session_snapshot_raw = status.get("session_snapshot", {})
	var session_snapshot: Dictionary = session_snapshot_raw if session_snapshot_raw is Dictionary else {}
	var commandable_session_count := int(session_snapshot.get("commandable_session_count", 1 if available else 0))
	var active_session_count := int(session_snapshot.get("active_session_count", 1 if available else 0))
	status["runtime_session_attached"] = active_session_count > 0
	status["commandable_session_count"] = commandable_session_count
	status["can_enable_runtime_control"] = available
	status["can_control_runtime"] = available and armed and commandable_session_count > 0
	status["can_capture_runtime"] = bool(status.get("can_control_runtime", false))
	status["external_visible_process_registered"] = false


func _build_runtime_capabilities(project_info: Dictionary, dotnet_build_data: Dictionary, runtime_summary: Dictionary, runtime_control_status: Dictionary = {}) -> Dictionary:
	var main_scene := str(project_info.get("main_scene", ""))
	var compile_error_count := int(dotnet_build_data.get("error_count", 0))
	var editor_context := _build_editor_runtime_context()
	var editor_interface_available := bool(editor_context.get("editor_interface_available", false))
	var main_scene_exists := not main_scene.is_empty() and FileAccess.file_exists(main_scene)
	var runtime_control := runtime_control_status.duplicate(true)
	if runtime_control.is_empty():
		runtime_control = _build_runtime_control_state_section()
	var blocking_reasons: Array[String] = []
	if not editor_interface_available:
		blocking_reasons.append("editor_interface_unavailable")
	if main_scene.is_empty():
		blocking_reasons.append("main_scene_missing")
	elif not main_scene_exists:
		blocking_reasons.append("main_scene_not_found")
	if compile_error_count > 0:
		blocking_reasons.append("compile_errors_present")
	var can_start_project := blocking_reasons.is_empty()
	return {
		"editor_interface_available": editor_interface_available,
		"editor_run_available": editor_interface_available,
		"can_start_project": can_start_project,
		"can_enable_runtime_control": bool(runtime_control.get("can_enable_runtime_control", false)),
		"can_control_runtime": bool(runtime_control.get("can_control_runtime", false)),
		"can_capture_runtime": bool(runtime_control.get("can_capture_runtime", false)),
		"headless_logic_ok": true,
		"visible_capture_required": true,
		"can_run_without_focus": false,
		"no_focus_launch_supported": false,
		"foreground_window_policy": "requires_foreground_window",
		"foreground_window_fallbacks": ["headless_logic_test", "editor_screenshot"],
		"runtime_session_attached": bool(runtime_control.get("runtime_session_attached", false)),
		"runtime_launched_by_editor": int(runtime_summary.get("session_count", 0)) > 0,
		"runtime_message_channel_available": bool(runtime_control.get("can_enable_runtime_control", false)),
		"runtime_bridge_installed": not str(runtime_summary.get("bridge_status", "")).is_empty() and str(runtime_summary.get("bridge_status", "unknown")) != "unknown",
		"runtime_control_armed": bool(runtime_control.get("armed", false)),
		"runtime_session_count": int(runtime_summary.get("session_count", 0)),
		"commandable_session_count": int(runtime_control.get("commandable_session_count", 0)),
		"external_visible_process_registered": false,
		"blocking_reasons": blocking_reasons,
		"editor_context": editor_context
	}


func _build_editor_runtime_context() -> Dictionary:
	var godot_path_result: Dictionary = bridge.call_atomic("editor_status", {"action": "get_godot_path"})
	var godot_path := _safe_extract_data(godot_path_result)
	var available := bool(godot_path_result.get("success", false))
	var session_identity := _enrich_editor_session_identity(godot_path.get("editor_session_identity", {}))
	return {
		"editor_interface_available": available,
		"error": "" if available else _result_error_text(godot_path_result, "Editor interface is unavailable."),
		"godot_executable_path": str(godot_path.get("godot_executable_path", "")),
		"project_root_path": str(godot_path.get("project_root_path", ProjectSettings.globalize_path("res://"))),
		"editor_session_identity": session_identity
	}


func _get_server_listen_endpoint() -> Dictionary:
	var server = _runtime_context.get("server", null)
	if server != null and is_instance_valid(server) and server.has_method("get_listen_endpoint"):
		var endpoint = server.get_listen_endpoint()
		if endpoint is Dictionary:
			return (endpoint as Dictionary).duplicate(true)
	return {}


func _enrich_editor_session_identity(raw_identity) -> Dictionary:
	var identity: Dictionary = raw_identity.duplicate(true) if raw_identity is Dictionary else MCPEditorSessionIdentity.build_identity()
	var endpoint := _get_server_listen_endpoint()
	if endpoint.is_empty():
		return identity
	var listen := {
		"host": str(endpoint.get("host", "")),
		"port": int(endpoint.get("port", 0)),
		"url": str(endpoint.get("url", "")),
		"running": bool(endpoint.get("running", false))
	}
	identity["listen"] = listen
	identity["listen_host"] = str(listen.get("host", ""))
	identity["listen_port"] = int(listen.get("port", 0))
	identity["listen_url"] = str(listen.get("url", ""))
	return identity


func _build_project_state_summary(_args: Dictionary = {}) -> Dictionary:
	var project_info_result: Dictionary = bridge.call_atomic("project_info", {"action": "get_info"})
	var dotnet_result: Dictionary = bridge.call_atomic("project_dotnet", {})
	var runtime_summary_result: Dictionary = bridge.call_atomic("debug_runtime_bridge", {"action": "get_summary"})
	var scene_snapshot_result: Dictionary = bridge.call_atomic("debug_runtime_bridge", {"action": "get_scene_snapshot"})
	var dotnet_build_result: Dictionary = bridge.call_atomic("debug_dotnet", {"action": "build"})
	var failed_result := {}
	for result in [project_info_result, dotnet_result, runtime_summary_result, scene_snapshot_result, dotnet_build_result]:
		if result is Dictionary and not bool(result.get("success", false)):
			failed_result = result
			break
	var dotnet_data: Dictionary = bridge.extract_data(dotnet_result)
	var runtime_summary: Dictionary = bridge.extract_data(runtime_summary_result)
	var scene_snapshot: Dictionary = bridge.extract_data(scene_snapshot_result)
	var dotnet_build_data: Dictionary = bridge.extract_data(dotnet_build_result)
	var project_info: Dictionary = bridge.extract_data(project_info_result)
	var runtime_control_status := _build_runtime_control_state_section()
	var runtime_capabilities := _build_runtime_capabilities(project_info, dotnet_build_data, runtime_summary, runtime_control_status)
	var state_data := {
		"running": _is_runtime_running(runtime_summary),
		"runtime_bridge_status": str(runtime_summary.get("bridge_status", "unknown")),
		"error_count": int(runtime_summary.get("error_count", 0)),
		"compile_error_count": int(dotnet_build_data.get("error_count", 0)),
		"current_scene": str(scene_snapshot.get("current_scene", scene_snapshot.get("scene", ""))),
		"dotnet_project_count": int(dotnet_data.get("count", 0)),
		"runtime_capabilities": runtime_capabilities
	}
	if failed_result is Dictionary and not failed_result.is_empty():
		return _section_failure("Project state is unavailable.", failed_result, state_data)
	return _section_success({
		"running": bool(state_data.get("running", false)),
		"runtime_bridge_status": str(state_data.get("runtime_bridge_status", "unknown")),
		"error_count": int(state_data.get("error_count", 0)),
		"compile_error_count": int(state_data.get("compile_error_count", 0)),
		"current_scene": str(state_data.get("current_scene", "")),
		"dotnet_project_count": int(state_data.get("dotnet_project_count", 0)),
		"runtime_capabilities": runtime_capabilities
	})


func _get_runtime_errors(limit: int) -> Array:
	return bridge.extract_array(bridge.call_atomic("debug_runtime_bridge", {
		"action": "get_errors_context", "limit": limit
	}), "errors")


func _get_runtime_warnings(limit: int) -> Array:
	var result: Dictionary = bridge.call_atomic("debug_runtime_bridge", {
		"action": "get_recent_filtered",
		"level": "warning",
		"tail": limit,
		"limit": max(limit * 4, 20)
	})
	var events: Array = bridge.extract_array(result, "events")
	var warnings: Array = []
	for event in events:
		if not (event is Dictionary):
			continue
		var payload = event.get("payload", {})
		if not (payload is Dictionary):
			payload = {}
		warnings.append({
			"timestamp": str(event.get("timestamp_text", "")),
			"message": str((payload as Dictionary).get("message", "")),
			"source": str((payload as Dictionary).get("source", (payload as Dictionary).get("script", "")))
		})
	return warnings


func _get_lsp_runtime_health_summary() -> Dictionary:
	var summary: Dictionary = {
		"enabled": false,
		"available": false,
		"last_state": "unavailable",
		"last_error": ""
	}
	if bridge == null or not bridge.has_method("get_tool_loader"):
		summary["last_error"] = "Tool loader is unavailable"
		return summary
	var loader = bridge.get_tool_loader()
	if loader == null:
		summary["last_error"] = "Tool loader is unavailable"
		return summary
	summary["enabled"] = loader.has_method("get_gdscript_lsp_diagnostics_service")
	if not loader.has_method("get_lsp_diagnostics_debug_snapshot"):
		summary["last_error"] = "LSP diagnostics snapshot is unavailable"
		return summary
	var snapshot_raw = loader.get_lsp_diagnostics_debug_snapshot()
	if not (snapshot_raw is Dictionary):
		summary["last_error"] = "LSP diagnostics snapshot is unavailable"
		return summary
	var snapshot: Dictionary = snapshot_raw
	var service_snapshot_raw = snapshot.get("service", {})
	if not (service_snapshot_raw is Dictionary):
		summary["last_error"] = "LSP diagnostics service snapshot is unavailable"
		return summary
	var service_snapshot: Dictionary = service_snapshot_raw
	var current_status_raw = service_snapshot.get("status", {})
	var current_status: Dictionary = current_status_raw if current_status_raw is Dictionary else {}
	var last_completed_raw = service_snapshot.get("last_completed_status", {})
	var last_completed: Dictionary = last_completed_raw if last_completed_raw is Dictionary else {}
	var source_status := current_status if not current_status.is_empty() else last_completed
	summary["available"] = bool(snapshot.get("service_available", false))
	summary["last_state"] = str(source_status.get("phase", source_status.get("state", "idle")))
	summary["last_error"] = str(source_status.get("error", last_completed.get("error", "")))
	return summary


func _get_tool_loader_health_summary() -> Dictionary:
	var summary: Dictionary = {
		"enabled": false,
		"available": false,
		"status": "unavailable",
		"tool_count": 0,
		"exposed_tool_count": 0,
		"last_error": ""
	}
	if bridge == null or not bridge.has_method("get_tool_loader"):
		summary["last_error"] = "Tool loader is unavailable"
		return summary
	var loader = bridge.get_tool_loader()
	if loader == null:
		summary["last_error"] = "Tool loader is unavailable"
		return summary
	summary["enabled"] = loader.has_method("get_tool_loader_status")
	if not loader.has_method("get_tool_loader_status"):
		summary["last_error"] = "Tool loader status is unavailable"
		return summary
	var status_raw = loader.get_tool_loader_status()
	if not (status_raw is Dictionary):
		summary["last_error"] = "Tool loader status is unavailable"
		return summary
	var status: Dictionary = status_raw
	summary["available"] = true
	summary["status"] = str(status.get("status", "unknown"))
	summary["tool_count"] = int(status.get("tool_count", 0))
	summary["exposed_tool_count"] = int(status.get("exposed_tool_count", 0))
	summary["last_error"] = ""
	return summary


func _get_self_diagnostics_health_summary() -> Dictionary:
	return PluginSelfDiagnosticStore.get_health_snapshot({
		"freshness": PluginInstanceFreshness.get_freshness_snapshot(),
		"tool_loader": _get_tool_loader_health_summary()
	}, 3)


func _is_runtime_running(summary: Dictionary) -> bool:
	var sessions = summary.get("sessions", {})
	if sessions is Dictionary:
		for session_id in (sessions as Dictionary).keys():
			var session = (sessions as Dictionary).get(session_id, {})
			if session is Dictionary and str((session as Dictionary).get("state", "")) in ["started", "running"]:
				return true
	elif sessions is Array:
		for session in sessions:
			if session is Dictionary and str((session as Dictionary).get("state", "")) in ["started", "running"]:
				return true
	return false


# --- tool implementations ---

func _execute_project_state(args: Dictionary) -> Dictionary:
	var sections_result := _normalize_project_state_sections(args)
	if not bool(sections_result.get("success", true)):
		return bridge.error(str(sections_result.get("error", "Invalid project_state sections")))
	var full_result := _execute_project_state_full(args)
	if not bool(full_result.get("success", false)):
		return full_result
	var full_data: Dictionary = bridge.extract_data(full_result)
	var selected_sections: Array = sections_result.get("sections", [])
	if not selected_sections.is_empty():
		return bridge.success(_build_project_state_sections_payload(full_data, selected_sections))
	if bool(args.get("summary", false)):
		return bridge.success(_build_project_state_compact_summary(full_data))
	return full_result


func _execute_project_state_full(args: Dictionary) -> Dictionary:
	var error_limit: int = max(int(args.get("error_limit", 10)), 0)
	var include_runtime_health := bool(args.get("include_runtime_health", false))
	MCPDebugBuffer.record("debug", "system", "project_state: collecting stats (error_limit=%d)" % error_limit)
	var project_info: Dictionary = bridge.extract_data(bridge.call_atomic("project_info", {"action": "get_info"}))
	var dotnet_result: Dictionary = bridge.call_atomic("project_dotnet", {})
	var dotnet_data: Dictionary = bridge.extract_data(dotnet_result)
	var runtime_summary := _get_runtime_summary()
	var recent_errors := _get_runtime_errors(error_limit)
	var recent_warnings := _get_runtime_warnings(min(error_limit, 10))
	var gd_scripts: Array[String] = _collect_project_files("*.gd")
	var cs_scripts: Array[String] = _collect_project_files("*.cs")
	var scene_paths: Array[String] = _collect_project_files("*.tscn")
	var resources_tres: Array[String] = _collect_project_files("*.tres")
	var resources_res: Array[String] = _collect_project_files("*.res")
	var all_resources: Array = []
	all_resources.append_array(resources_tres)
	all_resources.append_array(resources_res)
	all_resources.sort()
	var file_enumeration := _build_file_enumeration_status(gd_scripts, cs_scripts, scene_paths, all_resources)

	var compile_error_count := 0
	var dotnet_errors_data: Dictionary = {}
	if bool(dotnet_result.get("success", false)):
		dotnet_errors_data = bridge.extract_data(bridge.call_atomic("debug_dotnet", {"action": "build"}))
		compile_error_count = int(dotnet_errors_data.get("error_count", 0))

	var current_scene := ""
	var scene_snapshot: Dictionary = bridge.extract_data(bridge.call_atomic("debug_runtime_bridge", {"action": "get_scene_snapshot"}))
	if not scene_snapshot.is_empty():
		current_scene = str(scene_snapshot.get("current_scene", scene_snapshot.get("scene", "")))

	var main_scene := str(project_info.get("main_scene", ""))
	var runtime_capabilities := _build_runtime_capabilities(project_info, dotnet_errors_data, runtime_summary, _build_runtime_control_state_section())
	var result_data := {
		"project_name": str(project_info.get("name", "Untitled")),
		"project_description": str(project_info.get("description", "")),
		"project_version": str(project_info.get("version", "")),
		"project_path": str(project_info.get("project_path", ProjectSettings.globalize_path("res://"))),
		"godot_version": str(project_info.get("godot_version", "")),
		"godot_version_string": str(project_info.get("godot_version_string", "")),
		"main_scene": main_scene,
		"main_scene_exists": not main_scene.is_empty() and FileAccess.file_exists(main_scene),
		"current_scene": current_scene,
		"scripts": gd_scripts.size() + cs_scripts.size(),
		"gd_scripts": gd_scripts.size(),
		"cs_scripts": cs_scripts.size(),
		"scenes": scene_paths.size(),
		"resources": all_resources.size(),
		"scene_paths": scene_paths,
		"script_paths": gd_scripts + cs_scripts,
		"resource_paths": all_resources,
		"file_enumeration_status": str(file_enumeration.get("status", "ok")),
		"valid_file_enumeration": bool(file_enumeration.get("valid", true)),
		"file_enumeration": file_enumeration,
		"enumeration_diagnostics": file_enumeration.get("diagnostics", []),
		"has_dotnet": bool(dotnet_result.get("success", false)),
		"dotnet_project_count": int(dotnet_data.get("count", 0)),
		"dotnet_projects": dotnet_data.get("projects", []),
		"compile_error_count": compile_error_count,
		"running": _is_runtime_running(runtime_summary),
		"runtime_bridge_status": str(runtime_summary.get("bridge_status", "unknown")),
		"session_count": int(runtime_summary.get("session_count", 0)),
		"runtime_capabilities": runtime_capabilities,
		"recent_errors": recent_errors,
		"recent_warnings": recent_warnings,
		"error_count": recent_errors.size(),
		"warning_count": recent_warnings.size()
	}
	if include_runtime_health:
		result_data["runtime_health"] = {
			"self_diagnostics": _get_self_diagnostics_health_summary(),
			"lsp_diagnostics": _get_lsp_runtime_health_summary(),
			"tool_loader": _get_tool_loader_health_summary(),
			"freshness": PluginInstanceFreshness.get_freshness_snapshot(),
			"capabilities": runtime_capabilities
		}
	return bridge.success(result_data)


func _get_project_state_available_sections() -> Array[String]:
	return ["summary", "project", "files", "runtime", "capabilities", "health"]


func _normalize_project_state_sections(args: Dictionary) -> Dictionary:
	var requested = args.get("sections", [])
	if requested == null:
		return {"success": true, "sections": []}
	if not (requested is Array):
		return {"success": false, "error": "project_state sections must be an array. Valid sections: %s" % ", ".join(_get_project_state_available_sections())}
	var available := _get_project_state_available_sections()
	var sections: Array[String] = []
	for section in requested:
		var section_key := str(section).strip_edges()
		if section_key.is_empty():
			continue
		if not available.has(section_key):
			return {"success": false, "error": "Unknown project_state section: %s. Valid sections: %s" % [section_key, ", ".join(available)]}
		if not sections.has(section_key):
			sections.append(section_key)
	return {"success": true, "sections": sections}


func _build_project_state_compact_summary(full_data: Dictionary) -> Dictionary:
	return {
		"summary": true,
		"available_sections": _get_project_state_available_sections(),
		"project_name": str(full_data.get("project_name", "")),
		"project_path": str(full_data.get("project_path", "")),
		"godot_version_string": str(full_data.get("godot_version_string", "")),
		"main_scene": str(full_data.get("main_scene", "")),
		"main_scene_exists": bool(full_data.get("main_scene_exists", false)),
		"current_scene": str(full_data.get("current_scene", "")),
		"scripts": int(full_data.get("scripts", 0)),
		"gd_scripts": int(full_data.get("gd_scripts", 0)),
		"cs_scripts": int(full_data.get("cs_scripts", 0)),
		"scenes": int(full_data.get("scenes", 0)),
		"resources": int(full_data.get("resources", 0)),
		"file_enumeration_status": str(full_data.get("file_enumeration_status", "ok")),
		"valid_file_enumeration": bool(full_data.get("valid_file_enumeration", true)),
		"has_dotnet": bool(full_data.get("has_dotnet", false)),
		"dotnet_project_count": int(full_data.get("dotnet_project_count", 0)),
		"compile_error_count": int(full_data.get("compile_error_count", 0)),
		"running": bool(full_data.get("running", false)),
		"runtime_bridge_status": str(full_data.get("runtime_bridge_status", "unknown")),
		"session_count": int(full_data.get("session_count", 0)),
		"error_count": int(full_data.get("error_count", 0)),
		"warning_count": int(full_data.get("warning_count", 0)),
		"runtime_capabilities": full_data.get("runtime_capabilities", {})
	}


func _build_project_state_sections_payload(full_data: Dictionary, selected_sections: Array) -> Dictionary:
	var sections := {}
	for section in selected_sections:
		var section_key := str(section)
		match section_key:
			"summary":
				sections[section_key] = _build_project_state_compact_summary(full_data)
			"project":
				sections[section_key] = _build_project_state_project_section(full_data)
			"files":
				sections[section_key] = _build_project_state_files_section(full_data)
			"runtime":
				sections[section_key] = _build_project_state_runtime_section(full_data)
			"capabilities":
				sections[section_key] = full_data.get("runtime_capabilities", {})
			"health":
				sections[section_key] = _build_project_state_health_section(full_data)
	return {
		"available_sections": _get_project_state_available_sections(),
		"requested_sections": selected_sections.duplicate(),
		"sections": sections
	}


func _build_project_state_project_section(full_data: Dictionary) -> Dictionary:
	return {
		"project_name": str(full_data.get("project_name", "")),
		"project_description": str(full_data.get("project_description", "")),
		"project_version": str(full_data.get("project_version", "")),
		"project_path": str(full_data.get("project_path", "")),
		"godot_version": str(full_data.get("godot_version", "")),
		"godot_version_string": str(full_data.get("godot_version_string", "")),
		"main_scene": str(full_data.get("main_scene", "")),
		"main_scene_exists": bool(full_data.get("main_scene_exists", false)),
		"current_scene": str(full_data.get("current_scene", "")),
		"has_dotnet": bool(full_data.get("has_dotnet", false)),
		"dotnet_project_count": int(full_data.get("dotnet_project_count", 0)),
		"dotnet_projects": full_data.get("dotnet_projects", [])
	}


func _build_project_state_files_section(full_data: Dictionary) -> Dictionary:
	return {
		"scripts": int(full_data.get("scripts", 0)),
		"gd_scripts": int(full_data.get("gd_scripts", 0)),
		"cs_scripts": int(full_data.get("cs_scripts", 0)),
		"scenes": int(full_data.get("scenes", 0)),
		"resources": int(full_data.get("resources", 0)),
		"scene_paths": full_data.get("scene_paths", []),
		"script_paths": full_data.get("script_paths", []),
		"resource_paths": full_data.get("resource_paths", []),
		"file_enumeration_status": str(full_data.get("file_enumeration_status", "ok")),
		"valid_file_enumeration": bool(full_data.get("valid_file_enumeration", true)),
		"file_enumeration": full_data.get("file_enumeration", {}),
		"enumeration_diagnostics": full_data.get("enumeration_diagnostics", [])
	}


func _build_project_state_runtime_section(full_data: Dictionary) -> Dictionary:
	return {
		"running": bool(full_data.get("running", false)),
		"runtime_bridge_status": str(full_data.get("runtime_bridge_status", "unknown")),
		"session_count": int(full_data.get("session_count", 0)),
		"compile_error_count": int(full_data.get("compile_error_count", 0)),
		"recent_errors": full_data.get("recent_errors", []),
		"recent_warnings": full_data.get("recent_warnings", []),
		"error_count": int(full_data.get("error_count", 0)),
		"warning_count": int(full_data.get("warning_count", 0))
	}


func _build_project_state_health_section(full_data: Dictionary) -> Dictionary:
	var health = full_data.get("runtime_health", {})
	if health is Dictionary and not (health as Dictionary).is_empty():
		return (health as Dictionary).duplicate(true)
	return {
		"self_diagnostics": _get_self_diagnostics_health_summary(),
		"lsp_diagnostics": _get_lsp_runtime_health_summary(),
		"tool_loader": _get_tool_loader_health_summary(),
		"freshness": PluginInstanceFreshness.get_freshness_snapshot(),
		"capabilities": full_data.get("runtime_capabilities", {})
	}


func _execute_editor_state(_args: Dictionary) -> Dictionary:
	var runtime_control_status := _build_runtime_control_state_section()
	var project_section := _build_project_state_summary()
	var result_data := {
		"editor": _build_editor_state_section(),
		"inspector": _build_inspector_state_section(),
		"filesystem": _build_filesystem_state_section(),
		"project": project_section,
		"runtime_control": runtime_control_status,
		"runtime_capabilities": project_section.get("runtime_capabilities", {}) if project_section is Dictionary else {}
	}
	return bridge.success(result_data, "Editor state snapshot fetched")


func _execute_project_configure(args: Dictionary) -> Dictionary:
	var action := str(args.get("action", "")).strip_edges()
	var setting := str(args.get("setting", "")).strip_edges()
	match action:
		"get_settings":
			if setting.is_empty():
				return bridge.error("setting path is required for get_settings")
			return bridge.call_atomic("project_info", {"action": "get_settings", "setting": setting})
		"set_setting":
			if setting.is_empty():
				return bridge.error("setting path is required for set_setting")
			return bridge.call_atomic("project_settings", {"action": "set", "setting": setting, "value": args.get("value", null)})
		"list_autoloads":
			return bridge.call_atomic("project_autoload", {"action": "list"})
		"add_autoload":
			return bridge.call_atomic("project_autoload", {
				"action": "add",
				"name": str(args.get("name", "")),
				"path": str(args.get("path", ""))
			})
		"remove_autoload":
			return bridge.call_atomic("project_autoload", {
				"action": "remove",
				"name": str(args.get("name", ""))
			})
		"list_input_actions":
			return bridge.call_atomic("project_input", {"action": "list_actions"})
		_:
			return bridge.error("Unknown action: %s. Valid: get_settings, set_setting, list_autoloads, add_autoload, remove_autoload, list_input_actions" % action)


func _execute_project_files(args: Dictionary) -> Dictionary:
	var action := str(args.get("action", "")).strip_edges()
	match action:
		"list_dir":
			return bridge.call_atomic("filesystem_directory", {
				"action": "get_files",
				"path": str(args.get("path", "res://")),
				"filter": str(args.get("filter", "*")),
				"recursive": bool(args.get("recursive", false))
			})
		"create_dir":
			return bridge.call_atomic("filesystem_directory", {"action": "create", "path": str(args.get("path", ""))})
		"delete_dir":
			return bridge.call_atomic("filesystem_directory", {"action": "delete", "path": str(args.get("path", ""))})
		"read_file":
			return bridge.call_atomic("filesystem_file_read", {"action": "read", "path": str(args.get("path", ""))})
		"write_file":
			return bridge.call_atomic("filesystem_file_write", {
				"action": "write",
				"path": str(args.get("path", "")),
				"content": str(args.get("content", ""))
			})
		"delete_file":
			return bridge.call_atomic("filesystem_file_manage", {"action": "delete", "path": str(args.get("path", ""))})
		"copy_file":
			return bridge.call_atomic("filesystem_file_manage", {
				"action": "copy",
				"source": str(args.get("source", "")),
				"dest": str(args.get("dest", ""))
			})
		"move_file":
			return bridge.call_atomic("filesystem_file_manage", {
				"action": "move",
				"source": str(args.get("source", "")),
				"dest": str(args.get("dest", ""))
			})
		"select_file":
			return bridge.call_atomic("editor_filesystem", {"action": "select_file", "path": str(args.get("path", ""))})
		"get_selected":
			return bridge.call_atomic("editor_filesystem", {"action": "get_selected"})
		"get_current_path":
			return bridge.call_atomic("editor_filesystem", {"action": "get_current_path"})
		"scan":
			return bridge.call_atomic("editor_filesystem", {"action": "scan"})
		"reimport":
			return bridge.call_atomic("editor_filesystem", {"action": "reimport", "paths": args.get("paths", [])})
		_:
			return bridge.error("Unknown project_files action: %s" % action)


func _execute_project_run(args: Dictionary) -> Dictionary:
	if _has_run_log_markers(args):
		return bridge.error("project_run marker validation requires async tool execution", {
			"error_code": "project_run_marker_validation_requires_async",
			"hint": "Call system_project_run through the async MCP tool path when success_markers or failure_markers are supplied."
		})
	var custom_scene := str(args.get("scene", "")).strip_edges()
	var timeout_ms := int(args.get("timeout_ms", 0))
	if _project_run_foreground_options_requested(args):
		return bridge.error("Project run without foreground focus is not supported by this editor session.", _build_project_run_foreground_required_context(custom_scene, args))
	var run_result := _start_project_run(custom_scene)
	if not bool(run_result.get("success", false)):
		MCPDebugBuffer.record("warning", "system",
			"project_run failed: %s" % str(run_result.get("error", "unknown")))
		return bridge.error("Failed to start project: %s" % str(run_result.get("error", "unknown")), _build_project_run_failure_context(custom_scene, run_result))
	var auto_stop_enabled := timeout_ms > 0
	if auto_stop_enabled:
		_schedule_project_auto_stop(timeout_ms, custom_scene if not custom_scene.is_empty() else "main")
	else:
		_project_run_timeout_token += 1
	return bridge.success({
		"started": true,
		"scene": custom_scene if not custom_scene.is_empty() else "main",
		"auto_stop_scheduled": auto_stop_enabled,
		"timeout_ms": timeout_ms if auto_stop_enabled else 0,
		"runtime_capabilities": _build_project_run_success_capabilities(custom_scene)
	}, str(run_result.get("message", "Project started")))


func _execute_project_run_with_log_markers(args: Dictionary) -> Dictionary:
	var custom_scene := str(args.get("scene", "")).strip_edges()
	if _project_run_foreground_options_requested(args):
		return bridge.error("Project run without foreground focus is not supported by this editor session.", _build_project_run_foreground_required_context(custom_scene, args))
	var success_markers := _normalize_marker_list(args.get("success_markers", []))
	var failure_markers := _normalize_marker_list(args.get("failure_markers", []))
	if success_markers.is_empty() and failure_markers.is_empty():
		return _execute_project_run(args)
	var validation_error := _validate_run_log_markers(success_markers, failure_markers)
	if not validation_error.is_empty():
		return bridge.error(str(validation_error.get("message", "Invalid runtime log marker arguments.")), validation_error)
	var timeout_ms: int = clamp(int(args.get("timeout_ms", _RUN_LOG_MARKER_DEFAULT_TIMEOUT_MS)), 1, _RUN_LOG_MARKER_MAX_TIMEOUT_MS)
	var poll_interval_ms: int = clamp(int(args.get("poll_interval_ms", _RUN_LOG_MARKER_DEFAULT_POLL_INTERVAL_MS)), _RUN_LOG_MARKER_MIN_POLL_INTERVAL_MS, _RUN_LOG_MARKER_MAX_POLL_INTERVAL_MS)
	var log_tail: int = clamp(int(args.get("log_tail", _RUN_LOG_MARKER_DEFAULT_LOG_TAIL)), 1, _RUN_LOG_MARKER_MAX_LOG_TAIL)
	var auto_stop := bool(args.get("auto_stop", true))
	var baseline := _build_runtime_event_baseline(_fetch_runtime_log_events(log_tail))
	var run_result := _start_project_run(custom_scene)
	if not bool(run_result.get("success", false)):
		MCPDebugBuffer.record("warning", "system",
			"project_run failed: %s" % str(run_result.get("error", "unknown")))
		return bridge.error("Failed to start project: %s" % str(run_result.get("error", "unknown")), _build_project_run_failure_context(custom_scene, run_result))
	_project_run_timeout_token += 1
	var validation: Dictionary = await _wait_for_runtime_log_marker(success_markers, failure_markers, baseline, timeout_ms, poll_interval_ms, log_tail)
	var stop_result: Dictionary = {}
	if auto_stop:
		stop_result = _stop_project_after_marker_validation(custom_scene if not custom_scene.is_empty() else "main", str(validation.get("status", "unknown")))
	var result_data := {
		"started": true,
		"scene": custom_scene if not custom_scene.is_empty() else "main",
		"auto_stop_scheduled": false,
		"auto_stop": auto_stop,
		"timeout_ms": timeout_ms,
		"poll_interval_ms": poll_interval_ms,
		"log_tail": log_tail,
		"validation": validation,
		"runtime_capabilities": _build_project_run_success_capabilities(custom_scene)
	}
	if auto_stop:
		result_data["stop_result"] = stop_result
	match str(validation.get("status", "")):
		"passed":
			return bridge.success(result_data, "Project started and runtime log marker validation passed")
		"failed":
			result_data["error_code"] = "run_log_failure_marker_matched"
			return bridge.error("Runtime log failure marker matched: %s" % str(validation.get("matched_marker", "")), result_data)
		_:
			result_data["error_code"] = "run_log_marker_timeout"
			return bridge.error("Runtime log marker validation timed out after %d ms" % timeout_ms, result_data)


func _start_project_run(custom_scene: String) -> Dictionary:
	MCPDebugBuffer.record("debug", "system",
		"project_run: scene=%s" % (custom_scene if not custom_scene.is_empty() else "main"))
	if custom_scene.is_empty():
		return bridge.call_atomic("scene_run", {"action": "play_main"})
	return bridge.call_atomic("scene_run", {"action": "play_custom", "path": custom_scene})


func _has_run_log_markers(args: Dictionary) -> bool:
	return not _normalize_marker_list(args.get("success_markers", [])).is_empty() or not _normalize_marker_list(args.get("failure_markers", [])).is_empty()


func _normalize_marker_list(raw_value) -> Array[String]:
	var markers: Array[String] = []
	if raw_value is Array:
		for raw_marker in raw_value:
			var marker := str(raw_marker).strip_edges()
			if not marker.is_empty():
				markers.append(marker)
	elif raw_value is String:
		var marker := str(raw_value).strip_edges()
		if not marker.is_empty():
			markers.append(marker)
	return markers


func _validate_run_log_markers(success_markers: Array[String], failure_markers: Array[String]) -> Dictionary:
	var marker_count := success_markers.size() + failure_markers.size()
	if marker_count > _RUN_LOG_MARKER_MAX_COUNT:
		return {
			"error_code": "invalid_argument",
			"message": "Runtime log marker validation accepts at most %d markers." % _RUN_LOG_MARKER_MAX_COUNT,
			"max_marker_count": _RUN_LOG_MARKER_MAX_COUNT,
			"marker_count": marker_count
		}
	for marker in success_markers + failure_markers:
		if marker.length() > _RUN_LOG_MARKER_MAX_LENGTH:
			return {
				"error_code": "invalid_argument",
				"message": "Runtime log markers must be at most %d characters." % _RUN_LOG_MARKER_MAX_LENGTH,
				"max_marker_length": _RUN_LOG_MARKER_MAX_LENGTH,
				"marker_length": marker.length()
			}
	return {}


func _wait_for_runtime_log_marker(success_markers: Array[String], failure_markers: Array[String], baseline: Dictionary, timeout_ms: int, poll_interval_ms: int, log_tail: int) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var started_ms := Time.get_ticks_msec()
	var cursor_event_id := int(baseline.get("max_event_id", -1))
	while Time.get_ticks_msec() - started_ms <= timeout_ms:
		var elapsed_ms := Time.get_ticks_msec() - started_ms
		var recent_events := _fetch_runtime_log_events_after(cursor_event_id, log_tail)
		cursor_event_id = _max_runtime_event_id(recent_events, cursor_event_id)
		var failure_match := _find_marker_match(recent_events, failure_markers, "failure")
		if not failure_match.is_empty():
			failure_match["elapsed_ms"] = elapsed_ms
			return _build_marker_validation_result("failed", failure_match, success_markers, failure_markers)
		var success_match := _find_marker_match(recent_events, success_markers, "success")
		if not success_match.is_empty():
			success_match["elapsed_ms"] = elapsed_ms
			return _build_marker_validation_result("passed", success_match, success_markers, failure_markers)
		if tree == null:
			break
		if recent_events.size() >= log_tail:
			await tree.process_frame
			continue
		var remaining_ms: int = timeout_ms - elapsed_ms
		if remaining_ms <= 0:
			break
		await tree.create_timer(float(min(poll_interval_ms, remaining_ms)) / 1000.0).timeout
	return {
		"status": "timeout",
		"error_code": "run_log_marker_timeout",
		"timeout_ms": timeout_ms,
		"success_markers": success_markers,
		"failure_markers": failure_markers,
		"message": "No runtime bridge log marker matched before timeout."
	}


func _build_marker_validation_result(status: String, marker_match: Dictionary, success_markers: Array[String], failure_markers: Array[String]) -> Dictionary:
	return {
		"status": status,
		"matched_marker": str(marker_match.get("marker", "")),
		"matched_type": str(marker_match.get("marker_type", "")),
		"matched_event": marker_match.get("event", {}),
		"matched_text": str(marker_match.get("text", "")),
		"elapsed_ms": int(marker_match.get("elapsed_ms", 0)),
		"success_markers": success_markers,
		"failure_markers": failure_markers
	}


func _fetch_runtime_log_events(log_tail: int) -> Array:
	var result: Dictionary = bridge.call_atomic("debug_runtime_bridge", {"action": "get_recent", "limit": log_tail})
	if not bool(result.get("success", false)):
		result = bridge.call_atomic("debug_runtime_bridge", {"action": "get_recent_filtered", "limit": log_tail, "tail": log_tail})
	return bridge.extract_array(result, "events")


func _fetch_runtime_log_events_after(after_event_id: int, log_tail: int) -> Array:
	var result: Dictionary = bridge.call_atomic("debug_runtime_bridge", {"action": "get_since_event_id", "after_event_id": after_event_id, "limit": log_tail})
	if bool(result.get("success", false)):
		return bridge.extract_array(result, "events")
	return _filter_new_runtime_events(_fetch_runtime_log_events(log_tail), {"max_event_id": after_event_id})


func _max_runtime_event_id(events: Array, fallback_event_id: int) -> int:
	var max_event_id := fallback_event_id
	for event in events:
		if event is Dictionary and (event as Dictionary).has("event_id"):
			max_event_id = maxi(max_event_id, int((event as Dictionary).get("event_id", -1)))
	return max_event_id


func _build_runtime_event_baseline(events: Array) -> Dictionary:
	var max_event_id := -1
	for event in events:
		if not (event is Dictionary):
			continue
		var event_dict := event as Dictionary
		if event_dict.has("event_id"):
			max_event_id = maxi(max_event_id, int(event_dict.get("event_id", -1)))
	return {"max_event_id": max_event_id}


func _filter_new_runtime_events(events: Array, baseline: Dictionary) -> Array:
	var max_event_id := int(baseline.get("max_event_id", -1))
	var filtered: Array = []
	for event in events:
		if not (event is Dictionary) or not (event as Dictionary).has("event_id"):
			continue
		if int((event as Dictionary).get("event_id", -1)) <= max_event_id:
			continue
		filtered.append(event)
	return filtered


func _find_marker_match(events: Array, markers: Array[String], marker_type: String) -> Dictionary:
	if markers.is_empty():
		return {}
	for event_index in range(events.size()):
		var event = events[event_index]
		if not (event is Dictionary):
			continue
		var search_text := _build_runtime_event_search_text(event)
		for marker in markers:
			if search_text.find(marker) != -1:
				return {
					"marker": marker,
					"marker_type": marker_type,
					"event_index": event_index,
					"event": (event as Dictionary).duplicate(true),
					"text": search_text
				}
	return {}


func _build_runtime_event_search_text(event: Dictionary) -> String:
	var parts: Array[String] = [str(event.get("kind", ""))]
	_append_runtime_log_text(event.get("payload", {}), parts)
	return "\n".join(parts)


func _append_runtime_log_text(value, parts: Array[String]) -> void:
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			parts.append(str(key))
			_append_runtime_log_text((value as Dictionary).get(key), parts)
	elif value is Array:
		for item in value:
			_append_runtime_log_text(item, parts)
	else:
		parts.append(str(value))


func _stop_project_after_marker_validation(scene_label: String, validation_status: String) -> Dictionary:
	MCPDebugBuffer.record("info", "system", "project_run marker validation auto-stop: scene=%s status=%s" % [scene_label, validation_status])
	return bridge.call_atomic("scene_run", {"action": "stop"})


func _project_run_foreground_options_requested(args: Dictionary) -> bool:
	return bool(args.get("background", false)) or bool(args.get("minimized", false)) or bool(args.get("no_focus", false))


func _build_project_run_foreground_required_context(custom_scene: String, args: Dictionary) -> Dictionary:
	var project_info_result: Dictionary = bridge.call_atomic("project_info", {"action": "get_info"})
	var project_info: Dictionary = bridge.extract_data(project_info_result)
	var dotnet_build_result: Dictionary = bridge.call_atomic("debug_dotnet", {"action": "build"})
	var dotnet_build_data: Dictionary = bridge.extract_data(dotnet_build_result)
	var runtime_summary := _get_runtime_summary()
	var runtime_control_status := _build_runtime_control_state_section()
	return {
		"error_code": "requires_foreground_window",
		"requested_scene": custom_scene if not custom_scene.is_empty() else "main",
		"requested_options": {
			"background": bool(args.get("background", false)),
			"minimized": bool(args.get("minimized", false)),
			"no_focus": bool(args.get("no_focus", false))
		},
		"can_run_without_focus": false,
		"foreground_window_policy": "requires_foreground_window",
		"degradation_paths": ["headless_logic_test", "editor_screenshot"],
		"recovery_suggestions": [
			"Run without background/minimized/no_focus when foreground runtime interaction is acceptable.",
			"Use headless logic tests for non-visual acceptance flows.",
			"Use editor screenshots when visual QA can be performed without starting a runtime window."
		],
		"runtime_control_status": runtime_control_status,
		"runtime_capabilities": _build_runtime_capabilities(project_info, dotnet_build_data, runtime_summary, runtime_control_status)
	}


func _build_project_run_failure_context(custom_scene: String, run_result: Dictionary) -> Dictionary:
	var project_info_result: Dictionary = bridge.call_atomic("project_info", {"action": "get_info"})
	var project_info: Dictionary = bridge.extract_data(project_info_result)
	var dotnet_build_result: Dictionary = bridge.call_atomic("debug_dotnet", {"action": "build"})
	var dotnet_build_data: Dictionary = bridge.extract_data(dotnet_build_result)
	var runtime_summary := _get_runtime_summary()
	var runtime_control_status := _build_runtime_control_state_section()
	var main_scene := str(project_info.get("main_scene", ""))
	var requested_scene := custom_scene if not custom_scene.is_empty() else main_scene
	var scene_exists := not requested_scene.is_empty() and FileAccess.file_exists(requested_scene)
	var editor_context := _build_editor_runtime_context()
	var runtime_capabilities := _build_runtime_capabilities(project_info, dotnet_build_data, runtime_summary, runtime_control_status)
	var context := {
		"error_code": "project_run_failed",
		"requested_scene": custom_scene if not custom_scene.is_empty() else "main",
		"resolved_scene": requested_scene,
		"scene_exists": scene_exists,
		"main_scene": main_scene,
		"main_scene_exists": not main_scene.is_empty() and FileAccess.file_exists(main_scene),
		"compile_error_count": int(dotnet_build_data.get("error_count", 0)),
		"editor_context": editor_context,
		"runtime_control_status": runtime_control_status,
		"runtime_capabilities": runtime_capabilities,
		"run_result": run_result.duplicate(true)
	}
	if _is_editor_interface_unavailable_inconsistent(run_result, editor_context, runtime_capabilities):
		context["error_code"] = "editor_run_interface_unavailable_despite_state_available"
		context["state_probe_vs_run_invoker"] = _build_project_run_state_probe_comparison(editor_context, runtime_capabilities, run_result)
		context["recovery_suggestions"] = _build_project_run_editor_interface_recovery_suggestions()
		var cli_fallback := _build_project_run_cli_fallback(editor_context, requested_scene, scene_exists)
		if not cli_fallback.is_empty():
			context["cli_fallback"] = cli_fallback
	return context


func _is_editor_interface_unavailable_inconsistent(run_result: Dictionary, editor_context: Dictionary, runtime_capabilities: Dictionary) -> bool:
	var run_error := "%s %s" % [str(run_result.get("error", "")), str(run_result.get("message", ""))]
	if not run_error.contains("Editor interface not available"):
		return false
	return bool(runtime_capabilities.get("can_start_project", false)) or bool(editor_context.get("editor_interface_available", false))


func _build_project_run_state_probe_comparison(editor_context: Dictionary, runtime_capabilities: Dictionary, run_result: Dictionary) -> Dictionary:
	return {
		"state_probe": {
			"editor_interface_available": bool(editor_context.get("editor_interface_available", false)),
			"can_start_project": bool(runtime_capabilities.get("can_start_project", false)),
			"blocking_reasons": runtime_capabilities.get("blocking_reasons", []),
			"godot_executable_path": str(editor_context.get("godot_executable_path", "")),
			"project_root_path": str(editor_context.get("project_root_path", ""))
		},
		"run_invoker": {
			"success": bool(run_result.get("success", false)),
			"error": str(run_result.get("error", "")),
			"message": str(run_result.get("message", ""))
		},
		"interpretation": "State probing reported the editor run path as available, but the scene run invoker could not access EditorInterface."
	}


func _build_project_run_editor_interface_recovery_suggestions() -> Array[String]:
	return [
		"Retry system_project_state or system_editor_state to confirm the current MCP connection is attached to the intended Godot editor session.",
		"Reload the Godot .NET MCP plugin with system_plugin_reload(action=full_reload_plugin), reconnect the MCP client, then retry system_project_run.",
		"If multiple Godot editors are open, close stale sessions or reconnect to the editor that owns this project.",
		"If editor launching remains unavailable, use the cli_fallback command from this response to run the scene outside the editor."
	]


func _build_project_run_cli_fallback(editor_context: Dictionary, requested_scene: String, scene_exists: bool) -> Dictionary:
	var godot_executable_path := str(editor_context.get("godot_executable_path", ""))
	var project_root_path := str(editor_context.get("project_root_path", ""))
	if godot_executable_path.is_empty() or project_root_path.is_empty() or requested_scene.is_empty() or not scene_exists:
		return {}
	var scene_path := requested_scene
	if scene_path.begins_with("res://"):
		scene_path = ProjectSettings.globalize_path(scene_path)
	return {
		"description": "Safe CLI fallback for manual verification when the editor run invoker cannot access EditorInterface.",
		"command": [godot_executable_path, "--path", project_root_path, scene_path],
		"working_directory": project_root_path
	}


func _build_project_run_success_capabilities(custom_scene: String) -> Dictionary:
	var project_info: Dictionary = bridge.extract_data(bridge.call_atomic("project_info", {"action": "get_info"}))
	if not custom_scene.is_empty():
		project_info["main_scene"] = custom_scene
	var dotnet_build_data: Dictionary = bridge.extract_data(bridge.call_atomic("debug_dotnet", {"action": "build"}))
	return _build_runtime_capabilities(project_info, dotnet_build_data, _get_runtime_summary(), _build_runtime_control_state_section())


func _execute_project_stop(_args: Dictionary) -> Dictionary:
	_project_run_timeout_token += 1
	MCPDebugBuffer.record("debug", "system", "project_stop: stopping project")
	var stop_result: Dictionary = bridge.call_atomic("scene_run", {"action": "stop"})
	if not bool(stop_result.get("success", false)):
		MCPDebugBuffer.record("warning", "system",
			"project_stop failed: %s" % str(stop_result.get("error", "unknown")))
		return bridge.error("Failed to stop project: %s" % str(stop_result.get("error", "unknown")))
	return bridge.success({"stopped": true}, "Project stopped")


func _execute_runtime_diagnose(args: Dictionary) -> Dictionary:
	var include_compile_errors := bool(args.get("include_compile_errors", true))
	var include_performance := bool(args.get("include_performance", false))
	var include_gd_errors := bool(args.get("include_gd_errors", false))
	var tail: int = max(int(args.get("tail", 20)), 1)

	var runtime_errors_raw: Array = bridge.extract_array(
		bridge.call_atomic("debug_runtime_bridge", {"action": "get_errors_context", "limit": tail}),
		"errors"
	)
	var runtime_errors: Array = []
	for raw in runtime_errors_raw:
		if not (raw is Dictionary):
			continue
		runtime_errors.append({
			"timestamp": str((raw as Dictionary).get("timestamp_text", (raw as Dictionary).get("timestamp", ""))),
			"error_type": str((raw as Dictionary).get("error_type", "error")),
			"message": str((raw as Dictionary).get("message", "")),
			"script": str((raw as Dictionary).get("script", "")),
			"line": int((raw as Dictionary).get("line", 0)),
			"node": str((raw as Dictionary).get("node", "")),
			"stacktrace": (raw as Dictionary).get("stacktrace", [])
		})

	var compile_errors: Array = []
	var compile_error_count := 0
	if include_compile_errors:
		var dotnet_data: Dictionary = bridge.extract_data(bridge.call_atomic("debug_dotnet", {"action": "build"}))
		compile_error_count = int(dotnet_data.get("error_count", 0))
		for raw in dotnet_data.get("errors", []):
			if not (raw is Dictionary):
				continue
			compile_errors.append({
				"severity": str((raw as Dictionary).get("severity", "error")),
				"code": str((raw as Dictionary).get("code", "")),
				"message": str((raw as Dictionary).get("message", "")),
				"source_file": str((raw as Dictionary).get("source_file", "")),
				"source_path": str((raw as Dictionary).get("source_path", "")),
				"source_line": int((raw as Dictionary).get("source_line", 0))
			})

	var performance: Dictionary = {}
	if include_performance:
		var fps_data: Dictionary = bridge.extract_data(bridge.call_atomic("debug_performance", {"action": "get_fps"}))
		var mem_data: Dictionary = bridge.extract_data(bridge.call_atomic("debug_performance", {"action": "get_memory"}))
		var render_data: Dictionary = bridge.extract_data(bridge.call_atomic("debug_performance", {"action": "get_render_info"}))
		performance = {"fps": fps_data, "memory": mem_data, "render": render_data}

	var gd_errors: Array = []
	var gd_error_count := 0
	if include_gd_errors:
		var el_result: Dictionary = bridge.call_atomic("debug_editor_log", {"action": "get_errors", "limit": 50})
		if bool(el_result.get("success", false)):
			var el_data: Dictionary = bridge.extract_data(el_result)
			gd_error_count = int(el_data.get("error_count", 0))
			for raw in el_data.get("errors", []):
				if raw is Dictionary:
					gd_errors.append(raw)

	var result_data: Dictionary = {
		"has_errors": not runtime_errors.is_empty() or compile_error_count > 0 or gd_error_count > 0,
		"runtime_error_count": runtime_errors.size(),
		"runtime_errors": runtime_errors,
		"compile_error_count": compile_error_count,
		"compile_errors": compile_errors,
		"performance": performance
	}
	if include_gd_errors:
		result_data["gd_error_count"] = gd_error_count
		result_data["gd_errors"] = gd_errors
	return bridge.success(result_data)


func _schedule_project_auto_stop(timeout_ms: int, scene_label: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		MCPDebugBuffer.record("warning", "system", "project_run auto-stop skipped: SceneTree unavailable")
		return
	_project_run_timeout_token += 1
	var token := _project_run_timeout_token
	var timer: SceneTreeTimer = tree.create_timer(float(timeout_ms) / 1000.0)
	timer.timeout.connect(Callable(self, "_on_project_run_timeout").bind(token, scene_label, timeout_ms), CONNECT_ONE_SHOT)


func _on_project_run_timeout(token: int, scene_label: String, timeout_ms: int) -> void:
	if token != _project_run_timeout_token:
		return
	if bridge == null:
		return
	MCPDebugBuffer.record("info", "system", "project_run auto-stop: scene=%s timeout_ms=%d" % [scene_label, timeout_ms])
	bridge.call_atomic("scene_run", {"action": "stop"})
