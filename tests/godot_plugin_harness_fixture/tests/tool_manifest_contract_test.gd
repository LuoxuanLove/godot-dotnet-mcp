extends RefCounted

const MCPToolManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_manifest.gd")
const MCPToolRegistry = preload("res://addons/godot_dotnet_mcp/tools/tool_registry.gd")
const ToolCatalogService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_catalog_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var domain_defs: Array = MCPToolManifest.TOOL_DOMAIN_DEFS
	if domain_defs.size() != 3:
		return _failure("Tool manifest should define core, plugin, and user domains.")

	var catalog := ToolCatalogService.new()
	if catalog.find_domain_key_for_category(domain_defs, "plugin") != "":
		return _failure("Legacy plugin aggregate category should not remain in the manifest.")
	if catalog.find_domain_key_for_category(domain_defs, "system") != "core":
		return _failure("System tools should resolve to the core domain.")
	if catalog.find_domain_key_for_category(domain_defs, "plugin_runtime") != "plugin":
		return _failure("Plugin runtime tools should resolve to the plugin domain.")
	if catalog.find_domain_key_for_category(domain_defs, "user") != "user":
		return _failure("User tools should resolve to the user domain.")

	var registry := MCPToolRegistry.new()
	var builtin_categories := registry.get_builtin_categories()
	if builtin_categories.has("plugin"):
		return _failure("Tool registry should not register the legacy plugin aggregate category.")
	for split_plugin_category in ["plugin_runtime", "plugin_evolution", "plugin_developer"]:
		if not builtin_categories.has(split_plugin_category):
			return _failure("Tool registry should keep split plugin category: %s" % split_plugin_category)

	return {
		"name": "tool_manifest_contracts",
		"success": true,
		"error": "",
		"details": {
			"domain_count": domain_defs.size(),
			"category_count": MCPToolManifest.ALL_TOOL_CATEGORIES.size()
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_manifest_contracts",
		"success": false,
		"error": message
	}
