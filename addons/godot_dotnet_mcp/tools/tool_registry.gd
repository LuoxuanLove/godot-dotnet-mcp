@tool
extends RefCounted
class_name MCPToolRegistry

const ToolCatalogManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_catalog_manifest.gd")
const CUSTOM_TOOLS_DIR := ToolCatalogManifest.CUSTOM_TOOLS_DIR
const BUILTIN_ENTRIES: Array[Dictionary] = ToolCatalogManifest.BUILTIN_ENTRIES


func collect_entries() -> Dictionary:
	return {
		"entries": get_builtin_entries(),
		"errors": []
	}


func get_builtin_entries() -> Array[Dictionary]:
	return ToolCatalogManifest.get_builtin_entries()


func get_builtin_categories() -> Array[String]:
	return ToolCatalogManifest.get_builtin_categories()
