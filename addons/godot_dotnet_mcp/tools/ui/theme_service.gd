@tool
extends "res://addons/godot_dotnet_mcp/tools/ui/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	match str(args.get("action", "")):
		"create":
			return _create_theme(args)
		"get_info":
			return _get_theme_info(str(args.get("path", "")))
		"set_color":
			return _set_theme_color(args)
		"get_color":
			return _get_theme_color(args)
		"set_constant":
			return _set_theme_constant(args)
		"get_constant":
			return _get_theme_constant(args)
		"set_font":
			return _set_theme_font(args)
		"set_font_size":
			return _set_theme_font_size(args)
		"set_stylebox":
			return _set_theme_stylebox(args)
		"clear_item":
			return _clear_theme_item(args)
		"copy_default":
			return _copy_from_default(args)
		"assign_to_node":
			return _assign_theme_to_node(str(args.get("theme_path", "")), str(args.get("node_path", "")))
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


func _create_theme(args: Dictionary) -> Dictionary:
	var save_path := str(args.get("save_path", ""))
	var theme := Theme.new()

	if save_path.is_empty():
		return _success({"note": "Theme created in memory"}, "Theme created")

	var normalized_save_path := save_path
	if not normalized_save_path.begins_with("res://"):
		normalized_save_path = "res://" + normalized_save_path
	if not normalized_save_path.ends_with(".tres") and not normalized_save_path.ends_with(".res"):
		normalized_save_path += ".tres"

	var error = ResourceSaver.save(theme, normalized_save_path)
	if error != OK:
		return _error("Failed to save theme: %s" % error_string(error))

	return _success({"path": normalized_save_path}, "Theme created and saved")


func _get_theme_info(path: String) -> Dictionary:
	var theme = _load_theme(path)
	if not theme:
		return _error("Theme not found: %s" % path)

	var info = {
		"path": str(theme.resource_path) if theme.resource_path else null,
		"default_font": str(theme.default_font.resource_path) if theme.default_font else null,
		"default_font_size": theme.default_font_size,
		"default_base_scale": theme.default_base_scale
	}

	var type_list = theme.get_type_list()
	var types := {}
	for type_name in type_list:
		types[type_name] = {
			"colors": Array(theme.get_color_list(type_name)),
			"constants": Array(theme.get_constant_list(type_name)),
			"fonts": Array(theme.get_font_list(type_name)),
			"font_sizes": Array(theme.get_font_size_list(type_name)),
			"icons": Array(theme.get_icon_list(type_name)),
			"styleboxes": Array(theme.get_stylebox_list(type_name))
		}

	info["types"] = types
	info["type_count"] = type_list.size()
	return _success(info)


