@tool
extends RefCounted

const NavigationCatalog = preload("res://addons/godot_dotnet_mcp/tools/navigation/catalog.gd")
const MapService = preload("res://addons/godot_dotnet_mcp/tools/navigation/map_service.gd")
const RegionService = preload("res://addons/godot_dotnet_mcp/tools/navigation/region_service.gd")
const AgentService = preload("res://addons/godot_dotnet_mcp/tools/navigation/agent_service.gd")

var _catalog := NavigationCatalog.new()
var _map_service := MapService.new()
var _region_service := RegionService.new()
var _agent_service := AgentService.new()


func configure_context(context: Dictionary = {}) -> void:
	for service in [_map_service, _region_service, _agent_service]:
		service.configure_context(context)


func get_tools() -> Array[Dictionary]:
	return _catalog.get_tools()


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name != "navigation":
		return _map_service._error("Unknown tool: %s" % tool_name)

	var action := str(args.get("action", ""))
	match action:
		"get_map_info", "get_path":
			return _map_service.execute(tool_name, args)
		"list_regions", "bake_mesh", "set_region_enabled":
			return _region_service.execute(tool_name, args)
		"list_agents", "set_agent_target", "get_agent_info", "set_agent_enabled":
			return _agent_service.execute(tool_name, args)
		_:
			return _map_service._error("Unknown action: %s" % action)
