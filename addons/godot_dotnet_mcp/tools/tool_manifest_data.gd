@tool
extends RefCounted
class_name MCPToolManifestData

const BUILTIN_TOOL_ENTRIES: Array[Dictionary] = [
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
	{"category": "filesystem", "path": "res://addons/godot_dotnet_mcp/tools/filesystem/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
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

const ALL_TOOL_CATEGORIES: Array[String] = [
	"scene", "node", "script", "resource", "filesystem", "project", "editor", "debug",
	"plugin", "plugin_runtime", "plugin_evolution", "plugin_developer", "group", "signal",
	"animation", "material", "shader", "lighting", "particle", "tilemap", "geometry",
	"physics", "navigation", "audio", "ui", "user", "system"
]

const EXPOSED_CATEGORIES: Array[String] = ["system"]

const DEFAULT_COLLAPSED_DOMAINS: Array[String] = [
	"core", "plugin", "visual", "gameplay", "interface", "user", "other"
]

const TOOL_DOMAIN_DEFS: Array[Dictionary] = [
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
