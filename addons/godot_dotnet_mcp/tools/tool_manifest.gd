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
