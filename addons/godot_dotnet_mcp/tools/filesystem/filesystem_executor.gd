@tool
extends RefCounted

const FilesystemCatalog = preload("res://addons/godot_dotnet_mcp/tools/filesystem/catalog.gd")
const DirectoryService = preload("res://addons/godot_dotnet_mcp/tools/filesystem/directory_service.gd")
const FileReadService = preload("res://addons/godot_dotnet_mcp/tools/filesystem/file_read_service.gd")
const FileWriteService = preload("res://addons/godot_dotnet_mcp/tools/filesystem/file_write_service.gd")
const FileManageService = preload("res://addons/godot_dotnet_mcp/tools/filesystem/file_manage_service.gd")
const JsonService = preload("res://addons/godot_dotnet_mcp/tools/filesystem/json_service.gd")
const SearchService = preload("res://addons/godot_dotnet_mcp/tools/filesystem/search_service.gd")

var _catalog := FilesystemCatalog.new()
var _directory_service := DirectoryService.new()
var _file_read_service := FileReadService.new()
var _file_write_service := FileWriteService.new()
var _file_manage_service := FileManageService.new()
var _json_service := JsonService.new()
var _search_service := SearchService.new()


func configure_context(context: Dictionary = {}) -> void:
	for service in [
		_directory_service,
		_file_read_service,
		_file_write_service,
		_file_manage_service,
		_json_service,
		_search_service,
	]:
		service.configure_context(context)


func get_tools() -> Array[Dictionary]:
	return _catalog.get_tools()


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"directory":
			return _directory_service.execute(tool_name, args)
		"file_read":
			return _file_read_service.execute(tool_name, args)
		"file_write":
			return _file_write_service.execute(tool_name, args)
		"file_manage":
			return _file_manage_service.execute(tool_name, args)
		"json":
			return _json_service.execute(tool_name, args)
		"search":
			return _search_service.execute(tool_name, args)
		_:
			return _directory_service._error("Unknown tool: %s" % tool_name)
