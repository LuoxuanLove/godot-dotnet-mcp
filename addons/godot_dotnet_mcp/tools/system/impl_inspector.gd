@tool
extends RefCounted

## System implementation: inspector

var bridge

const HANDLED_TOOLS := ["inspector"]
const DEFAULT_LIMIT := 100
const DEFAULT_MAX_DEPTH := 8
const SUPPORTED_WRITE_TYPES := ["text", "number", "bool"]


func handles(tool_name: String) -> bool:
	return tool_name in HANDLED_TOOLS


func configure_runtime(_context: Dictionary) -> void:
	pass


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "inspector",
			"description": "INSPECTOR: High-level Inspector workflow entry. Use it to inspect the current edited object or resource, list visible property models, resolve a unique property, read, focus, set, verify, capture, or run a trusted locate/read/set/verify/capture task. Writes are limited to uniquely matched visible value controls with supported text, number, or bool editors; complex resources, colors, arrays, dictionaries, object pickers, and file pickers are reported as unsupported.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["status", "edit_object", "inspect_resource", "refresh", "list_properties", "resolve_property", "read_value", "focus_value", "set_value", "verify_value", "run_task", "capture"],
						"description": "Inspector workflow action"
					},
					"node_path": {
						"type": "string",
						"description": "Node path to edit in the Inspector for edit_object/run_task"
					},
					"resource_path": {
						"type": "string",
						"description": "Resource path to inspect for inspect_resource/run_task"
					},
					"property_path": {
						"type": "string",
						"description": "Inspector property path or path fragment to resolve"
					},
					"query": {
						"type": "string",
						"description": "Text query for Inspector property model search"
					},
					"target_path": {
						"type": "string",
						"description": "Inspector property row or value control path returned by list_properties/resolve_property"
					},
					"value": {
						"description": "Value for set_value/run_task writes. First PR supports text, number, and bool-like controls only."
					},
					"expected_value": {
						"description": "Expected value for verify_value/run_task"
					},
					"capture_policy": {
						"type": "string",
						"enum": ["none", "final", "on_failure", "always"],
						"description": "Capture policy for run_task: none disables evidence capture, final attempts capture on successful completion, on_failure attempts capture only for failed tasks, and always attempts capture for both success and failure. Use require_capture=true when missing capture evidence should fail the task."
					},
					"require_capture": {
						"type": "boolean",
						"description": "When true, run_task fails if required evidence capture cannot use any backend"
					},
					"require_confidence": {
						"type": "string",
						"enum": ["low", "medium", "high"],
						"description": "Minimum property model confidence accepted by read/focus/set/verify/run_task (default medium)"
					},
					"include_hidden": {
						"type": "boolean",
						"description": "Include hidden controls while observing Inspector property controls (default false). Writes refuse include_hidden=true."
					},
					"include_raw_controls": {
						"type": "boolean",
						"description": "Include raw observed control summaries in list_properties for diagnostics (default false)"
					},
					"limit": {
						"type": "integer",
						"description": "Maximum controls or property models to inspect/return (default 100)"
					},
					"max_depth": {
						"type": "integer",
						"description": "Maximum editor control traversal depth while observing Inspector properties (default 8)"
					},
					"path": {
						"type": "string",
						"description": "Optional output screenshot path for capture/run_task evidence"
					}
				},
				"required": ["action"]
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name not in HANDLED_TOOLS:
		return bridge.error("Unknown tool: %s" % tool_name)
	var action = str(args.get("action", "")).strip_edges()
	match action:
		"status":
			return _status(args)
		"edit_object":
			return _edit_object(args)
		"inspect_resource":
			return _inspect_resource(args)
		"refresh":
			return bridge.call_atomic("editor_inspector", {"action": "refresh"})
		"list_properties":
			return _list_properties(args)
		"resolve_property":
			return _resolve_property(args)
		"read_value":
			return _read_value(args)
		"focus_value":
			return _focus_value(args)
		"set_value":
			return bridge.error("set_value requires asynchronous execution")
		"verify_value":
			return _verify_value(args)
		"run_task":
			return bridge.error("run_task requires asynchronous execution")
		"capture":
			return _capture(args)
		_:
			return bridge.error("Unknown action: %s" % action)


