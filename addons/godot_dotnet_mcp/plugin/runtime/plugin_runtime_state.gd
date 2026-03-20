@tool
extends RefCounted
class_name PluginRuntimeState

const SETTINGS_PATH = "user://godot_dotnet_mcp_settings.json"
const TOOL_PROFILE_DIR = "user://godot_dotnet_mcp_tool_profiles"
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

const ALL_TOOL_CATEGORIES = [
	"scene", "node", "script", "resource", "filesystem", "project", "editor", "debug",
	"plugin", "plugin_runtime", "plugin_evolution", "plugin_developer", "group", "signal", "animation", "material", "shader", "lighting", "particle", "tilemap", "geometry",
	"physics", "navigation", "audio", "ui", "user", "system"
]

const DEFAULT_COLLAPSED_DOMAINS = ["core", "plugin", "visual", "gameplay", "interface", "user", "other"]
const DEFAULT_COLLAPSED_SYSTEM_TOOLS: Array = [
	"system_project_state",
	"system_project_advise",
	"system_runtime_diagnose",
	"system_project_configure",
	"system_project_run",
	"system_project_stop",
	"system_bindings_audit",
	"system_scene_validate",
	"system_scene_analyze",
	"system_scene_patch",
	"system_script_analyze",
	"system_script_patch",
	"system_project_index_build",
	"system_project_symbol_search",
	"system_scene_dependency_graph"
]

const BUILTIN_TOOL_PROFILES = [
	{
		"id": "system",
		"name_key": "tool_profile_system",
		"desc_key": "tool_profile_system_desc",
		"enabled_categories": ["system"]
	},
	{
		"id": "task",
		"name_key": "tool_profile_task",
		"desc_key": "tool_profile_task_desc",
		"enabled_categories": ["system", "project", "scene", "script", "debug", "plugin_runtime", "plugin_developer", "filesystem"]
	},
	{
		"id": "slim",
		"name_key": "tool_profile_slim",
		"desc_key": "tool_profile_slim_desc",
		"enabled_categories": ["scene", "node", "script", "resource", "filesystem", "project", "editor", "plugin", "plugin_runtime", "plugin_developer", "debug", "group", "signal", "system"]
	},
	{
		"id": "default",
		"name_key": "tool_profile_default",
		"desc_key": "tool_profile_default_desc",
		"enabled_categories": ["scene", "node", "script", "resource", "filesystem", "project", "editor", "plugin", "plugin_runtime", "plugin_evolution", "plugin_developer", "debug", "group", "signal", "animation", "physics", "navigation", "audio", "ui", "system"]
	},
	{
		"id": "full",
		"name_key": "tool_profile_full",
		"desc_key": "tool_profile_full_desc",
		"enabled_categories": [],
		"excluded_categories": ["user"]
	}
]

const TOOL_DOMAIN_DEFS = [
	{
		"key": "core",
		"label": "domain_core",
		"categories": ["scene", "node", "script", "resource", "filesystem", "project", "editor", "debug", "group", "signal", "system"]
	},
	{
		"key": "plugin",
		"label": "domain_plugin",
		"categories": ["plugin_runtime", "plugin_evolution", "plugin_developer"]
	},
	{
		"key": "visual",
		"label": "domain_visual",
		"categories": ["material", "shader", "lighting", "particle", "tilemap", "geometry", "animation"]
	},
	{
		"key": "gameplay",
		"label": "domain_gameplay",
		"categories": ["physics", "navigation", "audio"]
	},
	{
		"key": "interface",
		"label": "domain_interface",
		"categories": ["ui"]
	},
	{
		"key": "user",
		"label": "domain_user",
		"categories": ["user"]
	}
]

const DEFAULT_SETTINGS = {
	"port": 3000,
	"host": "127.0.0.1",
	"transport_mode": "http",
	"auto_start": true,
	"debug_mode": true,
	"log_level": "info",
	"permission_level": PERMISSION_EVOLUTION,
	"disabled_tools": [],
	"tool_profile_id": "system",
	"language": "",
	"show_user_tools": true,
	"collapsed_nodes": {},
	"bridge_executable_path": "",
	"bridge_install_source": "",
	"bridge_install_state": "not_configured",
	"bridge_install_version": "",
	"bridge_install_message": ""
}

var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var custom_tool_profiles: Dictionary = {}
var current_cli_scope := "user"
var current_config_platform := "claude_desktop"
var current_tab := 0
var restore_focus := false
var needs_initial_tool_profile_apply := false


func resolve_active_language(localization_service) -> String:
	if not str(settings.get("language", "")).is_empty():
		return str(settings["language"])
	if localization_service:
		return str(localization_service.get_language())
	return "en"


static func normalize_permission_level(raw_level: String) -> String:
	var level = str(raw_level)
	if PERMISSION_LEVELS.has(level):
		return level
	return PERMISSION_EVOLUTION


static func get_category_permission_level(category: String) -> String:
	# Any category not explicitly listed here is treated as stable by default.
	return str(PLUGIN_CATEGORY_PERMISSION_LEVELS.get(category, PERMISSION_STABLE))


static func get_domain_category_consistency_issues(domain_defs: Array = TOOL_DOMAIN_DEFS) -> Array[String]:
	var issues: Array[String] = []
	var known_categories := {}
	for category in ALL_TOOL_CATEGORIES:
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


static func get_domain_permission_level(domain_key: String, domain_defs: Array) -> String:
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


static func permission_allows_domain(level: String, domain_key: String, domain_defs: Array) -> bool:
	return _permission_rank(normalize_permission_level(level)) >= _permission_rank(get_domain_permission_level(domain_key, domain_defs))


static func _permission_rank(level: String) -> int:
	match normalize_permission_level(level):
		PERMISSION_DEVELOPER:
			return 2
		PERMISSION_EVOLUTION:
			return 1
		_:
			return 0
