@tool
extends RefCounted
class_name MCPToolManifest

const ToolCatalogManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_catalog_manifest.gd")

const TOOL_DOMAIN_DEFS: Array[Dictionary] = ToolCatalogManifest.TOOL_DOMAIN_DEFS
const PUBLIC_MCP_TOOL_CATEGORIES: Array[String] = ToolCatalogManifest.PUBLIC_MCP_TOOL_CATEGORIES
static var ALL_TOOL_CATEGORIES: Array[String] = ToolCatalogManifest.get_all_tool_categories()


static func get_domain_defs() -> Array[Dictionary]:
	return ToolCatalogManifest.get_domain_defs()


static func get_all_tool_categories() -> Array[String]:
	return ToolCatalogManifest.get_all_tool_categories()


static func get_public_mcp_tool_categories() -> Array[String]:
	return ToolCatalogManifest.get_public_mcp_tool_categories()
