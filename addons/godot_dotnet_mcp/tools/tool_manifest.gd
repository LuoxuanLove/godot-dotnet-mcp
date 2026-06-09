@tool
extends RefCounted
class_name MCPToolManifest

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

const ALL_TOOL_CATEGORIES: Array[String] = [
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
	"signal",
	"animation",
	"material",
	"shader",
	"lighting",
	"particle",
	"tilemap",
	"geometry",
	"physics",
	"navigation",
	"audio",
	"ui",
	"plugin_runtime",
	"plugin_evolution",
	"plugin_developer",
	"user"
]

const PUBLIC_MCP_TOOL_CATEGORIES: Array[String] = [
	"system",
	"user"
]
