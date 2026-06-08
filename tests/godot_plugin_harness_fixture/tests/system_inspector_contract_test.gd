extends RefCounted

# {"name": "system_inspector_contracts"}

const InspectorImplScript = preload("res://addons/godot_dotnet_mcp/tools/system/impl_inspector.gd")


class FakeBridge extends RefCounted:
	var name_value = "Hero"
	var speed_value = 3.5
	var visible_value = false
	var mode_index = 1
	var capture_control_enabled = true
	var capture_editor_enabled = true
	var include_settings_rows = false
	var query_filters_children = true
	var calls: Array[Dictionary] = []

	func call_atomic(tool_name: String, args: Dictionary) -> Dictionary:
		var action = str(args.get("action", ""))
		calls.append({"tool": tool_name, "action": action, "args": args.duplicate(true)})
		match tool_name:
			"editor_inspector":
				match action:
					"get_edited":
						return success({"kind": "node", "path": "/root/Hero", "class": "CharacterBody3D"})
					"get_selected_property":
						return success({"selected_path": "name"})
					"edit_object":
						return success({"kind": "node", "path": str(args.get("path", "")), "class": "CharacterBody3D"})
					"inspect_resource":
						return success({"kind": "resource", "resource_path": str(args.get("resource_path", "")), "class": "Resource"})
					"refresh":
						return success({"refreshed": true})
					_:
						return error("Unsupported editor_inspector action: %s" % action)
			"editor_ui_control":
				match action:
					"list_visible":
						var visible_controls = _visible_controls(bool(args.get("include_hidden", false)))
						var query = str(args.get("text_query", "")).strip_edges().to_lower()
						var filtered: Array[Dictionary] = []
						for control in visible_controls:
							if query.is_empty() or not query_filters_children or _control_matches(control, query):
								filtered.append(control)
						var limit = maxi(int(args.get("limit", filtered.size())), 1)
						return success({"count": filtered.size(), "controls": filtered.slice(0, mini(limit, filtered.size()))})
					"focus_control":
						return success({"target_path": str(args.get("target_path", "")), "focused": true})
					"set_text":
						var target_path = str(args.get("target_path", ""))
						if target_path.ends_with("/Name/Value"):
							name_value = str(args.get("text", ""))
							return success({"target_path": target_path, "text": name_value})
						return error("Text target not found")
					"set_value":
						var target_path = str(args.get("target_path", ""))
						if target_path.ends_with("/Speed/Value"):
							speed_value = float(args.get("value", 0.0))
							return success({"target_path": target_path, "value": speed_value})
						return error("Numeric target not found")
					"activate_control":
						var target_path = str(args.get("target_path", ""))
						if target_path.ends_with("/Visible/Value"):
							visible_value = not visible_value
							return success({"target_path": target_path, "button_pressed": visible_value})
						return error("Activation target not found")
					"capture_control":
						if capture_control_enabled:
							return success({"path": str(args.get("path", "user://inspector.png")), "target_path": str(args.get("target_path", "")), "capture_mode": "control"})
						return error("Control capture unavailable")
					_:
						return error("Unsupported editor_ui_control action: %s" % action)
			"editor_screenshot":
				if action == "capture" and capture_editor_enabled:
					return success({"path": str(args.get("path", "user://inspector_editor.png")), "capture_mode": "full"})
				return error("Unsupported editor_screenshot action: %s" % action)
			_:
				return error("Unsupported atomic tool: %s" % tool_name)

	func success(data = {}, message: String = "") -> Dictionary:
		return {"success": true, "data": data, "message": message}

	func error(message: String, data = {}) -> Dictionary:
		return {"success": false, "error": "bridge_error", "message": message, "data": data}

	func _visible_controls(include_hidden: bool) -> Array[Dictionary]:
		var rows: Array[Dictionary] = [
			{"path": "/root/InspectorDock/EditorInspector", "class": "EditorInspector", "name": "Inspector", "visible": true, "enabled": true, "child_count": 6}
		]
		rows.append_array(_property_row("Name", "name", "LineEdit", {"text": name_value, "editable_text": true, "actionable": ["focus", "set_text"]}))
		rows.append_array(_property_row("Speed", "movement/speed", "SpinBox", {"value": speed_value, "text": str(speed_value), "actionable": ["focus", "set_value"]}))
		rows.append_array(_property_row("Visible", "visible", "CheckBox", {"button_pressed": visible_value, "text": str(visible_value), "actionable": ["focus", "activate"]}))
		rows.append_array(_property_row("Mode", "mode", "OptionButton", {"text": "Walk", "selected_index": mode_index, "actionable": ["focus"]}))
		rows.append_array(_property_row("Duplicate", "duplicate", "LineEdit", {"text": "First", "editable_text": true, "actionable": ["focus", "set_text"]}))
		rows.append_array(_property_row("Duplicate Copy", "duplicate", "LineEdit", {"text": "Second", "editable_text": true, "actionable": ["focus", "set_text"]}))
		rows.append_array(_property_row("Read Only", "read_only", "LineEdit", {"text": "Locked", "editable_text": true, "read_only": true, "actionable": ["focus", "set_text"]}))
		rows.append_array(_property_row("Disabled", "disabled", "LineEdit", {"text": "Disabled", "editable_text": true, "enabled": false, "actionable": ["focus", "set_text"]}))
		if include_hidden:
			rows.append_array(_property_row("Hidden", "hidden", "LineEdit", {"text": "Hidden", "editable_text": true, "visible": false, "actionable": ["focus", "set_text"]}))
		if include_settings_rows:
			rows.append({"path": "/root/ProjectSettingsDialog/Rows/SettingRow", "parent_path": "/root/ProjectSettingsDialog/Rows", "class": "HBoxContainer", "text": "Application Name", "setting_path": "application/config/name", "visible": true, "enabled": true, "child_count": 2})
			rows.append({"path": "/root/ProjectSettingsDialog/Rows/SettingRow/Value", "parent_path": "/root/ProjectSettingsDialog/Rows/SettingRow", "class": "LineEdit", "text": "Wrong Surface", "visible": true, "enabled": true, "editable_text": true, "actionable": ["focus", "set_text"]})
		return rows

	func _property_row(label: String, property_path: String, value_class: String, value_fields: Dictionary) -> Array[Dictionary]:
		var base_path = "/root/InspectorDock/EditorInspector/Properties/%s" % label.replace(" ", "")
		var row_visible = bool(value_fields.get("visible", true))
		var row = {
			"path": base_path,
			"parent_path": "/root/InspectorDock/EditorInspector/Properties",
			"class": "HBoxContainer",
			"text": label,
			"property_path": property_path,
			"visible": row_visible,
			"enabled": true,
			"child_count": 2
		}
		var value = {
			"path": "%s/Value" % base_path,
			"parent_path": base_path,
			"class": value_class,
			"visible": row_visible,
			"enabled": bool(value_fields.get("enabled", true)),
			"child_count": 0
		}
		for key in value_fields.keys():
			value[key] = value_fields.get(key)
		return [row, value]

	func _control_matches(control: Dictionary, query: String) -> bool:
		var haystack = " ".join([
			str(control.get("path", "")),
			str(control.get("text", "")),
			str(control.get("name", "")),
			str(control.get("property_path", ""))
		]).to_lower()
		return haystack.contains(query)


