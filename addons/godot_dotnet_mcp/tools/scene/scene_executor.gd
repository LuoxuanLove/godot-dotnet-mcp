@tool
extends RefCounted

const SceneCatalog = preload("res://addons/godot_dotnet_mcp/tools/scene/catalog.gd")
const ManagementService = preload("res://addons/godot_dotnet_mcp/tools/scene/management_service.gd")
const HierarchyService = preload("res://addons/godot_dotnet_mcp/tools/scene/hierarchy_service.gd")
const RunService = preload("res://addons/godot_dotnet_mcp/tools/scene/run_service.gd")
const BindingsService = preload("res://addons/godot_dotnet_mcp/tools/scene/bindings_service.gd")
const AuditService = preload("res://addons/godot_dotnet_mcp/tools/scene/audit_service.gd")

var _catalog := SceneCatalog.new()
var _management_service := ManagementService.new()
var _hierarchy_service := HierarchyService.new()
var _run_service := RunService.new()
var _bindings_service := BindingsService.new()
var _audit_service := AuditService.new()


func configure_context(context: Dictionary = {}) -> void:
	for service in [
		_management_service,
		_hierarchy_service,
		_run_service,
		_bindings_service,
		_audit_service,
	]:
		service.configure_context(context)


func get_tools() -> Array[Dictionary]:
	return _catalog.get_tools()


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"management":
			return _management_service.execute(tool_name, args)
		"hierarchy":
			return _hierarchy_service.execute(tool_name, args)
		"run":
			return _run_service.execute(tool_name, args)
		"bindings":
			return _bindings_service.execute(tool_name, args)
		"audit":
			return _audit_service.execute(tool_name, args)
		_:
			return _management_service._error("Unknown tool: %s" % tool_name)
