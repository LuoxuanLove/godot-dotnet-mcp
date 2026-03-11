@tool
extends RefCounted
class_name PluginRuntimeState

const SETTINGS_PATH = "user://godot_dotnet_mcp_settings.json"
const TOOL_PROFILE_DIR = "user://godot_dotnet_mcp_tool_profiles"

const ALL_TOOL_CATEGORIES = [
	"scene", "node", "script", "resource", "filesystem", "project", "editor", "debug",
	"plugin", "group", "signal", "animation", "material", "shader", "lighting", "particle", "tilemap", "geometry",
	"physics", "navigation", "audio", "ui"
]

const DEFAULT_COLLAPSED_DOMAINS = ["core", "visual", "gameplay", "interface", "other"]

const BUILTIN_TOOL_PROFILES = [
	{
		"id": "slim",
		"name_key": "tool_profile_slim",
		"desc_key": "tool_profile_slim_desc",
		"enabled_categories": ["scene", "node", "script", "resource", "filesystem", "project", "editor", "plugin", "debug", "group", "signal"]
	},
	{
		"id": "default",
		"name_key": "tool_profile_default",
		"desc_key": "tool_profile_default_desc",
		"enabled_categories": ["scene", "node", "script", "resource", "filesystem", "project", "editor", "plugin", "debug", "group", "signal", "animation", "physics", "navigation", "audio", "ui"]
	},
	{
		"id": "full",
		"name_key": "tool_profile_full",
		"desc_key": "tool_profile_full_desc",
		"enabled_categories": []
	}
]

const TOOL_DOMAIN_DEFS = [
	{
		"key": "core",
		"label": "domain_core",
		"categories": ["scene", "node", "script", "resource", "filesystem", "project", "editor", "plugin", "debug", "group", "signal", "animation"]
	},
	{
		"key": "visual",
		"label": "domain_visual",
		"categories": ["material", "shader", "lighting", "particle", "tilemap", "geometry"]
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
	}
]

const DEFAULT_SETTINGS = {
	"port": 3000,
	"host": "127.0.0.1",
	"auto_start": true,
	"debug_mode": true,
	"disabled_tools": [],
	"tool_profile_id": "default",
	"language": "",
	"collapsed_categories": [],
	"collapsed_domains": []
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
