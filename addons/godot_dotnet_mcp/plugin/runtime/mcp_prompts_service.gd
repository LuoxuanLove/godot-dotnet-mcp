@tool
extends RefCounted
class_name MCPPromptsService

const PROJECT_ORIENTATION_PROMPT := "godot.project_orientation"
const CONTENT_AUTHORING_PROMPT := "godot.content_authoring"
const DEBUG_TRIAGE_PROMPT := "godot.debug_triage"
const REFERENCE_INTEGRITY_PROMPT := "godot.reference_integrity"
const RUNTIME_VALIDATION_PROMPT := "godot.runtime_validation"
const EDITOR_UI_CONTROL_PROMPT := "godot.editor_ui_control"
const MCPPathArgumentNormalizerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_path_argument_normalizer.gd")
const LocalizationServiceScript = preload("res://addons/godot_dotnet_mcp/localization/localization_service.gd")
const MAX_PROMPT_TEXT_BYTES := 32768

var _get_tool_loader_status := Callable()


func configure(context = null) -> void:
	if context == null:
		dispose()
		return
	_get_tool_loader_status = context.get_tool_loader_status


func dispose() -> void:
	_get_tool_loader_status = Callable()


func build_prompts_list_result(_params: Dictionary = {}) -> Dictionary:
	return {
		"prompts": [{
			"name": PROJECT_ORIENTATION_PROMPT,
			"title": _text("prompt_project_orientation_title", "Project orientation workflow"),
			"description": _text("prompt_project_orientation_desc", "Orient an agent in a Godot project with read-only state, health, file, symbol, and scene dependency evidence before choosing an editing or debugging workflow."),
			"arguments": [
				{"name": "goal", "description": _text("prompt_arg_goal_desc", "Optional user goal that should shape the workflow and validation checks."), "required": false},
				{"name": "symbol", "description": _text("prompt_arg_symbol_desc", "Optional class, script, scene, or symbol name to search after building the project index."), "required": false}
			]
		}, {
			"name": CONTENT_AUTHORING_PROMPT,
			"title": _text("prompt_content_authoring_title", "Content authoring workflow"),
			"description": _text("prompt_content_authoring_desc", "Create or modify scenes, nodes, scripts, resources, and small project settings through safe analysis, dry-run previews, and focused validation."),
			"arguments": [
				{"name": "scene_path", "description": _text("prompt_arg_scene_path_desc", "Optional res:// scene path to validate and analyze before editing."), "required": false},
				{"name": "script_path", "description": _text("prompt_arg_script_path_desc", "Optional C# or GDScript path whose declarations should be inspected."), "required": false},
				{"name": "goal", "description": _text("prompt_arg_goal_desc", "Optional user goal that should shape the workflow and validation checks."), "required": false}
			]
		}, {
			"name": DEBUG_TRIAGE_PROMPT,
			"title": _text("prompt_debug_triage_title", "Debug triage workflow"),
			"description": _text("prompt_debug_triage_desc", "Triage Godot editor, build, runtime, or DAP failures with an evidence-first order that separates logs, project state, runtime diagnostics, and debugger data."),
			"arguments": [
				{"name": "error_summary", "description": _text("prompt_arg_error_summary_desc", "Optional observed error text or symptom that should be preserved in the triage plan."), "required": false},
				{"name": "include_runtime", "description": _text("prompt_arg_include_runtime_desc", "Optional boolean indicating whether runtime diagnostics and capability checks are needed."), "required": false}
			]
		}, {
			"name": REFERENCE_INTEGRITY_PROMPT,
			"title": _text("prompt_reference_integrity_title", "Reference integrity workflow"),
			"description": _text("prompt_reference_integrity_desc", "Repair scene, script, signal, export, NodePath, resource UID/path, and C# Resource references after auditing the affected graph."),
			"arguments": [
				{"name": "script_path", "description": _text("prompt_arg_script_path_desc", "Optional C# or GDScript path whose declarations should be inspected."), "required": false},
				{"name": "scene_path", "description": _text("prompt_arg_scene_path_desc", "Optional res:// scene path to validate and analyze before editing."), "required": false},
				{"name": "resource_path", "description": _text("prompt_arg_resource_path_desc", "Optional res:// .tscn or .tres path to audit for UID, fallback path, or script reference consistency."), "required": false},
				{"name": "binding_name", "description": _text("prompt_arg_binding_name_desc", "Optional export, signal, or NodePath binding name that should receive focused attention."), "required": false}
			]
		}, {
			"name": RUNTIME_VALIDATION_PROMPT,
			"title": _text("prompt_runtime_validation_title", "Runtime validation workflow"),
			"description": _text("prompt_runtime_validation_desc", "Run a project or scene, wait for structured markers, arm runtime control, send inputs, and capture frames to validate behavior."),
			"arguments": [
				{"name": "scene_path", "description": _text("prompt_arg_scene_path_desc", "Optional res:// scene path to validate and analyze before editing."), "required": false},
				{"name": "goal", "description": _text("prompt_arg_goal_desc", "Optional user goal that should shape the workflow and validation checks."), "required": false},
				{"name": "success_marker", "description": _text("prompt_arg_success_marker_desc", "Optional structured runtime bridge marker text that should indicate validation success."), "required": false}
			]
		}, {
			"name": EDITOR_UI_CONTROL_PROMPT,
			"title": _text("prompt_editor_ui_control_title", "Editor UI control workflow"),
			"description": _text("prompt_editor_ui_control_desc", "Control Godot editor docks, panels, popups, screenshots, visible and hidden controls, and control-local input through editor APIs."),
			"arguments": [
				{"name": "ui_goal", "description": _text("prompt_arg_ui_goal_desc", "Optional editor UI outcome such as opening a dock, clicking a button, entering text, or verifying layout."), "required": false},
				{"name": "target_path", "description": _text("prompt_arg_target_path_desc", "Optional control or popup path returned by list_controls/list_popups that should receive focused inspection, capture, or interaction."), "required": false}
			]
		}]
	}


