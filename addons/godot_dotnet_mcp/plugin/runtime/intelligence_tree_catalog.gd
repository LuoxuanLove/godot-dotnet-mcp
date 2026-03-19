@tool
extends RefCounted
class_name IntelligenceTreeCatalog

const INTELLIGENCE_TOOL_ATOMIC_CHILDREN := {
	"intelligence_project_state": [
		{"tool": "project_info",         "actions": ["get_info"]},
		{"tool": "project_dotnet",       "actions": []},
		{"tool": "filesystem_directory", "actions": ["get_files"]},
		{"tool": "debug_runtime_bridge", "actions": ["get_summary", "get_errors_context", "get_scene_snapshot", "get_recent_filtered"]},
		{"tool": "debug_dotnet",         "actions": ["restore"]}
	],
	"intelligence_project_advise": [
		{"tool": "project_info",         "actions": ["get_info"]},
		{"tool": "filesystem_directory", "actions": ["get_files"]},
		{"tool": "debug_runtime_bridge", "actions": ["get_summary", "get_recent_filtered"]},
		{"tool": "debug_dotnet",         "actions": ["restore"]}
	],
	"intelligence_runtime_diagnose": [
		{"tool": "debug_runtime_bridge", "actions": ["get_errors_context"]},
		{"tool": "debug_dotnet",         "actions": ["restore"]},
		{"tool": "debug_performance",    "actions": ["get_fps", "get_memory", "get_render_info"]}
	],
	"intelligence_project_configure": [
		{"tool": "project_info",     "actions": ["get_settings"]},
		{"tool": "project_settings", "actions": ["set"]},
		{"tool": "project_autoload", "actions": ["list", "add", "remove"]},
		{"tool": "project_input",    "actions": ["list_actions"]}
	],
	"intelligence_project_run":  [{"tool": "scene_run", "actions": ["play_main", "play_custom"]}],
	"intelligence_project_stop": [{"tool": "scene_run", "actions": ["stop"]}],
	"intelligence_bindings_audit": [
		{"tool": "script_inspect",       "actions": ["path"]},
		{"tool": "script_references",    "actions": ["get_scene_refs", "get_base_type"]},
		{"tool": "scene_bindings",       "actions": ["from_path"]},
		{"tool": "scene_audit",          "actions": ["from_path"]},
		{"tool": "filesystem_directory", "actions": ["get_files"]}
	],
	"intelligence_scene_validate": [
		{"tool": "scene_audit",    "actions": ["from_path"]},
		{"tool": "resource_query", "actions": ["get_dependencies", "get_info"]}
	],
	"intelligence_scene_analyze": [
		{"tool": "scene_bindings", "actions": ["from_path"]},
		{"tool": "scene_audit",    "actions": ["from_path"]},
		{"tool": "script_inspect", "actions": ["path"]}
	],
	"intelligence_scene_patch": [
		{"tool": "scene_management", "actions": ["get_current", "open", "save"]},
		{"tool": "node_lifecycle",   "actions": ["create", "delete"]},
		{"tool": "node_property",    "actions": ["set"]},
		{"tool": "node_hierarchy",   "actions": ["reparent"]}
	],
	"intelligence_script_analyze": [
		{"tool": "script_inspect",    "actions": ["path"]},
		{"tool": "script_symbols",    "actions": ["path"]},
		{"tool": "script_exports",    "actions": ["path"]},
		{"tool": "script_references", "actions": ["get_scene_refs", "get_base_type"]}
	],
	"intelligence_script_patch": [
		{"tool": "script_inspect",  "actions": ["path"]},
		{"tool": "script_edit_gd",  "actions": ["add_function", "add_variable", "add_signal", "add_export"]},
		{"tool": "script_edit_cs",  "actions": ["add_method", "add_field"]}
	],
	"intelligence_project_index_build": [
		{"tool": "filesystem_directory", "actions": ["get_files"]},
		{"tool": "script_inspect",       "actions": ["path"]},
		{"tool": "resource_query",       "actions": ["get_dependencies"]}
	],
	"intelligence_project_symbol_search":  [{"tool": "filesystem_directory", "actions": ["get_files"]}],
	"intelligence_scene_dependency_graph": [{"tool": "resource_query",       "actions": ["get_dependencies"]}]
}


static func get_default_collapsed_atomic_tools() -> Array[String]:
	var defaults: Array[String] = []
	var visited := {}
	var intelligence_tools := INTELLIGENCE_TOOL_ATOMIC_CHILDREN.keys()
	intelligence_tools.sort()
	for intelligence_full_name in intelligence_tools:
		_collect_default_atomic_tools(str(intelligence_full_name), visited, defaults)
	defaults.sort()
	return defaults


static func _collect_default_atomic_tools(intelligence_full_name: String, visited: Dictionary, defaults: Array[String]) -> void:
	for entry in INTELLIGENCE_TOOL_ATOMIC_CHILDREN.get(intelligence_full_name, []):
		var atomic_full_name := ""
		if entry is Dictionary:
			atomic_full_name = str(entry.get("tool", ""))
		else:
			atomic_full_name = str(entry)
		if atomic_full_name.is_empty() or visited.has(atomic_full_name):
			continue
		visited[atomic_full_name] = true
		defaults.append(atomic_full_name)
		_collect_default_atomic_tools(atomic_full_name, visited, defaults)
