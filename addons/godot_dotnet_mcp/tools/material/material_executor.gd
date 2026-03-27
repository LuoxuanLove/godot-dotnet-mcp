@tool
extends RefCounted

const MaterialCatalog = preload("res://addons/godot_dotnet_mcp/tools/material/catalog.gd")
const MaterialService = preload("res://addons/godot_dotnet_mcp/tools/material/material_service.gd")
const ParameterService = preload("res://addons/godot_dotnet_mcp/tools/material/parameter_service.gd")
const MeshService = preload("res://addons/godot_dotnet_mcp/tools/material/mesh_service.gd")

var _catalog := MaterialCatalog.new()
var _material_service := MaterialService.new()
var _parameter_service := ParameterService.new()
var _mesh_service := MeshService.new()


func configure_context(context: Dictionary = {}) -> void:
	for service in [_material_service, _parameter_service, _mesh_service]:
		service.configure_context(context)


func get_tools() -> Array[Dictionary]:
	return _catalog.get_tools()


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"material":
			var action := str(args.get("action", ""))
			if action in ["set_property", "get_property", "list_properties"]:
				return _parameter_service.execute(tool_name, args)
			return _material_service.execute(tool_name, args)
		"mesh":
			return _mesh_service.execute(tool_name, args)
		_:
			return _material_service._error("Unknown tool: %s" % tool_name)