func run_case(tree: SceneTree) -> Dictionary:
	var fake = FakeBridge.new()
	var impl = InspectorImplScript.new()
	impl.bridge = fake

	var schema = impl.get_tools()[0]
	var actions: Array = schema.get("inputSchema", {}).get("properties", {}).get("action", {}).get("enum", [])
	for action in ["status", "edit_object", "inspect_resource", "refresh", "list_properties", "resolve_property", "read_value", "focus_value", "set_value", "verify_value", "run_task", "capture"]:
		if not actions.has(action):
			return _failure("system_inspector schema should expose action: %s" % action)

	var status = impl.execute("inspector", {"action": "status"})
	if not bool(status.get("success", false)):
		return _failure("status should read the edited Inspector object.")
	if str(status.get("data", {}).get("edited", {}).get("path", "")) != "/root/Hero":
		return _failure("status should preserve edited object metadata.")

	var object_result = impl.execute("inspector", {"action": "edit_object", "node_path": "/root/Hero"})
	if not bool(object_result.get("success", false)) or not _has_call(fake.calls, "editor_inspector", "edit_object"):
		return _failure("edit_object should delegate to editor_inspector.edit_object.")
	var resource_result = impl.execute("inspector", {"action": "inspect_resource", "resource_path": "res://example.tres"})
	if not bool(resource_result.get("success", false)) or not _has_call(fake.calls, "editor_inspector", "inspect_resource"):
		return _failure("inspect_resource should delegate to editor_inspector.inspect_resource.")
	var refresh_result = impl.execute("inspector", {"action": "refresh"})
	if not bool(refresh_result.get("success", false)) or not _has_call(fake.calls, "editor_inspector", "refresh"):
		return _failure("refresh should delegate to editor_inspector.refresh.")

	var listed = impl.execute("inspector", {"action": "list_properties", "include_raw_controls": true, "limit": 20})
	if not bool(listed.get("success", false)):
		return _failure("list_properties should succeed against visible Inspector controls.")
	var listed_data: Dictionary = listed.get("data", {})
	if int(listed_data.get("property_count", 0)) < 5:
		return _failure("list_properties should summarize visible Inspector property rows.")
	if not listed_data.has("raw_controls"):
		return _failure("list_properties(include_raw_controls=true) should include raw controls for diagnostics.")
	if str(listed_data.get("model_quality", {}).get("high", "")) == "0":
		return _failure("list_properties should report high-confidence property models.")
	fake.include_settings_rows = true
	var mixed_surface_list = impl.execute("inspector", {"action": "list_properties", "property_path": "application/config/name", "limit": 20})
	fake.include_settings_rows = false
	if bool(mixed_surface_list.get("success", false)) and int(mixed_surface_list.get("data", {}).get("property_count", 0)) != 0:
		return _failure("system_inspector should ignore settings rows outside the Inspector subtree.")
	fake.query_filters_children = false
	var queried = impl.execute("inspector", {"action": "read_value", "query": "Name"})
	fake.query_filters_children = true
	if not bool(queried.get("success", false)) or str(queried.get("data", {}).get("value", {}).get("value", "")) != "Hero":
		return _failure("system_inspector should filter queries after collecting Inspector value children.")

	var resolved = impl.execute("inspector", {"action": "resolve_property", "property_path": "movement/speed"})
	if not bool(resolved.get("success", false)):
		return _failure("resolve_property should resolve one visible property.")
	if str(resolved.get("data", {}).get("value_control_path", "")) != "/root/InspectorDock/EditorInspector/Properties/Speed/Value":
		return _failure("resolve_property should expose the value control path.")
	if _has_value_payload_key(resolved.get("data", {})):
		return _failure("resolve_property should not leak current value payloads.")

	var ambiguous = impl.execute("inspector", {"action": "resolve_property", "property_path": "duplicate"})
	if bool(ambiguous.get("success", false)):
		return _failure("resolve_property should fail on ambiguous selectors.")
	if _has_value_payload_key(ambiguous.get("data", {})):
		return _failure("ambiguous resolve payload should sanitize value hints.")

	var text_read = impl.execute("inspector", {"action": "read_value", "property_path": "name"})
	if not bool(text_read.get("success", false)):
		return _failure("read_value should read a unique text property.")
	if str(text_read.get("data", {}).get("value", {}).get("value", "")) != "Hero":
		return _failure("read_value should return typed text values.")
	var number_read = impl.execute("inspector", {"action": "read_value", "property_path": "movement/speed"})
	if not bool(number_read.get("success", false)) or not is_equal_approx(float(number_read.get("data", {}).get("value", {}).get("value", 0.0)), 3.5):
		return _failure("read_value should return typed numeric values.")
	var bool_read = impl.execute("inspector", {"action": "read_value", "property_path": "visible"})
	if not bool(bool_read.get("success", false)) or bool(bool_read.get("data", {}).get("value", {}).get("value", true)):
		return _failure("read_value should return typed bool values.")

	var calls_before_focus = fake.calls.size()
	var focused = impl.execute("inspector", {"action": "focus_value", "property_path": "name"})
	if not bool(focused.get("success", false)) or not _has_call_since(fake.calls, calls_before_focus, "editor_ui_control", "focus_control"):
		return _failure("focus_value should delegate to editor_ui_control.focus_control.")

	var text_set = await impl.execute_async("inspector", {"action": "set_value", "property_path": "name", "value": "Player"})
	if not bool(text_set.get("success", false)) or fake.name_value != "Player":
		return _failure("set_value should write and verify supported text properties.")
	if str(text_set.get("data", {}).get("write", {}).get("write_action", "")) != "set_text":
		return _failure("text set_value should report set_text write_action.")
	var number_set = await impl.execute_async("inspector", {"action": "set_value", "property_path": "movement/speed", "value": 9.25})
	if not bool(number_set.get("success", false)) or not is_equal_approx(fake.speed_value, 9.25):
		return _failure("set_value should write and verify supported number properties.")
	var bool_set = await impl.execute_async("inspector", {"action": "set_value", "property_path": "visible", "value": true})
	if not bool(bool_set.get("success", false)) or not fake.visible_value:
		return _failure("set_value should activate bool controls only when the value changes.")
	var bool_noop_calls = fake.calls.size()
	var bool_noop = await impl.execute_async("inspector", {"action": "set_value", "property_path": "visible", "value": true})
	if not bool(bool_noop.get("success", false)) or _has_call_since(fake.calls, bool_noop_calls, "editor_ui_control", "activate_control"):
		return _failure("set_value should no-op bool writes that already match.")

	var enum_write = await impl.execute_async("inspector", {"action": "set_value", "property_path": "mode", "value": "Run"})
	if bool(enum_write.get("success", false)):
		return _failure("set_value should report unsupported enum writes instead of guessing.")
	var disabled_write = await impl.execute_async("inspector", {"action": "set_value", "property_path": "read_only", "value": "Unlocked"})
	if bool(disabled_write.get("success", false)) or str(disabled_write.get("data", {}).get("reason", "")) != "disabled_value_refused":
		return _failure("set_value should refuse disabled/read-only value controls.")
	var disabled_control_write = await impl.execute_async("inspector", {"action": "set_value", "property_path": "disabled", "value": "Unlocked"})
	if bool(disabled_control_write.get("success", false)) or str(disabled_control_write.get("data", {}).get("reason", "")) != "disabled_value_refused":
		return _failure("set_value should refuse enabled=false value controls.")
	var invalid_bool_write = await impl.execute_async("inspector", {"action": "set_value", "property_path": "visible", "value": "banana"})
	if bool(invalid_bool_write.get("success", false)) or str(invalid_bool_write.get("data", {}).get("write", {}).get("reason", "")) != "invalid_value_type":
		return _failure("set_value should reject ambiguous bool strings instead of coercing them to false.")
	var hidden_write = await impl.execute_async("inspector", {"action": "set_value", "property_path": "hidden", "value": "Shown", "include_hidden": true})
	if bool(hidden_write.get("success", false)) or str(hidden_write.get("data", {}).get("reason", "")) != "hidden_write_refused":
		return _failure("set_value should refuse writes when include_hidden=true.")

	var verify_ok = impl.execute("inspector", {"action": "verify_value", "property_path": "name", "expected_value": "Player"})
	if not bool(verify_ok.get("success", false)):
		return _failure("verify_value should succeed for matching current values.")
	var verify_fail = impl.execute("inspector", {"action": "verify_value", "property_path": "movement/speed", "expected_value": 1.0})
	if bool(verify_fail.get("success", false)) or str(verify_fail.get("data", {}).get("verification", {}).get("reason", "")) != "value_mismatch":
		return _failure("verify_value should fail with value_mismatch for different values.")
	var invalid_bool_verify = impl.execute("inspector", {"action": "verify_value", "property_path": "visible", "expected_value": "banana"})
	if bool(invalid_bool_verify.get("success", false)) or str(invalid_bool_verify.get("data", {}).get("verification", {}).get("reason", "")) != "invalid_value_type":
		return _failure("verify_value should reject ambiguous bool expected values.")

	var captured = impl.execute("inspector", {"action": "capture", "property_path": "name", "path": "user://inspector_name.png"})
	if not bool(captured.get("success", false)) or str(captured.get("data", {}).get("capture_backend", "")) != "control":
		return _failure("capture should prefer the resolved Inspector value/control evidence target.")
	fake.capture_control_enabled = false
	var editor_capture = impl.execute("inspector", {"action": "capture", "property_path": "name"})
	fake.capture_control_enabled = true
	if not bool(editor_capture.get("success", false)) or str(editor_capture.get("data", {}).get("capture_backend", "")) != "editor":
		return _failure("capture should fall back to full editor screenshots when control capture is unavailable.")

	fake.capture_control_enabled = false
	fake.capture_editor_enabled = false
	var required_capture_failure = await impl.execute_async("inspector", {
		"action": "run_task",
		"property_path": "name",
		"value": "Unsafe",
		"require_capture": true
	})
	fake.capture_control_enabled = true
	fake.capture_editor_enabled = true
	if bool(required_capture_failure.get("success", false)):
		return _failure("run_task(require_capture=true) should fail before writing when no evidence backend works.")
	if fake.name_value == "Unsafe":
		return _failure("run_task should not write after required preflight capture failure.")

	var task = await impl.execute_async("inspector", {
		"action": "run_task",
		"node_path": "/root/Hero",
		"property_path": "name",
		"value": "Trusted",
		"expected_value": "Trusted",
		"capture_policy": "always",
		"path": "user://trusted_inspector.png"
	})
	if not bool(task.get("success", false)) or fake.name_value != "Trusted":
		return _failure("run_task should compose target prep, read, supported write, verify, and capture.")
	var task_data: Dictionary = task.get("data", {})
	if str(task_data.get("capture_backend", "")) != "control":
		return _failure("run_task(capture_policy=always) should attach final Inspector evidence when possible.")
	if not bool(task_data.get("write_verified", false)):
		return _failure("run_task should report write_verified for successful write-and-verify tasks.")
	if _task_steps_have_raw_payload(task_data.get("steps", {})):
		return _failure("run_task step summaries should not expose raw control lists.")
	if not _has_call(fake.calls, "editor_inspector", "edit_object"):
		return _failure("run_task(node_path=...) should prepare the target object before property operations.")
	if not _has_call(fake.calls, "editor_inspector", "refresh"):
		return _failure("run_task(node_path=...) should refresh the Inspector after changing the target object.")

	var read_task = await impl.execute_async("inspector", {"action": "run_task", "property_path": "name", "capture_policy": "none"})
	if not bool(read_task.get("success", false)):
		return _failure("run_task without value or expected_value should work as a read task.")
	if bool(read_task.get("data", {}).get("write_attempted", true)):
		return _failure("read-only run_task should report write_attempted=false.")

	return {"name": "system_inspector_contracts", "success": true}


