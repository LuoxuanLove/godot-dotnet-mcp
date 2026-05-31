@tool
extends RefCounted
class_name MCPPromptsService

const SCENE_BOOTSTRAP_PROMPT := "godot.scene_bootstrap"
const DEBUG_TRIAGE_PROMPT := "godot.debug_triage"
const BINDING_FIX_PROMPT := "godot.binding_fix"
const MCPPathArgumentNormalizerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_path_argument_normalizer.gd")
const LocalizationServiceScript = preload("res://addons/godot_dotnet_mcp/localization/localization_service.gd")

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
			"name": SCENE_BOOTSTRAP_PROMPT,
			"title": _text("prompt_scene_bootstrap_title", "Scene workflow bootstrap"),
			"description": _text("prompt_scene_bootstrap_desc", "Plan scene edits from the live Godot editor context, validate the target scene first, and choose the safest scene tool before changing nodes or files."),
			"arguments": [
				{"name": "scene_path", "description": _text("prompt_arg_scene_path_desc", "Optional res:// scene path to validate and analyze before editing."), "required": false},
				{"name": "goal", "description": _text("prompt_arg_goal_desc", "Optional user goal that should shape the scene workflow and validation checks."), "required": false}
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
			"name": BINDING_FIX_PROMPT,
			"title": _text("prompt_binding_fix_title", "Binding repair workflow"),
			"description": _text("prompt_binding_fix_desc", "Investigate C#, GDScript, signal, export, and NodePath binding mismatches by auditing scene references before applying the smallest safe fix."),
			"arguments": [
				{"name": "script_path", "description": _text("prompt_arg_script_path_desc", "Optional C# or GDScript path whose declarations should be inspected."), "required": false},
				{"name": "scene_path", "description": _text("prompt_arg_scene_path_desc", "Optional res:// scene path to validate and analyze before editing."), "required": false},
				{"name": "binding_name", "description": _text("prompt_arg_binding_name_desc", "Optional export, signal, or NodePath binding name that should receive focused attention."), "required": false}
			]
		}]
	}


func build_prompts_get_result(params: Dictionary) -> Dictionary:
	var name := str(params.get("name", ""))
	var arguments = params.get("arguments", {})
	if not (arguments is Dictionary):
		return {"success": false, "error": "Prompt arguments must be an object."}
	match name:
		SCENE_BOOTSTRAP_PROMPT:
			return _build_scene_bootstrap_prompt(arguments as Dictionary)
		DEBUG_TRIAGE_PROMPT:
			return _build_debug_triage_prompt(arguments as Dictionary)
		BINDING_FIX_PROMPT:
			return _build_binding_fix_prompt(arguments as Dictionary)
		_:
			return {"success": false, "error": "Unknown prompt: %s" % name}


func _build_scene_bootstrap_prompt(arguments: Dictionary) -> Dictionary:
	var scene_path_result := _optional_res_path(arguments, "scene_path", [".tscn", ".scn"])
	if not bool(scene_path_result.get("success", false)):
		return scene_path_result
	var scene_path := str(scene_path_result.get("path", ""))
	var goal := str(arguments.get("goal", "")).strip_edges()
	var text := _text("prompt_scene_bootstrap_body", "Use when: Start here before changing a Godot scene, adding nodes, or editing scene-backed resources. Recommended workflow: 1. Call system_help to confirm current MCP capabilities and available prompt guides. 2. Call system_project_state to confirm project path, errors, and runtime capability state. 3. Call system_scene_validate on the target scene before editing. 4. Call system_scene_analyze when the scene loads so existing scripts, signals, and node structure are understood. 5. Use system_scene_patch for file-safe structural edits, or system_scene_tree when the edited scene is already open and must reflect live editor state. Validation: read back the scene with system_scene_validate or system_scene_analyze, then run the smallest relevant project or scene check before reporting completion. Avoid: do not patch a scene before validating that its current references are loadable.")
	if not scene_path.is_empty():
		text += " Target scene: %s." % scene_path
	if not goal.is_empty():
		text += " Goal: %s." % goal
	return _prompt_response(_text("prompt_scene_bootstrap_title", "Scene workflow bootstrap"), text)


func _build_debug_triage_prompt(arguments: Dictionary) -> Dictionary:
	var error_summary := str(arguments.get("error_summary", "")).strip_edges()
	var include_runtime := bool(arguments.get("include_runtime", false))
	var text := _text("prompt_debug_triage_body", "Use when: Start here when a Godot editor warning, build failure, runtime exception, DAP issue, or unclear symptom needs diagnosis. Recommended workflow: 1. Call system_project_state to separate compile errors, runtime state, file enumeration, and capability blockers. 2. Call system_editor_log for current Output warnings and errors before changing code. 3. If runtime evidence is relevant, call system_runtime_diagnose and include runtime capability state before proposing a fix. 4. If a DAP endpoint is involved, use system_dap_debugger(status) before breakpoints, stack traces, or stepping. 5. Fix the root cause with the smallest relevant tool and re-run the same diagnostic surface. Validation: cite the failing evidence, the changed evidence after the fix, and any remaining unrelated warnings. Avoid: do not hide symptoms with broad guards or skip compile/runtime evidence.")
	if include_runtime:
		text += " Include runtime_diagnose output and runtime capability state before proposing fixes."
	if not error_summary.is_empty():
		text += " Observed error summary: %s." % error_summary
	return _prompt_response(_text("prompt_debug_triage_title", "Debug triage workflow"), text)


func _build_binding_fix_prompt(arguments: Dictionary) -> Dictionary:
	var script_path_result := _optional_res_path(arguments, "script_path", [".cs", ".gd"])
	if not bool(script_path_result.get("success", false)):
		return script_path_result
	var scene_path_result := _optional_res_path(arguments, "scene_path", [".tscn", ".scn"])
	if not bool(scene_path_result.get("success", false)):
		return scene_path_result
	var script_path := str(script_path_result.get("path", ""))
	var scene_path := str(scene_path_result.get("path", ""))
	var binding_name := str(arguments.get("binding_name", "")).strip_edges()
	var text := _text("prompt_binding_fix_body", "Use when: Start here when C#, GDScript, export, signal, or NodePath bindings disagree with the scene. Recommended workflow: 1. Call system_bindings_audit with the script or scene path before editing binding declarations. 2. Call system_scene_validate to confirm the scene reference graph is loadable. 3. Call system_script_analyze for the script so exported members, signals, variables, and methods are grounded in saved source. 4. Compare the scene reference and script declaration, then apply the smallest matching rename, property, or signal fix. 5. Re-run system_bindings_audit and system_scene_validate on the same targets. Validation: the audited binding should disappear from the issue list, the scene should still validate, and no unrelated scene/resource reference should be changed. Avoid: do not add duplicate fallback bindings or change unrelated node paths.")
	if not script_path.is_empty():
		text += " Inspect script: %s." % script_path
	if not scene_path.is_empty():
		text += " Audit scene: %s." % scene_path
	if not binding_name.is_empty():
		text += " Binding of interest: %s." % binding_name
	return _prompt_response(_text("prompt_binding_fix_title", "Binding repair workflow"), text)


func _text(key: String, fallback: String) -> String:
	var localization = LocalizationServiceScript.get_instance()
	var text := str(localization.get_text(key)) if localization != null else key
	if text == key or text.is_empty():
		return fallback
	return text


func _prompt_response(description: String, text: String) -> Dictionary:
	return {
		"description": description,
		"messages": [{
			"role": "user",
			"content": {"type": "text", "text": text}
		}]
	}


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
