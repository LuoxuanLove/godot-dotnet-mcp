@tool
extends RefCounted

## Canonical executor catalog for AtomicBridge runtime dispatch.

const EXECUTOR_SCRIPT_PATHS := {
	"project": "res://addons/godot_dotnet_mcp/tools/project/executor.gd",
	"script": "res://addons/godot_dotnet_mcp/tools/script/executor.gd",
	"scene": "res://addons/godot_dotnet_mcp/tools/scene/executor.gd",
	"node": "res://addons/godot_dotnet_mcp/tools/node/executor.gd",
	"editor": "res://addons/godot_dotnet_mcp/tools/editor/executor.gd",
	"resource": "res://addons/godot_dotnet_mcp/tools/resource/executor.gd",
	"debug": "res://addons/godot_dotnet_mcp/tools/debug/executor.gd",
	"dap": "res://addons/godot_dotnet_mcp/tools/dap/executor.gd",
	"filesystem": "res://addons/godot_dotnet_mcp/tools/filesystem/executor.gd",
	"runtime": "res://addons/godot_dotnet_mcp/tools/runtime/executor.gd"
}

const EXECUTOR_DEPENDENCY_PATHS := {
	"editor": ["res://addons/godot_dotnet_mcp/tools/editor_tools.gd"]
}


static func get_executor_script_paths() -> Dictionary:
	return EXECUTOR_SCRIPT_PATHS.duplicate(true)


static func get_executor_dependency_paths() -> Dictionary:
	var dependency_paths := {}
	for category in EXECUTOR_DEPENDENCY_PATHS.keys():
		var paths = EXECUTOR_DEPENDENCY_PATHS[category]
		if paths is Array:
			dependency_paths[category] = paths.duplicate(true)
		else:
			dependency_paths[category] = paths
	return dependency_paths


static func get_categories() -> Array[String]:
	var categories: Array[String] = []
	for category in EXECUTOR_SCRIPT_PATHS.keys():
		categories.append(str(category))
	categories.sort()
	return categories
