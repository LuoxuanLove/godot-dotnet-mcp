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
	"tool_profile_id": "default",
	"update_source": "latest_stable",
	"update_custom_branch": "dev",
	"update_release_tag": ""
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
	"system_plugin_reload",
	"system_plugin_update",
	"system_project_configure",
	"system_project_files",
	"system_project_index_build",
	"system_project_run",
	"system_project_state",
	"system_project_stop",
	"system_project_symbol_search",
	"system_runtime_control",
	"system_runtime_diagnose",
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
var update_refs_state := "idle"
var update_refs_status := ""
var update_refs_error := ""
var update_ref_branches: Array[String] = []
var update_ref_releases: Array[String] = []
var update_ref_latest_stable_release := ""
var update_ref_latest_release := ""
var update_refs_release_source := ""
var update_ref_commits: Dictionary = {}
var update_ref_versions: Dictionary = {}
var update_compare_state := "idle"
var update_compare_error := ""
var update_compare_base_commit := ""
var update_compare_target_ref := ""
var update_compare_target_commit := ""
var update_compare_ahead_by := -1
var update_compare_behind_by := -1
var update_sync_state := "idle"
var update_sync_status := ""
var update_sync_error := ""
var update_sync_target_ref := ""
var update_sync_target_kind := ""


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
