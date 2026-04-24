@tool
extends RefCounted
class_name PluginRuntimeState

const ToolProfileCatalog = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_profile_catalog.gd")
const MCPToolManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_manifest.gd")

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
	"system_editor_log",
	"system_editor_state",
	"system_help",
	"system_project_configure",
	"system_project_files",
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
	"system_scene_tree",
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


static func build_default_settings() -> Dictionary:
	return DEFAULT_SETTINGS.duplicate(true)
