@tool
extends RefCounted

const GroupCatalog = preload("res://addons/godot_dotnet_mcp/tools/group/catalog.gd")
const QueryService = preload("res://addons/godot_dotnet_mcp/tools/group/query_service.gd")
const MembershipService = preload("res://addons/godot_dotnet_mcp/tools/group/membership_service.gd")
const OperationService = preload("res://addons/godot_dotnet_mcp/tools/group/operation_service.gd")

var _catalog := GroupCatalog.new()
var _query_service := QueryService.new()
var _membership_service := MembershipService.new()
var _operation_service := OperationService.new()


func configure_context(context: Dictionary = {}) -> void:
	for service in [_query_service, _membership_service, _operation_service]:
		service.configure_context(context)


func get_tools() -> Array[Dictionary]:
	return _catalog.get_tools()


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name != "group":
		return _query_service._error("Unknown tool: %s" % tool_name)

	var action := str(args.get("action", ""))
	match action:
		"list", "is_in", "get_nodes":
			return _query_service.execute(tool_name, args)
		"add", "remove":
			return _membership_service.execute(tool_name, args)
		"call_group", "set_group":
			return _operation_service.execute(tool_name, args)
		_:
			return _query_service._error("Unknown action: %s" % action)
