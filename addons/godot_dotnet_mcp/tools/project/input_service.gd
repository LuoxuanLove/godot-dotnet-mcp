@tool
extends "res://addons/godot_dotnet_mcp/tools/project/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	match str(args.get("action", "")):
		"list_actions":
			return _list_input_actions()
		"get_action":
			return _get_input_action(str(args.get("name", "")))
		"add_action":
			return _add_input_action(str(args.get("name", "")))
		"remove_action":
			return _remove_input_action(str(args.get("name", "")))
		"add_binding":
			return _add_input_binding(args)
		"remove_binding":
			return _remove_input_binding(args)
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


func _list_input_actions() -> Dictionary:
	var actions: Array[Dictionary] = []
	for prop in ProjectSettings.get_property_list():
		var prop_name := str(prop.name)
		if prop_name.begins_with("input/"):
			var action_name = prop_name.substr(6)
			var action_data = ProjectSettings.get_setting(prop_name)
			if action_data is Dictionary:
				var events = action_data.get("events", [])
				actions.append({
					"name": action_name,
					"deadzone": action_data.get("deadzone", 0.5),
					"event_count": events.size()
				})

	return _success({
		"count": actions.size(),
		"actions": actions
	})


func _get_input_action(name: String) -> Dictionary:
	if name.is_empty():
		return _error("Action name is required")

	var setting_path = "input/" + name
	if not ProjectSettings.has_setting(setting_path):
		return _error("Action not found: %s" % name)

	var action_data = ProjectSettings.get_setting(setting_path)
	var events_info: Array[Dictionary] = []
	if action_data is Dictionary:
		var events = action_data.get("events", [])
		for event in events:
			events_info.append(_event_to_dict(event))

	return _success({
		"name": name,
		"deadzone": action_data.get("deadzone", 0.5) if action_data is Dictionary else 0.5,
		"events": events_info
	})


func _add_input_action(name: String) -> Dictionary:
	if name.is_empty():
		return _error("Action name is required")

	var setting_path = "input/" + name
	if ProjectSettings.has_setting(setting_path):
		return _error("Action already exists: %s" % name)

	ProjectSettings.set_setting(setting_path, {
		"deadzone": 0.5,
		"events": []
	})

	var error = ProjectSettings.save()
	if error != OK:
		return _error("Failed to save project settings")

	return _success({"name": name}, "Input action added")


func _remove_input_action(name: String) -> Dictionary:
	if name.is_empty():
		return _error("Action name is required")

	var setting_path = "input/" + name
	if not ProjectSettings.has_setting(setting_path):
		return _error("Action not found: %s" % name)

	ProjectSettings.set_setting(setting_path, null)

	var error = ProjectSettings.save()
	if error != OK:
		return _error("Failed to save project settings")

	return _success({"name": name}, "Input action removed")


func _add_input_binding(args: Dictionary) -> Dictionary:
	var name = str(args.get("name", ""))
	var input_type = str(args.get("type", ""))

	if name.is_empty():
		return _error("Action name is required")
	if input_type.is_empty():
		return _error("Input type is required")

	var setting_path = "input/" + name
	if not ProjectSettings.has_setting(setting_path):
		return _error("Action not found: %s" % name)

	var action_data = ProjectSettings.get_setting(setting_path)
	if not (action_data is Dictionary):
		action_data = {"deadzone": 0.5, "events": []}

	var events = action_data.get("events", [])
	var new_event: InputEvent

	match input_type:
		"key":
			new_event = InputEventKey.new()
			var key_string = str(args.get("key", ""))
			if key_string.is_empty():
				return _error("Key is required for keyboard input")
			new_event.keycode = OS.find_keycode_from_string(key_string)
		"mouse":
			new_event = InputEventMouseButton.new()
			match str(args.get("button", "left")):
				"left":
					new_event.button_index = MOUSE_BUTTON_LEFT
				"right":
					new_event.button_index = MOUSE_BUTTON_RIGHT
				"middle":
					new_event.button_index = MOUSE_BUTTON_MIDDLE
				_:
					return _error("Unknown mouse button: %s" % str(args.get("button", "")))
		"joypad_button":
			new_event = InputEventJoypadButton.new()
			new_event.button_index = int(args.get("button", 0))
		"joypad_axis":
			new_event = InputEventJoypadMotion.new()
			new_event.axis = int(args.get("axis", 0))
			new_event.axis_value = float(args.get("axis_value", 1.0))
		_:
			return _error("Unknown input type: %s" % input_type)

	events.append(new_event)
	action_data["events"] = events
	ProjectSettings.set_setting(setting_path, action_data)

	var error = ProjectSettings.save()
	if error != OK:
		return _error("Failed to save project settings")

	return _success({
		"name": name,
		"type": input_type,
		"event_count": events.size()
	}, "Input binding added")


func _remove_input_binding(args: Dictionary) -> Dictionary:
	var name = str(args.get("name", ""))
	var index = int(args.get("index", -1))

	if name.is_empty():
		return _error("Action name is required")
	if index < 0:
		return _error("Binding index is required")

	var setting_path = "input/" + name
	if not ProjectSettings.has_setting(setting_path):
		return _error("Action not found: %s" % name)

	var action_data = ProjectSettings.get_setting(setting_path)
	if not (action_data is Dictionary):
		return _error("Invalid action data")

	var events = action_data.get("events", [])
	if index >= events.size():
		return _error("Binding index out of range")

	events.remove_at(index)
	action_data["events"] = events
	ProjectSettings.set_setting(setting_path, action_data)

	var error = ProjectSettings.save()
	if error != OK:
		return _error("Failed to save project settings")

	return _success({
		"name": name,
		"removed_index": index
	}, "Input binding removed")
