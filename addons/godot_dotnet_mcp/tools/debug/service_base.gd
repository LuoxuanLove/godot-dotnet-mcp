@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const MCPRuntimeDebugStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_runtime_debug_store.gd")

const DOTNET_DEFAULT_TIMEOUT_SEC := 30
