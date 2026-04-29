@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

const PluginRoslynServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_roslyn_service.gd")

var _plugin_roslyn_service = null

func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	var path = _normalize_res_path(str(args.get("path", "")))
	if path.is_empty():
		return _error("Path is required")
	if not path.ends_with(".cs"):
		return _error("script_edit_cs only supports .cs files")

	match action:
		"create":
			return _mutation_disabled_error(action)
		"write":
			return _mutation_disabled_error(action)
		"add_field", "upsert_field", "add_method", "upsert_method", "replace_method_body", "delete_member", "rename_member":
			return _execute_roslyn_patch(path, args)
		_:
			return _error("Unknown action: %s. edit_cs is read-only in plugin; use host cs_file_patch for C# mutations." % action)


func _mutation_disabled_error(action: String) -> Dictionary:
	return _error("edit_cs action '%s' is disabled in plugin. Use host cs_file_patch for C# mutations." % action)


func _execute_roslyn_patch(path: String, request: Dictionary) -> Dictionary:
	var service = _get_plugin_roslyn_service()
	if service == null:
		return _error("Plugin Roslyn service is unavailable")
	var result = service.patch_file(path, request)
	return result


func _get_plugin_roslyn_service():
	if _plugin_roslyn_service == null:
		_plugin_roslyn_service = PluginRoslynServiceScript.new()
	return _plugin_roslyn_service


func clear() -> void:
	if _plugin_roslyn_service != null:
		var service = _plugin_roslyn_service
		_plugin_roslyn_service = null
		if service.has_method("clear"):
			service.clear()
		if service is Node and is_instance_valid(service):
			service.free()
