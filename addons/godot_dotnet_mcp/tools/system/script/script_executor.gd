@tool
extends RefCounted

const ScriptCatalog = preload("res://addons/godot_dotnet_mcp/tools/system/script/catalog.gd")
const BindingsAuditService = preload("res://addons/godot_dotnet_mcp/tools/system/script/bindings_audit_service.gd")
const AnalyzeService = preload("res://addons/godot_dotnet_mcp/tools/system/script/analyze_service.gd")
const PatchService = preload("res://addons/godot_dotnet_mcp/tools/system/script/patch_service.gd")
const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")

var bridge
var _catalog := ScriptCatalog.new()
var _bindings_audit_service := BindingsAuditService.new()
var _analyze_service := AnalyzeService.new()
var _patch_service := PatchService.new()


func configure_runtime(context: Dictionary) -> void:
	for service in [_bindings_audit_service, _analyze_service, _patch_service]:
		service.bridge = bridge
		service.configure_runtime(context)


func handles(tool_name: String) -> bool:
	return tool_name in ["bindings_audit", "script_analyze", "script_patch"]


func get_tools() -> Array[Dictionary]:
	return _catalog.get_tools()


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	MCPDebugBuffer.record("debug", "system", "tool: %s" % tool_name)
	match tool_name:
		"bindings_audit":
			return _bindings_audit_service.execute(tool_name, args)
		"script_analyze":
			return _analyze_service.execute(tool_name, args)
		"script_patch":
			return _patch_service.execute(tool_name, args)
		_:
			return bridge.error("Unknown tool: %s" % tool_name)
