@tool
extends "res://addons/godot_dotnet_mcp/tools/ui/service_base.gd"


func handle_control(control: Control, args: Dictionary) -> Dictionary:
	match str(args.get("action", "")):
		"get_layout":
			return _get_control_layout(control)
		"arrange":
			return _arrange_children(control)
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


func _get_control_layout(control: Control) -> Dictionary:
	return _success({
		"path": _get_scene_path(control),
		"position": _serialize_value(control.position),
		"size": _serialize_value(control.size),
		"global_position": _serialize_value(control.global_position),
		"anchors": {
			"left": control.anchor_left,
			"top": control.anchor_top,
			"right": control.anchor_right,
			"bottom": control.anchor_bottom
		},
		"offsets": {
			"left": control.offset_left,
			"top": control.offset_top,
			"right": control.offset_right,
			"bottom": control.offset_bottom
		},
		"pivot_offset": _serialize_value(control.pivot_offset),
		"rotation": control.rotation,
		"scale": _serialize_value(control.scale),
		"custom_minimum_size": _serialize_value(control.custom_minimum_size),
		"size_flags": {
			"horizontal": control.size_flags_horizontal,
			"vertical": control.size_flags_vertical,
			"stretch_ratio": control.size_flags_stretch_ratio
		},
		"focus_mode": control.focus_mode,
		"mouse_filter": control.mouse_filter,
		"tooltip_text": control.tooltip_text
	})


func _arrange_children(control: Control) -> Dictionary:
	if control is Container:
		control.queue_sort()
		return _success({
			"path": _get_scene_path(control),
			"child_count": control.get_child_count()
		}, "Children arranged")

	return _success({
		"note": "Node is not a Container, no arrangement needed"
	})
