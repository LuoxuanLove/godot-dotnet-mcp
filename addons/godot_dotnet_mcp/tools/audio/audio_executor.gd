@tool
extends RefCounted

const AudioCatalog = preload("res://addons/godot_dotnet_mcp/tools/audio/catalog.gd")
const BusService = preload("res://addons/godot_dotnet_mcp/tools/audio/bus_service.gd")
const PlayerService = preload("res://addons/godot_dotnet_mcp/tools/audio/player_service.gd")

var _catalog := AudioCatalog.new()
var _bus_service := BusService.new()
var _player_service := PlayerService.new()


func configure_context(context: Dictionary = {}) -> void:
	for service in [_bus_service, _player_service]:
		service.configure_context(context)


func get_tools() -> Array[Dictionary]:
	return _catalog.get_tools()


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"bus":
			return _bus_service.execute(tool_name, args)
		"player":
			return _player_service.execute(tool_name, args)
		_:
			return _bus_service._error("Unknown tool: %s" % tool_name)
