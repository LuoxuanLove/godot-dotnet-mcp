@tool
extends "res://addons/godot_dotnet_mcp/tools/editor/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	match action:
		"list":
			return _list_plugins()
		"is_enabled":
			return _plugin_enabled_state(str(args.get("plugin", "")), false)
		"enable":
			return _plugin_enabled_state(str(args.get("plugin", "")), true, true)
		"disable":
			return _plugin_enabled_state(str(args.get("plugin", "")), false, true)
		_:
			return _error("Unknown action: %s" % action)


func _list_plugins() -> Dictionary:
	var plugins: Array[Dictionary] = []
	var dir = DirAccess.open("res://addons")
	if dir != null:
		dir.list_dir_begin()
		while true:
			var folder := dir.get_next()
			if folder.is_empty():
				break
			if dir.current_is_dir() and not folder.begins_with("."):
				var plugin_cfg := "res://addons/%s/plugin.cfg" % folder
				if FileAccess.file_exists(plugin_cfg):
					var cfg := ConfigFile.new()
					if cfg.load(plugin_cfg) == OK:
						plugins.append({
							"name": folder,
							"script": str(cfg.get_value("plugin", "script", "")),
							"description": str(cfg.get_value("plugin", "description", "")),
							"author": str(cfg.get_value("plugin", "author", "")),
							"version": str(cfg.get_value("plugin", "version", ""))
						})
		dir.list_dir_end()

	return _success({"count": plugins.size(), "plugins": plugins})


func _plugin_enabled_state(plugin_name: String, enabled: bool, mutate: bool = false) -> Dictionary:
	if plugin_name.is_empty():
		return _error("Plugin name is required")
	var editor_interface = _get_active_editor_interface()
	if editor_interface == null:
		return _error("Editor interface not available")
	if mutate and enabled:
		var plugin_cfg := "res://addons/%s/plugin.cfg" % plugin_name
		if not FileAccess.file_exists(plugin_cfg):
			return _error("Plugin not found: %s" % plugin_name)
	if mutate:
		editor_interface.set_plugin_enabled(plugin_name, enabled)
		return _success({"plugin": plugin_name, "enabled": enabled}, "Plugin %s" % ("enabled" if enabled else "disabled"))
	return _success({"plugin": plugin_name, "enabled": editor_interface.is_plugin_enabled(plugin_name)})
