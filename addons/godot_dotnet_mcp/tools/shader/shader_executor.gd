@tool
extends RefCounted

const ShaderCatalog = preload("res://addons/godot_dotnet_mcp/tools/shader/catalog.gd")
const ShaderService = preload("res://addons/godot_dotnet_mcp/tools/shader/shader_service.gd")
const MaterialService = preload("res://addons/godot_dotnet_mcp/tools/shader/material_service.gd")

var _catalog := ShaderCatalog.new()
var _shader_service := ShaderService.new()
var _material_service := MaterialService.new()


func configure_context(context: Dictionary = {}) -> void:
	_shader_service.configure_context(context)
	_material_service.configure_context(context)


func get_tools() -> Array[Dictionary]:
	return _catalog.get_tools()


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"shader":
			return _shader_service.execute(tool_name, args)
		"shader_material":
			return _material_service.execute(tool_name, args)
		_:
			return _shader_service._error("Unknown tool: %s" % tool_name)
