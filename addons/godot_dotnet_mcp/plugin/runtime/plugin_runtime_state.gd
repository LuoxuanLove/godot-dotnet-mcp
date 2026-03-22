@tool
extends RefCounted
class_name PluginRuntimeState

const MCPToolManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_manifest.gd")
const ToolPermissionPolicy = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_permission_policy.gd")
const SETTINGS_PATH = "user://godot_dotnet_mcp_settings.json"
const TOOL_PROFILE_DIR = "user://godot_dotnet_mcp_tool_profiles"

const ALL_TOOL_CATEGORIES = MCPToolManifest.ALL_TOOL_CATEGORIES

const DEFAULT_COLLAPSED_DOMAINS = MCPToolManifest.DEFAULT_COLLAPSED_DOMAINS
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

const TOOL_DOMAIN_DEFS = MCPToolManifest.TOOL_DOMAIN_DEFS

const DEFAULT_SETTINGS = {
	"port": 3000,
	"host": "127.0.0.1",
	"transport_mode": "http",
	"auto_start": true,
	"debug_mode": true,
	"log_level": "info",
	"permission_level": ToolPermissionPolicy.PERMISSION_EVOLUTION,
	"disabled_tools": [],
	"tool_profile_id": "system",
	"language": "",
	"show_user_tools": true,
	"collapsed_nodes": {},
	"central_server_attach_enabled": true,
	"central_server_host": "127.0.0.1",
	"central_server_port": 3020,
	"central_server_auto_launch": true,
	"central_server_command_path": "",
	"central_server_command_args": "",
	"central_server_dotnet_path": "",
	"central_server_release_enabled": true,
	"central_server_release_url": "",
	"client_manual_paths": {},
	"current_cli_scope": "user",
	"current_config_platform": "claude_desktop"
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
