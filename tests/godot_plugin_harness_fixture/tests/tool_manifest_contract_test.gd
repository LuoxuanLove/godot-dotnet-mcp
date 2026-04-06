extends RefCounted

const MCPToolManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_manifest.gd")
const ToolCatalogService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_catalog_service.gd")
const ToolPermissionPolicy = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_permission_policy.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var domain_defs: Array = MCPToolManifest.TOOL_DOMAIN_DEFS
	if domain_defs.size() != 3:
		return _failure("Tool manifest should define core, plugin, and user domains.")

	var consistency_issues: Array[String] = ToolPermissionPolicy.get_domain_category_consistency_issues(domain_defs)
	if not consistency_issues.is_empty():
		return _failure("Tool manifest has consistency issues: %s" % "; ".join(consistency_issues))

	var catalog := ToolCatalogService.new()
	if catalog.find_domain_key_for_category(domain_defs, "system") != "core":
		return _failure("System tools should resolve to the core domain.")
	if catalog.find_domain_key_for_category(domain_defs, "plugin_runtime") != "plugin":
		return _failure("Plugin runtime tools should resolve to the plugin domain.")
	if catalog.find_domain_key_for_category(domain_defs, "user") != "user":
		return _failure("User tools should resolve to the user domain.")

	if ToolPermissionPolicy.get_domain_permission_level("core", domain_defs) != ToolPermissionPolicy.PERMISSION_STABLE:
		return _failure("Core domain should remain stable permission level.")
	if ToolPermissionPolicy.get_domain_permission_level("plugin", domain_defs) != ToolPermissionPolicy.PERMISSION_DEVELOPER:
		return _failure("Plugin domain should require developer permission.")
	if not ToolPermissionPolicy.permission_allows_domain(ToolPermissionPolicy.PERMISSION_DEVELOPER, "plugin", domain_defs):
		return _failure("Developer permission should allow the plugin domain.")

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
