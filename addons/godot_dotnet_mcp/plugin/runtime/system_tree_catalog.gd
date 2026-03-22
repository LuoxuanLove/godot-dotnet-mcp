@tool
extends RefCounted
class_name SystemTreeCatalog

const SYSTEM_TOOL_ATOMIC_CHILDREN := {
	"system_project_state": [
		{"tool": "project_info",         "actions": ["get_info"]},
		{"tool": "project_dotnet",       "actions": []},
		{"tool": "filesystem_directory", "actions": ["get_files"]},
		{"tool": "debug_runtime_bridge", "actions": ["get_summary", "get_errors_context", "get_scene_snapshot", "get_recent_filtered"]},
		{"tool": "debug_dotnet",         "actions": ["restore"]}
	],
	"system_project_advise": [
		{"tool": "project_info",         "actions": ["get_info"]},
		{"tool": "filesystem_directory", "actions": ["get_files"]},
		{"tool": "debug_runtime_bridge", "actions": ["get_summary", "get_recent_filtered"]},
		{"tool": "debug_dotnet",         "actions": ["restore"]}
	],
	"system_runtime_diagnose": [
		{"tool": "debug_runtime_bridge", "actions": ["get_errors_context"]},
		{"tool": "debug_dotnet",         "actions": ["restore"]},
		{"tool": "debug_performance",    "actions": ["get_fps", "get_memory", "get_render_info"]}
	],
	"system_project_configure": [
		{"tool": "project_info",     "actions": ["get_settings"]},
		{"tool": "project_settings", "actions": ["set"]},
		{"tool": "project_autoload", "actions": ["list", "add", "remove"]},
		{"tool": "project_input",    "actions": ["list_actions"]}
	],
	"system_project_run":  [{"tool": "scene_run", "actions": ["play_main", "play_custom"]}],
	"system_project_stop": [{"tool": "scene_run", "actions": ["stop"]}],
	"system_bindings_audit": [
		{"tool": "script_inspect",       "actions": ["path"]},
		{"tool": "script_references",    "actions": ["get_scene_refs", "get_base_type"]},
		{"tool": "scene_bindings",       "actions": ["from_path"]},
		{"tool": "scene_audit",          "actions": ["from_path"]},
		{"tool": "filesystem_directory", "actions": ["get_files"]}
	],
	"system_scene_validate": [
		{"tool": "scene_audit",    "actions": ["from_path"]},
		{"tool": "resource_query", "actions": ["get_dependencies", "get_info"]}
	],
	"system_scene_analyze": [
		{"tool": "scene_bindings", "actions": ["from_path"]},
		{"tool": "scene_audit",    "actions": ["from_path"]},
		{"tool": "script_inspect", "actions": ["path"]}
	],
	"system_scene_patch": [
		{"tool": "scene_management", "actions": ["get_current", "open", "save"]},
		{"tool": "node_lifecycle",   "actions": ["create", "delete"]},
		{"tool": "node_property",    "actions": ["set"]},
		{"tool": "node_hierarchy",   "actions": ["reparent"]}
	],
	"system_script_analyze": [
		{"tool": "script_inspect",    "actions": ["path"]},
		{"tool": "script_symbols",    "actions": ["path"]},
		{"tool": "script_exports",    "actions": ["path"]},
		{"tool": "script_references", "actions": ["get_scene_refs", "get_base_type"]}
	],
	"system_script_patch": [
		{"tool": "script_inspect",  "actions": ["path"]},
		{"tool": "script_edit_gd",  "actions": ["add_function", "add_variable", "add_signal", "add_export"]},
		{"tool": "script_edit_cs",  "actions": ["add_method", "add_field"]}
	],
	"system_project_index_build": [
		{"tool": "filesystem_directory", "actions": ["get_files"]},
		{"tool": "script_inspect",       "actions": ["path"]},
		{"tool": "resource_query",       "actions": ["get_dependencies"]}
	],
	"system_project_symbol_search":  [{"tool": "filesystem_directory", "actions": ["get_files"]}],
	"system_scene_dependency_graph": [{"tool": "resource_query",       "actions": ["get_dependencies"]}]
}


static func get_default_collapsed_atomic_tools() -> Array[String]:
	var defaults: Array[String] = []
	var visited := {}
	var system_tools := SYSTEM_TOOL_ATOMIC_CHILDREN.keys()
	system_tools.sort()
	for system_full_name in system_tools:
		_collect_default_atomic_tools(str(system_full_name), visited, defaults)
	defaults.sort()
	return defaults


static func _collect_default_atomic_tools(system_full_name: String, visited: Dictionary, defaults: Array[String]) -> void:
	for entry in SYSTEM_TOOL_ATOMIC_CHILDREN.get(system_full_name, []):
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


static func get_action_name_key(parent_tool: String, action_name: String) -> String:
	return "tool_action_%s_%s_name" % [parent_tool, action_name]


static func get_action_desc_key(parent_tool: String, action_name: String) -> String:
	return "tool_action_%s_%s_desc" % [parent_tool, action_name]


static func get_generic_action_name_key(action_name: String) -> String:
	return "tool_action_%s_name" % action_name


static func get_generic_action_desc_key(action_name: String) -> String:
	return "tool_action_%s_desc" % action_name

