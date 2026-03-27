@tool
extends "res://addons/godot_dotnet_mcp/tools/ui/service_base.gd"


func handle_control(control: Control, args: Dictionary) -> Dictionary:
	match str(args.get("action", "")):
		"set_anchor":
			return _set_control_anchor(control, args)
		"set_anchor_preset":
			return _set_anchor_preset(control, str(args.get("preset", "")))
		"set_margins":
			return _set_control_margins(control, args)
		"set_size_flags":
			return _set_size_flags(control, args)
		"set_min_size":
			return _set_min_size(control, args)
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


func _set_control_anchor(control: Control, args: Dictionary) -> Dictionary:
	if args.has("left"):
		control.anchor_left = float(args.get("left", control.anchor_left))
	if args.has("top"):
		control.anchor_top = float(args.get("top", control.anchor_top))
	if args.has("right"):
		control.anchor_right = float(args.get("right", control.anchor_right))
	if args.has("bottom"):
		control.anchor_bottom = float(args.get("bottom", control.anchor_bottom))

	return _success({
		"anchors": {
			"left": control.anchor_left,
			"top": control.anchor_top,
			"right": control.anchor_right,
			"bottom": control.anchor_bottom
		}
	}, "Anchors set")


func _set_anchor_preset(control: Control, preset: String) -> Dictionary:
	var preset_value: Control.LayoutPreset
	match preset.to_lower():
		"top_left": preset_value = Control.PRESET_TOP_LEFT
		"top_right": preset_value = Control.PRESET_TOP_RIGHT
		"bottom_left": preset_value = Control.PRESET_BOTTOM_LEFT
		"bottom_right": preset_value = Control.PRESET_BOTTOM_RIGHT
		"center_left": preset_value = Control.PRESET_CENTER_LEFT
		"center_right": preset_value = Control.PRESET_CENTER_RIGHT
		"center_top": preset_value = Control.PRESET_CENTER_TOP
		"center_bottom": preset_value = Control.PRESET_CENTER_BOTTOM
		"center": preset_value = Control.PRESET_CENTER
		"full_rect": preset_value = Control.PRESET_FULL_RECT
		"top_wide": preset_value = Control.PRESET_TOP_WIDE
		"bottom_wide": preset_value = Control.PRESET_BOTTOM_WIDE
		"left_wide": preset_value = Control.PRESET_LEFT_WIDE
		"right_wide": preset_value = Control.PRESET_RIGHT_WIDE
		"hcenter_wide": preset_value = Control.PRESET_HCENTER_WIDE
		"vcenter_wide": preset_value = Control.PRESET_VCENTER_WIDE
		_:
			return _error("Invalid preset: %s" % preset)

	control.set_anchors_and_offsets_preset(preset_value)
	return _success({"preset": preset}, "Anchor preset applied")


func _set_control_margins(control: Control, args: Dictionary) -> Dictionary:
	if args.has("left"):
		control.offset_left = float(args.get("left", control.offset_left))
	if args.has("top"):
		control.offset_top = float(args.get("top", control.offset_top))
	if args.has("right"):
		control.offset_right = float(args.get("right", control.offset_right))
	if args.has("bottom"):
		control.offset_bottom = float(args.get("bottom", control.offset_bottom))

	return _success({
		"offsets": {
			"left": control.offset_left,
			"top": control.offset_top,
			"right": control.offset_right,
			"bottom": control.offset_bottom
		}
	}, "Margins/offsets set")


func _set_size_flags(control: Control, args: Dictionary) -> Dictionary:
	if args.has("horizontal"):
		var horizontal_flags := 0
		for flag in args.get("horizontal", []):
			match str(flag).to_lower():
				"fill":
					horizontal_flags |= Control.SIZE_FILL
				"expand":
					horizontal_flags |= Control.SIZE_EXPAND
				"shrink_center":
					horizontal_flags |= Control.SIZE_SHRINK_CENTER
				"shrink_end":
					horizontal_flags |= Control.SIZE_SHRINK_END
		control.size_flags_horizontal = horizontal_flags

	if args.has("vertical"):
		var vertical_flags := 0
		for flag in args.get("vertical", []):
			match str(flag).to_lower():
				"fill":
					vertical_flags |= Control.SIZE_FILL
				"expand":
					vertical_flags |= Control.SIZE_EXPAND
				"shrink_center":
					vertical_flags |= Control.SIZE_SHRINK_CENTER
				"shrink_end":
					vertical_flags |= Control.SIZE_SHRINK_END
		control.size_flags_vertical = vertical_flags

	return _success({
		"horizontal": control.size_flags_horizontal,
		"vertical": control.size_flags_vertical
	}, "Size flags set")


func _set_min_size(control: Control, args: Dictionary) -> Dictionary:
	var width := float(args.get("width", control.custom_minimum_size.x))
	var height := float(args.get("height", control.custom_minimum_size.y))
	control.custom_minimum_size = Vector2(width, height)
	return _success({
		"custom_minimum_size": _serialize_value(control.custom_minimum_size)
	}, "Minimum size set")
