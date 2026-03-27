@tool
extends "res://addons/godot_dotnet_mcp/tools/system/script/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var target_script := str(args.get("script", "")).strip_edges()
	var target_scene := str(args.get("scene", "")).strip_edges()
	var include_warnings := bool(args.get("include_warnings", true))
	var results: Array = []

	if not target_script.is_empty():
		if not target_script.ends_with(".cs"):
			return bridge.error("bindings_audit only supports C# scripts (.cs)")
		MCPDebugBuffer.record("debug", "system", "bindings_audit: script=%s" % target_script)
		results.append(_audit_script(target_script, include_warnings))
	elif not target_scene.is_empty():
		if not target_scene.ends_with(".tscn"):
			return bridge.error("scene must be a .tscn file")
		MCPDebugBuffer.record("debug", "system", "bindings_audit: scene=%s" % target_scene)
		results.append(_audit_scene(target_scene, include_warnings))
	else:
		var cs_scripts: Array = bridge.collect_files("*.cs")
		MCPDebugBuffer.record("debug", "system", "bindings_audit: scanning %d C# scripts" % cs_scripts.size())
		for script_path in cs_scripts:
			results.append(_audit_script(str(script_path), include_warnings))

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
		"script": target_script,
		"scene": target_scene,
		"target_count": results.size(),
		"targets_with_issues": targets_with_issues,
		"total_issues": total_issues,
		"results": results
	})


func _audit_scene(scene_path: String, include_warnings: bool) -> Dictionary:
	var bindings_data: Dictionary = bridge.extract_data(bridge.call_atomic("scene_bindings", {
		"action": "from_path",
		"path": scene_path
	}))
	var audit_data: Dictionary = bridge.extract_data(bridge.call_atomic("scene_audit", {
		"action": "from_path",
		"path": scene_path
	}))
	var issues: Array = []
	for issue in audit_data.get("issues", []):
		if issue is Dictionary:
			bridge.append_unique_issue(issues, (issue as Dictionary).duplicate(true))
	for issue in bindings_data.get("issues", []):
		if issue is Dictionary:
			bridge.append_unique_issue(issues, (issue as Dictionary).duplicate(true))
	if include_warnings and issues.is_empty():
		bridge.append_unique_issue(issues, bridge.build_issue("info", "scene_clean", "Scene bindings and audit checks returned no issues.", {"scene": scene_path}))
	return {
		"kind": "scene",
		"scene": scene_path,
		"binding_count": int(bindings_data.get("binding_count", bindings_data.get("count", 0))),
		"issue_count": issues.size(),
		"issues": issues
	}


func _audit_script(script_path: String, include_warnings: bool) -> Dictionary:
	var inspect_data: Dictionary = bridge.extract_data(bridge.call_atomic("script_inspect", {"path": script_path}))
	var references_data: Dictionary = bridge.extract_data(bridge.call_atomic("script_references", {
		"action": "get_scene_refs",
		"path": script_path
	}))
	var base_type_data: Dictionary = bridge.extract_data(bridge.call_atomic("script_references", {
		"action": "get_base_type",
		"path": script_path
	}))
	var issues: Array = []
	var scenes: Array = []
	for scene_path in references_data.get("scenes", []):
		scenes.append(str(scene_path))

	if scenes.is_empty():
		bridge.append_unique_issue(issues, bridge.build_issue("warning" if include_warnings else "info", "no_scene_reference", "Script is not referenced by any discovered scene.", {"script": script_path}))

	var exports = inspect_data.get("exports", [])
	if include_warnings and exports is Array and (exports as Array).is_empty():
		bridge.append_unique_issue(issues, bridge.build_issue("info", "no_exports", "Script declares no exported members.", {"script": script_path}))

	var signals_list = inspect_data.get("signals", [])
	if include_warnings and signals_list is Array and (signals_list as Array).is_empty():
		bridge.append_unique_issue(issues, bridge.build_issue("info", "no_signals", "Script declares no signals.", {"script": script_path}))

	for scene_path in scenes:
		var scene_audit := _audit_scene(scene_path, include_warnings)
		for issue in scene_audit.get("issues", []):
			if not (issue is Dictionary):
				continue
			var scene_issue: Dictionary = (issue as Dictionary).duplicate(true)
			scene_issue["script"] = script_path
			bridge.append_unique_issue(issues, scene_issue)

	return {
		"kind": "script",
		"script": script_path,
		"class_name": str(inspect_data.get("class_name", "")),
		"base_type": str(base_type_data.get("base_type", inspect_data.get("base_type", ""))),
		"language": str(inspect_data.get("language", "")),
		"scene_count": scenes.size(),
		"scenes": scenes,
		"issue_count": issues.size(),
		"issues": issues
	}
