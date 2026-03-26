@tool
extends RefCounted

## System implementation: project_symbol_search, scene_dependency_graph
## Holds _index_cache shared state -- legitimate memory sharing, not system->system calls.

var bridge
var _index_cache: Dictionary = {}

const HANDLED_TOOLS := ["project_symbol_search", "scene_dependency_graph"]
const INDEX_SIGNATURE_VERSION := 1
const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")


func handles(tool_name: String) -> bool:
	return tool_name in HANDLED_TOOLS


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "project_symbol_search",
			"description": "PROJECT SYMBOL SEARCH: Find scripts, scenes, or classes by name using the internal project index. The index is built lazily on first use, auto-refreshes when tracked project files change, and can also be refreshed on demand. Matches class names, script filenames, scene filenames (exact and partial). Returns: matches[]{symbol, kind, path, class_name, base_type}, exact_match_count, partial_match_count. Requires: symbol (name to search).",
			"inputSchema": {
				"type": "object",
				"properties": {
					"symbol": {
						"type": "string",
						"description": "Symbol name to search for (class name, script basename, or scene name)"
					},
					"refresh_index": {
						"type": "boolean",
						"description": "Force rebuilding the internal project index before searching, even when the cached index still looks fresh (default: false)"
					}
				},
				"required": ["symbol"]
			}
		},
		{
			"name": "scene_dependency_graph",
			"description": "SCENE DEPENDENCY GRAPH: Scene-to-scene dependency map from ExtResource references. Uses the internal project index, which is built lazily on first use, auto-refreshes when tracked project files change, and can also be refreshed on demand. Omit root_scene for full project map; set root_scene (.tscn) to traverse from a specific scene. Optional: max_depth (default 4). Returns: dependencies{scene_path -> [dep_paths]}, count.",
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
					},
					"refresh_index": {
						"type": "boolean",
						"description": "Force rebuilding the internal project index before generating the graph, even when the cached index still looks fresh (default: false)"
					}
				}
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	MCPDebugBuffer.record("debug", "system", "tool: %s" % tool_name)
	match tool_name:
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


func _collect_project_sources(include_resources: bool) -> Dictionary:
	var gd_scripts: Array = bridge.collect_files("*.gd")
	var cs_scripts: Array = bridge.collect_files("*.cs")
	var scene_paths: Array = bridge.collect_files("*.tscn")
	var resource_paths: Array = []
	gd_scripts.sort()
	cs_scripts.sort()
	scene_paths.sort()
	if include_resources:
		resource_paths.append_array(bridge.collect_files("*.tres"))
		resource_paths.append_array(bridge.collect_files("*.res"))
		resource_paths.sort()

	var signature_components: Array = ["version:%d" % INDEX_SIGNATURE_VERSION]
	var latest_modified_unix := 0
	latest_modified_unix = _append_source_signature(signature_components, "res://project.godot", latest_modified_unix)
	for path in gd_scripts:
		latest_modified_unix = _append_source_signature(signature_components, str(path), latest_modified_unix)
	for path in cs_scripts:
		latest_modified_unix = _append_source_signature(signature_components, str(path), latest_modified_unix)
	for path in scene_paths:
		latest_modified_unix = _append_source_signature(signature_components, str(path), latest_modified_unix)
	for path in resource_paths:
		latest_modified_unix = _append_source_signature(signature_components, str(path), latest_modified_unix)

	return {
		"gd_scripts": gd_scripts,
		"cs_scripts": cs_scripts,
		"scene_paths": scene_paths,
		"resource_paths": resource_paths,
		"include_resources": include_resources,
		"source_file_count": gd_scripts.size() + cs_scripts.size() + scene_paths.size() + resource_paths.size() + 1,
		"latest_modified_unix": latest_modified_unix,
		"signature": hash(signature_components)
	}


func _append_source_signature(signature_components: Array, path: String, latest_modified_unix: int) -> int:
	var modified_unix := _get_source_modified_unix(path)
	signature_components.append("%s|%d" % [path, modified_unix])
	return maxi(latest_modified_unix, modified_unix)


func _get_source_modified_unix(path: String) -> int:
	var resolved_path := path
	if path.begins_with("res://") or path.begins_with("user://"):
		resolved_path = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(resolved_path):
		return 0
	return int(FileAccess.get_modified_time(resolved_path))