func build_prompts_get_result(params: Dictionary) -> Dictionary:
	var name := str(params.get("name", ""))
	var arguments = params.get("arguments", {})
	if not (arguments is Dictionary):
		return {"success": false, "error": "Prompt arguments must be an object."}
	match name:
		PROJECT_ORIENTATION_PROMPT:
			return _build_project_orientation_prompt(arguments as Dictionary)
		CONTENT_AUTHORING_PROMPT:
			return _build_content_authoring_prompt(arguments as Dictionary)
		DEBUG_TRIAGE_PROMPT:
			return _build_debug_triage_prompt(arguments as Dictionary)
		REFERENCE_INTEGRITY_PROMPT:
			return _build_reference_integrity_prompt(arguments as Dictionary)
		RUNTIME_VALIDATION_PROMPT:
			return _build_runtime_validation_prompt(arguments as Dictionary)
		EDITOR_UI_CONTROL_PROMPT:
			return _build_editor_ui_control_prompt(arguments as Dictionary)
		_:
			return {"success": false, "error": "Unknown prompt: %s" % name}


func _build_project_orientation_prompt(arguments: Dictionary) -> Dictionary:
	var goal := str(arguments.get("goal", "")).strip_edges()
	var symbol := str(arguments.get("symbol", "")).strip_edges()
	var text := _text("prompt_project_orientation_body", "Use when: Start here when connecting to an unfamiliar Godot project or when a task needs project-level context before choosing an edit, debug, or validation path. Recommended workflow: 1. Call system_help to confirm current MCP capabilities and the available six Prompt Guides. 2. Call system_project_state with summary=true or sections=[summary,project,runtime,capabilities] for a lightweight health snapshot before requesting full file arrays. 3. Call system_editor_state when the current editor selection, inspector, or UI state may affect the task. 4. When names or relationships matter, call system_project_index_build, then system_project_symbol_search or system_scene_dependency_graph. 5. Use system_project_files only for targeted file-tree reads, selections, scans, or reimports after the orientation evidence narrows the scope. Validation: cite the project path, current errors or blockers, relevant symbols or dependency edges, and the next Prompt Guide or tool family chosen from the evidence. Avoid: do not modify files, launch the project, or perform broad recursive reads during orientation.")
	if not goal.is_empty():
		text += " Goal: %s." % goal
	if not symbol.is_empty():
		text += " Symbol or target name: %s." % symbol
	return _prompt_response(_text("prompt_project_orientation_title", "Project orientation workflow"), text)


