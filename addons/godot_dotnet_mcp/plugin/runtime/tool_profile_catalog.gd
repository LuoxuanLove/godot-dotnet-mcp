@tool
extends RefCounted
class_name ToolProfileCatalog

const MCPUserDataPaths = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_user_data_paths.gd")
const PROFILE_STORAGE_DIR := MCPUserDataPaths.PROFILE_STORAGE_DIR

const BUILTIN_TOOL_PROFILES: Array[Dictionary] = [
	{
		"id": "system",
		"name_key": "tool_profile_system",
		"desc_key": "tool_profile_system_desc",
		"enabled_categories": ["system", "runtime"]
	},
	{
		"id": "task",
		"name_key": "tool_profile_task",
		"desc_key": "tool_profile_task_desc",
		"enabled_categories": ["system", "project", "scene", "script", "debug", "plugin_runtime", "plugin_developer", "filesystem", "runtime"]
	},
	{
		"id": "slim",
		"name_key": "tool_profile_slim",
		"desc_key": "tool_profile_slim_desc",
		"enabled_categories": ["scene", "node", "script", "resource", "filesystem", "project", "editor", "plugin_runtime", "plugin_developer", "debug", "runtime", "group", "signal", "system"]
	},
	{
		"id": "default",
		"name_key": "tool_profile_default",
		"desc_key": "tool_profile_default_desc",
		"enabled_categories": ["scene", "node", "script", "resource", "filesystem", "project", "editor", "plugin_runtime", "plugin_evolution", "plugin_developer", "debug", "runtime", "group", "signal", "animation", "physics", "navigation", "audio", "ui", "system"]
	},
	{
		"id": "full",
		"name_key": "tool_profile_full",
		"desc_key": "tool_profile_full_desc",
		"enabled_categories": [],
		"excluded_categories": ["user"]
	}
]


static func get_builtin_profiles() -> Array[Dictionary]:
	return BUILTIN_TOOL_PROFILES.duplicate(true)
