@tool
extends RefCounted
class_name MCPToolManifest

const MCPToolManifestData = preload("res://addons/godot_dotnet_mcp/tools/tool_manifest_data.gd")

const BUILTIN_TOOL_ENTRIES = MCPToolManifestData.BUILTIN_TOOL_ENTRIES
const ALL_TOOL_CATEGORIES = MCPToolManifestData.ALL_TOOL_CATEGORIES
const EXPOSED_CATEGORIES = MCPToolManifestData.EXPOSED_CATEGORIES
const DEFAULT_COLLAPSED_DOMAINS = MCPToolManifestData.DEFAULT_COLLAPSED_DOMAINS
const TOOL_DOMAIN_DEFS = MCPToolManifestData.TOOL_DOMAIN_DEFS


static func get_builtin_entries() -> Array[Dictionary]:
	return BUILTIN_TOOL_ENTRIES.duplicate(true)


static func collect_entries() -> Dictionary:
	return {
		"entries": get_builtin_entries(),
		"errors": []
	}


static func get_builtin_categories() -> Array[String]:
	var categories: Array[String] = []
	for entry in BUILTIN_TOOL_ENTRIES:
		categories.append(str(entry.get("category", "")))
	return categories


static func get_all_tool_categories() -> Array[String]:
	return ALL_TOOL_CATEGORIES.duplicate()


static func get_exposed_categories() -> Array[String]:
	return EXPOSED_CATEGORIES.duplicate()


static func get_default_collapsed_domains() -> Array[String]:
	return DEFAULT_COLLAPSED_DOMAINS.duplicate()


static func get_tool_domain_defs() -> Array[Dictionary]:
	return TOOL_DOMAIN_DEFS.duplicate(true)


static func find_domain_key_for_category(category: String) -> String:
	for domain_def in TOOL_DOMAIN_DEFS:
		if category in domain_def.get("categories", []):
			return str(domain_def.get("key", ""))
	return ""