func _build_content_authoring_prompt(arguments: Dictionary) -> Dictionary:
	var scene_path_result := _optional_res_path(arguments, "scene_path", [".tscn", ".scn"])
	if not bool(scene_path_result.get("success", false)):
		return scene_path_result
	var script_path_result := _optional_res_path(arguments, "script_path", [".cs", ".gd"])
	if not bool(script_path_result.get("success", false)):
		return script_path_result
	var scene_path := str(scene_path_result.get("path", ""))
	var script_path := str(script_path_result.get("path", ""))
	var goal := str(arguments.get("goal", "")).strip_edges()
	var text := _text("prompt_content_authoring_body", "Use when: Start here before creating or modifying Godot content such as scenes, nodes, scripts, resources, visual settings, or small project configuration that directly supports the current content change. Recommended workflow: 1. Call system_project_state to confirm errors and capability blockers, and use godot.project_orientation first if the target is not known. 2. For scene-backed work, call system_scene_validate, then system_scene_analyze before changing nodes, properties, scripts, or resources. 3. For script-backed work, call system_script_analyze before using system_script_patch; prefer dry_run=true previews before applying member-level changes. 4. Choose system_scene_patch for file-safe scene edits, system_scene_tree for the live edited scene, system_project_configure for narrow settings/autoload/input changes, and project or visual tools only after the target is grounded. 5. Keep edits minimal and scoped to the user goal. Validation: re-read the changed scene or script with system_scene_validate, system_scene_analyze, or system_script_analyze, then hand off to godot.runtime_validation when behavior must be proven in a running project. Avoid: do not diagnose unrelated failures here, do not repair reference graphs without godot.reference_integrity, and do not use OS mouse automation for editor UI tasks.")
	if not scene_path.is_empty():
		text += " Target scene: %s." % scene_path
	if not script_path.is_empty():
		text += " Target script: %s." % script_path
	if not goal.is_empty():
		text += " Goal: %s." % goal
	return _prompt_response(_text("prompt_content_authoring_title", "Content authoring workflow"), text)


func _build_debug_triage_prompt(arguments: Dictionary) -> Dictionary:
	var error_summary := str(arguments.get("error_summary", "")).strip_edges()
	var include_runtime := bool(arguments.get("include_runtime", false))
	var text := _text("prompt_debug_triage_body", "Use when: Start here when a Godot editor warning, build failure, runtime exception, DAP symptom, or unclear failure needs diagnosis before choosing a fix. Recommended workflow: 1. Call system_project_state to separate compile errors, runtime state, file enumeration, capability blockers, and project health. 2. Call system_editor_log for current Output warnings and errors before changing code. 3. If runtime evidence is relevant, call system_runtime_diagnose and include runtime capability state before proposing a fix. 4. If normal logs are insufficient or a debugger session is required, use system_dap_debugger(status), then initialize or attach, configure breakpoints, continue or step, inspect threads, stack_trace, and output, and terminate or disconnect cleanly. 5. Fix the root cause with the smallest relevant content, reference, or configuration workflow, then re-run the same diagnostic surface. Validation: cite the failing evidence, the changed evidence after the fix, any DAP session facts used, and any remaining unrelated warnings. Avoid: do not create a separate DAP-only workflow, do not hide symptoms with broad guards, and do not skip compile or runtime evidence.")
	if include_runtime:
		text += " Include runtime_diagnose output and runtime capability state before proposing fixes."
	if not error_summary.is_empty():
		text += " Observed error summary: %s." % error_summary
	return _prompt_response(_text("prompt_debug_triage_title", "Debug triage workflow"), text)


