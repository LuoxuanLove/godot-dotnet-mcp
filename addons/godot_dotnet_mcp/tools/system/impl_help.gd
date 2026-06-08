@tool
extends RefCounted

## System implementation: help

const MCPProtocolFacts = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd")
const MCPPromptsServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_prompts_service.gd")
const LocalizationService = preload("res://addons/godot_dotnet_mcp/localization/localization_service.gd")

var bridge
var _runtime_context: Dictionary = {}

const HANDLED_TOOLS := ["help"]


func handles(tool_name: String) -> bool:
	return tool_name in HANDLED_TOOLS


func configure_runtime(context: Dictionary) -> void:
	_runtime_context = context.duplicate()


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
			"Call prompts/list and prompts/get when you need MCP-native workflow guides for project orientation, content authoring, debug triage, reference integrity, runtime validation, or editor UI control before choosing tools.",
			LocalizationService.translate("help_recommended_start_tool_activity"),
			"Call system_editor_state when the task depends on the current editor UI.",
			"Use system_settings_dialog(action=run_task) for trusted Project Settings or Editor Settings locate/read/set/verify/capture tasks, and split into open/status/search/list_tabs/activate_tab/list_categories/focus_category/list_rows/resolve_row/read_value/focus_value/set_value/verify_value/focus_result/capture/close only when you need individual workflow steps before falling back to raw editor control enumeration.",
			"Use system_inspector(action=run_task) for trusted Inspector property locate/read/set/verify/capture tasks on the currently edited object or a prepared node/resource target before falling back to raw control enumeration.",
			"Use system_editor_evidence(action=capture) when visual proof is needed; choose surface=auto/editor/control/popup/active_dialog so the result states what was captured, which backend ran, and whether fallback or degraded evidence occurred.",
			"Use system_editor_control(action=activate_ui) for non-invasive dock/plugin tab activation before considering foreground automation.",
			"Use system_editor_plugin_control to inspect or toggle third-party EditorPlugin session state; use dedicated plugin reload/update tools for this plugin itself.",
			"Prefer self-describing system_editor_evidence captures for UI or layout judgment before acting; default captures are stored under user://godot_dotnet_mcp/captures/.",
			"Use system_userdata_maintenance(action=list_capture_cache) to inspect managed screenshot caches, cleanup_capture_cache with dry_run=true to preview removal, and cleanup_legacy_cache for stale root-level MCP files; cleanup skips symlinks/junctions/reparse points and must only be applied by explicit Agent/user action.",
			"If a target UI is not found, retry system_editor_control(action=list_controls) with include_hidden=true."
		],
		"capabilities": {
			"project": ["state", "settings", "autoloads", "input actions", "run", "stop", "runtime diagnostics"],
			"prompts": ["MCP prompts/list discovery", "MCP prompts/get guided project orientation", "content authoring", "debug triage", "reference integrity", "runtime validation", "editor UI control"],
			"editor": ["self-describing visual evidence", "full editor screenshot", "control enumeration", "hidden control enumeration", "settings dialog navigation", "Inspector property workflow", "non-invasive dock/plugin/bottom-panel UI activation", "dock tab activation", "control capture", "popup capture", "focus", "safe activation", "popup control", "third-party EditorPlugin session diagnostics"],
			"runtime": ["debugger session arming", "single or sequence capture", "scripted input", "input-wait-capture step"],
			"dap": ["endpoint status", "runtime settings", "session IDs", "initialize", "launch/attach", "configuration_done", "breakpoint set/remove/list", "pause", "continue", "step over", "threads", "stack trace", "output events", "terminate/disconnect", "structured dap_unavailable"],
			"logs": ["Output panel read", "warnings/errors filter", "Output clear"],
			"analysis": ["scene validation", "scene analysis", "script analysis", "C# binding audit", "Godot LSP diagnostics", "project symbol search", "scene dependency graph"],
			"configuration": ["MCP client config inspection", "one-click CLI add/remove where supported", "install status path display"],
			"coordination": ["running tool call activity", "recent tool call history", "self-reported agent context", "execution order visibility"]
		},
		"runtime_capability_guidance": {
			"source": "system_project_state(include_runtime_health=true).runtime_capabilities and system_editor_state.runtime_capabilities",
			"read_only_tools_note": "Project, scene, and editor read-only tools can be available even when project launch, runtime control, or runtime capture is unavailable.",
			"check_before_running": ["can_start_project", "blocking_reasons", "headless_logic_ok", "visible_capture_required", "can_run_without_focus", "no_focus_launch_supported", "foreground_window_policy", "foreground_window_fallbacks"],
			"check_before_runtime_automation": ["can_control_runtime", "can_capture_runtime", "commandable_session_count"],
			"project_lifecycle_marker_validation": "system_project_lifecycle(action=start) can optionally wait for success_markers or failure_markers in structured debug_runtime_bridge events through the async MCP tool path. This is not universal stdout capture; markers are matched against runtime bridge event kind and payload text. In marker mode failure markers take precedence, timeout_ms is clamped as the wait timeout, log_tail is capped, and auto_stop defaults to true via scene_run stop only.",
			"foreground_window_note": "This plugin does not guarantee background, minimized, or no-focus runtime launch. Unsupported requests return requires_foreground_window with fallback guidance.",
			"external_process_note": "Externally launched visible Godot processes are not treated as commandable runtime sessions unless they attach through the editor debugger bridge."
		},
		"visual_guidance": {
			"prefer_editor_screenshot": true,
			"screenshot_tool": "system_editor_evidence",
			"screenshot_action": "capture",
			"capture_surfaces": ["auto", "editor", "control", "popup", "active_dialog"],
			"capture_contract": "Every evidence capture reports requested surface, actual backend, target path, visible popup metadata when available, fallback reasons, and degraded state.",
			"settings_dialog_tool": "system_settings_dialog",
			"inspector_tool": "system_inspector",
			"non_invasive_activation_action": "activate_ui",
			"avoid_os_mouse_window_automation": true,
			"hidden_controls_supported": true,
			"hidden_control_hint": "Use list_controls with include_hidden=true when visible enumeration misses a target.",
			"ui_automation_preference_order": [{
				"level": "semantic",
				"guidance": "Prefer semantic workflow and navigation tools before raw control actions.",
				"tools": ["system_settings_dialog", "system_inspector", "system_editor_evidence", "system_editor_control"],
				"actions": ["run_task", "resolve_property", "capture", "activate_ui", "activate_dock_tab", "set_main_screen", "list_menus", "open_menu", "select_menu_item", "list_tree_items", "select_tree_item"]
			}, {
				"level": "control",
				"guidance": "Use control-level focus, activation, text, value, and popup actions when no higher-level workflow covers the target.",
				"tools": ["system_editor_control"],
				"actions": ["focus_control", "activate_control", "set_control_text", "set_value", "press_popup_button", "select_popup_menu_item", "set_popup_text", "close_popup"]
			}, {
				"level": "mouse_fallback",
				"guidance": "Use mouse and pointer events only as a fallback for unsupported UI, context menus, tooltips, or pointer-event validation, with Control-local coordinates returned by the tools.",
				"tools": ["system_editor_control"],
				"actions": ["click_control", "right_click_control", "hover_control", "leave_control"]
			}]
		},
		"schema": {
			"tool_schema_version": str(facts.get("tool_schema_version", "")),
			"refresh_hint": "After plugin reload or schema changes, reconnect or fetch /api/tools again before relying on cached tool descriptions."
		},
		"prompt_guides": {
			"discovery_methods": ["prompts/list", "prompts/get"],
			"usage_note": "Prompt guides are MCP-native prompt templates, not tools/call actions. Use prompts/list to discover them and prompts/get with optional arguments to fetch the workflow text.",
			"available": _build_prompt_guide_entries()
		}
	}
	if include_tools:
		payload["exposed_system_tools"] = _collect_exposed_system_tools()
	return payload

func _build_prompt_guide_entries() -> Array[Dictionary]:
	var prompt_service = MCPPromptsServiceScript.new()
	var prompt_result: Dictionary = prompt_service.build_prompts_list_result()
	var prompts = prompt_result.get("prompts", [])
	var entries: Array[Dictionary] = []
	if prompts is Array:
		for prompt in prompts:
			if not (prompt is Dictionary):
				continue
			var prompt_data := prompt as Dictionary
			entries.append({
				"name": str(prompt_data.get("name", "")),
				"purpose": str(prompt_data.get("description", ""))
			})
	return entries

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
