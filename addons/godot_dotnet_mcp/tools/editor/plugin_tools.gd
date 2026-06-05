@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

## Editor plugin tools for Godot MCP


func execute(ei, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	var plugin_name := str(args.get("plugin", "")).strip_edges()

	if not ei:
		return _error("Editor interface not available")

	match action:
		"list":
			return _list_plugins(ei)
		"inspect":
			return _inspect_plugin(ei, plugin_name)
		"is_enabled":
			return _is_plugin_enabled(ei, plugin_name)
		"enable":
			return _set_plugin_enabled(ei, plugin_name, true, bool(args.get("allow_self", false)))
		"disable":
			return _set_plugin_enabled(ei, plugin_name, false, bool(args.get("allow_self", false)))
		_:
			return _error("Unknown action: %s" % action)


func _list_plugins(ei) -> Dictionary:
	var plugins: Array[Dictionary] = []
	var dir = DirAccess.open("res://addons")

	if dir:
		dir.list_dir_begin()
		var folder = dir.get_next()

		while not folder.is_empty():
			if dir.current_is_dir() and not folder.begins_with("."):
				var plugin_cfg = "res://addons/%s/plugin.cfg" % folder
				if FileAccess.file_exists(plugin_cfg):
					var summary := _build_plugin_summary(ei, folder)
					if bool(summary.get("exists", false)):
						plugins.append(summary)
			folder = dir.get_next()
		dir.list_dir_end()

	return _success({
		"count": plugins.size(),
		"plugins": plugins
	})


func _is_plugin_enabled(ei, plugin_name: String) -> Dictionary:
	if plugin_name.is_empty():
		return _error("Plugin name is required")
	if not _plugin_exists(plugin_name):
		return _plugin_not_found(plugin_name)

	return _success(_build_plugin_summary(ei, plugin_name))


func _inspect_plugin(ei, plugin_name: String) -> Dictionary:
	if plugin_name.is_empty():
		return _error("Plugin name is required")
	if not _plugin_exists(plugin_name):
		return _plugin_not_found(plugin_name)
	return _success(_build_plugin_summary(ei, plugin_name))


func _set_plugin_enabled(ei, plugin_name: String, enabled: bool, allow_self: bool) -> Dictionary:
	if plugin_name.is_empty():
		return _error("Plugin name is required")
	if not _plugin_exists(plugin_name):
		return _plugin_not_found(plugin_name)
	if _is_self_plugin(plugin_name) and not allow_self:
		return _error("Refusing to toggle the active MCP plugin from the generic editor plugin tool", _build_plugin_summary(ei, plugin_name), [
			"Use system_plugin_reload or the dedicated plugin update/reload tools for this plugin.",
			"Pass allow_self=true only when an interactive operator explicitly accepts the disconnect risk."
		])

	ei.set_plugin_enabled(plugin_name, enabled)
	var summary := _build_plugin_summary(ei, plugin_name)
	summary["requested_enabled"] = enabled

	return _success(summary, "Plugin enabled" if enabled else "Plugin disabled")


func _plugin_not_found(plugin_name: String) -> Dictionary:
	return _error("Plugin not found: %s" % plugin_name, {
		"plugin": plugin_name,
		"exists": false,
		"error_type": "plugin_not_found",
		"plugin_cfg_path": _plugin_cfg_path(plugin_name)
	})


func _build_plugin_summary(ei, plugin_name: String) -> Dictionary:
	var metadata := _read_plugin_metadata(plugin_name)
	var display_name := str(metadata.get("display_name", "")).strip_edges()
	var editor_enabled := _safe_editor_enabled(ei, plugin_name)
	var setting_enabled := _is_plugin_enabled_in_project_settings(plugin_name)
	var ui_probe := _find_visible_plugin_ui(ei, [display_name, plugin_name])
	var instantiated := bool(ui_probe.get("visible", false))
	return {
		"plugin": plugin_name,
		"name": plugin_name,
		"exists": bool(metadata.get("exists", false)),
		"plugin_cfg_path": _plugin_cfg_path(plugin_name),
		"display_name": display_name,
		"script": str(metadata.get("script", "")),
		"description": str(metadata.get("description", "")),
		"author": str(metadata.get("author", "")),
		"version": str(metadata.get("version", "")),
		"setting_enabled": setting_enabled,
		"editor_enabled": editor_enabled,
		"enabled": editor_enabled,
		"instantiated": instantiated,
		"main_screen_visible": instantiated,
		"ui_probe": ui_probe,
		"requires_restart_or_manual_activation": setting_enabled and not editor_enabled,
		"self_plugin": _is_self_plugin(plugin_name),
		"can_toggle": not _is_self_plugin(plugin_name)
	}


func _read_plugin_metadata(plugin_name: String) -> Dictionary:
	var plugin_cfg := _plugin_cfg_path(plugin_name)
	if not FileAccess.file_exists(plugin_cfg):
		return {"exists": false}
	var cfg := ConfigFile.new()
	if cfg.load(plugin_cfg) != OK:
		return {"exists": false}
	return {
		"exists": true,
		"display_name": str(cfg.get_value("plugin", "name", plugin_name)),
		"script": str(cfg.get_value("plugin", "script", "")),
		"description": str(cfg.get_value("plugin", "description", "")),
		"author": str(cfg.get_value("plugin", "author", "")),
		"version": str(cfg.get_value("plugin", "version", ""))
	}


func _plugin_exists(plugin_name: String) -> bool:
	return FileAccess.file_exists(_plugin_cfg_path(plugin_name))


func _plugin_cfg_path(plugin_name: String) -> String:
	return "res://addons/%s/plugin.cfg" % plugin_name


func _safe_editor_enabled(ei, plugin_name: String) -> bool:
	if ei != null and ei.has_method("is_plugin_enabled"):
		return bool(ei.is_plugin_enabled(plugin_name))
	return false


func _is_plugin_enabled_in_project_settings(plugin_name: String) -> bool:
	var enabled_plugins = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	var plugin_cfg := _plugin_cfg_path(plugin_name)
	if enabled_plugins is PackedStringArray:
		return (enabled_plugins as PackedStringArray).has(plugin_name) or (enabled_plugins as PackedStringArray).has(plugin_cfg)
	if enabled_plugins is Array:
		return (enabled_plugins as Array).has(plugin_name) or (enabled_plugins as Array).has(plugin_cfg)
	return false


func _find_visible_plugin_ui(ei, labels: Array) -> Dictionary:
	var base_control = ei.get_base_control() if ei != null and ei.has_method("get_base_control") else null
	if base_control == null:
		return {"visible": false}
	var normalized_labels := []
	for label in labels:
		var normalized := str(label).strip_edges().to_lower()
		if not normalized.is_empty():
			normalized_labels.append(normalized)
	return _find_visible_plugin_ui_recursive(base_control, normalized_labels)


func _find_visible_plugin_ui_recursive(node, normalized_labels: Array) -> Dictionary:
	if node == null:
		return {"visible": false}
	if _is_control_visible(node):
		for label in _read_control_labels(node):
			if normalized_labels.has(label.to_lower()):
				return {
					"visible": true,
					"label": label,
					"path": _safe_control_path(node),
					"class": _control_class_name(node)
				}
	if node.has_method("get_children"):
		for child in node.get_children():
			var found := _find_visible_plugin_ui_recursive(child, normalized_labels)
			if bool(found.get("visible", false)):
				return found
	return {"visible": false}


func _read_control_labels(node) -> Array[String]:
	var labels: Array[String] = []
	for property_name in ["text", "title", "name"]:
		var value = node.get(property_name) if node is Object else null
		var label := str(value).strip_edges()
		if not label.is_empty():
			labels.append(label)
	return labels


func _is_control_visible(node) -> bool:
	if node != null and node.has_method("is_visible_in_tree"):
		return bool(node.is_visible_in_tree())
	if node != null and node is CanvasItem:
		return bool((node as CanvasItem).visible)
	return true


func _safe_control_path(node) -> String:
	if node == null or not node.has_method("get_path"):
		return ""
	return str(node.get_path())


func _control_class_name(node) -> String:
	if node == null:
		return ""
	if node.has_method("get_class"):
		return str(node.get_class())
	return str(node.get("class") if node is Object else "")


func _is_self_plugin(plugin_name: String) -> bool:
	return plugin_name == _get_self_plugin_name()


func _get_self_plugin_name() -> String:
	var plugin_host = _context.get("plugin_host", null)
	if plugin_host != null and is_instance_valid(plugin_host) and plugin_host.has_method("get_script"):
		var script = plugin_host.get_script()
		if script != null:
			var path := str(script.resource_path)
			var prefix := "res://addons/"
			if path.begins_with(prefix):
				var remainder := path.substr(prefix.length())
				var slash_index := remainder.find("/")
				if slash_index > 0:
					return remainder.substr(0, slash_index)
	return "godot_dotnet_mcp"
