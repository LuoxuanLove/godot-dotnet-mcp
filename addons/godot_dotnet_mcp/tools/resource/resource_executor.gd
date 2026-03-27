@tool
extends RefCounted

const ResourceCatalog = preload("res://addons/godot_dotnet_mcp/tools/resource/catalog.gd")
const QueryService = preload("res://addons/godot_dotnet_mcp/tools/resource/query_service.gd")
const CreateService = preload("res://addons/godot_dotnet_mcp/tools/resource/create_service.gd")
const FileOpsService = preload("res://addons/godot_dotnet_mcp/tools/resource/file_ops_service.gd")
const TextureService = preload("res://addons/godot_dotnet_mcp/tools/resource/texture_service.gd")

var _catalog := ResourceCatalog.new()
var _query_service := QueryService.new()
var _create_service := CreateService.new()
var _file_ops_service := FileOpsService.new()
var _texture_service := TextureService.new()


func configure_context(context: Dictionary = {}) -> void:
	for service in [_query_service, _create_service, _file_ops_service, _texture_service]:
		service.configure_context(context)


func get_tools() -> Array[Dictionary]:
	return _catalog.get_tools()


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"query":
			return _query_service.execute(tool_name, args)
		"create":
			return _create_service.execute(tool_name, args)
		"file_ops":
			return _file_ops_service.execute(tool_name, args)
		"texture":
			return _texture_service.execute(tool_name, args)
		_:
			return _query_service._error("Unknown tool: %s" % tool_name)