func _build_reference_integrity_prompt(arguments: Dictionary) -> Dictionary:
	var script_path_result := _optional_res_path(arguments, "script_path", [".cs", ".gd"])
	if not bool(script_path_result.get("success", false)):
		return script_path_result
	var scene_path_result := _optional_res_path(arguments, "scene_path", [".tscn", ".scn"])
	if not bool(scene_path_result.get("success", false)):
		return scene_path_result
	var resource_path_result := _optional_res_path(arguments, "resource_path", [".tscn", ".tres"])
	if not bool(resource_path_result.get("success", false)):
		return resource_path_result
	var script_path := str(script_path_result.get("path", ""))
	var scene_path := str(scene_path_result.get("path", ""))
	var resource_path := str(resource_path_result.get("path", ""))
	var binding_name := str(arguments.get("binding_name", "")).strip_edges()
	var text := _text("prompt_reference_integrity_body", "Use when: Start here when C#, GDScript, export, signal, NodePath, scene dependency, resource UID, fallback path, or C# Resource script references disagree with saved scenes and resources. Recommended workflow: 1. Call system_bindings_audit with the script or scene path when member declarations may disagree with scene references. 2. Call system_resource_reference_audit for project-wide or focused .tscn/.tres UID, fallback path, and Resource script consistency checks. 3. Call system_scene_validate to confirm the scene reference graph is loadable and system_script_analyze to ground exported members, signals, variables, and methods in saved source. 4. Compare the audited reference with the declaration or resource path, then apply the smallest matching rename, property, signal, UID/path, or script reference fix. 5. Re-run the same audit tools and validation on the same targets. Validation: the audited issue should disappear, the scene or resource should still validate, and no unrelated scene, resource, or binding reference should change. Avoid: do not add duplicate fallback bindings, do not rewrite unrelated node paths, and do not treat a passing .NET build as proof that resource references are valid.")
	if not script_path.is_empty():
		text += " Inspect script: %s." % script_path
	if not scene_path.is_empty():
		text += " Audit scene: %s." % scene_path
	if not resource_path.is_empty():
		text += " Audit resource: %s." % resource_path
	if not binding_name.is_empty():
		text += " Binding of interest: %s." % binding_name
	return _prompt_response(_text("prompt_reference_integrity_title", "Reference integrity workflow"), text)


func _build_runtime_validation_prompt(arguments: Dictionary) -> Dictionary:
	var scene_path_result := _optional_res_path(arguments, "scene_path", [".tscn", ".scn"])
	if not bool(scene_path_result.get("success", false)):
		return scene_path_result
	var scene_path := str(scene_path_result.get("path", ""))
	var goal := str(arguments.get("goal", "")).strip_edges()
	var success_marker := str(arguments.get("success_marker", "")).strip_edges()
	var text := _text("prompt_runtime_validation_body", "Use when: Start here when behavior must be proven by running a project or scene, waiting for structured markers, driving runtime input, or capturing one or more frames. Recommended workflow: 1. Call system_project_state and inspect runtime_capabilities before launching; do not request background, minimized, or no-focus launch unless the capability state says it is supported. 2. Call system_project_lifecycle(action=start) with a scene path when needed, and use success_markers and failure_markers when the project emits structured runtime bridge events that can prove the check. 3. Pair every start with system_project_lifecycle(action=stop) or marker-mode auto_stop unless the user explicitly needs the run to remain active. 4. For interactive checks, call system_runtime_control(action=enable), then system_runtime_step(action=input), system_runtime_step(action=step), or system_runtime_step(action=capture) with bounded waits and capture labels. 5. Use system_runtime_diagnose only when validation produces errors, then transfer root-cause work to godot.debug_triage. Validation: report the lifecycle result, matched marker or timeout status, runtime control state, capture path or skipped reason, and whether the evidence satisfies the user goal. Avoid: do not treat launch success as behavior success, do not leave runs active by accident, and do not use runtime automation before arming a commandable session.")
	if not scene_path.is_empty():
		text += " Scene to run: %s." % scene_path
	if not goal.is_empty():
		text += " Validation goal: %s." % goal
	if not success_marker.is_empty():
		text += " Expected success marker: %s." % success_marker
	return _prompt_response(_text("prompt_runtime_validation_title", "Runtime validation workflow"), text)


