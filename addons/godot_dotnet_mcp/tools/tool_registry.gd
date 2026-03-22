@tool
extends RefCounted
class_name MCPToolRegistry

const MCPToolManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_manifest.gd")
const CUSTOM_TOOLS_DIR := "res://addons/godot_dotnet_mcp/custom_tools"


func collect_entries() -> Dictionary:
	return {
		"entries": get_builtin_entries(),
		"errors": []
	}


func get_builtin_entries() -> Array[Dictionary]:
	return MCPToolManifest.get_builtin_entries()


func get_builtin_categories() -> Array[String]:
	return MCPToolManifest.get_builtin_categories()
