@tool
extends RefCounted
class_name ToolCatalogManifest

const CUSTOM_TOOLS_DIR := "res://addons/godot_dotnet_mcp/custom_tools"

const BUILTIN_ENTRIES: Array[Dictionary] = [
	{"category": "system", "path": "res://addons/godot_dotnet_mcp/tools/system/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
	{"category": "user", "path": "res://addons/godot_dotnet_mcp/tools/user/executor.gd", "domain_key": "user", "source": "builtin", "hot_reloadable": true, "allow_empty_definitions": true},
	{"category": "scene", "path": "res://addons/godot_dotnet_mcp/tools/scene/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
	{"category": "node", "path": "res://addons/godot_dotnet_mcp/tools/node/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
	{"category": "resource", "path": "res://addons/godot_dotnet_mcp/tools/resource/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
	{"category": "project", "path": "res://addons/godot_dotnet_mcp/tools/project/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
	{"category": "script", "path": "res://addons/godot_dotnet_mcp/tools/script/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
	{"category": "editor", "path": "res://addons/godot_dotnet_mcp/tools/editor/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
	{"category": "plugin_runtime", "path": "res://addons/godot_dotnet_mcp/tools/plugin_runtime/executor.gd", "domain_key": "plugin", "source": "builtin", "hot_reloadable": true},
	{"category": "plugin_evolution", "path": "res://addons/godot_dotnet_mcp/tools/plugin_evolution/executor.gd", "domain_key": "plugin", "source": "builtin", "hot_reloadable": true},
	{"category": "plugin_developer", "path": "res://addons/godot_dotnet_mcp/tools/plugin_developer/executor.gd", "domain_key": "plugin", "source": "builtin", "hot_reloadable": true},
	{"category": "debug", "path": "res://addons/godot_dotnet_mcp/tools/debug/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
	{"category": "dap", "path": "res://addons/godot_dotnet_mcp/tools/dap/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
	{"category": "filesystem", "path": "res://addons/godot_dotnet_mcp/tools/filesystem/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
	{"category": "runtime", "path": "res://addons/godot_dotnet_mcp/tools/runtime/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
	{"category": "group", "path": "res://addons/godot_dotnet_mcp/tools/group/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
	{"category": "signal", "path": "res://addons/godot_dotnet_mcp/tools/signal/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
	{"category": "animation", "path": "res://addons/godot_dotnet_mcp/tools/animation/executor.gd", "domain_key": "visual", "source": "builtin", "hot_reloadable": true},
	{"category": "material", "path": "res://addons/godot_dotnet_mcp/tools/material/executor.gd", "domain_key": "visual", "source": "builtin", "hot_reloadable": true},
	{"category": "shader", "path": "res://addons/godot_dotnet_mcp/tools/shader/executor.gd", "domain_key": "visual", "source": "builtin", "hot_reloadable": true},
	{"category": "lighting", "path": "res://addons/godot_dotnet_mcp/tools/lighting/executor.gd", "domain_key": "visual", "source": "builtin", "hot_reloadable": true},
	{"category": "particle", "path": "res://addons/godot_dotnet_mcp/tools/particle/executor.gd", "domain_key": "visual", "source": "builtin", "hot_reloadable": true},
	{"category": "tilemap", "path": "res://addons/godot_dotnet_mcp/tools/tilemap/executor.gd", "domain_key": "visual", "source": "builtin", "hot_reloadable": true},
	{"category": "geometry", "path": "res://addons/godot_dotnet_mcp/tools/geometry/executor.gd", "domain_key": "visual", "source": "builtin", "hot_reloadable": true},
	{"category": "physics", "path": "res://addons/godot_dotnet_mcp/tools/physics/executor.gd", "domain_key": "gameplay", "source": "builtin", "hot_reloadable": true},
	{"category": "navigation", "path": "res://addons/godot_dotnet_mcp/tools/navigation/executor.gd", "domain_key": "gameplay", "source": "builtin", "hot_reloadable": true},
	{"category": "audio", "path": "res://addons/godot_dotnet_mcp/tools/audio/executor.gd", "domain_key": "gameplay", "source": "builtin", "hot_reloadable": true},
	{"category": "ui", "path": "res://addons/godot_dotnet_mcp/tools/ui/executor.gd", "domain_key": "interface", "source": "builtin", "hot_reloadable": true},
]

const TOOL_DOMAIN_DEFS: Array[Dictionary] = [
	{
		"key": "core",
		"label": "domain_core",
		"categories": [
			"system",
			"project",
			"scene",
			"script",
			"debug",
			"dap",
			"filesystem",
			"node",
			"resource",
			"editor",
			"runtime",
			"group",
			"signal"
		]
	},
	{
		"key": "visual",
		"label": "domain_visual",
		"categories": [
			"animation",
			"material",
			"shader",
			"lighting",
			"particle",
			"tilemap",
			"geometry"
		]
	},
	{
		"key": "gameplay",
		"label": "domain_gameplay",
		"categories": [
			"physics",
			"navigation",
			"audio"
		]
	},
	{
		"key": "interface",
		"label": "domain_interface",
		"categories": [
			"ui"
		]
	},
	{
		"key": "plugin",
		"label": "domain_plugin",
		"categories": [
			"plugin_runtime",
			"plugin_evolution",
			"plugin_developer"
		]
	},
	{
		"key": "user",
		"label": "domain_user",
		"categories": ["user"]
	}
]

const PUBLIC_MCP_TOOL_CATEGORIES: Array[String] = [
	"system",
	"user"
]

const PUBLIC_REMOVED_MCP_TOOLS := {
	"system_help": true,
	"system_plugin_reload": true,
	"system_plugin_update": true,
	"system_scene_analyze": true,
	"system_scene_validate": true,
	"system_editor_log": true,
	"system_tool_catalog": true,
	"system_tool_activity": true,
	"resource_manage": true
}

const MCP_TOOL_NAME_MAX_LENGTH := 128


static func get_builtin_entries() -> Array[Dictionary]:
	return BUILTIN_ENTRIES.duplicate(true)


func collect_entries() -> Dictionary:
	return {
		"entries": get_builtin_entries(),
		"errors": []
	}


static func get_builtin_categories() -> Array[String]:
	var categories: Array[String] = []
	for entry in BUILTIN_ENTRIES:
		categories.append(str(entry.get("category", "")))
	return categories


static func get_domain_defs() -> Array[Dictionary]:
	return TOOL_DOMAIN_DEFS.duplicate(true)


static func get_all_tool_categories() -> Array[String]:
	var categories: Array[String] = []
	for domain_def in TOOL_DOMAIN_DEFS:
		for category in domain_def.get("categories", []):
			categories.append(str(category))
	return categories


static func get_public_mcp_tool_categories() -> Array[String]:
	return PUBLIC_MCP_TOOL_CATEGORIES.duplicate()


static func get_removed_public_tools() -> Dictionary:
	return PUBLIC_REMOVED_MCP_TOOLS.duplicate(true)


static func get_removed_public_tool_names() -> Array[String]:
	var names: Array[String] = []
	for tool_name in PUBLIC_REMOVED_MCP_TOOLS.keys():
		names.append(str(tool_name))
	names.sort()
	return names


static func get_domain_key_for_category(category: String) -> String:
	for domain_def in TOOL_DOMAIN_DEFS:
		var categories = domain_def.get("categories", [])
		if categories is Array and (categories as Array).has(category):
			return str(domain_def.get("key", ""))
	return ""


static func is_public_category(category: String) -> bool:
	return PUBLIC_MCP_TOOL_CATEGORIES.has(category)


static func is_removed_public_tool(tool_name: String) -> bool:
	return PUBLIC_REMOVED_MCP_TOOLS.has(tool_name)


static func is_valid_mcp_tool_name(tool_name: String) -> bool:
	if tool_name.is_empty() or tool_name.length() > MCP_TOOL_NAME_MAX_LENGTH:
		return false
	for index in range(tool_name.length()):
		var code := tool_name.unicode_at(index)
		var is_digit := code >= 48 and code <= 57
		var is_upper := code >= 65 and code <= 90
		var is_lower := code >= 97 and code <= 122
		var is_symbol := code == 45 or code == 46 or code == 95
		if not (is_digit or is_upper or is_lower or is_symbol):
			return false
	return true
