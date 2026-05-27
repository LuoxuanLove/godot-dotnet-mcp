@tool
extends RefCounted
class_name MCPPromptsService

const SCENE_BOOTSTRAP_PROMPT := "godot.scene_bootstrap"
const DEBUG_TRIAGE_PROMPT := "godot.debug_triage"
const BINDING_FIX_PROMPT := "godot.binding_fix"
const MCPPathArgumentNormalizerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_path_argument_normalizer.gd")

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
			"description": "Plan scene work from live editor context before editing nodes or files.",
			"arguments": [
				{"name": "scene_path", "description": "Optional scene path to inspect first.", "required": false},
				{"name": "goal", "description": "Optional user goal for the scene change.", "required": false}
			]
		}, {
			"name": DEBUG_TRIAGE_PROMPT,
			"description": "Triage runtime, editor, or build errors with the recommended diagnostics order.",
			"arguments": [
				{"name": "error_summary", "description": "Observed error summary.", "required": false},
				{"name": "include_runtime", "description": "Whether runtime diagnostics should be included.", "required": false}
			]
		}, {
			"name": BINDING_FIX_PROMPT,
			"description": "Investigate and fix C# export, signal, or NodePath binding mismatches.",
			"arguments": [
				{"name": "script_path", "description": "C# or GDScript path to inspect.", "required": false},
				{"name": "scene_path", "description": "Scene path to audit.", "required": false},
				{"name": "binding_name", "description": "Optional binding or signal name.", "required": false}
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
	var text := "Start scene work by calling system_help, system_project_state, and system_scene_validate before editing."
	if not scene_path.is_empty():
		text += " Target scene: %s." % scene_path
	if not goal.is_empty():
		text += " Goal: %s." % goal
	text += " Prefer system_scene_analyze, system_scene_patch, and system_scene_tree for scene changes."
	return _prompt_response("Scene bootstrap", text)


func _build_debug_triage_prompt(arguments: Dictionary) -> Dictionary:
	var error_summary := str(arguments.get("error_summary", "")).strip_edges()
	var include_runtime := bool(arguments.get("include_runtime", false))
	var text := "Start debugging with system_project_state and system_editor_log, then call system_runtime_diagnose when runtime evidence is needed."
	if include_runtime:
		text += " Include runtime_diagnose output and runtime capability state before proposing fixes."
	if not error_summary.is_empty():
		text += " Observed error summary: %s." % error_summary
	return _prompt_response("Debug triage", text)


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
	var text := "Use system_bindings_audit before editing C# export, signal, or NodePath bindings."
	if not script_path.is_empty():
		text += " Inspect script: %s." % script_path
	if not scene_path.is_empty():
		text += " Audit scene: %s." % scene_path
	if not binding_name.is_empty():
		text += " Binding of interest: %s." % binding_name
	text += " Confirm the scene reference and script declaration agree before patching."
	return _prompt_response("Binding fix", text)


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
