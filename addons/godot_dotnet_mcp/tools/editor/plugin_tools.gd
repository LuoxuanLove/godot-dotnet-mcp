@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

## Editor plugin tools for Godot MCP


func execute(ei, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")

	if not ei:
		return _error("Editor interface not available")

	match action:
		"list":
			return _list_plugins()
		"is_enabled":
			return _is_plugin_enabled(ei, args.get("plugin", ""))
		"enable":
			return _enable_plugin(ei, args.get("plugin", ""))
		"disable":
			return _disable_plugin(ei, args.get("plugin", ""))
		_:
			return _error("Unknown action: %s" % action)


func _list_plugins() -> Dictionary:
	var plugins: Array[Dictionary] = []
	var dir = DirAccess.open("res://addons")

	if dir:
		dir.list_dir_begin()
		var folder = dir.get_next()

		while not folder.is_empty():
			if dir.current_is_dir() and not folder.begins_with("."):
				var plugin_cfg = "res://addons/%s/plugin.cfg" % folder
				if FileAccess.file_exists(plugin_cfg):
					var cfg = ConfigFile.new()
					if cfg.load(plugin_cfg) == OK:
						plugins.append({
							"name": folder,
							"script": str(cfg.get_value("plugin", "script", "")),
							"description": str(cfg.get_value("plugin", "description", "")),
							"author": str(cfg.get_value("plugin", "author", "")),
							"version": str(cfg.get_value("plugin", "version", ""))
						})
			folder = dir.get_next()
		dir.list_dir_end()

	return _success({
		"count": plugins.size(),
		"plugins": plugins
	})


func _is_plugin_enabled(ei, plugin_name: String) -> Dictionary:
	if plugin_name.is_empty():
		return _error("Plugin name is required")

	var enabled = ei.is_plugin_enabled(plugin_name)

	return _success({
		"plugin": plugin_name,
		"enabled": enabled
	})


func _enable_plugin(ei, plugin_name: String) -> Dictionary:
	if plugin_name.is_empty():
		return _error("Plugin name is required")

	var plugin_cfg = "res://addons/%s/plugin.cfg" % plugin_name
	if not FileAccess.file_exists(plugin_cfg):
		return _error("Plugin not found: %s" % plugin_name)

	ei.set_plugin_enabled(plugin_name, true)

	return _success({
		"plugin": plugin_name,
		"enabled": true
	}, "Plugin enabled")


func _disable_plugin(ei, plugin_name: String) -> Dictionary:
	if plugin_name.is_empty():
		return _error("Plugin name is required")

	ei.set_plugin_enabled(plugin_name, false)

	return _success({
		"plugin": plugin_name,
		"enabled": false
	}, "Plugin disabled")