func _build_editor_ui_control_prompt(arguments: Dictionary) -> Dictionary:
	var ui_goal := str(arguments.get("ui_goal", "")).strip_edges()
	var target_path := str(arguments.get("target_path", "")).strip_edges()
	var text := _text("prompt_editor_ui_control_body", "Use when: Start here when a task depends on the current Godot editor UI, including docks, plugin panels, bottom panels, popups, settings dialogs, Inspector properties, layout, focus, button visibility, screenshots, or control-local text and value edits. Recommended workflow: 1. Call system_editor_state to capture the current main screen, selections, inspector summary, runtime state, and editor capability context. 2. Semantic/workflow tools first: for Project Settings or Editor Settings use system_settings_dialog(action=run_task) for trusted locate/read/set/verify/capture tasks, then use open, observe, search, list or activate settings tabs, list or focus category tree items, list read-only row models, resolve_row, read current values, focus value editors, set supported values, verify expected values, capture, or close the settings surface when you need individual steps; for Inspector properties use system_inspector(action=run_task), then list_properties, resolve_property, read_value, focus_value, set_value, verify_value, or capture when you need individual steps. 3. Evidence before interaction: use system_editor_evidence(action=capture) with surface=auto/editor/control/popup/active_dialog before layout or visibility judgment so the result reports the requested surface, actual backend, target path, visible popup metadata, fallback reasons, and degraded state; use list_controls with include_hidden=false then include_hidden=true when needed, and use get_control or list_popups/get_popup when choosing a precise target_path. 4. Editor navigation and control-level operations second: for other editor surfaces use system_editor_control(action=activate_ui), activate_dock_tab, set_main_screen, list_menus/open_menu/select_menu_item, and list_tree_items/select_tree_item before raw control actions; use focus_control or activate_control for focus/buttons, set_control_text for text, set_value for numeric values, and press_popup_button, select_popup_menu_item, set_popup_text, or close_popup for popup controls. 5. Mouse/coordinate events are fallback only: use click_control, right_click_control, hover_control, or leave_control only when no semantic/workflow or control-level action exists, for context menus, tooltip checks, or pointer-event validation, and only with Control-local coordinates returned by these tools. Validation: capture or list the resulting control state, popup state, settings dialog status, Inspector property status, or editor log evidence after the UI action. Avoid: do not use OS mouse or window automation unless explicitly authorized, do not guess screen coordinates, and do not use editor UI control when scene_patch or script_patch can safely make the file-level change.")
	if not ui_goal.is_empty():
		text += " UI goal: %s." % ui_goal
	if not target_path.is_empty():
		text += " Target control path: %s." % target_path
	return _prompt_response(_text("prompt_editor_ui_control_title", "Editor UI control workflow"), text)


func _text(key: String, fallback: String) -> String:
	var localization = LocalizationServiceScript.get_instance()
	var text := str(localization.get_text(key)) if localization != null else key
	if text == key or text.is_empty():
		return fallback
	return text


func _prompt_response(description: String, text: String) -> Dictionary:
	var limited := _limit_text_output(text, MAX_PROMPT_TEXT_BYTES)
	var result := {
		"description": description,
		"messages": [{
			"role": "user",
			"content": {"type": "text", "text": str(limited.get("text", ""))}
		}]
	}
	if bool(limited.get("truncated", false)):
		result["_meta"] = {
			"godotDotnetMcp": {
				"output": {
					"truncated": true,
					"originalByteSize": int(limited.get("original_byte_size", 0)),
					"returnedByteSize": int(limited.get("returned_byte_size", 0)),
					"maxByteSize": int(limited.get("max_byte_size", MAX_PROMPT_TEXT_BYTES))
				}
			}
		}
	return result


func _optional_res_path(arguments: Dictionary, key: String, allowed_extensions: Array[String]) -> Dictionary:
	if not arguments.has(key):
		return {"success": true, "path": ""}
	var raw_value = arguments.get(key, "")
	if not (raw_value is String):
		return {"success": false, "error": "Path argument '%s' must be a string." % key}
	return MCPPathArgumentNormalizerScript.normalize_project_path(str(raw_value), allowed_extensions, "path argument '%s'" % key, true)


func _get_loader_status_safe() -> Dictionary:
	if _get_tool_loader_status.is_valid():
		var status = _get_tool_loader_status.call()
		if status is Dictionary:
			return (status as Dictionary).duplicate(true)
	return {}


func _limit_text_output(text: String, max_byte_size: int) -> Dictionary:
	var original_byte_size := text.to_utf8_buffer().size()
	if original_byte_size <= max_byte_size:
		return {
			"text": text,
			"truncated": false,
			"original_byte_size": original_byte_size,
			"returned_byte_size": original_byte_size,
			"max_byte_size": max_byte_size
		}
	var limited_text := _truncate_text_to_utf8_byte_limit(text, max_byte_size)
	return {
		"text": limited_text,
		"truncated": true,
		"original_byte_size": original_byte_size,
		"returned_byte_size": limited_text.to_utf8_buffer().size(),
		"max_byte_size": max_byte_size
	}


func _truncate_text_to_utf8_byte_limit(text: String, max_byte_size: int) -> String:
	var low := 0
	var high := text.length()
	while low < high:
		var mid := int(ceil(float(low + high + 1) / 2.0))
		if text.substr(0, mid).to_utf8_buffer().size() <= max_byte_size:
			low = mid
		else:
			high = mid - 1
	return text.substr(0, low)
