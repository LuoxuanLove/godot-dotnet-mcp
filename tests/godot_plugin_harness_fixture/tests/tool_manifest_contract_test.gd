extends RefCounted

const MCPToolManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_manifest.gd")
const MCPToolRegistry = preload("res://addons/godot_dotnet_mcp/tools/tool_registry.gd")
const ToolCatalogManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_catalog_manifest.gd")
const ToolCatalogService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_catalog_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var domain_defs: Array = MCPToolManifest.TOOL_DOMAIN_DEFS
	if JSON.stringify(domain_defs) != JSON.stringify(ToolCatalogManifest.get_domain_defs()):
		return _failure("MCPToolManifest should expose ToolCatalogManifest domain definitions without maintaining a second source.")
	if JSON.stringify(MCPToolManifest.ALL_TOOL_CATEGORIES) != JSON.stringify(ToolCatalogManifest.get_all_tool_categories()):
		return _failure("MCPToolManifest should expose ToolCatalogManifest categories without maintaining a second source.")
	if JSON.stringify(MCPToolManifest.PUBLIC_MCP_TOOL_CATEGORIES) != JSON.stringify(ToolCatalogManifest.get_public_mcp_tool_categories()):
		return _failure("MCPToolManifest should expose ToolCatalogManifest public categories without maintaining a second source.")
	var manifest_categories := ToolCatalogManifest.get_all_tool_categories()
	var manifest_builtin_categories := ToolCatalogManifest.get_builtin_categories()
	if JSON.stringify(manifest_categories) != JSON.stringify(_collect_domain_categories(domain_defs).get("categories", [])):
		return _failure("ToolCatalogManifest categories should be derived from domain definitions.")
	if manifest_categories.is_empty() or manifest_categories[0] != "system" or manifest_categories[manifest_categories.size() - 1] != "user":
		return _failure("ToolCatalogManifest category order should preserve the legacy system-first and user-last ordering.")
	var domain_coverage := _collect_domain_categories(domain_defs)
	if not domain_coverage.get("duplicates", []).is_empty():
		return _failure("ToolCatalogManifest domain definitions should not duplicate categories: %s" % ", ".join(domain_coverage.get("duplicates", [])))
	if not _arrays_equal_sorted(domain_coverage.get("categories", []), manifest_builtin_categories):
		return _failure("ToolCatalogManifest domain definitions should exactly cover builtin categories.")
	if domain_defs.size() != 6:
		return _failure("Tool manifest should define core, visual, gameplay, interface, plugin, and user domains.")
	var public_categories: Array = MCPToolManifest.PUBLIC_MCP_TOOL_CATEGORIES
	if public_categories != ["system", "user"]:
		return _failure("Public MCP exposure should stay limited to high-level system tools and user extensions.")
	if not ToolCatalogManifest.is_public_category("system") or ToolCatalogManifest.is_public_category("plugin_runtime"):
		return _failure("ToolCatalogManifest should be the public exposure allow-list source.")
	var removed_public_tools := ToolCatalogManifest.get_removed_public_tool_names()
	for removed_tool in ["system_help", "system_tool_catalog", "system_tool_activity", "system_plugin_reload", "system_plugin_update", "system_scene_validate", "system_scene_analyze", "system_editor_log", "resource_manage"]:
		if not removed_public_tools.has(removed_tool):
			return _failure("ToolCatalogManifest should keep removed public tool guard: %s" % removed_tool)
		if not ToolCatalogManifest.is_removed_public_tool(removed_tool):
			return _failure("ToolCatalogManifest should identify removed public tool: %s" % removed_tool)

	var catalog := ToolCatalogService.new()
	if catalog.find_domain_key_for_category(domain_defs, "plugin") != "":
		return _failure("Legacy plugin aggregate category should not remain in the manifest.")
	if catalog.find_domain_key_for_category(domain_defs, "system") != "core":
		return _failure("System tools should resolve to the core domain.")
	if catalog.find_domain_key_for_category(domain_defs, "plugin_runtime") != "plugin":
		return _failure("Plugin runtime tools should resolve to the plugin domain.")
	if catalog.find_domain_key_for_category(domain_defs, "animation") != "visual":
		return _failure("Animation tools should resolve to the visual domain.")
	if catalog.find_domain_key_for_category(domain_defs, "audio") != "gameplay":
		return _failure("Audio tools should resolve to the gameplay domain.")
	if catalog.find_domain_key_for_category(domain_defs, "ui") != "interface":
		return _failure("UI tools should resolve to the interface domain.")
	if catalog.find_domain_key_for_category(domain_defs, "user") != "user":
		return _failure("User tools should resolve to the user domain.")

	var registry := MCPToolRegistry.new()
	var builtin_categories := registry.get_builtin_categories()
	if JSON.stringify(registry.get_builtin_entries()) != JSON.stringify(ToolCatalogManifest.get_builtin_entries()):
		return _failure("MCPToolRegistry should expose ToolCatalogManifest builtin entries without maintaining a second source.")
	if JSON.stringify(builtin_categories) != JSON.stringify(ToolCatalogManifest.get_builtin_categories()):
		return _failure("MCPToolRegistry should expose ToolCatalogManifest builtin category order without maintaining a second source.")
	if MCPToolRegistry.CUSTOM_TOOLS_DIR != ToolCatalogManifest.CUSTOM_TOOLS_DIR:
		return _failure("MCPToolRegistry custom tools directory should come from ToolCatalogManifest.")
	if builtin_categories.has("plugin"):
		return _failure("Tool registry should not register the legacy plugin aggregate category.")
	for split_plugin_category in ["plugin_runtime", "plugin_evolution", "plugin_developer"]:
		if not builtin_categories.has(split_plugin_category):
			return _failure("Tool registry should keep split plugin category: %s" % split_plugin_category)
		if public_categories.has(split_plugin_category):
			return _failure("Split plugin implementation category should not be publicly exposed: %s" % split_plugin_category)
	for public_category in public_categories:
		if not builtin_categories.has(str(public_category)):
			return _failure("Public MCP category should exist in the registry: %s" % public_category)
	var seen_categories := {}
	for entry in registry.get_builtin_entries():
		var category := str(entry.get("category", ""))
		if category.is_empty():
			return _failure("ToolCatalogManifest registry entries should include a category.")
		if seen_categories.has(category):
			return _failure("ToolCatalogManifest registry entries should not duplicate category: %s" % category)
		seen_categories[category] = true
		var script_path := str(entry.get("path", ""))
		if not script_path.begins_with("res://addons/godot_dotnet_mcp/tools/"):
			return _failure("ToolCatalogManifest registry entry should stay inside the tool tree: %s" % category)
		if not bool(entry.get("hot_reloadable", false)):
			return _failure("ToolCatalogManifest registry entry should keep hot reload enabled: %s" % category)
		if category == "user" and not bool(entry.get("allow_empty_definitions", false)):
			return _failure("ToolCatalogManifest user entry should allow an empty custom tool directory.")
		var registry_domain_key := str(entry.get("domain_key", ""))
		var manifest_domain_key := catalog.find_domain_key_for_category(domain_defs, category)
		if manifest_domain_key != ToolCatalogManifest.get_domain_key_for_category(category):
			return _failure("ToolCatalogManifest should resolve the same domain as ToolCatalogService for category '%s'." % category)
		if manifest_domain_key.is_empty():
			return _failure("Manifest should map registry category '%s' to a domain." % category)
		if manifest_domain_key != registry_domain_key:
			return _failure("Manifest domain '%s' should match registry domain '%s' for category '%s'." % [manifest_domain_key, registry_domain_key, category])

	return {
		"name": "tool_manifest_contracts",
		"success": true,
		"error": "",
		"details": {
			"domain_count": domain_defs.size(),
			"category_count": MCPToolManifest.ALL_TOOL_CATEGORIES.size(),
			"registry_entry_count": registry.get_builtin_entries().size()
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_manifest_contracts",
		"success": false,
		"error": message
	}


func _collect_domain_categories(domain_defs: Array) -> Dictionary:
	var seen := {}
	var categories: Array[String] = []
	var duplicates: Array[String] = []
	for domain_def in domain_defs:
		if not (domain_def is Dictionary):
			continue
		for category in (domain_def as Dictionary).get("categories", []):
			var category_name := str(category)
			if seen.has(category_name):
				duplicates.append(category_name)
				continue
			seen[category_name] = true
			categories.append(category_name)
	return {
		"categories": categories,
		"duplicates": duplicates
	}


func _arrays_equal_sorted(left: Array, right: Array) -> bool:
	var left_copy := _string_array(left)
	var right_copy := _string_array(right)
	left_copy.sort()
	right_copy.sort()
	return JSON.stringify(left_copy) == JSON.stringify(right_copy)


func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
