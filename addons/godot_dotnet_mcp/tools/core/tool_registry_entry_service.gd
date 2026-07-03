@tool
extends RefCounted
class_name ToolRegistryEntryService

const ToolCatalogManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_catalog_manifest.gd")


func build_index(collected: Dictionary) -> Dictionary:
	var entries_by_category: Dictionary = {}
	var ordered_categories: Array[String] = []
	var load_errors: Array[Dictionary] = []

	for error_info in collected.get("errors", []):
		if not (error_info is Dictionary):
			continue
		load_errors.append((error_info as Dictionary).duplicate(true))

	for entry in collected.get("entries", []):
		if not (entry is Dictionary):
			continue
		var entry_dict := entry as Dictionary
		var category := str(entry_dict.get("category", ""))
		if category.is_empty():
			continue
		if not ToolCatalogManifest.is_valid_mcp_tool_name(category):
			load_errors.append({
				"category": category,
				"path": str(entry_dict.get("path", "")),
				"message": "Invalid MCP tool category registered",
				"source": str(entry_dict.get("source", "builtin"))
			})
			continue
		if entries_by_category.has(category):
			load_errors.append({
				"category": category,
				"path": str(entry_dict.get("path", "")),
				"message": "Duplicate tool category registered",
				"source": str(entry_dict.get("source", "builtin"))
			})
			continue
		entries_by_category[category] = entry_dict.duplicate(true)
		ordered_categories.append(category)

	return {
		"entries_by_category": entries_by_category,
		"ordered_categories": ordered_categories,
		"load_errors": load_errors
	}