func _build_project_index(include_resources: bool, sources: Dictionary = {}) -> Dictionary:
	var effective_sources: Dictionary = sources
	if effective_sources.is_empty():
		effective_sources = _collect_project_sources(include_resources)

	var gd_scripts: Array = effective_sources.get("gd_scripts", [])
	var cs_scripts: Array = effective_sources.get("cs_scripts", [])
	var scene_paths: Array = effective_sources.get("scene_paths", [])
	var resource_paths: Array = effective_sources.get("resource_paths", [])

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

	_index_cache = {
		"built_at_unix": int(Time.get_unix_time_from_system()),
		"include_resources": bool(effective_sources.get("include_resources", include_resources)),
		"source_signature_version": INDEX_SIGNATURE_VERSION,
		"source_signature": int(effective_sources.get("signature", 0)),
		"source_file_count": int(effective_sources.get("source_file_count", 0)),
		"source_latest_modified_unix": int(effective_sources.get("latest_modified_unix", 0)),
		"scripts": scripts,
		"script_paths": gd_scripts + cs_scripts,
		"scenes": scene_paths,
		"resources": resource_paths,
		"symbols": symbols,
		"scene_dependencies": scene_dependencies,
		"dependency_records": dependency_records
	}
	return _index_cache


func _ensure_index_cache(include_resources: bool = true, force_rebuild: bool = false) -> Dictionary:
	var state := "reused"
	var sources := _collect_project_sources(include_resources)
	if _index_cache.is_empty():
		_index_cache = _build_project_index(include_resources, sources)
		state = "built"
	elif force_rebuild:
		_index_cache = _build_project_index(include_resources, sources)
		state = "refreshed"
	elif include_resources and not bool(_index_cache.get("include_resources", true)):
		_index_cache = _build_project_index(true, sources)
		state = "refreshed"
	elif _is_index_cache_stale(sources):
		_index_cache = _build_project_index(include_resources, sources)
		state = "stale_refreshed"
	return {
		"state": state,
		"index": _index_cache
	}


func _is_index_cache_stale(sources: Dictionary) -> bool:
	if int(_index_cache.get("source_signature_version", 0)) != INDEX_SIGNATURE_VERSION:
		return true
	if bool(_index_cache.get("include_resources", true)) != bool(sources.get("include_resources", true)):
		return true
	return int(_index_cache.get("source_signature", 0)) != int(sources.get("signature", 0))


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


func _execute_project_symbol_search(args: Dictionary) -> Dictionary:
	var symbol := str(args.get("symbol", "")).strip_edges()
	if symbol.is_empty():
		return bridge.error("symbol is required")

	var refresh_index := bool(args.get("refresh_index", false))
	var index_result := _ensure_index_cache(true, refresh_index)
	var index: Dictionary = index_result.get("index", {})
	var index_state := str(index_result.get("state", "reused"))
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
		"index_state": index_state,
		"index_built_at_unix": int(index.get("built_at_unix", 0)),
		"exact_match_count": exact_matches.size(),
		"partial_match_count": partial_matches.size(),
		"match_count": matches.size(),
		"matches": matches
	})


func _execute_scene_dependency_graph(args: Dictionary) -> Dictionary:
	var refresh_index := bool(args.get("refresh_index", false))
	var index_result := _ensure_index_cache(true, refresh_index)
	var index: Dictionary = index_result.get("index", {})
	var index_state := str(index_result.get("state", "reused"))
	var root_scene := str(args.get("root_scene", "")).strip_edges()
	var max_depth := max(int(args.get("max_depth", 4)), 0)
	var dep_map: Dictionary = index.get("scene_dependencies", {})

	if root_scene.is_empty():
		return bridge.success({
			"root": "", "max_depth": max_depth,
			"index_state": index_state,
			"index_built_at_unix": int(index.get("built_at_unix", 0)),
			"count": dep_map.size(), "dependencies": dep_map
		})

	var result: Dictionary = {}
	var visited: Dictionary = {}
	_traverse_scene_deps(root_scene, max_depth, dep_map, visited, result, 0)
	return bridge.success({"root": root_scene, "max_depth": max_depth,
		"index_state": index_state,
		"index_built_at_unix": int(index.get("built_at_unix", 0)),
		"count": result.size(), "dependencies": result})
