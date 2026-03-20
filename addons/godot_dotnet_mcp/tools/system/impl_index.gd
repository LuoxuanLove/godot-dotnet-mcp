@tool
extends RefCounted

## System implementation: project_index_build, project_symbol_search, scene_dependency_graph
## Holds _project_index shared state -- legitimate memory sharing, not system->system calls.

var bridge
var _project_index: Dictionary = {}

const HANDLED_TOOLS := ["project_index_build", "project_symbol_search", "scene_dependency_graph"]


func handles(tool_name: String) -> bool:
	return tool_name in HANDLED_TOOLS


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "project_index_build",
			"description": "PROJECT INDEX BUILD: Build an in-memory symbol index over all scripts, scenes, and resources. MUST be called before project_symbol_search or scene_dependency_graph. Index is session-scoped — call again after plugin reload. Returns: script_count, scene_count, resource_count, symbol_count. Optional: include_resources=false to skip .tres/.res files.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"include_resources": {
						"type": "boolean",
						"description": "Whether to include .tres/.res resources in the index (default: true)"
					}
				}
			}
		},
		{
			"name": "project_symbol_search",
			"description": "PROJECT SYMBOL SEARCH: Find scripts, scenes, or classes by name in the project index. REQUIRES project_index_build first. Matches class names, script filenames, scene filenames (exact and partial). Returns: matches[]{symbol, kind, path, class_name, base_type}, exact_match_count, partial_match_count. Requires: symbol (name to search).",
			"inputSchema": {
				"type": "object",
				"properties": {
					"symbol": {
						"type": "string",
						"description": "Symbol name to search for (class name, script basename, or scene name)"
					}
				},
				"required": ["symbol"]
			}
		},
		{
			"name": "scene_dependency_graph",
			"description": "SCENE DEPENDENCY GRAPH: Scene-to-scene dependency map from ExtResource references. REQUIRES project_index_build first. Omit root_scene for full project map; set root_scene (.tscn) to traverse from a specific scene. Optional: max_depth (default 4). Returns: dependencies{scene_path → [dep_paths]}, count.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"root_scene": {
						"type": "string",
						"description": "Optional root scene path. If omitted, returns the full dependency map."
					},
					"max_depth": {
						"type": "integer",
						"description": "Optional max traversal depth when a root_scene is provided (default: 4)"
					}
				}
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	MCPDebugBuffer.record("debug", "system", "tool: %s" % tool_name)
	match tool_name:
		"project_index_build":    return _execute_project_index_build(args)
		"project_symbol_search":  return _execute_project_symbol_search(args)
		"scene_dependency_graph": return _execute_scene_dependency_graph(args)
		_: return bridge.error("Unknown tool: %s" % tool_name)


# --- private helpers ---

func _index_symbol(symbols: Dictionary, symbol: String, kind: String, path: String, extra: Dictionary = {}) -> void:
	var key := symbol.strip_edges()
	if key.is_empty():
		return
	if not symbols.has(key):
		symbols[key] = []
	var entries: Array = symbols[key]
	var entry := {"symbol": key, "kind": kind, "path": path}
	for k in extra.keys():
		entry[k] = extra[k]
	entries.append(entry)
	symbols[key] = entries


func _build_project_index(include_resources: bool) -> Dictionary:
	var gd_scripts: Array = bridge.collect_files("*.gd")
	var cs_scripts: Array = bridge.collect_files("*.cs")
	var scene_paths: Array = bridge.collect_files("*.tscn")
	var resource_paths: Array = []
	if include_resources:
		resource_paths.append_array(bridge.collect_files("*.tres"))
		resource_paths.append_array(bridge.collect_files("*.res"))
		resource_paths.sort()

	var scripts := []
	var symbols := {}
	var scene_dependencies := {}
	var dependency_records := []

	for script_path in gd_scripts + cs_scripts:
		var inspect_result: Dictionary = bridge.call_atomic("script_inspect", {"path": script_path})
		if not bool(inspect_result.get("success", false)):
			continue
		var metadata: Dictionary = bridge.extract_data(inspect_result)
		var entry := {
			"path": script_path,
			"language": str(metadata.get("language", "unknown")),
			"class_name": str(metadata.get("class_name", "")),
			"base_type": str(metadata.get("base_type", "")),
			"namespace": str(metadata.get("namespace", "")),
			"method_count": int(metadata.get("method_count", 0)),
			"export_count": int(metadata.get("export_count", 0))
		}
		scripts.append(entry)
		_index_symbol(symbols, str(script_path).get_file().get_basename(), "script", script_path, entry)
		var class_name_val := str(entry.get("class_name", ""))
		if not class_name_val.is_empty():
			_index_symbol(symbols, class_name_val, "class", script_path, entry)

	for scene_path in scene_paths:
		var scene_entry := {"path": scene_path, "name": str(scene_path).get_file().get_basename()}
		_index_symbol(symbols, str(scene_entry.get("name", "")), "scene", scene_path, scene_entry)
		var dep_result: Dictionary = bridge.call_atomic("resource_query", {
			"action": "get_dependencies", "path": scene_path
		})
		var normalized_deps: Array = []
		for raw_dep in bridge.extract_array(dep_result, "dependencies"):
			var dep_path: String = bridge.normalize_dependency_path(str(raw_dep))
			if dep_path.is_empty():
				continue
			normalized_deps.append(dep_path)
		scene_dependencies[scene_path] = normalized_deps
		dependency_records.append({
			"scene": scene_path,
			"count": normalized_deps.size(),
			"dependencies": normalized_deps
		})

	for resource_path in resource_paths:
		var resource_entry := {"path": resource_path, "name": str(resource_path).get_file().get_basename()}
		_index_symbol(symbols, str(resource_entry.get("name", "")), "resource", resource_path, resource_entry)

	_project_index = {
		"built_at_unix": int(Time.get_unix_time_from_system()),
		"include_resources": include_resources,
		"scripts": scripts,
		"script_paths": gd_scripts + cs_scripts,
		"scenes": scene_paths,
		"resources": resource_paths,
		"symbols": symbols,
		"scene_dependencies": scene_dependencies,
		"dependency_records": dependency_records
	}
	return _project_index


