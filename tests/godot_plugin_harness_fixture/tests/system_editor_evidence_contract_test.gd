extends RefCounted

# {"name": "system_editor_evidence_contracts"}

const EvidenceImplScript = preload("res://addons/godot_dotnet_mcp/tools/system/impl_evidence.gd")


class FakeBridge extends RefCounted:
	var popup_visible := true
	var popup_count := 1
	var control_capture_enabled := true
	var popup_capture_enabled := true
	var editor_capture_enabled := true
	var calls: Array[Dictionary] = []

	func call_atomic(tool_name: String, args: Dictionary) -> Dictionary:
		var action := str(args.get("action", ""))
		calls.append({"tool": tool_name, "action": action, "args": args.duplicate(true)})
		match tool_name:
			"editor_screenshot":
				if action == "capture" and editor_capture_enabled:
					var path := str(args.get("path", ""))
					return success({"path": path if not path.is_empty() else "user://editor.png", "capture_mode": "full"})
				return error("Editor capture unavailable")
			"editor_ui_control":
				if action == "capture_control" and control_capture_enabled and str(args.get("target_path", "")) == "/root/Editor/SearchField":
					return success({"path": str(args.get("path", "user://control.png")), "target_path": str(args.get("target_path", "")), "capture_mode": "control"})
				return error("Control capture unavailable")
			"editor_popup":
				match action:
					"list_visible":
						if popup_visible:
							var popups: Array = [{"node_path": "/root/Editor/SearchDialog", "class": "AcceptDialog", "title": "Search"}]
							if popup_count > 1:
								popups.append({"node_path": "/root/Editor/ConfirmDialog", "class": "ConfirmationDialog", "title": "Confirm"})
							return success({"count": popups.size(), "popups": popups})
						return success({"count": 0, "popups": []})
					"capture_popup":
						if popup_capture_enabled and str(args.get("target_path", "")) == "/root/Editor/SearchDialog":
							return success({"path": str(args.get("path", "user://popup.png")), "popup_path": "/root/Editor/SearchDialog", "target_path": str(args.get("target_path", "")), "capture_mode": "popup"})
						return error("Popup capture unavailable")
					_:
						return error("Unsupported editor_popup action")
			_:
				return error("Unsupported atomic tool: %s" % tool_name)

	func success(data = {}, message: String = "") -> Dictionary:
		return {"success": true, "data": data, "message": message}

	func error(message: String, data = {}) -> Dictionary:
		return {"success": false, "error": "bridge_error", "message": message, "data": data}


