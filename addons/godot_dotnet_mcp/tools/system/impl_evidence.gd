@tool
extends RefCounted

## System implementation: editor_evidence

var bridge

const HANDLED_TOOLS := ["editor_evidence"]
const SURFACES := ["auto", "editor", "control", "popup", "active_dialog"]
const CAPTURE_POLICIES := ["best_effort", "allow_fallback", "require_exact"]


func handles(tool_name: String) -> bool:
	return tool_name in HANDLED_TOOLS


func configure_runtime(_context: Dictionary) -> void:
	pass


func get_tools() -> Array[Dictionary]:
	return [{
		"name": "editor_evidence",
		"description": "EDITOR EVIDENCE: Capture self-describing visual evidence for editor, control, popup, active dialog, or auto-selected surfaces. Use this when an agent needs to know what UI object was captured, which backend was used, whether fallback occurred, and which popups were visible.",
		"inputSchema": {
			"type": "object",
			"properties": {
				"action": {
					"type": "string",
					"enum": ["status", "capture"],
					"description": "Editor evidence action"
				},
				"surface": {
					"type": "string",
					"enum": SURFACES,
					"description": "Requested evidence surface: auto, editor, control, popup, or active_dialog"
				},
				"target_path": {
					"type": "string",
					"description": "Control or popup path returned by editor UI tools. Required for control/popup capture."
				},
				"path": {
					"type": "string",
					"description": "Optional output screenshot path."
				},
				"require_target": {
					"type": "boolean",
					"description": "Fail instead of falling back to editor capture when a requested target surface is unavailable."
				},
				"capture_policy": {
					"type": "string",
					"enum": CAPTURE_POLICIES,
					"description": "Capture fallback policy. best_effort/allow_fallback may degrade to broader evidence; require_exact fails when the requested target surface cannot be captured."
				},
				"include_popups": {
					"type": "boolean",
					"description": "Attach visible popup metadata to editor or fallback captures (default true)."
				}
			},
			"required": ["action"]
		}
	}]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name not in HANDLED_TOOLS:
		return bridge.error("Unknown tool: %s" % tool_name)

	var action := str(args.get("action", "")).strip_edges()
	match action:
		"status":
			return _status(args)
		"capture":
			return _capture(args)
		_:
			return bridge.error("Unknown action: %s" % action)


func _status(_args: Dictionary) -> Dictionary:
	var popup_result: Dictionary = bridge.call_atomic("editor_popup", {"action": "list_visible"})
	var popup_data := _safe_data(popup_result)
	return bridge.success({
		"available": true,
		"surfaces": SURFACES.duplicate(),
		"default_surface": "auto",
		"capture_policies": CAPTURE_POLICIES.duplicate(),
		"default_capture_policy": "best_effort",
		"visible_popup_count": int(popup_data.get("count", 0)) if bool(popup_result.get("success", false)) else 0,
		"visible_popups": popup_data.get("popups", []) if bool(popup_result.get("success", false)) else [],
		"popup_observation_available": bool(popup_result.get("success", false)),
		"popup_observation_error": "" if bool(popup_result.get("success", false)) else str(popup_result.get("message", popup_result.get("error", "")))
	}, "Editor evidence status fetched")


func _capture(args: Dictionary) -> Dictionary:
	var requested_surface := str(args.get("surface", "auto")).strip_edges().to_lower()
	var target_path := str(args.get("target_path", "")).strip_edges()
	var output_path := str(args.get("path", "")).strip_edges()
	var include_popups := bool(args.get("include_popups", true))
	var payload := _base_payload(requested_surface, target_path)
	if not SURFACES.has(requested_surface):
		return _failed_capture(payload, [], "invalid_surface", "Invalid evidence surface: %s. Expected one of: %s." % [requested_surface, ", ".join(SURFACES)])
	var capture_policy := str(args.get("capture_policy", "best_effort")).strip_edges().to_lower()
	if not CAPTURE_POLICIES.has(capture_policy):
		return _failed_capture(payload, [], "invalid_capture_policy", "Invalid capture_policy: %s. Expected one of: %s." % [capture_policy, ", ".join(CAPTURE_POLICIES)])
	var require_target := bool(args.get("require_target", false)) or capture_policy == "require_exact"
	payload["capture_policy"] = capture_policy
	payload["target_required"] = require_target
	var fallback_reasons: Array[String] = []

	match requested_surface:
		"editor":
			return _capture_editor_surface(payload, output_path, include_popups, fallback_reasons)
		"control":
			if target_path.is_empty():
				return _target_required_error(payload, "control_target_required")
			return _capture_target_surface(payload, "control", target_path, output_path, include_popups, fallback_reasons, require_target)
		"popup":
			if target_path.is_empty():
				return _target_required_error(payload, "popup_target_required")
			return _capture_target_surface(payload, "popup", target_path, output_path, include_popups, fallback_reasons, require_target)
		"active_dialog":
			var popup_path := _active_popup_path(payload, fallback_reasons)
			if popup_path.is_empty():
				var missing_reason := _active_dialog_missing_reason(payload)
				if not fallback_reasons.has(missing_reason):
					fallback_reasons.append(missing_reason)
				if require_target:
					return _failed_capture(payload, fallback_reasons, missing_reason, _active_dialog_missing_message(missing_reason))
				return _capture_editor_surface(payload, output_path, include_popups, fallback_reasons)
			return _capture_target_surface(payload, "popup", popup_path, output_path, include_popups, fallback_reasons, require_target)
		_:
			return _capture_auto(payload, target_path, output_path, include_popups, fallback_reasons, require_target)


