@tool
extends RefCounted

const LightingCatalog = preload("res://addons/godot_dotnet_mcp/tools/lighting/catalog.gd")
const LightService = preload("res://addons/godot_dotnet_mcp/tools/lighting/light_service.gd")
const EnvironmentService = preload("res://addons/godot_dotnet_mcp/tools/lighting/environment_service.gd")
const SkyService = preload("res://addons/godot_dotnet_mcp/tools/lighting/sky_service.gd")

var _catalog := LightingCatalog.new()
var _light_service := LightService.new()
var _environment_service := EnvironmentService.new()
var _sky_service := SkyService.new()


func configure_context(context: Dictionary = {}) -> void:
	for service in [_light_service, _environment_service, _sky_service]:
		service.configure_context(context)


func get_tools() -> Array[Dictionary]:
	return _catalog.get_tools()


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"light":
			return _light_service.execute(tool_name, args)
		"environment":
			return _environment_service.execute(tool_name, args)
		"sky":
			return _sky_service.execute(tool_name, args)
		_:
			return _light_service._error("Unknown tool: %s" % tool_name)
