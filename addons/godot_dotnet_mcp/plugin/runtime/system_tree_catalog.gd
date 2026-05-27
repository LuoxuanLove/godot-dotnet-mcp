@tool
extends RefCounted

const SYSTEM_TOOL_ATOMIC_CHILDREN := {
	"system_help": [],
	"system_project_state": [
		{"tool": "project_info",         "actions": ["get_info"]},
		{"tool": "project_dotnet",       "actions": []},
		{"tool": "filesystem_directory", "actions": ["get_files"]},
		{"tool": "debug_runtime_bridge", "actions": ["get_summary", "get_errors_context", "get_scene_snapshot", "get_recent_filtered"]},
		{"tool": "debug_dotnet",         "actions": ["build"]}
	],
	"system_editor_state": [
		{"tool": "editor_status",       "actions": ["get_info", "get_main_screen", "get_focus_context", "get_distraction_free", "get_godot_path"]},
		{"tool": "editor_inspector",    "actions": ["get_edited", "get_selected_property"]},
		{"tool": "editor_filesystem",   "actions": ["get_selected", "get_current_path"]},
		{"tool": "debug_runtime_bridge", "actions": ["get_summary", "get_scene_snapshot", "get_errors_context", "get_recent_filtered"]},
		{"tool": "debug_dotnet",         "actions": ["build"]}
	],
	"system_plugin_reload": [],
	"system_plugin_update": [],
	"system_editor_control": [
		{"tool": "editor_status",      "actions": ["set_main_screen"]},
		{"tool": "editor_screenshot",  "actions": ["capture"]},
		{"tool": "editor_ui_control",  "actions": ["list_visible", "list_dock_tabs", "activate_dock_tab", "activate_ui", "get_control", "capture_control", "focus_control", "activate_control", "click_control", "right_click_control", "set_text"]},
		{"tool": "editor_popup",       "actions": ["list_visible", "press_button", "set_text", "close_popup"]}
	],
	"system_editor_log": [
		{"tool": "debug_editor_log", "actions": ["get_output", "get_errors", "clear"]}
	],
	"system_runtime_diagnose": [
		{"tool": "debug_runtime_bridge", "actions": ["get_errors_context"]},
		{"tool": "debug_dotnet",         "actions": ["build"]},
		{"tool": "debug_performance",    "actions": ["get_fps", "get_memory", "get_render_info"]}
	],
	"system_runtime_control": [{"tool": "runtime_control", "actions": ["status", "enable", "disable"]}],
	"system_runtime_step": [
		{"tool": "runtime_step", "actions": ["step", "capture", "input"]},
		{"tool": "runtime_capture", "actions": []},
		{"tool": "runtime_input", "actions": []}
	],
	"system_dap_debugger": [
		{"tool": "dap_debugger", "actions": ["status", "set_breakpoint", "remove_breakpoint", "list_breakpoints", "pause", "continue", "step_over", "stack_trace", "output"]}
	],
	"system_project_configure": [
		{"tool": "project_info",     "actions": ["get_settings"]},
		{"tool": "project_settings", "actions": ["set"]},
		{"tool": "project_autoload", "actions": ["list", "add", "remove"]},
		{"tool": "project_input",    "actions": ["list_actions"]}
	],
	"system_project_files": [
		{"tool": "filesystem_directory", "actions": ["get_files", "create", "delete"]},
		{"tool": "filesystem_file_read", "actions": ["read"]},
		{"tool": "filesystem_file_write", "actions": ["write"]},
		{"tool": "filesystem_file_manage", "actions": ["delete", "copy", "move"]},
		{"tool": "editor_filesystem", "actions": ["select_file", "get_selected", "get_current_path", "scan", "reimport"]}
	],
	"system_userdata_maintenance": [],
	"system_project_run":  [
		{"tool": "scene_run", "actions": ["play_main", "play_custom", "stop"]},
		{"tool": "debug_runtime_bridge", "actions": ["get_recent", "get_recent_filtered"]}
	],
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
		{"tool": "node_lifecycle",   "actions": ["create", "delete", "attach_script", "rename"]},
		{"tool": "node_property",    "actions": ["get", "set"]},
		{"tool": "node_hierarchy",   "actions": ["reparent"]}
	],
	"system_scene_tree": [
		{"tool": "scene_hierarchy",  "actions": ["get_tree", "get_selected", "select"]},
		{"tool": "node_lifecycle",   "actions": ["create", "delete", "attach_script", "rename"]},
		{"tool": "node_property",    "actions": ["get", "set"]},
		{"tool": "node_hierarchy",   "actions": ["reparent", "reorder"]},
		{"tool": "node_transform",   "actions": ["set_position"]}
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
	"system_project_symbol_search": [
		{"tool": "filesystem_directory", "actions": ["get_files"]},
		{"tool": "script_inspect",       "actions": ["path"]},
		{"tool": "resource_query",       "actions": ["get_dependencies"]}
	],
	"system_scene_dependency_graph": [
		{"tool": "filesystem_directory", "actions": ["get_files"]},
		{"tool": "resource_query",       "actions": ["get_dependencies"]}
	]
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
