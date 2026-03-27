@tool
extends "res://addons/godot_dotnet_mcp/tools/system/project/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var goal := str(args.get("goal", "general")).strip_edges()
	MCPDebugBuffer.record("debug", "system", "project_advise: goal=%s" % goal)
	var include_suggestions := bool(args.get("include_suggestions", true))
	var include_workflow := bool(args.get("include_workflow", true))
	if goal.is_empty():
		goal = "general"

	var project_info: Dictionary = bridge.extract_data(bridge.call_atomic("project_info", {"action": "get_info"}))
	var dotnet_result: Dictionary = bridge.call_atomic("project_dotnet", {})
	var runtime_summary := _get_runtime_summary()
	var compile_error_count := 0
	if bool(dotnet_result.get("success", false)):
		var dotnet_errors_data: Dictionary = bridge.extract_data(bridge.call_atomic("debug_dotnet", {"action": "build"}))
		compile_error_count = int(dotnet_errors_data.get("error_count", 0))

	var cs_count: int = (bridge.collect_files("*.cs") as Array).size()
	var scene_count_val: int = (bridge.collect_files("*.tscn") as Array).size()
	var error_count := int(runtime_summary.get("error_count", 0))
	var warning_count := int(runtime_summary.get("warning_count", 0))
	var main_scene := str(project_info.get("main_scene", ""))

	var suggestions: Array = []
	var next_tools: Array = []
	if include_suggestions:
		if main_scene.is_empty():
			suggestions.append({"category": "structure", "severity": "error", "message": "Project has no configured main scene.", "tool_hint": "project_state"})
		elif not FileAccess.file_exists(main_scene):
			suggestions.append({"category": "structure", "severity": "error", "message": "Configured main scene does not exist: %s" % main_scene, "tool_hint": "scene_validate"})
		if error_count > 0:
			suggestions.append({"category": "runtime", "severity": "error", "message": "Recent runtime errors detected. Diagnose bindings or scene integrity.", "tool_hint": "bindings_audit"})
		if cs_count > 0:
			suggestions.append({"category": "dotnet", "severity": "info", "message": "Project contains C# scripts. Run bindings_audit to verify consistency.", "tool_hint": "bindings_audit"})
		if scene_count_val > 0:
			suggestions.append({"category": "index", "severity": "info", "message": "Use project_symbol_search or scene_dependency_graph to build and reuse the internal project index on demand.", "tool_hint": "project_symbol_search"})
		if warning_count > 0 and error_count == 0:
			suggestions.append({"category": "runtime", "severity": "warning", "message": "Recent runtime warnings detected. Review scene setup before patching.", "tool_hint": "scene_validate"})
		if compile_error_count > 0:
			suggestions.append({"category": "dotnet", "severity": "error", "message": "C# compile errors detected (%d). Fix before running." % compile_error_count, "tool_hint": "runtime_diagnose"})

	if include_workflow:
		next_tools.append("project_state")
		if error_count > 0 or compile_error_count > 0:
			next_tools.append("runtime_diagnose")
			next_tools.append("bindings_audit")
			next_tools.append("scene_validate")
		if _goal_contains(goal, ["symbol", "index", "search", "class"]) and not ("project_symbol_search" in next_tools):
			next_tools.append("project_symbol_search")
		if _goal_contains(goal, ["scene", "dependency"]) and not ("scene_dependency_graph" in next_tools):
			next_tools.append("scene_dependency_graph")
		if cs_count > 0 and not _goal_contains(goal, ["symbol", "index", "search"]) and not ("bindings_audit" in next_tools):
			next_tools.append("bindings_audit")
		if not ("project_advise" in next_tools):
			next_tools.append("project_advise")

	var has_issues := false
	for suggestion in suggestions:
		if suggestion is Dictionary and str((suggestion as Dictionary).get("severity", "")) in ["error", "warning"]:
			has_issues = true
			break

	return bridge.success({
		"goal": goal,
		"has_issues": has_issues,
		"suggestion_count": suggestions.size(),
		"suggestions": suggestions,
		"next_tools": next_tools
	})
