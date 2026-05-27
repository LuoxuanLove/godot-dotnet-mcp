@tool
extends RefCounted

## System implementation: help

const MCPProtocolFacts = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd")

var bridge
var _runtime_context: Dictionary = {}

const HANDLED_TOOLS := ["help"]


func handles(tool_name: String) -> bool:
	return tool_name in HANDLED_TOOLS


func configure_runtime(context: Dictionary) -> void:
	_runtime_context = context.duplicate(true)


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "help",
			"description": "HELP: Return the Godot .NET MCP capability guide for agents, including recommended first steps, visual verification guidance, hidden-control enumeration, runtime automation, logs, LSP diagnostics, and schema version facts.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"include_tools": {
						"type": "boolean",
						"description": "Include the currently exposed system tool names when available (default: true)"
					}
				}
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name not in HANDLED_TOOLS:
		return _error("Unknown tool: %s" % tool_name)
	var include_tools := bool(args.get("include_tools", true))
	var data := _build_help(include_tools)
	return {
		"success": true,
		"data": data,
		"message": "Godot .NET MCP help fetched"
	}


func _build_help(include_tools: bool) -> Dictionary:
	var facts := MCPProtocolFacts.build_server_facts()
	var payload := {
		"server": facts,
		"purpose": "Editor-native MCP tools for Godot 4.6+ .NET projects.",
		"recommended_start": [
			"Call system_project_state to confirm project path, Godot version, run state, and current errors.",
			"Call system_editor_state when the task depends on the current editor UI.",
			"Use system_editor_control(action=activate_ui) for non-invasive dock/plugin tab activation before considering foreground automation.",
			"Prefer system_editor_control(action=capture_editor) for UI or layout judgment before acting; default captures are stored under user://godot_dotnet_mcp/captures/.",
			"Use system_userdata_maintenance(action=list_capture_cache) to inspect managed screenshot caches, cleanup_capture_cache with dry_run=true to preview removal, and cleanup_legacy_cache for stale root-level MCP files; cleanup skips symlinks/junctions/reparse points and must only be applied by explicit Agent/user action.",
			"If a target UI is not found, retry system_editor_control(action=list_controls) with include_hidden=true."
		],
		"capabilities": {
			"project": ["state", "settings", "autoloads", "input actions", "run", "stop", "runtime diagnostics"],
			"editor": ["full editor screenshot", "control enumeration", "hidden control enumeration", "non-invasive dock/plugin/bottom-panel UI activation", "dock tab activation", "control capture", "focus", "safe activation", "popup control"],
			"runtime": ["debugger session arming", "single or sequence capture", "scripted input", "input-wait-capture step"],
			"dap": ["endpoint status", "breakpoint set/remove/list", "pause", "continue", "step over", "stack trace", "output events", "structured dap_unavailable"],
			"logs": ["Output panel read", "warnings/errors filter", "Output clear"],
			"analysis": ["scene validation", "scene analysis", "script analysis", "C# binding audit", "Godot LSP diagnostics", "project symbol search", "scene dependency graph"],
			"configuration": ["MCP client config inspection", "one-click CLI add/remove where supported", "install status path display"]
		},
		"runtime_capability_guidance": {
			"source": "system_project_state(include_runtime_health=true).runtime_capabilities and system_editor_state.runtime_capabilities",
			"read_only_tools_note": "Project, scene, and editor read-only tools can be available even when project launch, runtime control, or runtime capture is unavailable.",
			"check_before_running": ["can_start_project", "blocking_reasons", "headless_logic_ok", "visible_capture_required", "can_run_without_focus", "no_focus_launch_supported", "foreground_window_policy", "foreground_window_fallbacks"],
			"check_before_runtime_automation": ["can_control_runtime", "can_capture_runtime", "commandable_session_count"],
			"project_run_log_marker_validation": "system_project_run can optionally wait for success_markers or failure_markers in structured debug_runtime_bridge events through the async MCP tool path. This is not universal stdout capture; markers are matched against runtime bridge event kind and payload text. In marker mode failure markers take precedence, timeout_ms is clamped as the wait timeout, log_tail is capped, and auto_stop defaults to true via scene_run stop only.",
			"foreground_window_note": "This plugin does not guarantee background, minimized, or no-focus runtime launch. Unsupported requests return requires_foreground_window with fallback guidance.",
			"external_process_note": "Externally launched visible Godot processes are not treated as commandable runtime sessions unless they attach through the editor debugger bridge."
		},
		"visual_guidance": {
			"prefer_editor_screenshot": true,
			"screenshot_tool": "system_editor_control",
			"screenshot_action": "capture_editor",
			"non_invasive_activation_action": "activate_ui",
			"avoid_os_mouse_window_automation": true,
			"hidden_controls_supported": true,
			"hidden_control_hint": "Use list_controls with include_hidden=true when visible enumeration misses a target."
		},
		"schema": {
			"tool_schema_version": str(facts.get("tool_schema_version", "")),
			"refresh_hint": "After plugin reload or schema changes, reconnect or fetch /api/tools again before relying on cached tool descriptions."
		}
	}
	if include_tools:
		payload["exposed_system_tools"] = _collect_exposed_system_tools()
	return payload


func _collect_exposed_system_tools() -> Array[String]:
	var tool_loader = _runtime_context.get("tool_loader", null)
	if tool_loader == null or not tool_loader.has_method("get_exposed_tool_definitions"):
		return []
	var names: Array[String] = []
	for tool_def in tool_loader.get_exposed_tool_definitions():
		if not (tool_def is Dictionary):
			continue
		var name := str((tool_def as Dictionary).get("name", ""))
		if not name.is_empty():
			names.append(name)
	names.sort()
	return names


func _error(message: String) -> Dictionary:
	if bridge != null and bridge.has_method("error"):
		return bridge.error(message)
	return {
		"success": false,
		"error": message,
		"message": message
	}
