@tool
extends RefCounted

const ProjectCatalog = preload("res://addons/godot_dotnet_mcp/tools/project/catalog.gd")
const InfoService = preload("res://addons/godot_dotnet_mcp/tools/project/info_service.gd")
const DotnetService = preload("res://addons/godot_dotnet_mcp/tools/project/dotnet_service.gd")
const SettingsService = preload("res://addons/godot_dotnet_mcp/tools/project/settings_service.gd")
const InputService = preload("res://addons/godot_dotnet_mcp/tools/project/input_service.gd")
const AutoloadService = preload("res://addons/godot_dotnet_mcp/tools/project/autoload_service.gd")

var _catalog := ProjectCatalog.new()
var _info_service := InfoService.new()
var _dotnet_service := DotnetService.new()
var _settings_service := SettingsService.new()
var _input_service := InputService.new()
var _autoload_service := AutoloadService.new()


func get_tools() -> Array[Dictionary]:
	return _catalog.get_tools()


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"info":
			return _info_service.execute(tool_name, args)
		"dotnet":
			return _dotnet_service.execute(tool_name, args)
		"settings":
			return _settings_service.execute(tool_name, args)
		"input":
			return _input_service.execute(tool_name, args)
		"autoload":
			return _autoload_service.execute(tool_name, args)
		_:
			return _info_service._error("Unknown tool: %s" % tool_name)
