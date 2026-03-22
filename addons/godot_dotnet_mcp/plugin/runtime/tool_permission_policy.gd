@tool
extends RefCounted
class_name ToolPermissionPolicy

const MCPToolManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_manifest.gd")

const PERMISSION_STABLE := "stable"
const PERMISSION_EVOLUTION := "evolution"
const PERMISSION_DEVELOPER := "developer"
const PERMISSION_LEVELS := [PERMISSION_STABLE, PERMISSION_EVOLUTION, PERMISSION_DEVELOPER]
const PLUGIN_CATEGORY_PERMISSION_LEVELS := {
	"plugin": PERMISSION_DEVELOPER,
	"plugin_runtime": PERMISSION_STABLE,
	"plugin_evolution": PERMISSION_EVOLUTION,
	"plugin_developer": PERMISSION_DEVELOPER
}


static func normalize_permission_level(raw_level: String) -> String:
	var level = str(raw_level)
	if PERMISSION_LEVELS.has(level):
		return level
	return PERMISSION_EVOLUTION


static func get_category_permission_level(category: String) -> String:
	return str(PLUGIN_CATEGORY_PERMISSION_LEVELS.get(category, PERMISSION_STABLE))


static func get_domain_category_consistency_issues(domain_defs: Array = MCPToolManifest.TOOL_DOMAIN_DEFS) -> Array[String]:
	var issues: Array[String] = []
	var known_categories := {}
	for category in MCPToolManifest.ALL_TOOL_CATEGORIES:
		known_categories[str(category)] = true

	for domain_def in domain_defs:
		var domain_key = str(domain_def.get("key", ""))
		for category in domain_def.get("categories", []):
			var category_name = str(category)
			if not known_categories.has(category_name):
				issues.append("Unknown category '%s' declared in domain '%s'" % [category_name, domain_key])
			elif domain_key == "plugin" and not PLUGIN_CATEGORY_PERMISSION_LEVELS.has(category_name):
				issues.append("Plugin category '%s' is missing an explicit permission level" % category_name)
	return issues


static func permission_allows_category(level: String, category: String) -> bool:
	return _permission_rank(normalize_permission_level(level)) >= _permission_rank(get_category_permission_level(category))


static func permission_allows_tool(level: String, tool_name: String) -> bool:
	var category = extract_category_from_tool_name(tool_name)
	if category.is_empty():
		return true
	return permission_allows_category(level, category)


static func extract_category_from_tool_name(tool_name: String) -> String:
	var best_match := ""
	for category in PLUGIN_CATEGORY_PERMISSION_LEVELS.keys():
		var prefix = "%s_" % str(category)
		if tool_name.begins_with(prefix) and prefix.length() > best_match.length():
			best_match = str(category)
	return best_match


static func get_domain_permission_level(domain_key: String, domain_defs: Array = MCPToolManifest.TOOL_DOMAIN_DEFS) -> String:
	var required_level = PERMISSION_STABLE
	for domain_def in domain_defs:
		if str(domain_def.get("key", "")) != domain_key:
			continue
		for category in domain_def.get("categories", []):
			var level = get_category_permission_level(str(category))
			if _permission_rank(level) > _permission_rank(required_level):
				required_level = level
		break
	return required_level


static func permission_allows_domain(level: String, domain_key: String, domain_defs: Array = MCPToolManifest.TOOL_DOMAIN_DEFS) -> bool:
	return _permission_rank(normalize_permission_level(level)) >= _permission_rank(get_domain_permission_level(domain_key, domain_defs))


static func _permission_rank(level: String) -> int:
	match normalize_permission_level(level):
		PERMISSION_DEVELOPER:
			return 2
		PERMISSION_EVOLUTION:
			return 1
		_:
			return 0
