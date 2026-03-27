@tool
extends RefCounted

const SignalCatalog = preload("res://addons/godot_dotnet_mcp/tools/signal/catalog.gd")
const QueryService = preload("res://addons/godot_dotnet_mcp/tools/signal/query_service.gd")
const ConnectService = preload("res://addons/godot_dotnet_mcp/tools/signal/connect_service.gd")
const EmitService = preload("res://addons/godot_dotnet_mcp/tools/signal/emit_service.gd")

var _catalog := SignalCatalog.new()
var _query_service := QueryService.new()
var _connect_service := ConnectService.new()
var _emit_service := EmitService.new()


func configure_context(context: Dictionary = {}) -> void:
	for service in [_query_service, _connect_service, _emit_service]:
		service.configure_context(context)


func get_tools() -> Array[Dictionary]:
	return _catalog.get_tools()


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name != "signal":
		return _query_service._error("Unknown tool: %s" % tool_name)

	var action := str(args.get("action", ""))
	match action:
		"list", "get_info", "list_connections", "is_connected", "list_all_connections":
			return _query_service.execute(tool_name, args)
		"connect", "disconnect", "disconnect_all":
			return _connect_service.execute(tool_name, args)
		"emit":
			return _emit_service.execute(tool_name, args)
		_:
			return _query_service._error("Unknown action: %s" % action)
