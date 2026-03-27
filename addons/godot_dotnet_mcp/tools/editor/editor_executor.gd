@tool
extends RefCounted

const EditorCatalog = preload("res://addons/godot_dotnet_mcp/tools/editor/catalog.gd")
const StatusService = preload("res://addons/godot_dotnet_mcp/tools/editor/status_service.gd")
const SettingsService = preload("res://addons/godot_dotnet_mcp/tools/editor/settings_service.gd")
const UndoRedoService = preload("res://addons/godot_dotnet_mcp/tools/editor/undo_redo_service.gd")
const NotificationService = preload("res://addons/godot_dotnet_mcp/tools/editor/notification_service.gd")
const InspectorService = preload("res://addons/godot_dotnet_mcp/tools/editor/inspector_service.gd")
const FilesystemService = preload("res://addons/godot_dotnet_mcp/tools/editor/filesystem_service.gd")
const PluginService = preload("res://addons/godot_dotnet_mcp/tools/editor/plugin_service.gd")

var _catalog := EditorCatalog.new()
var _status_service := StatusService.new()
var _settings_service := SettingsService.new()
var _undo_redo_service := UndoRedoService.new()
var _notification_service := NotificationService.new()
var _inspector_service := InspectorService.new()
var _filesystem_service := FilesystemService.new()
var _plugin_service := PluginService.new()


func configure_context(context: Dictionary = {}) -> void:
	for service in [
		_status_service,
		_settings_service,
		_undo_redo_service,
		_notification_service,
		_inspector_service,
		_filesystem_service,
		_plugin_service,
	]:
		service.configure_context(context)


func get_tools() -> Array[Dictionary]:
	return _catalog.get_tools()


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"status":
			return _status_service.execute(tool_name, args)
		"settings":
			return _settings_service.execute(tool_name, args)
		"undo_redo":
			return _undo_redo_service.execute(tool_name, args)
		"notification":
			return _notification_service.execute(tool_name, args)
		"inspector":
			return _inspector_service.execute(tool_name, args)
		"filesystem":
			return _filesystem_service.execute(tool_name, args)
		"plugin":
			return _plugin_service.execute(tool_name, args)
		_:
			return _status_service._error("Unknown tool: %s" % tool_name)