func _capture_auto(payload: Dictionary, target_path: String, output_path: String, include_popups: bool, fallback_reasons: Array[String], require_target: bool) -> Dictionary:
	if not target_path.is_empty():
		var popup_result := _try_capture_popup(payload, target_path, output_path, fallback_reasons)
		if bool(popup_result.get("success", false)):
			return popup_result
		var control_result := _try_capture_control(payload, target_path, output_path, fallback_reasons)
		if bool(control_result.get("success", false)):
			return control_result
		if require_target:
			return _failed_capture(payload, fallback_reasons, "target_capture_failed", "The requested target could not be captured as a popup or control.")

	var popup_path := _active_popup_path(payload, fallback_reasons)
	if not popup_path.is_empty():
		var dialog_result := _try_capture_popup(payload, popup_path, output_path, fallback_reasons)
		if bool(dialog_result.get("success", false)):
			return dialog_result
		fallback_reasons.append("active_dialog_capture_failed")
	elif target_path.is_empty():
		var missing_reason := _active_dialog_missing_reason(payload)
		if not fallback_reasons.has(missing_reason):
			fallback_reasons.append(missing_reason)

	if require_target:
		var reason := str(fallback_reasons[fallback_reasons.size() - 1]) if not fallback_reasons.is_empty() else "target_capture_failed"
		return _failed_capture(payload, fallback_reasons, reason, "Exact editor evidence could not be captured for the requested surface.")

	return _capture_editor_surface(payload, output_path, include_popups, fallback_reasons)


func _capture_target_surface(payload: Dictionary, surface: String, target_path: String, output_path: String, include_popups: bool, fallback_reasons: Array[String], require_target: bool) -> Dictionary:
	var result: Dictionary
	if surface == "popup":
		result = _try_capture_popup(payload, target_path, output_path, fallback_reasons)
	else:
		result = _try_capture_control(payload, target_path, output_path, fallback_reasons)
	if bool(result.get("success", false)):
		return result
	if require_target:
		return _failed_capture(payload, fallback_reasons, "%s_capture_failed" % surface, "The requested %s target could not be captured." % surface)
	return _capture_editor_surface(payload, output_path, include_popups, fallback_reasons)


func _try_capture_popup(payload: Dictionary, target_path: String, output_path: String, fallback_reasons: Array[String]) -> Dictionary:
	var popup_result: Dictionary = bridge.call_atomic("editor_popup", {
		"action": "capture_popup",
		"target_path": target_path,
		"path": output_path
	})
	if bool(popup_result.get("success", false)):
		return _finish_capture(payload, popup_result, "popup", "popup", target_path, fallback_reasons)
	fallback_reasons.append("popup_capture_failed")
	return popup_result


func _try_capture_control(payload: Dictionary, target_path: String, output_path: String, fallback_reasons: Array[String]) -> Dictionary:
	var control_result: Dictionary = bridge.call_atomic("editor_ui_control", {
		"action": "capture_control",
		"target_path": target_path,
		"path": output_path
	})
	if bool(control_result.get("success", false)):
		return _finish_capture(payload, control_result, "control", "control", target_path, fallback_reasons)
	fallback_reasons.append("control_capture_failed")
	return control_result


func _capture_editor_surface(payload: Dictionary, output_path: String, include_popups: bool, fallback_reasons: Array[String]) -> Dictionary:
	var editor_result: Dictionary = bridge.call_atomic("editor_screenshot", {
		"action": "capture",
		"path": output_path
	})
	if not bool(editor_result.get("success", false)):
		return _failed_capture(payload, fallback_reasons, "editor_capture_failed", str(editor_result.get("message", editor_result.get("error", "Editor capture failed."))))
	var result := _finish_capture(payload, editor_result, "editor", "editor", "", fallback_reasons)
	if include_popups:
		_attach_popup_observation(result.get("data", {}))
	return result


