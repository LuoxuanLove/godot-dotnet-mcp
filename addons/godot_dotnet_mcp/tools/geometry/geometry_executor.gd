@tool
extends RefCounted

const GeometryCatalog = preload("res://addons/godot_dotnet_mcp/tools/geometry/catalog.gd")
const CsgService = preload("res://addons/godot_dotnet_mcp/tools/geometry/csg_service.gd")
const GridmapService = preload("res://addons/godot_dotnet_mcp/tools/geometry/gridmap_service.gd")
const MultimeshService = preload("res://addons/godot_dotnet_mcp/tools/geometry/multimesh_service.gd")

var _catalog := GeometryCatalog.new()
var _csg_service := CsgService.new()
var _gridmap_service := GridmapService.new()
var _multimesh_service := MultimeshService.new()


func configure_context(context: Dictionary = {}) -> void:
	for service in [_csg_service, _gridmap_service, _multimesh_service]:
		service.configure_context(context)


func get_tools() -> Array[Dictionary]:
	return _catalog.get_tools()


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"csg":
			return _csg_service.execute(tool_name, args)
		"gridmap":
			return _gridmap_service.execute(tool_name, args)
		"multimesh":
			return _multimesh_service.execute(tool_name, args)
		_:
			return _csg_service._error("Unknown tool: %s" % tool_name)