func _ensure_project_index(include_resources: bool = true) -> Dictionary:
	if _project_index.is_empty():
		return _build_project_index(include_resources)
	if include_resources and not bool(_project_index.get("include_resources", true)):
		return _build_project_index(true)
	return _project_index


func _traverse_scene_deps(current: String, max_depth: int, dep_map: Dictionary, visited: Dictionary, result: Dictionary, depth: int) -> void:
	if depth > max_depth or visited.has(current):
		return
	visited[current] = true
	var children = dep_map.get(current, [])
	result[current] = children
	if not (children is Array):
		return
	for child in children:
		_traverse_scene_deps(str(child), max_depth, dep_map, visited, result, depth + 1)


# --- tool implementations ---

func _execute_project_index_build(args: Dictionary) -> Dictionary:
	var include_resources := bool(args.get("include_resources", true))
	MCPDebugBuffer.record("debug", "system",
		"index_build: include_resources=%s" % str(include_resources))
	var index := _build_project_index(include_resources)
	MCPDebugBuffer.record("debug", "system",
		"index_build: %d scripts, %d scenes, %d symbols" % [
			int((index.get("script_paths", []) as Array).size()),
			int((index.get("scenes", []) as Array).size()),
			int((index.get("symbols", {}) as Dictionary).size())
		])
	return bridge.success({
		"built_at_unix": int(index.get("built_at_unix", 0)),
		"include_resources": include_resources,
		"script_count": int((index.get("script_paths", []) as Array).size()),
		"scene_count": int((index.get("scenes", []) as Array).size()),
		"resource_count": int((index.get("resources", []) as Array).size()),
		"symbol_count": int((index.get("symbols", {}) as Dictionary).size())
	})


func _execute_project_symbol_search(args: Dictionary) -> Dictionary:
	var symbol := str(args.get("symbol", "")).strip_edges()
	if symbol.is_empty():
		return bridge.error("symbol is required")

	var index := _ensure_project_index(true)
	var exact_matches: Array = []
	var partial_matches: Array = []
	var lowered := symbol.to_lower()

	for key in (index.get("symbols", {}) as Dictionary).keys():
		var entries = index["symbols"][key]
		if not (entries is Array):
			continue
		if str(key) == symbol:
			for entry in entries:
				if entry is Dictionary:
					exact_matches.append((entry as Dictionary).duplicate(true))
		elif str(key).to_lower().find(lowered) != -1:
			for entry in entries:
				if entry is Dictionary:
					partial_matches.append((entry as Dictionary).duplicate(true))

	var matches: Array = []
	matches.append_array(exact_matches)
	matches.append_array(partial_matches)

	MCPDebugBuffer.record("debug", "system",
		"symbol_search: '%s' → %d exact, %d partial" % [symbol, exact_matches.size(), partial_matches.size()])
	return bridge.success({
		"symbol": symbol,
		"exact_match_count": exact_matches.size(),
		"partial_match_count": partial_matches.size(),
		"match_count": matches.size(),
		"matches": matches
	})


func _execute_scene_dependency_graph(args: Dictionary) -> Dictionary:
	var index := _ensure_project_index(true)
	var root_scene := str(args.get("root_scene", "")).strip_edges()
	var max_depth := max(int(args.get("max_depth", 4)), 0)
	var dep_map: Dictionary = index.get("scene_dependencies", {})

	if root_scene.is_empty():
		return bridge.success({
			"root": "", "max_depth": max_depth,
			"count": dep_map.size(), "dependencies": dep_map
		})

	var result: Dictionary = {}
	var visited: Dictionary = {}
	_traverse_scene_deps(root_scene, max_depth, dep_map, visited, result, 0)
	return bridge.success({"root": root_scene, "max_depth": max_depth,
		"count": result.size(), "dependencies": result})
