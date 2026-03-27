@tool
extends RefCounted

const DebugCatalog = preload("res://addons/godot_dotnet_mcp/tools/debug/catalog.gd")
const LogWriteService = preload("res://addons/godot_dotnet_mcp/tools/debug/log_write_service.gd")
const LogBufferService = preload("res://addons/godot_dotnet_mcp/tools/debug/log_buffer_service.gd")
const RuntimeBridgeService = preload("res://addons/godot_dotnet_mcp/tools/debug/runtime_bridge_service.gd")
const DotnetService = preload("res://addons/godot_dotnet_mcp/tools/debug/dotnet_service.gd")
const PerformanceService = preload("res://addons/godot_dotnet_mcp/tools/debug/performance_service.gd")
const ProfilerService = preload("res://addons/godot_dotnet_mcp/tools/debug/profiler_service.gd")
const EditorLogService = preload("res://addons/godot_dotnet_mcp/tools/debug/editor_log_service.gd")
const ClassDbService = preload("res://addons/godot_dotnet_mcp/tools/debug/class_db_service.gd")

var _catalog := DebugCatalog.new()
var _log_write_service := LogWriteService.new()
var _log_buffer_service := LogBufferService.new()
var _runtime_bridge_service := RuntimeBridgeService.new()
var _dotnet_service := DotnetService.new()
var _performance_service := PerformanceService.new()
var _profiler_service := ProfilerService.new()
var _editor_log_service := EditorLogService.new()
var _class_db_service := ClassDbService.new()


func get_tools() -> Array[Dictionary]:
	return _catalog.get_tools()


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"log_write":
			return _log_write_service.execute(tool_name, args)
		"log_buffer":
			return _log_buffer_service.execute(tool_name, args)
		"runtime_bridge":
			return _runtime_bridge_service.execute(tool_name, args)
		"dotnet":
			return _dotnet_service.execute(tool_name, args)
		"performance":
			return _performance_service.execute(tool_name, args)
		"profiler":
			return _profiler_service.execute(tool_name, args)
		"editor_log":
			return _editor_log_service.execute(tool_name, args)
		"class_db":
			return _class_db_service.execute(tool_name, args)
		_:
			return _log_write_service._error("Unknown tool: %s" % tool_name)