func execute_async(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name not in HANDLED_TOOLS:
		return bridge.error("Unknown tool: %s" % tool_name)
	var action = str(args.get("action", "")).strip_edges()
	match action:
		"set_value":
			return await _set_value(args)
		"run_task":
			return await _run_task(args)
		_:
			return execute(tool_name, args)


func _status(_args: Dictionary) -> Dictionary:
	var edited_result: Dictionary = bridge.call_atomic("editor_inspector", {"action": "get_edited"})
	var selected_result: Dictionary = bridge.call_atomic("editor_inspector", {"action": "get_selected_property"})
	var payload = {
		"edited": _safe_data(edited_result),
		"selected_property": str(_safe_data(selected_result).get("selected_path", "")),
		"available": bool(edited_result.get("success", false)) and bool(selected_result.get("success", false))
	}
	if not bool(edited_result.get("success", false)):
		return bridge.error(str(edited_result.get("message", "Inspector state is unavailable.")), payload)
	return bridge.success(payload, "Inspector status read")


func _edit_object(args: Dictionary) -> Dictionary:
	var node_path = str(args.get("node_path", args.get("path", ""))).strip_edges()
	if node_path.is_empty():
		return bridge.error("node_path is required")
	var result: Dictionary = bridge.call_atomic("editor_inspector", {"action": "edit_object", "path": node_path})
	if not bool(result.get("success", false)):
		return result
	var payload: Dictionary = _safe_data(result)
	payload["node_path"] = node_path
	return bridge.success(payload, "Inspector object selected")


func _inspect_resource(args: Dictionary) -> Dictionary:
	var resource_path = str(args.get("resource_path", "")).strip_edges()
	if resource_path.is_empty():
		return bridge.error("resource_path is required")
	var result: Dictionary = bridge.call_atomic("editor_inspector", {"action": "inspect_resource", "resource_path": resource_path})
	if not bool(result.get("success", false)):
		return result
	var payload: Dictionary = _safe_data(result)
	payload["resource_path"] = resource_path
	return bridge.success(payload, "Inspector resource selected")


func _list_properties(args: Dictionary) -> Dictionary:
	var observation = _observe(args)
	var properties: Array[Dictionary] = _property_models(observation.get("controls", []), args, _result_limit(args))
	var payload = {
		"edited": observation.get("edited", {}),
		"selected_property": observation.get("selected_property", ""),
		"inspector_root": observation.get("inspector_root", {}),
		"property_count": properties.size(),
		"properties": properties,
		"model_quality": _model_quality(properties)
	}
	if bool(args.get("include_raw_controls", false)):
		payload["raw_controls"] = observation.get("controls", [])
	return bridge.success(payload, "Inspector properties listed")


func _resolve_property(args: Dictionary) -> Dictionary:
	var observation = _observe(args)
	var resolution = _resolve_property_from_controls(observation.get("controls", []), args, true)
	var payload = {
		"edited": observation.get("edited", {}),
		"selected_property": observation.get("selected_property", ""),
		"inspector_root": observation.get("inspector_root", {}),
		"resolution": _sanitize_resolution(resolution)
	}
	if not bool(resolution.get("success", false)):
		return bridge.error(str(resolution.get("message", "Inspector property could not be resolved.")), payload)
	payload["property"] = _sanitize_property_model(resolution.get("property", {}))
	payload["property_path"] = str(payload.get("property", {}).get("property_path", ""))
	payload["row_control_path"] = str(payload.get("property", {}).get("row_control_path", ""))
	payload["value_control_path"] = str(payload.get("property", {}).get("value_control_path", ""))
	return bridge.success(payload, "Inspector property resolved")


func _read_value(args: Dictionary) -> Dictionary:
	var observation = _observe(args)
	var resolution = _resolve_property_from_controls(observation.get("controls", []), args)
	var payload = _property_action_payload(observation, resolution)
	if not bool(resolution.get("success", false)):
		return bridge.error(str(resolution.get("message", "Inspector property could not be resolved.")), payload)
	payload["value"] = _read_property_value(resolution.get("property", {}))
	return bridge.success(payload, "Inspector property value read")


func _focus_value(args: Dictionary) -> Dictionary:
	var observation = _observe(args)
	var resolution = _resolve_property_from_controls(observation.get("controls", []), args)
	var payload = _property_action_payload(observation, resolution)
	if not bool(resolution.get("success", false)):
		return bridge.error(str(resolution.get("message", "Inspector property could not be resolved.")), payload)
	var property: Dictionary = resolution.get("property", {})
	var value_path = str(property.get("value_control_path", ""))
	if value_path.is_empty():
		return bridge.error("Inspector property does not expose a focusable value control.", payload)
	var focus_result: Dictionary = bridge.call_atomic("editor_ui_control", {"action": "focus_control", "target_path": value_path})
	payload["focus"] = _safe_data(focus_result)
	if not bool(focus_result.get("success", false)):
		return bridge.error(str(focus_result.get("message", "Inspector value control could not be focused.")), payload)
	return bridge.success(payload, "Inspector value control focused")


func _set_value(args: Dictionary) -> Dictionary:
	if bool(args.get("include_hidden", false)):
		return bridge.error("system_inspector refuses writes while include_hidden=true.", {"reason": "hidden_write_refused"})
	if str(args.get("require_confidence", "medium")).strip_edges().to_lower() == "low":
		return bridge.error("system_inspector refuses low-confidence writes.", {"reason": "low_confidence_write_refused"})
	if not args.has("value") or args.get("value") == null:
		return bridge.error("value is required for set_value", {"reason": "null_value_refused"})
	var observation = _observe(args)
	var resolution = _resolve_property_from_controls(observation.get("controls", []), args)
	var payload = _property_action_payload(observation, resolution)
	if not bool(resolution.get("success", false)):
		return bridge.error(str(resolution.get("message", "Inspector property could not be resolved.")), payload)
	var property: Dictionary = resolution.get("property", {})
	if bool(property.get("disabled", false)):
		payload["reason"] = "disabled_value_refused"
		return bridge.error("system_inspector refuses writes to disabled Inspector value controls.", payload)
	var before = _read_property_value(property)
	payload["before"] = before
	var write_result = _write_property_value(property, args.get("value"))
	payload["write"] = write_result.get("data", {})
	if not bool(write_result.get("success", false)):
		return bridge.error(str(write_result.get("message", "Inspector property value could not be set.")), payload)
	await _await_frame()
	var verify_observation = _observe(args)
	var verify_resolution = _resolve_property_from_controls(verify_observation.get("controls", []), args)
	if bool(verify_resolution.get("success", false)):
		var after_value = _read_property_value(verify_resolution.get("property", {}))
		payload["after"] = after_value
		payload["verification"] = _verify_typed_value(after_value, args.get("value"), str(after_value.get("value_editor_type", before.get("value_editor_type", "unknown"))))
	else:
		payload["after"] = {}
		payload["verification"] = {"success": false, "reason": "property_not_resolved_after_write"}
	if not bool(payload.get("verification", {}).get("success", false)):
		return bridge.error("Inspector property value did not match expected value after writing.", payload)
	return bridge.success(payload, "Inspector property value set and verified")


func _verify_value(args: Dictionary) -> Dictionary:
	if not args.has("expected_value"):
		return bridge.error("expected_value is required for verify_value")
	var read_result = _read_value(args)
	var payload: Dictionary = _safe_data(read_result)
	if not bool(read_result.get("success", false)):
		return read_result
	var value_payload: Dictionary = payload.get("value", {})
	var verification = _verify_typed_value(value_payload, args.get("expected_value"), str(value_payload.get("value_editor_type", "unknown")))
	payload["verification"] = verification
	if bool(verification.get("success", false)):
		return bridge.success(payload, "Inspector property value matched expected_value")
	return bridge.error("Inspector property value did not match expected_value.", payload)


func _capture(args: Dictionary) -> Dictionary:
	var observation = _observe(args)
	var payload = observation
	if _has_property_selector(args):
		var resolution = _resolve_property_from_controls(observation.get("controls", []), args)
		payload = _property_action_payload(observation, resolution)
		if not bool(resolution.get("success", false)):
			return bridge.error(str(resolution.get("message", "Inspector property could not be resolved.")), payload)
	_attach_capture(payload, args)
	return bridge.success(payload, "Inspector evidence captured")


func _run_task(args: Dictionary) -> Dictionary:
	var payload = {
		"task_action": "run_task",
		"mode": _task_mode(args),
		"selectors": _task_selectors(args),
		"write_attempted": args.has("value"),
		"write_verified": false,
		"steps": {},
		"workflow": []
	}
	var capture_policy = _capture_policy(args)
	if bool(args.get("require_capture", false)) and capture_policy == "none":
		return _finish_task_failure(payload, args, "preflight", "capture_policy_refused", "run_task requires capture evidence, but capture_policy=none disables evidence capture.", "none")
	if bool(args.get("include_hidden", false)) and args.has("value"):
		return _finish_task_failure(payload, args, "preflight", "hidden_write_refused", "system_inspector refuses hidden-control writes.", capture_policy)
	if str(args.get("require_confidence", "medium")).strip_edges().to_lower() == "low" and args.has("value"):
		return _finish_task_failure(payload, args, "preflight", "low_confidence_write_refused", "system_inspector refuses low-confidence writes.", capture_policy)
	if args.has("value") and args.get("value") == null:
		return _finish_task_failure(payload, args, "preflight", "null_value_refused", "run_task requires a non-null value for writes.", capture_policy)
	if not _has_property_selector(args):
		return _finish_task_failure(payload, args, "preflight", "property_selector_required", "run_task requires target_path, property_path, or query.", capture_policy)

	var target_result = _prepare_target(args)
	_record_step(payload, "prepare_target", target_result)
	if not bool(target_result.get("success", false)):
		return _finish_task_failure(payload, args, "prepare_target", _result_reason(target_result, "target_unavailable"), str(target_result.get("message", "Inspector target could not be prepared.")), capture_policy, target_result)
	payload["target"] = _safe_data(target_result)
	if bool(_safe_data(target_result).get("target_changed", false)):
		await _await_frame()
		var refresh_result: Dictionary = bridge.call_atomic("editor_inspector", {"action": "refresh"})
		_record_step(payload, "refresh_target", refresh_result)
		await _await_frame()

	var read_result = _read_value(args)
	_record_step(payload, "read_before", read_result)
	if not bool(read_result.get("success", false)):
		return _finish_task_failure(payload, args, "read_before", _result_reason(read_result, "read_failed"), str(read_result.get("message", "Inspector property value could not be read.")), capture_policy, read_result)
	_merge_property_payload(payload, _safe_data(read_result))
	payload["before"] = _safe_data(read_result).get("value", {})

	if args.has("value"):
		if bool(args.get("require_capture", false)):
			var capture_probe = _capture(args)
			_record_step(payload, "capture_preflight", capture_probe)
			_copy_capture_fields(payload, _safe_data(capture_probe))
			if str(payload.get("capture_backend", "none")) == "none":
				return _finish_task_failure(payload, args, "capture", "capture_required", "run_task required capture evidence before writing, but no capture backend succeeded.", "none", capture_probe)
		var set_result = await _set_value(args)
		_record_step(payload, "set_value", set_result)
		if not bool(set_result.get("success", false)):
			return _finish_task_failure(payload, args, "set_value", _result_reason(set_result, "write_failed"), str(set_result.get("message", "Inspector property value could not be set.")), capture_policy, set_result)
		_merge_property_payload(payload, _safe_data(set_result))
		payload["write_attempted"] = true

	var expected_source = ""
	var verify_args = args.duplicate(true)
	if args.has("expected_value"):
		expected_source = "expected_value"
	elif args.has("value"):
		expected_source = "value"
		verify_args["expected_value"] = args.get("value")
	if not expected_source.is_empty():
		var verify_result = _verify_value(verify_args)
		_record_step(payload, "verify_after", verify_result)
		_merge_property_payload(payload, _safe_data(verify_result))
		var verification: Dictionary = payload.get("verification", {})
		verification["performed"] = true
		verification["expected_source"] = expected_source
		payload["verification"] = verification
		payload["write_verified"] = bool(verification.get("success", false)) if bool(payload.get("write_attempted", false)) else false
		if not bool(verify_result.get("success", false)):
			return _finish_task_failure(payload, args, "verify_after", _result_reason(verify_result, "value_mismatch"), str(verify_result.get("message", "Inspector property value did not match expected_value.")), capture_policy, verify_result)
	else:
		payload["verification"] = {"performed": false, "reason": "not_requested"}
	return _finish_task_success(payload, args, capture_policy)


func _prepare_target(args: Dictionary) -> Dictionary:
	var node_path = str(args.get("node_path", "")).strip_edges()
	var resource_path = str(args.get("resource_path", "")).strip_edges()
	if not node_path.is_empty() and not resource_path.is_empty():
		return bridge.error("node_path and resource_path are mutually exclusive", {"reason": "ambiguous_target"})
	if not node_path.is_empty():
		var result = _edit_object(args)
		if bool(result.get("success", false)):
			var data: Dictionary = _safe_data(result)
			data["target_changed"] = true
			return bridge.success(data, str(result.get("message", "Inspector object selected")))
		return result
	if not resource_path.is_empty():
		var result = _inspect_resource(args)
		if bool(result.get("success", false)):
			var data: Dictionary = _safe_data(result)
			data["target_changed"] = true
			return bridge.success(data, str(result.get("message", "Inspector resource selected")))
		return result
	return _status(args)


func _observe(args: Dictionary) -> Dictionary:
	var edited_result: Dictionary = bridge.call_atomic("editor_inspector", {"action": "get_edited"})
	var selected_result: Dictionary = bridge.call_atomic("editor_inspector", {"action": "get_selected_property"})
	var controls_result: Dictionary = bridge.call_atomic("editor_ui_control", {
		"action": "list_visible",
		"class_name": str(args.get("class_name", "")).strip_edges(),
		"text_query": "",
		"include_hidden": bool(args.get("include_hidden", false)),
		"limit": _result_limit(args),
		"max_depth": maxi(int(args.get("max_depth", DEFAULT_MAX_DEPTH)), 0)
	})
	var raw_controls: Array = _safe_data(controls_result).get("controls", [])
	var controls: Array = _inspector_scoped_controls(raw_controls)
	var inspector_root = _find_inspector_root(controls)
	return {
		"edited": _safe_data(edited_result),
		"selected_property": str(_safe_data(selected_result).get("selected_path", "")),
		"controls": controls,
		"inspector_root": inspector_root,
		"raw_control_count": raw_controls.size(),
		"available": bool(edited_result.get("success", false)) and bool(controls_result.get("success", false))
	}


func _property_models(controls: Array, args: Dictionary, limit: int) -> Array[Dictionary]:
	var query_values = _query_values(args)
	var models: Array[Dictionary] = []
	for control in controls:
		if not (control is Dictionary):
			continue
		var row = control as Dictionary
		if not _looks_like_property_row(row):
			continue
		var model = _build_property_model(row, controls)
		if model.is_empty():
			continue
		if not _property_matches(model, query_values):
			continue
		models.append(model)
		if models.size() >= limit:
			break
	return models


func _inspector_scoped_controls(raw_controls: Array) -> Array:
	var roots: Array[String] = []
	for control in raw_controls:
		if not (control is Dictionary):
			continue
		var row = control as Dictionary
		var path = str(row.get("path", ""))
		if not path.is_empty() and _is_editor_inspector_root(row):
			roots.append(path)
	var scoped: Array = []
	for control in raw_controls:
		if not (control is Dictionary):
			continue
		var row = control as Dictionary
		var path = str(row.get("path", ""))
		if path.is_empty():
			continue
		if roots.is_empty():
			if _path_under_inspector(path):
				scoped.append(row)
			continue
		for root_path in roots:
			if path == root_path or path.begins_with(root_path + "/"):
				scoped.append(row)
				break
	return scoped


func _resolve_property_from_controls(controls: Array, args: Dictionary, sanitize: bool = false) -> Dictionary:
	var selector_target = str(args.get("target_path", "")).strip_edges()
	var candidates: Array[Dictionary] = []
	for model in _property_models(controls, args, max(1, controls.size())):
		if not selector_target.is_empty():
			if str(model.get("row_control_path", "")) != selector_target and str(model.get("value_control_path", "")) != selector_target:
				continue
		if not _confidence_allowed(model, str(args.get("require_confidence", "medium"))):
			continue
		candidates.append(model)
	if candidates.size() == 1:
		return {"success": true, "property": candidates[0], "resolution": {"candidate_count": 1, "reason": "unique_property"}}
	if candidates.is_empty():
		return {"success": false, "message": "Inspector property not found.", "reason": "property_not_found", "resolution": {"candidate_count": 0, "reason": "property_not_found"}}
	var reported = []
	for candidate in candidates:
		reported.append(_sanitize_property_model(candidate) if sanitize else candidate)
	return {"success": false, "message": "Inspector property selector matched multiple properties.", "reason": "ambiguous_property", "resolution": {"candidate_count": candidates.size(), "reason": "ambiguous_property", "candidates": reported}}


func _build_property_model(row: Dictionary, controls: Array) -> Dictionary:
	var row_path = str(row.get("path", ""))
	var value_control = _find_value_control(row, controls)
	var source = value_control if not value_control.is_empty() else row
	var property_path = _property_path(row)
	var label = _property_label(row, property_path)
	var editor_type = _value_editor_type(source)
	var model = {
		"property_path": property_path,
		"label": label,
		"row_control_path": row_path,
		"value_control_path": str(source.get("path", row_path)),
		"row_class": str(row.get("class", "")),
		"value_class": str(source.get("class", row.get("class", ""))),
		"value_editor_type": editor_type,
		"value_text": str(source.get("text", row.get("text", ""))),
		"visible": bool(row.get("visible", true)),
		"disabled": bool(row.get("disabled", false)) or bool(source.get("disabled", false)) or bool(source.get("read_only", false)) or not bool(row.get("enabled", true)) or not bool(source.get("enabled", true)),
		"confidence": "medium",
		"supported_write": SUPPORTED_WRITE_TYPES.has(editor_type),
		"unsupported_reason": "" if SUPPORTED_WRITE_TYPES.has(editor_type) else "unsupported_value_editor_type"
	}
	for value_key in ["text", "value", "pressed", "button_pressed", "selected", "selected_index"]:
		if source.has(value_key):
			model[value_key] = source.get(value_key)
	model["row_id"] = _property_row_id(model)
	model["confidence"] = _property_confidence(model)
	return model


func _looks_like_property_row(row: Dictionary) -> bool:
	if not bool(row.get("visible", true)):
		return false
	var path = str(row.get("path", ""))
	if path.is_empty():
		return false
	if not _path_under_inspector(path):
		return false
	var control_class = str(row.get("class", "")).to_lower()
	if control_class in ["label", "button", "lineedit", "spinbox", "checkbutton", "checkbox", "optionbutton"]:
		return false
	if row.has("property_path"):
		return true
	if int(row.get("child_count", 0)) > 0 and not str(row.get("text", "")).strip_edges().is_empty():
		return _path_under_inspector(path)
	return false


func _path_under_inspector(path: String) -> bool:
	var lower = path.to_lower()
	if _path_is_settings_or_dialog_inspector(path):
		return false
	return lower.contains("editorinspector") or lower.contains("inspector_dock") or lower.contains("inspectordock") or lower.contains("/inspector/")


func _is_editor_inspector_root(row: Dictionary) -> bool:
	var path = str(row.get("path", ""))
	if path.is_empty() or _path_is_settings_or_dialog_inspector(path):
		return false
	var normalized_class = str(row.get("class", "")).strip_edges().to_lower().replace("_", "")
	return normalized_class == "editorinspector"


func _path_is_settings_or_dialog_inspector(path: String) -> bool:
	var normalized = path.to_lower().replace("_", "")
	return normalized.contains("projectsettings") or normalized.contains("editorsettings") or normalized.contains("sectionedinspector") or normalized.contains("settingsdialog")


func _find_value_control(row: Dictionary, controls: Array) -> Dictionary:
	var row_path = str(row.get("path", ""))
	var best = {}
	for control in controls:
		if not (control is Dictionary):
			continue
		var candidate = control as Dictionary
		var candidate_path = str(candidate.get("path", ""))
		if candidate_path == row_path or not candidate_path.begins_with(row_path + "/"):
			continue
		var editor_type = _value_editor_type(candidate)
		if editor_type != "unknown":
			return candidate
		if best.is_empty() and candidate_path.to_lower().ends_with("/value"):
			best = candidate
	return best


func _read_property_value(property: Dictionary) -> Dictionary:
	var editor_type = str(property.get("value_editor_type", "unknown"))
	var text = str(property.get("value_text", ""))
	var typed_value = _typed_value(property, editor_type, text)
	return {
		"property_path": str(property.get("property_path", "")),
		"value_control_path": str(property.get("value_control_path", "")),
		"value_editor_type": editor_type,
		"value": typed_value,
		"value_text": text,
		"supported_write": bool(property.get("supported_write", false))
	}


func _write_property_value(property: Dictionary, value) -> Dictionary:
	var editor_type = str(property.get("value_editor_type", "unknown"))
	var value_path = str(property.get("value_control_path", ""))
	if value_path.is_empty():
		return bridge.error("Inspector property does not expose a value control.", {"reason": "value_control_missing"})
	if not SUPPORTED_WRITE_TYPES.has(editor_type):
		return bridge.error("Inspector property editor type is not supported for writes.", {"reason": "unsupported_value_editor_type", "value_editor_type": editor_type})
	if editor_type == "text":
		var result: Dictionary = bridge.call_atomic("editor_ui_control", {"action": "set_text", "target_path": value_path, "text": str(value)})
		var payload = _safe_data(result)
		payload["write_action"] = "set_text"
		payload["expected_value"] = str(value)
		if bool(result.get("success", false)):
			return bridge.success(payload, "Inspector text property written")
		return result
	if editor_type == "number":
		if not _can_coerce_number(value):
			return bridge.error("Inspector numeric property writes require a numeric value.", {"reason": "invalid_value_type", "value_editor_type": editor_type})
		var result: Dictionary = bridge.call_atomic("editor_ui_control", {"action": "set_value", "target_path": value_path, "value": value})
		var payload = _safe_data(result)
		payload["write_action"] = "set_value"
		payload["expected_value"] = value
		if bool(result.get("success", false)):
			return bridge.success(payload, "Inspector numeric property written")
		return result
	if editor_type == "bool":
		var before = bool(_typed_value(property, editor_type, str(property.get("value_text", ""))))
		if not _can_coerce_bool(value):
			return bridge.error("Inspector bool property writes require an explicit boolean-like value.", {"reason": "invalid_value_type", "value_editor_type": editor_type})
		var expected = _coerce_bool(value)
		var payload = {"write_action": "activate_control", "expected_value": expected, "noop": before == expected}
		if before == expected:
			return bridge.success(payload, "Inspector bool property already matched")
		var result: Dictionary = bridge.call_atomic("editor_ui_control", {"action": "activate_control", "target_path": value_path})
		payload.merge(_safe_data(result), true)
		if bool(result.get("success", false)):
			return bridge.success(payload, "Inspector bool property toggled")
		return result
	return bridge.error("Unsupported inspector property editor type.", {"reason": "unsupported_value_editor_type", "value_editor_type": editor_type})


func _verify_typed_value(value_payload: Dictionary, expected_value, editor_type: String) -> Dictionary:
	var actual = value_payload.get("value")
	var expected = expected_value
	if editor_type == "number":
		if not _can_coerce_number(expected_value):
			return {"success": false, "actual": actual, "expected": expected_value, "reason": "invalid_value_type"}
		expected = float(expected_value)
		return {"success": is_equal_approx(float(actual), float(expected)), "actual": actual, "expected": expected, "reason": "" if is_equal_approx(float(actual), float(expected)) else "value_mismatch"}
	if editor_type == "bool":
		if not _can_coerce_bool(expected_value):
			return {"success": false, "actual": actual, "expected": expected_value, "reason": "invalid_value_type"}
		expected = _coerce_bool(expected_value)
		return {"success": bool(actual) == bool(expected), "actual": bool(actual), "expected": bool(expected), "reason": "" if bool(actual) == bool(expected) else "value_mismatch"}
	return {"success": str(actual) == str(expected), "actual": actual, "expected": expected, "reason": "" if str(actual) == str(expected) else "value_mismatch"}


func _attach_capture(payload: Dictionary, args: Dictionary) -> void:
	var target_path = str(payload.get("value_control_path", payload.get("row_control_path", "")))
	if target_path.is_empty():
		var inspector_root = payload.get("inspector_root", {})
		if inspector_root is Dictionary:
			target_path = str((inspector_root as Dictionary).get("path", ""))
	if not target_path.is_empty():
		var control_result: Dictionary = bridge.call_atomic("editor_ui_control", {"action": "capture_control", "target_path": target_path, "path": str(args.get("path", ""))})
		if bool(control_result.get("success", false)):
			var data = _safe_data(control_result)
			payload["capture_backend"] = "control"
			payload["capture_path"] = str(data.get("path", ""))
			payload["capture_target_path"] = target_path
			return
	var editor_result: Dictionary = bridge.call_atomic("editor_screenshot", {"action": "capture", "path": str(args.get("path", ""))})
	if bool(editor_result.get("success", false)):
		var data = _safe_data(editor_result)
		payload["capture_backend"] = "editor"
		payload["capture_path"] = str(data.get("path", ""))
		payload["capture_target_path"] = ""
		return
	payload["capture_backend"] = "none"
	payload["capture_error"] = str(editor_result.get("message", editor_result.get("error", "")))


func _finish_task_success(payload: Dictionary, args: Dictionary, capture_policy: String) -> Dictionary:
	if _should_capture(capture_policy, false):
		_attach_capture(payload, args)
	if bool(args.get("require_capture", false)) and str(payload.get("capture_backend", "none")) == "none":
		return _finish_task_failure(payload, args, "capture", "capture_required", "run_task required capture evidence, but no capture backend succeeded.", "none")
	return bridge.success(payload, "Inspector task completed")


func _finish_task_failure(payload: Dictionary, args: Dictionary, failed_step: String, reason: String, message: String, capture_policy: String, failure_result: Dictionary = {}) -> Dictionary:
	payload["failed_step"] = failed_step
	payload["reason"] = reason
	if not failure_result.is_empty():
		payload["failure_result"] = _step_summary(failure_result)
	if failed_step != "preflight" and _should_capture(capture_policy, true):
		_attach_capture(payload, args)
	if bool(args.get("require_capture", false)) and failed_step != "preflight" and str(payload.get("capture_backend", "none")) == "none" and reason != "capture_required":
		payload["failed_step"] = "capture"
		payload["reason"] = "capture_required"
		message = "run_task required capture evidence, but no capture backend succeeded."
	return bridge.error(message, payload)


func _record_step(payload: Dictionary, step_name: String, result: Dictionary) -> void:
	var steps: Dictionary = payload.get("steps", {})
	steps[step_name] = _step_summary(result)
	payload["steps"] = steps
	var workflow: Array = payload.get("workflow", [])
	workflow.append({"step": "run_task.%s" % step_name, "success": bool(result.get("success", false)), "reason": _result_reason(result, "") if not bool(result.get("success", false)) else ""})
	payload["workflow"] = workflow


func _step_summary(result: Dictionary) -> Dictionary:
	var summary = {"success": bool(result.get("success", false)), "message": str(result.get("message", ""))}
	if result.has("error"):
		summary["error"] = result.get("error")
	var data = _safe_data(result)
	var safe_data = {}
	for key in ["edited", "selected_property", "target", "property", "property_path", "row_control_path", "value_control_path", "value", "before", "write", "after", "verification", "capture_backend", "capture_path", "capture_target_path", "reason", "failed_step"]:
		if data.has(key):
			safe_data[key] = data.get(key)
	if not safe_data.is_empty():
		summary["data"] = safe_data
	return summary


func _merge_property_payload(payload: Dictionary, data: Dictionary) -> void:
	for key in ["edited", "selected_property", "property", "property_path", "row_control_path", "value_control_path", "before", "write", "after", "verification"]:
		if data.has(key):
			payload[key] = data.get(key)


func _property_action_payload(observation: Dictionary, resolution: Dictionary) -> Dictionary:
	var payload = {
		"edited": observation.get("edited", {}),
		"selected_property": observation.get("selected_property", ""),
		"inspector_root": observation.get("inspector_root", {}),
		"resolution": _sanitize_resolution(resolution)
	}
	if bool(resolution.get("success", false)):
		var property = resolution.get("property", {})
		payload["property"] = _sanitize_property_model(property)
		payload["property_path"] = str(property.get("property_path", ""))
		payload["row_control_path"] = str(property.get("row_control_path", ""))
		payload["value_control_path"] = str(property.get("value_control_path", ""))
	return payload


func _safe_data(result: Dictionary) -> Dictionary:
	var data = result.get("data", {})
	return (data as Dictionary).duplicate(true) if data is Dictionary else {}


func _result_limit(args: Dictionary) -> int:
	return maxi(int(args.get("limit", DEFAULT_LIMIT)), 1)


func _query_values(args: Dictionary) -> Array[String]:
	var values: Array[String] = []
	for key in ["target_path", "property_path", "query"]:
		var value = str(args.get(key, "")).strip_edges()
		if not value.is_empty():
			values.append(value.to_lower())
	return values


func _task_selectors(args: Dictionary) -> Dictionary:
	var selectors = {}
	for key in ["node_path", "resource_path", "property_path", "query", "target_path"]:
		if args.has(key):
			selectors[key] = args.get(key)
	return selectors


func _task_mode(args: Dictionary) -> String:
	if args.has("value") and args.has("expected_value"):
		return "set_and_verify"
	if args.has("value"):
		return "set"
	if args.has("expected_value"):
		return "verify"
	return "read"


func _capture_policy(args: Dictionary) -> String:
	var policy = str(args.get("capture_policy", "final")).strip_edges().to_lower()
	return policy if ["none", "final", "on_failure", "always"].has(policy) else "final"


func _should_capture(capture_policy: String, failed: bool) -> bool:
	match capture_policy:
		"none":
			return false
		"on_failure":
			return failed
		"always":
			return true
		_:
			return not failed


func _has_property_selector(args: Dictionary) -> bool:
	return not str(args.get("target_path", "")).strip_edges().is_empty() or not str(args.get("property_path", "")).strip_edges().is_empty() or not str(args.get("query", "")).strip_edges().is_empty()


func _find_inspector_root(controls: Array) -> Dictionary:
	for control in controls:
		if control is Dictionary and _is_editor_inspector_root(control as Dictionary):
			return (control as Dictionary).duplicate(true)
	return {}


func _property_path(row: Dictionary) -> String:
	for key in ["property_path", "property", "name"]:
		var value = str(row.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	var text = str(row.get("text", "")).strip_edges()
	return text.to_snake_case() if not text.is_empty() else str(row.get("path", "")).get_file().to_snake_case()


func _property_label(row: Dictionary, property_path: String) -> String:
	var text = str(row.get("text", "")).strip_edges()
	if not text.is_empty():
		return text
	return property_path.get_file().replace("_", " ").capitalize()


func _property_matches(model: Dictionary, queries: Array[String]) -> bool:
	if queries.is_empty():
		return true
	var haystack = " ".join([
		str(model.get("property_path", "")),
		str(model.get("label", "")),
		str(model.get("row_control_path", "")),
		str(model.get("value_control_path", "")),
		str(model.get("value_text", ""))
	]).to_lower()
	for query in queries:
		if not haystack.contains(str(query).to_lower()):
			return false
	return true


func _value_editor_type(row: Dictionary) -> String:
	var control_class = str(row.get("class", "")).to_lower()
	var raw_actionable = row.get("actionable", [])
	var actionable: Array = raw_actionable if raw_actionable is Array else []
	if bool(row.get("editable_text", false)) or actionable.has("set_text") or control_class in ["lineedit", "textedit", "codeedit"]:
		return "text"
	if row.has("value") or actionable.has("set_value") or control_class in ["spinbox", "slider", "hslider", "vslider"]:
		return "number"
	if row.has("pressed") or row.has("button_pressed") or control_class in ["checkbox", "checkbutton"]:
		return "bool"
	if row.has("selected") or row.has("selected_index") or control_class == "optionbutton":
		return "enum"
	if control_class.contains("color"):
		return "color"
	if control_class.contains("resource") or control_class.contains("object"):
		return "resource"
	return "unknown"


func _typed_value(row: Dictionary, editor_type: String, raw_text: String):
	if editor_type == "number":
		if row.has("value"):
			return float(row.get("value"))
		return raw_text.to_float() if raw_text.is_valid_float() else 0.0
	if editor_type == "bool":
		if row.has("button_pressed"):
			return bool(row.get("button_pressed"))
		if row.has("pressed"):
			return bool(row.get("pressed"))
		return _coerce_bool(raw_text)
	if editor_type == "enum":
		return {"text": raw_text, "selected": row.get("selected", row.get("selected_index", null))}
	return raw_text


func _coerce_bool(value) -> bool:
	if value is bool:
		return bool(value)
	var text = str(value).strip_edges().to_lower()
	return text in ["true", "1", "yes", "y", "on", "enabled", "pressed"]


func _can_coerce_bool(value) -> bool:
	if value is bool:
		return true
	var text = str(value).strip_edges().to_lower()
	return text in ["true", "false", "1", "0", "yes", "no", "y", "n", "on", "off", "enabled", "disabled", "pressed", "unpressed"]


func _can_coerce_number(value) -> bool:
	if value is int or value is float:
		return true
	if value is String:
		return str(value).strip_edges().is_valid_float()
	return false


func _confidence_allowed(model: Dictionary, required: String) -> bool:
	var rank = {"low": 0, "medium": 1, "high": 2}
	var required_rank = int(rank.get(required.strip_edges().to_lower(), 1))
	var actual_rank = int(rank.get(str(model.get("confidence", "medium")), 1))
	return actual_rank >= required_rank


func _property_confidence(model: Dictionary) -> String:
	if not str(model.get("property_path", "")).is_empty() and str(model.get("value_editor_type", "unknown")) != "unknown":
		return "high"
	if not str(model.get("value_control_path", "")).is_empty():
		return "medium"
	return "low"


func _property_row_id(model: Dictionary) -> String:
	var basis = str(model.get("property_path", ""))
	if basis.is_empty():
		basis = str(model.get("row_control_path", ""))
	return basis.to_lower().replace(" ", "_").replace("/", ".")


func _sanitize_resolution(resolution: Dictionary) -> Dictionary:
	var data = resolution.get("resolution", {})
	return (data as Dictionary).duplicate(true) if data is Dictionary else {}


func _sanitize_property_model(property) -> Dictionary:
	if not (property is Dictionary):
		return {}
	var dict = property as Dictionary
	var result = {}
	for key in ["row_id", "property_path", "label", "row_control_path", "value_control_path", "row_class", "value_class", "value_editor_type", "visible", "disabled", "confidence", "supported_write", "unsupported_reason"]:
		if dict.has(key):
			result[key] = dict.get(key)
	return result


func _model_quality(properties: Array[Dictionary]) -> Dictionary:
	var counts = {"high": 0, "medium": 0, "low": 0}
	for property in properties:
		var confidence = str(property.get("confidence", "low"))
		counts[confidence] = int(counts.get(confidence, 0)) + 1
	return counts


func _result_reason(result: Dictionary, default_reason: String) -> String:
	var data = _safe_data(result)
	for key in ["reason", "failed_step"]:
		if not str(data.get(key, "")).strip_edges().is_empty():
			return str(data.get(key, ""))
	var resolution = data.get("resolution", {})
	if resolution is Dictionary and not str((resolution as Dictionary).get("reason", "")).strip_edges().is_empty():
		return str((resolution as Dictionary).get("reason", ""))
	var verification = data.get("verification", {})
	if verification is Dictionary and not str((verification as Dictionary).get("reason", "")).strip_edges().is_empty():
		return str((verification as Dictionary).get("reason", ""))
	var write = data.get("write", {})
	if write is Dictionary and not str((write as Dictionary).get("reason", "")).strip_edges().is_empty():
		return str((write as Dictionary).get("reason", ""))
	return default_reason


func _copy_capture_fields(payload: Dictionary, source: Dictionary) -> void:
	for key in ["capture_backend", "capture_path", "capture_target_path", "capture_error"]:
		if source.has(key):
			payload[key] = source.get(key)


func _await_frame() -> void:
	var tree = Engine.get_main_loop()
	if tree != null:
		await tree.process_frame
