@tool
extends "res://addons/godot_dotnet_mcp/tools/system/script/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var script_path := str(args.get("script", "")).strip_edges()
	var include_diagnostics := bool(args.get("include_diagnostics", false))
	if script_path.is_empty():
		return bridge.error("script path is required")
	if not (script_path.ends_with(".gd") or script_path.ends_with(".cs")):
		return bridge.error("script must be a .gd or .cs file")
	if not FileAccess.file_exists(script_path):
		MCPDebugBuffer.record("warning", "system", "script_analyze: file not found: %s" % script_path)
		return bridge.error("Script file not found: %s" % script_path)
	MCPDebugBuffer.record("debug", "system", "script_analyze: %s" % script_path)

	var inspect_data: Dictionary = bridge.extract_data(bridge.call_atomic("script_inspect", {"path": script_path}))
	var symbols_data: Dictionary = bridge.extract_data(bridge.call_atomic("script_symbols", {"path": script_path}))
	var exports_data: Dictionary = bridge.extract_data(bridge.call_atomic("script_exports", {"path": script_path}))
	var refs_data: Dictionary = bridge.extract_data(bridge.call_atomic("script_references", {
		"action": "get_scene_refs",
		"path": script_path
	}))
	var base_type_data: Dictionary = bridge.extract_data(bridge.call_atomic("script_references", {
		"action": "get_base_type",
		"path": script_path
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
	for scene_path in refs_data.get("scenes", []):
		scene_refs.append(str(scene_path))

	var issues: Array = []
	if scene_refs.is_empty():
		issues.append(bridge.build_issue("info", "no_scene_reference", "Script is not referenced by any discovered scene.", {"script": script_path}))

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
		var diagnostics_source := FileAccess.get_file_as_string(script_path)
		var diagnostics_service = _get_gdscript_lsp_diagnostics_service()
		var diagnostics_result: Dictionary = {}
		if diagnostics_service != null and diagnostics_service.has_method("request_diagnostics"):
			var diagnostics_result_raw = diagnostics_service.request_diagnostics(script_path, diagnostics_source)
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
		result_data["diagnostics"] = diagnostics_result
		result_data["diagnostics_status"] = _build_diagnostics_status_summary(diagnostics_result)

	return bridge.success(result_data)
