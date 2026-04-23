@tool
extends RefCounted
class_name PluginRuntimeState

const ToolPermissionPolicy = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_permission_policy.gd")
const ToolProfileCatalog = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_profile_catalog.gd")
const MCPToolManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_manifest.gd")

const PERMISSION_STABLE := ToolPermissionPolicy.PERMISSION_STABLE
const PERMISSION_EVOLUTION := ToolPermissionPolicy.PERMISSION_EVOLUTION
const PERMISSION_DEVELOPER := ToolPermissionPolicy.PERMISSION_DEVELOPER
const PERMISSION_LEVELS := ToolPermissionPolicy.PERMISSION_LEVELS

const PLUGIN_CATEGORY_PERMISSION_LEVELS: Dictionary = ToolPermissionPolicy.PLUGIN_CATEGORY_PERMISSION_LEVELS

const SETTINGS_PATH := "user://godot_dotnet_mcp/settings.json"
const TOOL_PROFILE_DIR := ToolProfileCatalog.PROFILE_STORAGE_DIR

const DEFAULT_SETTINGS: Dictionary = {
	"auto_start": true,
	"client_manual_paths": {},
	"current_cli_scope": "user",
	"current_config_platform": "claude_desktop",
	"debug_mode": true,
	"disabled_tools": [],
	"host": "127.0.0.1",
	"language": "en",
	"log_level": "info",
	"permission_level": PERMISSION_EVOLUTION,
	"port": 3000,
	"show_user_tools": true,
	"tool_profile_id": "default"
}

const ALL_TOOL_CATEGORIES: Array[String] = MCPToolManifest.ALL_TOOL_CATEGORIES
const DEFAULT_COLLAPSED_DOMAINS: Array[String] = []

const BUILTIN_TOOL_PROFILES: Array[Dictionary] = ToolProfileCatalog.BUILTIN_TOOL_PROFILES
const TOOL_DOMAIN_DEFS: Array[Dictionary] = MCPToolManifest.TOOL_DOMAIN_DEFS
const DEFAULT_COLLAPSED_SYSTEM_TOOLS: Array[String] = [
	"system_bindings_audit",
	"system_editor_state",
	"system_project_configure",
	"system_project_run",
	"system_project_state",
	"system_project_stop",
	"system_project_symbol_search",
	"system_runtime_capture",
	"system_runtime_control",
	"system_runtime_diagnose",
	"system_runtime_input",
	"system_runtime_step",
	"system_scene_analyze",
	"system_scene_dependency_graph",
	"system_scene_patch",
	"system_scene_validate",
	"system_script_analyze",
	"system_script_patch"
]

var settings: Dictionary = {}
var custom_tool_profiles: Dictionary = {}
var current_cli_scope := "user"
var current_config_platform := "claude_desktop"
var current_tab := 0
var restore_focus := false
var needs_initial_tool_profile_apply := false


func resolve_active_language(localization) -> String:
	if settings is Dictionary:
		var configured_language = str(settings.get("language", "")).strip_edges()
		if not configured_language.is_empty():
			return configured_language
	if localization != null and localization.has_method("get_language"):
		var localization_language = str(localization.get_language()).strip_edges()
		if not localization_language.is_empty():
			return localization_language
	return "en"


static func get_domain_category_consistency_issues(domain_defs: Array = TOOL_DOMAIN_DEFS) -> Array[String]:
	return ToolPermissionPolicy.get_domain_category_consistency_issues(domain_defs)


static func build_default_settings() -> Dictionary:
	return DEFAULT_SETTINGS.duplicate(true)


static func normalize_permission_level(raw_level: String) -> String:
	return ToolPermissionPolicy.normalize_permission_level(raw_level)


static func permission_allows_category(level: String, category: String) -> bool:
	return ToolPermissionPolicy.permission_allows_category(level, category)


static func extract_category_from_tool_name(tool_name: String) -> String:
	return ToolPermissionPolicy.extract_category_from_tool_name(tool_name)


static func permission_allows_tool(level: String, tool_name: String) -> bool:
	return ToolPermissionPolicy.permission_allows_tool(level, tool_name)


static func permission_allows_domain(level: String, domain_key: String, domain_defs: Array = TOOL_DOMAIN_DEFS) -> bool:
	return ToolPermissionPolicy.permission_allows_domain(level, domain_key, domain_defs)
