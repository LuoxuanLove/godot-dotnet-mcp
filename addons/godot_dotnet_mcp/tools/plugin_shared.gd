@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

const PluginRuntimeState = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_state.gd")

var _runtime_context: Dictionary = {}


func configure_runtime(context: Dictionary) -> void:
	_runtime_context = context.duplicate()


func _get_plugin():
	var server = _runtime_context.get("server", null)
	if server == null:
		return null
	return server.get_parent()


func _get_loader():
	return _runtime_context.get("tool_loader", null)


func _call_plugin_method(method_name: String, args: Array = [], unavailable_message: String = "Plugin bridge is unavailable") -> Dictionary:
	var plugin = _get_plugin()
	if plugin == null or not plugin.has_method(method_name):
		return _error(unavailable_message)
	return plugin.callv(method_name, args)
