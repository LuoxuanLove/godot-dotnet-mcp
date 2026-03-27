@tool
extends "res://addons/godot_dotnet_mcp/tools/ui/service_base.gd"


func handle_control(control: Control, args: Dictionary) -> Dictionary:
	match str(args.get("action", "")):
		"set_focus_mode":
			return _set_focus_mode(control, str(args.get("mode", "none")))
		"set_mouse_filter":
			return _set_mouse_filter(control, str(args.get("filter", "stop")))
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


func _set_focus_mode(control: Control, mode: String) -> Dictionary:
	match mode.to_lower():
		"none":
			control.focus_mode = Control.FOCUS_NONE
		"click":
			control.focus_mode = Control.FOCUS_CLICK
		"all":
			control.focus_mode = Control.FOCUS_ALL
		_:
			return _error("Invalid focus mode: %s" % mode)

	return _success({"focus_mode": mode}, "Focus mode set")


func _set_mouse_filter(control: Control, filter_name: String) -> Dictionary:
	match filter_name.to_lower():
		"stop":
			control.mouse_filter = Control.MOUSE_FILTER_STOP
		"pass":
			control.mouse_filter = Control.MOUSE_FILTER_PASS
		"ignore":
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_:
			return _error("Invalid mouse filter: %s" % filter_name)

	return _success({"mouse_filter": filter_name}, "Mouse filter set")