func run_case(_tree: SceneTree) -> Dictionary:
	var fake := FakeBridge.new()
	var impl = EvidenceImplScript.new()
	impl.bridge = fake

	var tool_defs: Array[Dictionary] = impl.get_tools()
	if tool_defs.size() != 1 or str(tool_defs[0].get("name", "")) != "editor_evidence":
		return _failure("system_editor_evidence should expose one local editor_evidence tool.")
	var properties: Dictionary = tool_defs[0].get("inputSchema", {}).get("properties", {})
	var actions: Array = properties.get("action", {}).get("enum", [])
	for action in ["status", "capture"]:
		if not actions.has(action):
			return _failure("system_editor_evidence schema should expose action: %s" % action)
	var surfaces: Array = properties.get("surface", {}).get("enum", [])
	for surface in ["auto", "editor", "control", "popup", "active_dialog"]:
		if not surfaces.has(surface):
			return _failure("system_editor_evidence schema should expose surface: %s" % surface)
	var policies: Array = properties.get("capture_policy", {}).get("enum", [])
	for policy in ["best_effort", "allow_fallback", "require_exact"]:
		if not policies.has(policy):
			return _failure("system_editor_evidence schema should expose capture_policy: %s" % policy)

	var status := impl.execute("editor_evidence", {"action": "status"})
	if not bool(status.get("success", false)):
		return _failure("status should succeed and report evidence surfaces.")
	if int(status.get("data", {}).get("visible_popup_count", 0)) != 1:
		return _failure("status should include visible popup metadata.")

	var editor_capture := impl.execute("editor_evidence", {"action": "capture", "surface": "editor", "path": "user://editor_evidence.png"})
	if not bool(editor_capture.get("success", false)):
		return _failure("editor surface capture should succeed.")
	var editor_data: Dictionary = editor_capture.get("data", {})
	if str(editor_data.get("capture_backend", "")) != "editor" or str(editor_data.get("capture_scope", "")) != "editor":
		return _failure("editor surface capture should report editor backend and scope.")
	if int(editor_data.get("visible_popup_count", 0)) != 1 or ((editor_data.get("visible_popups", []) as Array).size() != 1):
		return _failure("editor surface capture should attach visible popup metadata by default.")
	if str(editor_data.get("workflow", "")) != "editor_evidence":
		return _failure("editor surface capture should include the editor_evidence workflow marker.")

	var control_capture := impl.execute("editor_evidence", {"action": "capture", "surface": "control", "target_path": "/root/Editor/SearchField"})
	if not bool(control_capture.get("success", false)):
		return _failure("control surface capture should succeed for a valid control target.")
	var control_data: Dictionary = control_capture.get("data", {})
	if str(control_data.get("capture_backend", "")) != "control" or str(control_data.get("capture_target_path", "")) != "/root/Editor/SearchField":
		return _failure("control surface capture should report the control backend and target path.")
	if bool(control_data.get("degraded", true)):
		return _failure("direct control capture should not be marked degraded.")

	var popup_capture := impl.execute("editor_evidence", {"action": "capture", "surface": "popup", "target_path": "/root/Editor/SearchDialog"})
	if not bool(popup_capture.get("success", false)) or str(popup_capture.get("data", {}).get("capture_backend", "")) != "popup":
		return _failure("popup surface capture should use popup capture backend.")

	var active_dialog_capture := impl.execute("editor_evidence", {"action": "capture", "surface": "active_dialog"})
	if not bool(active_dialog_capture.get("success", false)):
		return _failure("active_dialog surface capture should capture the first visible popup.")
	if str(active_dialog_capture.get("data", {}).get("capture_target_path", "")) != "/root/Editor/SearchDialog":
		return _failure("active_dialog capture should record the popup path selected from visible popups.")

	var auto_popup := impl.execute("editor_evidence", {"action": "capture", "surface": "auto", "target_path": "/root/Editor/SearchDialog"})
	if not bool(auto_popup.get("success", false)) or str(auto_popup.get("data", {}).get("capture_backend", "")) != "popup":
		return _failure("auto capture should prefer popup capture when the target resolves as a popup.")

	var auto_control := impl.execute("editor_evidence", {"action": "capture", "surface": "auto", "target_path": "/root/Editor/SearchField"})
	if not bool(auto_control.get("success", false)) or str(auto_control.get("data", {}).get("capture_backend", "")) != "control":
		return _failure("auto capture should fall back from popup target probing to control capture.")
	if not ((auto_control.get("data", {}).get("capture_fallback_reasons", []) as Array).has("popup_capture_failed")):
		return _failure("auto control capture should report the popup fallback reason.")

	var missing_target := impl.execute("editor_evidence", {"action": "capture", "surface": "control"})
	if bool(missing_target.get("success", false)) or str(missing_target.get("data", {}).get("reason", "")) != "control_target_required":
		return _failure("control surface capture should fail clearly without target_path.")

	var calls_before_required := fake.calls.size()
	var required_failure := impl.execute("editor_evidence", {"action": "capture", "surface": "control", "target_path": "/root/Editor/Missing", "require_target": true})
	if bool(required_failure.get("success", false)) or str(required_failure.get("data", {}).get("reason", "")) != "control_capture_failed":
		return _failure("require_target should fail instead of falling back when the requested control cannot be captured.")
	if _has_call_since(fake.calls, calls_before_required, "editor_screenshot", "capture"):
		return _failure("require_target failures must not take an editor fallback screenshot.")

	var calls_before_exact := fake.calls.size()
	var exact_failure := impl.execute("editor_evidence", {"action": "capture", "surface": "auto", "target_path": "/root/Editor/Missing", "capture_policy": "require_exact"})
	if bool(exact_failure.get("success", false)) or str(exact_failure.get("data", {}).get("capture_backend", "")) != "none":
		return _failure("capture_policy=require_exact should fail when auto target capture cannot resolve.")
	if _has_call_since(fake.calls, calls_before_exact, "editor_screenshot", "capture"):
		return _failure("capture_policy=require_exact must not take an editor fallback screenshot.")

	var invalid_surface := impl.execute("editor_evidence", {"action": "capture", "surface": "desktop"})
	if bool(invalid_surface.get("success", false)) or str(invalid_surface.get("data", {}).get("reason", "")) != "invalid_surface":
		return _failure("invalid surface should fail explicitly instead of silently using auto.")

	fake.popup_count = 2
	var ambiguous_dialog := impl.execute("editor_evidence", {"action": "capture", "surface": "active_dialog", "require_target": true})
	fake.popup_count = 1
	if bool(ambiguous_dialog.get("success", false)) or str(ambiguous_dialog.get("data", {}).get("reason", "")) != "active_dialog_ambiguous":
		return _failure("active_dialog require_target should fail when multiple visible popups make the target ambiguous.")
	if int(ambiguous_dialog.get("data", {}).get("active_dialog_candidate_count", 0)) != 2:
		return _failure("ambiguous active_dialog failures should include candidate count.")

	fake.popup_visible = false
	var dialog_fallback := impl.execute("editor_evidence", {"action": "capture", "surface": "active_dialog"})
	fake.popup_visible = true
	if not bool(dialog_fallback.get("success", false)) or str(dialog_fallback.get("data", {}).get("capture_backend", "")) != "editor":
		return _failure("active_dialog capture should fall back to editor capture when no popup is visible and require_target=false.")
	if not ((dialog_fallback.get("data", {}).get("capture_fallback_reasons", []) as Array).has("active_dialog_not_found")):
		return _failure("active_dialog editor fallback should report why it degraded.")

	fake.popup_visible = false
	var dialog_required := impl.execute("editor_evidence", {"action": "capture", "surface": "active_dialog", "require_target": true})
	fake.popup_visible = true
	if bool(dialog_required.get("success", false)) or str(dialog_required.get("data", {}).get("reason", "")) != "active_dialog_not_found":
		return _failure("active_dialog require_target should fail when no popup is visible.")

	return {"name": "system_editor_evidence_contracts", "success": true}


func _has_call_since(calls: Array, start_index: int, tool_name: String, action: String) -> bool:
	for index in range(start_index, calls.size()):
		var call: Dictionary = calls[index]
		if str(call.get("tool", "")) == tool_name and str(call.get("action", "")) == action:
			return true
	return false


func _failure(message: String) -> Dictionary:
	return {"name": "system_editor_evidence_contracts", "success": false, "error": message}
