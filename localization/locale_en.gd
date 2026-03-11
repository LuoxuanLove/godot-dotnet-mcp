@tool
extends RefCounted

## English translations for MCP Server

const TRANSLATIONS: Dictionary = {
	# Tab names
	"tab_server": "Server",
	"tab_tools": "Tools",
	"tab_config": "Config",

	# Header
	"title": "Godot MCP Server",
	"dialog_title": "Godot MCP",
	"status_running": "Running",
	"status_stopped": "Stopped",

	# Server tab
	"server_status": "Server Status",
	"server_state_label": "State:",
	"endpoint": "Endpoint:",
	"connections": "Connections:",
	"active_connections": "Active Connections:",
	"total_requests": "Total Requests:",
	"total_connections_short": "connections",
	"last_request": "Last Request:",
	"last_request_none": "No requests yet",
	"settings": "Settings",
	"port": "Port:",
	"auto_start": "Auto Start",
	"debug_log": "Debug Log",
	"btn_start": "Start",
	"btn_restart": "Restart",
	"btn_stop": "Stop",
	"btn_reload_plugin": "Reload Plugin",

	# About section
	"about": "About",
	"author": "Author:",
	"wechat": "WeChat:",

	# Tools tab
	"tools_enabled": "Tools: %d/%d enabled",
	"tool_profile": "Profile:",
	"tool_profile_slim": "Slim",
	"tool_profile_default": "Default",
	"tool_profile_full": "Full",
	"tool_profile_slim_desc": "Enable the core inspection and editing tools used most often in Godot.NET projects.",
	"tool_profile_default_desc": "Recommended everyday preset. Keeps core, gameplay, animation and UI tools available.",
	"tool_profile_full_desc": "Expose every registered tool category.",
	"tool_profile_custom_desc": "Custom preset: %s",
	"tool_profile_modified_desc": "Current selection has been modified. Use Add to save it as a custom preset.",
	"tool_profile_save_title": "Save Custom Tool Preset",
	"tool_profile_save_desc": "Save the current tool selection as a reusable custom preset file.",
	"tool_profile_name_placeholder": "Preset name",
	"tool_profile_name_required": "Preset name is required",
	"tool_profile_saved": "Preset saved: %s",
	"tool_profile_save_failed": "Failed to save preset",
	"btn_expand_all": "Expand All",
	"btn_collapse_all": "Collapse All",
	"btn_select_all": "Select All",
	"btn_deselect_all": "Deselect All",
	"btn_add_profile": "Add",
	"btn_save_profile": "Save",
	"tools_server_unavailable": "Server unavailable. Check editor output for script load errors.",
	"tools_load_errors": "Skipped %d tool categories due to script load errors. See editor output for details.",

	# Tool categories - Core
	"cat_scene": "Scene",
	"cat_node": "Node",
	"cat_script": "Script",
	"cat_resource": "Resource",
	"cat_filesystem": "Filesystem",
	"cat_project": "Project",
	"cat_editor": "Editor",
	"cat_plugin": "Plugin Runtime",
	"cat_debug": "Debug",
	"cat_animation": "Animation",

	# Tool categories - Visual
	"cat_material": "Material",
	"cat_shader": "Shader",
	"cat_lighting": "Lighting",
	"cat_particle": "Particle",

	# Tool categories - 2D
	"cat_tilemap": "TileMap",
	"cat_geometry": "Geometry",

	# Tool categories - Gameplay
	"cat_physics": "Physics",
	"cat_navigation": "Navigation",
	"cat_audio": "Audio",

	# Tool categories - Utilities
	"cat_ui": "UI",
	"cat_signal": "Signal",
	"cat_group": "Group",
	"domain_core": "Core",
	"domain_visual": "Visual",
	"domain_gameplay": "Gameplay",
	"domain_interface": "Interface",
	"domain_other": "Other",

	# Config tab - IDE section
	"ide_config": "IDE One-Click Configuration",
	"ide_config_desc": "Click to auto-write config file, restart client to take effect",
	"btn_one_click": "One-Click Config",
	"btn_copy": "Copy",

	# Config tab - CLI section
	"cli_config": "CLI Command Line Configuration",
	"cli_config_desc": "Copy command and run in terminal",
	"config_scope": "Configuration Scope:",
	"scope_user": "User (Global)",
	"scope_project": "Project (Current Only)",
	"btn_copy_cmd": "Copy Command",

	# Messages
	"msg_config_success": "%s configured successfully!",
	"msg_config_failed": "Configuration failed",
	"msg_copied": "%s copied to clipboard",
	"msg_parse_error": "Configuration parse error",
	"msg_dir_error": "Cannot create directory: ",
	"msg_write_error": "Cannot write config file",

	# Language
	"language": "Language:",

	# ==================== Tool Descriptions ====================
	# Scene tools
	"tool_scene_bindings_name": "Bindings",
	"tool_scene_audit_name": "Audit",
	"tool_scene_management_name": "Management",
	"tool_scene_hierarchy_name": "Hierarchy",
	"tool_scene_run_name": "Run",
	"tool_scene_management_desc": "Open, save, create and manage scenes",
	"tool_scene_hierarchy_desc": "Get scene tree structure and node selection",
	"tool_scene_run_desc": "Run and test scenes in the editor",
	"tool_scene_bindings_desc": "Inspect exported script bindings used by a scene",
	"tool_scene_audit_desc": "Report scene issues derived from exported bindings",

	# Node tools
	"tool_node_query_name": "Query",
	"tool_node_lifecycle_name": "Lifecycle",
	"tool_node_transform_name": "Transform",
	"tool_node_property_name": "Property",
	"tool_node_hierarchy_name": "Hierarchy",
	"tool_node_signal_name": "Signal",
	"tool_node_group_name": "Group",
	"tool_node_process_name": "Process",
	"tool_node_metadata_name": "Metadata",
	"tool_node_call_name": "Call",
	"tool_node_visibility_name": "Visibility",
	"tool_node_physics_name": "Physics",
	"tool_node_query_desc": "Find and inspect nodes by name, type or pattern",
	"tool_node_lifecycle_desc": "Create, delete, duplicate and instantiate nodes",
	"tool_node_transform_desc": "Modify position, rotation and scale",
	"tool_node_property_desc": "Get and set any node property",
	"tool_node_hierarchy_desc": "Manage parent-child relationships and order",
	"tool_node_signal_desc": "Connect, disconnect and emit signals",
	"tool_node_group_desc": "Add, remove and query node groups",
	"tool_node_process_desc": "Control node processing modes",
	"tool_node_metadata_desc": "Get and set node metadata",
	"tool_node_call_desc": "Call methods on nodes dynamically",
	"tool_node_visibility_desc": "Control node visibility and layers",
	"tool_node_physics_desc": "Configure physics properties",

	# Resource tools
	"tool_resource_query_name": "Query",
	"tool_resource_manage_name": "Manage",
	"tool_resource_texture_name": "Texture",
	"tool_resource_query_desc": "Find and inspect resources",
	"tool_resource_manage_desc": "Load, save and duplicate resources",
	"tool_resource_texture_desc": "Manage texture resources",

	# Project tools
	"tool_project_info_name": "Info",
	"tool_project_settings_name": "Settings",
	"tool_project_input_name": "Input",
	"tool_project_autoload_name": "Autoload",
	"tool_project_info_desc": "Get project information and paths",
	"tool_project_settings_desc": "Read and modify project settings",
	"tool_project_input_desc": "Manage input action mappings",
	"tool_project_autoload_desc": "Manage autoload singletons",

	# Script tools
	"tool_script_read_name": "Read",
	"tool_script_open_name": "Open",
	"tool_script_inspect_name": "Inspect",
	"tool_script_symbols_name": "Symbols",
	"tool_script_exports_name": "Exports",
	"tool_script_edit_gd_name": "Edit GDScript",
	"tool_script_manage_desc": "Create, read and modify scripts",
	"tool_script_attach_desc": "Attach or detach scripts from nodes",
	"tool_script_edit_desc": "Add functions, variables and signals",
	"tool_script_open_desc": "Open scripts in the editor",
	"tool_script_read_desc": "Read script files as plain text",
	"tool_script_inspect_desc": "Parse script metadata for GDScript and C#",
	"tool_script_symbols_desc": "List parsed classes, methods, exports and enums",
	"tool_script_exports_desc": "List exported members declared by a script",
	"tool_script_edit_gd_desc": "Edit GDScript files with structured helpers",

	# Editor tools
	"tool_editor_status_name": "Status",
	"tool_editor_settings_name": "Settings",
	"tool_editor_undo_redo_name": "Undo Redo",
	"tool_editor_notification_name": "Notification",
	"tool_editor_inspector_name": "Inspector",
	"tool_editor_filesystem_name": "Filesystem",
	"tool_editor_plugin_name": "Plugin",
	"tool_editor_status_desc": "Get editor status and scene info",
	"tool_editor_settings_desc": "Read and modify editor settings",
	"tool_editor_undo_redo_desc": "Manage undo/redo operations",
	"tool_editor_notification_desc": "Show editor notifications and dialogs",
	"tool_editor_inspector_desc": "Control the inspector panel",
	"tool_editor_filesystem_desc": "Interact with the filesystem dock",
	"tool_editor_plugin_desc": "Query and manage editor plugins",
	"tool_plugin_runtime_name": "Runtime",
	"tool_plugin_runtime_desc": "Inspect loader state, reload domains and read runtime summaries",

	# Debug tools
	"tool_debug_log_name": "Log",
	"tool_debug_performance_name": "Performance",
	"tool_debug_profiler_name": "Profiler",
	"tool_debug_class_db_name": "Class DB",
	"tool_debug_log_desc": "Print debug messages and errors",
	"tool_debug_performance_desc": "Monitor performance metrics",
	"tool_debug_profiler_desc": "Profile code execution",
	"tool_debug_class_db_desc": "Query Godot's class database",

	# Filesystem tools
	"tool_filesystem_directory_name": "Directory",
	"tool_filesystem_file_name": "File",
	"tool_filesystem_json_name": "JSON",
	"tool_filesystem_search_name": "Search",
	"tool_filesystem_directory_desc": "Create, delete and list directories",
	"tool_filesystem_file_desc": "Read, write and manage files",
	"tool_filesystem_json_desc": "Read and write JSON files",
	"tool_filesystem_search_desc": "Search files by pattern",

	# Animation tools
	"tool_animation_player_name": "Player",
	"tool_animation_animation_name": "Animation",
	"tool_animation_track_name": "Track",
	"tool_animation_tween_name": "Tween",
	"tool_animation_animation_tree_name": "Animation Tree",
	"tool_animation_state_machine_name": "State Machine",
	"tool_animation_blend_space_name": "Blend Space",
	"tool_animation_blend_tree_name": "Blend Tree",
	"tool_animation_player_desc": "Control AnimationPlayer nodes",
	"tool_animation_animation_desc": "Create and modify animations",
	"tool_animation_track_desc": "Add and edit animation tracks",
	"tool_animation_tween_desc": "Create and control tweens",
	"tool_animation_animation_tree_desc": "Setup and configure animation trees",
	"tool_animation_state_machine_desc": "Manage animation state machines",
	"tool_animation_blend_space_desc": "Configure blend spaces",
	"tool_animation_blend_tree_desc": "Setup blend tree nodes",

	# Material tools
	"tool_material_material_name": "Material",
	"tool_material_mesh_name": "Mesh",
	"tool_material_material_desc": "Create and modify materials",
	"tool_material_mesh_desc": "Manage mesh resources",

	# Shader tools
	"tool_shader_shader_name": "Shader",
	"tool_shader_shader_material_name": "Shader Material",
	"tool_shader_shader_desc": "Create and edit shaders",
	"tool_shader_shader_material_desc": "Apply shaders to materials",

	# Lighting tools
	"tool_lighting_light_name": "Light",
	"tool_lighting_environment_name": "Environment",
	"tool_lighting_sky_name": "Sky",
	"tool_lighting_light_desc": "Create and configure lights",
	"tool_lighting_environment_desc": "Setup world environment",
	"tool_lighting_sky_desc": "Configure sky and atmosphere",

	# Particle tools
	"tool_particle_particles_name": "Particles",
	"tool_particle_particle_material_name": "Particle Material",
	"tool_particle_particles_desc": "Create and configure particle systems",
	"tool_particle_particle_material_desc": "Setup particle materials",

	# Tilemap tools
	"tool_tilemap_tileset_name": "Tileset",
	"tool_tilemap_tilemap_name": "TileMap",
	"tool_tilemap_tileset_desc": "Create and edit tilesets",
	"tool_tilemap_tilemap_desc": "Edit tilemap layers and cells",

	# Geometry tools
	"tool_geometry_csg_name": "CSG",
	"tool_geometry_gridmap_name": "GridMap",
	"tool_geometry_multimesh_name": "MultiMesh",
	"tool_geometry_csg_desc": "Create CSG constructive solid geometry",
	"tool_geometry_gridmap_desc": "Edit 3D grid-based maps",
	"tool_geometry_multimesh_desc": "Setup multi-mesh instances",

	# Physics tools
	"tool_physics_physics_body_name": "Physics Body",
	"tool_physics_collision_shape_name": "Collision Shape",
	"tool_physics_physics_joint_name": "Physics Joint",
	"tool_physics_physics_query_name": "Physics Query",
	"tool_physics_physics_body_desc": "Create and configure physics bodies",
	"tool_physics_collision_shape_desc": "Add and modify collision shapes",
	"tool_physics_physics_joint_desc": "Create physics joints and constraints",
	"tool_physics_physics_query_desc": "Perform physics queries and raycasts",

	# Navigation tools
	"tool_navigation_navigation_name": "Navigation",
	"tool_navigation_navigation_desc": "Setup navigation meshes and agents",

	# Audio tools
	"tool_audio_bus_name": "Bus",
	"tool_audio_player_name": "Player",
	"tool_audio_bus_desc": "Manage audio buses and effects",
	"tool_audio_player_desc": "Control audio playback",

	# UI tools
	"tool_ui_theme_name": "Theme",
	"tool_ui_control_name": "Control",
	"tool_ui_theme_desc": "Create and modify UI themes",
	"tool_ui_control_desc": "Configure control nodes",

	# Signal tools
	"tool_signal_signal_name": "Signal",
	"tool_signal_signal_desc": "Manage signal connections globally",

	# Group tools
	"tool_group_group_name": "Group",
	"tool_group_group_desc": "Query and manage node groups globally",
}


static func get_translations() -> Dictionary:
	return TRANSLATIONS