func _set_theme_color(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	var name := str(args.get("name", ""))
	var type_name := str(args.get("type", ""))
	var color_dict: Dictionary = args.get("color", {})
	if name.is_empty() or type_name.is_empty():
		return _error("Name and type are required")

	var theme = _load_theme(path)
	if not theme:
		return _error("Theme not found: %s" % path)

	var color := Color(color_dict.get("r", 1.0), color_dict.get("g", 1.0), color_dict.get("b", 1.0), color_dict.get("a", 1.0))
	theme.set_color(name, type_name, color)
	return _success({
		"name": name,
		"type": type_name,
		"color": _serialize_value(color)
	}, "Color set")


func _get_theme_color(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	var name := str(args.get("name", ""))
	var type_name := str(args.get("type", ""))
	if name.is_empty() or type_name.is_empty():
		return _error("Name and type are required")

	var theme = _load_theme(path)
	if not theme:
		return _error("Theme not found: %s" % path)
	if not theme.has_color(name, type_name):
		return _error("Color not found: %s in %s" % [name, type_name])

	return _success({
		"name": name,
		"type": type_name,
		"color": _serialize_value(theme.get_color(name, type_name))
	})


func _set_theme_constant(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	var name := str(args.get("name", ""))
	var type_name := str(args.get("type", ""))
	var value := int(args.get("value", 0))
	if name.is_empty() or type_name.is_empty():
		return _error("Name and type are required")

	var theme = _load_theme(path)
	if not theme:
		return _error("Theme not found: %s" % path)
	theme.set_constant(name, type_name, value)
	return _success({
		"name": name,
		"type": type_name,
		"value": value
	}, "Constant set")


func _get_theme_constant(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	var name := str(args.get("name", ""))
	var type_name := str(args.get("type", ""))
	if name.is_empty() or type_name.is_empty():
		return _error("Name and type are required")

	var theme = _load_theme(path)
	if not theme:
		return _error("Theme not found: %s" % path)
	if not theme.has_constant(name, type_name):
		return _error("Constant not found: %s in %s" % [name, type_name])

	return _success({
		"name": name,
		"type": type_name,
		"value": theme.get_constant(name, type_name)
	})


func _set_theme_font(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	var name := str(args.get("name", ""))
	var type_name := str(args.get("type", ""))
	var font_path := str(args.get("font_path", ""))
	if name.is_empty() or type_name.is_empty():
		return _error("Name and type are required")

	var theme = _load_theme(path)
	if not theme:
		return _error("Theme not found: %s" % path)

	var font: Font = null
	if not font_path.is_empty():
		var normalized_font_path := font_path
		if not normalized_font_path.begins_with("res://"):
			normalized_font_path = "res://" + normalized_font_path
		font = load(normalized_font_path) as Font
		if not font:
			return _error("Font not found: %s" % normalized_font_path)

	theme.set_font(name, type_name, font)
	return _success({
		"name": name,
		"type": type_name,
		"font": font_path if font else null
	}, "Font set")


func _set_theme_font_size(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	var name := str(args.get("name", ""))
	var type_name := str(args.get("type", ""))
	var value := int(args.get("value", 16))
	if name.is_empty() or type_name.is_empty():
		return _error("Name and type are required")

	var theme = _load_theme(path)
	if not theme:
		return _error("Theme not found: %s" % path)
	theme.set_font_size(name, type_name, value)
	return _success({
		"name": name,
		"type": type_name,
		"size": value
	}, "Font size set")


func _set_theme_stylebox(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	var name := str(args.get("name", ""))
	var type_name := str(args.get("type", ""))
	var stylebox_type := str(args.get("stylebox_type", "flat"))
	if name.is_empty() or type_name.is_empty():
		return _error("Name and type are required")

	var theme = _load_theme(path)
	if not theme:
		return _error("Theme not found: %s" % path)

	var stylebox: StyleBox
	match stylebox_type:
		"flat":
			var flat := StyleBoxFlat.new()
			if args.has("bg_color"):
				var c: Dictionary = args.get("bg_color", {})
				flat.bg_color = Color(c.get("r", 1.0), c.get("g", 1.0), c.get("b", 1.0), c.get("a", 1.0))
			if args.has("corner_radius"):
				var radius := int(args.get("corner_radius", 0))
				flat.corner_radius_top_left = radius
				flat.corner_radius_top_right = radius
				flat.corner_radius_bottom_left = radius
				flat.corner_radius_bottom_right = radius
			if args.has("border_width"):
				var border_width := int(args.get("border_width", 0))
				flat.border_width_left = border_width
				flat.border_width_top = border_width
				flat.border_width_right = border_width
				flat.border_width_bottom = border_width
			if args.has("border_color"):
				var bc: Dictionary = args.get("border_color", {})
				flat.border_color = Color(bc.get("r", 0.0), bc.get("g", 0.0), bc.get("b", 0.0), bc.get("a", 1.0))
			stylebox = flat
		"line":
			stylebox = StyleBoxLine.new()
		"empty":
			stylebox = StyleBoxEmpty.new()
		_:
			return _error("Invalid stylebox type: %s" % stylebox_type)

	theme.set_stylebox(name, type_name, stylebox)
	return _success({
		"name": name,
		"type": type_name,
		"stylebox_type": stylebox_type
	}, "StyleBox set")


func _clear_theme_item(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	var name := str(args.get("name", ""))
	var type_name := str(args.get("type", ""))
	var data_type := str(args.get("data_type", "color"))
	if name.is_empty() or type_name.is_empty():
		return _error("Name and type are required")

	var theme = _load_theme(path)
	if not theme:
		return _error("Theme not found: %s" % path)

	match data_type:
		"color":
			theme.clear_color(name, type_name)
		"constant":
			theme.clear_constant(name, type_name)
		"font":
			theme.clear_font(name, type_name)
		"font_size":
			theme.clear_font_size(name, type_name)
		"icon":
			theme.clear_icon(name, type_name)
		"stylebox":
			theme.clear_stylebox(name, type_name)
		_:
			return _error("Invalid data type: %s" % data_type)

	return _success({
		"name": name,
		"type": type_name,
		"data_type": data_type
	}, "Theme item cleared")


func _copy_from_default(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	var type_name := str(args.get("type", ""))
	if type_name.is_empty():
		return _error("Type is required")

	var theme = _load_theme(path)
	if not theme:
		return _error("Theme not found: %s" % path)

	var default_theme = ThemeDB.get_default_theme()
	if not default_theme:
		return _error("Default theme not available")

	var items_copied := 0
	for color_name in default_theme.get_color_list(type_name):
		theme.set_color(color_name, type_name, default_theme.get_color(color_name, type_name))
		items_copied += 1
	for constant_name in default_theme.get_constant_list(type_name):
		theme.set_constant(constant_name, type_name, default_theme.get_constant(constant_name, type_name))
		items_copied += 1
	for stylebox_name in default_theme.get_stylebox_list(type_name):
		var stylebox = default_theme.get_stylebox(stylebox_name, type_name)
		if stylebox:
			theme.set_stylebox(stylebox_name, type_name, stylebox.duplicate())
			items_copied += 1

	return _success({
		"type": type_name,
		"items_copied": items_copied
	}, "Copied %d items from default theme" % items_copied)


func _assign_theme_to_node(theme_path: String, node_path: String) -> Dictionary:
	if theme_path.is_empty() or node_path.is_empty():
		return _error("Both theme_path and node_path are required")

	var theme = _load_theme(theme_path)
	if not theme:
		return _error("Theme not found: %s" % theme_path)
	var node = _find_active_node(node_path)
	if not node:
		return _error("Node not found: %s" % node_path)
	if not (node is Control):
		return _error("Node is not a Control: %s" % node_path)

	node.theme = theme
	return _success({
		"theme": theme_path,
		"node": node_path
	}, "Theme assigned")
