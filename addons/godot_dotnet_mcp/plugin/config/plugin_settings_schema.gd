@tool
extends RefCounted
class_name PluginSettingsSchema

const MCPToolManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_manifest.gd")
const ToolPermissionPolicy = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_permission_policy.gd")

const SETTINGS_PATH := "user://godot_dotnet_mcp_settings.json"
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


static func build_default_settings() -> Dictionary:
	return DEFAULT_SETTINGS.duplicate(true)