func _active_popup_path(payload: Dictionary, fallback_reasons: Array[String]) -> String:
	var popup_result: Dictionary = bridge.call_atomic("editor_popup", {"action": "list_visible"})
	if not bool(popup_result.get("success", false)):
		payload["popup_observation_error"] = str(popup_result.get("message", popup_result.get("error", "")))
		return ""
	var popup_data := _safe_data(popup_result)
	payload["visible_popup_count"] = int(popup_data.get("count", 0))
	payload["visible_popups"] = popup_data.get("popups", [])
	var popups = popup_data.get("popups", [])
	if not (popups is Array) or (popups as Array).is_empty():
		return ""
	if (popups as Array).size() > 1:
		payload["active_dialog_ambiguous"] = true
		payload["active_dialog_candidate_count"] = (popups as Array).size()
		payload["active_dialog_candidates"] = (popups as Array).duplicate(true)
		if not fallback_reasons.has("active_dialog_ambiguous"):
			fallback_reasons.append("active_dialog_ambiguous")
		return ""
	var first = (popups as Array)[0]
	if first is Dictionary:
		return _popup_path(first as Dictionary)
	return ""


func _attach_popup_observation(payload: Dictionary) -> void:
	var popup_result: Dictionary = bridge.call_atomic("editor_popup", {"action": "list_visible"})
	if not bool(popup_result.get("success", false)):
		payload["popup_observation_error"] = str(popup_result.get("message", popup_result.get("error", "")))
		return
	var popup_data := _safe_data(popup_result)
	payload["visible_popup_count"] = int(popup_data.get("count", 0))
	payload["visible_popups"] = popup_data.get("popups", [])


func _finish_capture(payload: Dictionary, capture_result: Dictionary, backend: String, scope: String, target_path: String, fallback_reasons: Array[String]) -> Dictionary:
	var data := payload.duplicate(true)
	var capture_data := _safe_data(capture_result)
	data["capture"] = capture_data
	data["capture_path"] = str(capture_data.get("path", ""))
	data["capture_backend"] = backend
	data["capture_scope"] = scope
	data["capture_target_path"] = target_path
	data["capture_fallback_reasons"] = fallback_reasons.duplicate()
	data["degraded"] = not fallback_reasons.is_empty()
	data["unsupported_reasons"] = []
	data["target_resolved"] = not target_path.is_empty()
	return bridge.success(data, "Editor evidence captured")


func _failed_capture(payload: Dictionary, fallback_reasons: Array[String], reason: String, message: String) -> Dictionary:
	var data := payload.duplicate(true)
	data["capture"] = {}
	data["capture_path"] = ""
	data["capture_backend"] = "none"
	data["capture_scope"] = "none"
	data["capture_target_path"] = ""
	data["capture_fallback_reasons"] = fallback_reasons.duplicate()
	data["degraded"] = true
	data["unsupported_reasons"] = [reason]
	data["reason"] = reason
	data["target_resolved"] = false
	return bridge.error(message, data)


func _target_required_error(payload: Dictionary, reason: String) -> Dictionary:
	return _failed_capture(payload, [], reason, "target_path is required for this evidence surface.")


func _base_payload(surface: String, target_path: String) -> Dictionary:
	return {
		"capture_surface": surface,
		"requested_surface": surface,
		"requested_target_path": target_path,
		"capture_policy": "best_effort",
		"target_required": false,
		"target_resolved": false,
		"workflow": "editor_evidence",
		"visible_popup_count": 0,
		"visible_popups": []
	}


func _active_dialog_missing_reason(payload: Dictionary) -> String:
	if bool(payload.get("active_dialog_ambiguous", false)):
		return "active_dialog_ambiguous"
	return "active_dialog_not_found"


func _active_dialog_missing_message(reason: String) -> String:
	if reason == "active_dialog_ambiguous":
		return "Multiple visible editor popups or dialogs were available; provide target_path or use surface=editor for broader evidence."
	return "No visible editor popup or dialog was available to capture."


func _popup_path(popup: Dictionary) -> String:
	for key in ["popup_path", "node_path", "path", "target_path"]:
		var value := str(popup.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return ""


func _safe_data(result: Dictionary) -> Dictionary:
	var data = result.get("data", {})
	return (data as Dictionary).duplicate(true) if data is Dictionary else {}