func _has_call(calls: Array, tool_name: String, action: String) -> bool:
	for call in calls:
		if str(call.get("tool", "")) == tool_name and str(call.get("action", "")) == action:
			return true
	return false


func _has_call_since(calls: Array, start_index: int, tool_name: String, action: String) -> bool:
	for index in range(start_index, calls.size()):
		var call: Dictionary = calls[index]
		if str(call.get("tool", "")) == tool_name and str(call.get("action", "")) == action:
			return true
	return false


func _has_value_payload_key(value) -> bool:
	if value is Dictionary:
		var dict = value as Dictionary
		for key in dict.keys():
			if ["value", "value_text", "pressed", "button_pressed", "selected", "selected_index"].has(str(key)):
				return true
			if _has_value_payload_key(dict.get(key)):
				return true
		return false
	if value is Array:
		for item in value:
			if _has_value_payload_key(item):
				return true
	return false


func _task_steps_have_raw_payload(steps) -> bool:
	if not (steps is Dictionary):
		return false
	for step_name in (steps as Dictionary).keys():
		var step = (steps as Dictionary).get(step_name)
		if not (step is Dictionary):
			continue
		var data = (step as Dictionary).get("data", {})
		if not (data is Dictionary):
			continue
		for raw_key in ["controls", "raw_controls", "properties", "candidates"]:
			if (data as Dictionary).has(raw_key):
				return true
	return false


func _failure(message: String) -> Dictionary:
	return {"name": "system_inspector_contracts", "success": false, "error": message}
