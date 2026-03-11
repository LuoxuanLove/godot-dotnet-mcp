@tool
extends RefCounted
class_name MCPToolRegistry

const CUSTOM_TOOLS_DIR := "res://addons/godot_dotnet_mcp/custom_tools"

const BUILTIN_ENTRIES: Array[Dictionary] = [
	{"category": "scene", "path": "res://addons/godot_dotnet_mcp/tools/scene/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
	{"category": "node", "path": "res://addons/godot_dotnet_mcp/tools/node/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
	{"category": "resource", "path": "res://addons/godot_dotnet_mcp/tools/resource/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
	{"category": "project", "path": "res://addons/godot_dotnet_mcp/tools/project/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
	{"category": "script", "path": "res://addons/godot_dotnet_mcp/tools/script/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
	{"category": "editor", "path": "res://addons/godot_dotnet_mcp/tools/editor/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
	{"category": "plugin", "path": "res://addons/godot_dotnet_mcp/tools/plugin/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": false},
	{"category": "debug", "path": "res://addons/godot_dotnet_mcp/tools/debug/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
	{"category": "filesystem", "path": "res://addons/godot_dotnet_mcp/tools/filesystem/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
	{"category": "group", "path": "res://addons/godot_dotnet_mcp/tools/group/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
	{"category": "signal", "path": "res://addons/godot_dotnet_mcp/tools/signal/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
	{"category": "animation", "path": "res://addons/godot_dotnet_mcp/tools/animation/executor.gd", "domain_key": "core", "source": "builtin", "hot_reloadable": true},
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


func collect_entries() -> Dictionary:
	var entries: Array[Dictionary] = get_builtin_entries()
	var errors: Array[Dictionary] = []
	var custom_result = _collect_custom_entries()
	entries.append_array(custom_result.get("entries", []))
	errors.append_array(custom_result.get("errors", []))
	return {
		"entries": entries,
		"errors": errors
	}


func get_builtin_entries() -> Array[Dictionary]:
	return BUILTIN_ENTRIES.duplicate(true)


func get_builtin_categories() -> Array[String]:
	var categories: Array[String] = []
	for entry in BUILTIN_ENTRIES:
		categories.append(str(entry.get("category", "")))
	return categories


func _collect_custom_entries() -> Dictionary:
	var entries: Array[Dictionary] = []
	var errors: Array[Dictionary] = []
	var global_path = ProjectSettings.globalize_path(CUSTOM_TOOLS_DIR)
	if not DirAccess.dir_exists_absolute(global_path):
		return {"entries": entries, "errors": errors}

	var script_paths: Array[String] = []
	_scan_custom_tool_dir(CUSTOM_TOOLS_DIR, script_paths)
	script_paths.sort()

	for script_path in script_paths:
		var result = _build_custom_entry(script_path)
		if result.get("success", false):
			entries.append(result.get("entry", {}).duplicate(true))
		else:
			errors.append({
				"category": str(result.get("category", "")),
				"path": script_path,
				"message": str(result.get("error", "Failed to register custom tool")),
				"source": "custom"
			})

	return {"entries": entries, "errors": errors}


func _scan_custom_tool_dir(dir_path: String, script_paths: Array[String]) -> void:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var name = dir.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue
		var child_path = "%s/%s" % [dir_path, name]
		if dir.current_is_dir():
			_scan_custom_tool_dir(child_path, script_paths)
		elif name.ends_with(".gd"):
			script_paths.append(child_path)
	dir.list_dir_end()


func _build_custom_entry(script_path: String) -> Dictionary:
	var script_resource = _load_custom_script(script_path)
	if script_resource == null:
		return {"success": false, "error": "Failed to load custom tool script"}
	if script_resource is Script and not script_resource.can_instantiate():
		return {"success": false, "error": "Custom tool script could not be instantiated"}
	if not script_resource.has_method("new"):
		return {"success": false, "error": "Loaded custom tool resource is not instantiable"}

	var executor = script_resource.new()
	if executor == null:
		return {"success": false, "error": "Custom tool executor instance creation returned null"}
	if not executor.has_method("get_tools") or not executor.has_method("execute"):
		return {"success": false, "error": "Custom tool executor does not expose get_tools/execute"}

	var registration: Dictionary = {}
	if executor.has_method("get_registration"):
		registration = executor.get_registration()
	elif executor.has_method("get_custom_tool_registration"):
		registration = executor.get_custom_tool_registration()

	var default_category = _sanitize_category_name(script_path.get_file().get_basename())
	var category = str(registration.get("category", default_category))
	if category.is_empty():
		return {"success": false, "error": "Custom tool category is empty"}

	return {
		"success": true,
		"entry": {
			"category": category,
			"path": script_path,
			"domain_key": str(registration.get("domain_key", "other")),
			"source": "custom",
			"hot_reloadable": bool(registration.get("hot_reloadable", true)),
			"display_name": str(registration.get("display_name", category))
		}
	}


func _load_custom_script(script_path: String) -> Resource:
	var script_resource = ResourceLoader.load(script_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if script_resource is Script:
		script_resource.reload()
	return script_resource


func _sanitize_category_name(value: String) -> String:
	var sanitized = value.strip_edges().to_lower()
	for ch in [" ", "-", ".", "/", "\\"]:
		sanitized = sanitized.replace(ch, "_")
	while sanitized.contains("__"):
		sanitized = sanitized.replace("__", "_")
	return sanitized.strip_edges()
