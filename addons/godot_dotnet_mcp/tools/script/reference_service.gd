@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

var _reference_index: Dictionary = {}
var _reference_index_ready := false


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", "")).strip_edges()
	var index_result = _get_reference_index(bool(args.get("refresh", false)))
	if not bool(index_result.get("success", false)):
		return index_result

	var index: Dictionary = index_result.get("data", {})
	if action == "get_class_map":
		var csharp_classes = index.get("csharp_classes", [])
		return _success({
			"built_at_unix": int(index.get("built_at_unix", 0)),
			"count": csharp_classes.size(),
			"unique_script_count": int(index.get("csharp_script_count", 0)),
			"classes": csharp_classes
		})
	if action == "get_base_type":
		return _get_reference_base_type(index, args)
	if action == "get_scene_refs":
		return _get_reference_scene_refs(index, args)

	return _error("Unknown action: %s" % action)


func _get_reference_index(force_refresh: bool) -> Dictionary:
	if _reference_index_ready and not force_refresh:
		return _success(_reference_index)

	var build_result = _build_reference_index()
	if not bool(build_result.get("success", false)):
		return build_result

	_reference_index = build_result.get("data", {}).duplicate(true)
	_reference_index_ready = true
	return _success(_reference_index)


func _build_reference_index() -> Dictionary:
	var script_paths: Array[String] = []
	var scene_paths: Array[String] = []
	_collect_reference_paths("res://", script_paths, scene_paths)
	script_paths.sort()
	scene_paths.sort()

	var csharp_classes = []
	var script_entries = []
	var script_entries_by_path = {}
	var script_entries_by_name = {}
	var scene_refs_by_script = {}
	var parse_errors = []
	var csharp_script_paths = {}

	for script_path in script_paths:
		var normalized_path = script_path
		if normalized_path.is_empty():
			continue
		var parse_result: Dictionary = _parse_script_metadata(normalized_path)
		if not bool(parse_result.get("success", false)):
			parse_errors.append({
				"path": normalized_path,
				"error": str(parse_result.get("error", "parse_failed"))
			})
			continue
		var metadata: Dictionary = parse_result.get("data", {})
		var entries: Array = _build_reference_entries(normalized_path, metadata)
		script_entries_by_path[normalized_path] = entries
		if entries.is_empty():
			continue

		var entry: Dictionary = entries[0]
		script_entries.append(entry.duplicate(true))
		if str(entry.get("language", "")) == "csharp":
			csharp_classes.append(entry.duplicate(true))
			csharp_script_paths[str(entry.get("path", ""))] = true

	for scene_path in scene_paths:
		var read_result: Dictionary = _read_text_file(scene_path)
		if not bool(read_result.get("success", false)):
			parse_errors.append({
				"path": scene_path,
				"error": str(read_result.get("error", "read_failed"))
			})
			continue
		var scene_content = str(read_result.get("data", {}).get("content", ""))
		_index_scene_references(scene_path, scene_content, scene_refs_by_script)

	return _success({
		"built_at_unix": int(Time.get_unix_time_from_system()),
		"script_count": script_paths.size(),
		"scene_count": scene_paths.size(),
		"csharp_script_count": csharp_script_paths.size(),
		"csharp_classes": csharp_classes,
		"script_entries": script_entries,
		"script_entries_by_path": script_entries_by_path,
		"script_entries_by_name": script_entries_by_name,
		"scene_refs_by_script": scene_refs_by_script,
		"parse_errors": parse_errors
	})


func _collect_reference_paths(dir_path: String, script_paths: Array[String], scene_paths: Array[String]) -> void:
	var pending: Array[String] = [dir_path]

	while not pending.is_empty():
		var current_dir = pending.pop_back()
		var dir = DirAccess.open(current_dir)
		if dir == null:
			continue

		dir.list_dir_begin()
		while true:
			var entry = dir.get_next()
			if entry.is_empty():
				break
			if entry.begins_with("."):
				continue

			var child_path = current_dir + entry if current_dir == "res://" else "%s/%s" % [current_dir, entry]
			if dir.current_is_dir():
				pending.append(child_path)
			elif entry.ends_with(".cs") or entry.ends_with(".gd"):
				script_paths.append(_normalize_res_path(child_path))
			elif entry.ends_with(".tscn"):
				scene_paths.append(_normalize_res_path(child_path))

		dir.list_dir_end()


func _build_reference_entries(script_path: String, metadata: Dictionary) -> Array:
	var entries = []
	var language = str(metadata.get("language", "unknown"))
	var primary_name = str(metadata.get("class_name", "")).strip_edges()

	if language == "csharp":
		if not primary_name.is_empty():
			entries.append({
				"class_name": primary_name,
				"path": script_path,
				"language": "csharp",
				"namespace": str(metadata.get("namespace", "")),
				"base_type": str(metadata.get("base_type", "")).strip_edges(),
				"is_primary": true
			})
		return entries

	if language == "gdscript":
		if primary_name.is_empty():
			return entries
		entries.append({
			"class_name": primary_name,
			"path": script_path,
			"language": "gdscript",
			"namespace": "",
			"base_type": str(metadata.get("base_type", "")).strip_edges(),
			"is_primary": true
		})

	return entries


func _index_scene_references(scene_path: String, content: String, scene_refs_by_script: Dictionary) -> void:
	var script_resources = {}

	for raw_line in content.split("\n"):
		var line = raw_line.strip_edges()
		if not line.begins_with("[ext_resource"):
			continue
		if line.find("type=\"Script\"") == -1:
			continue

		var resource_id = _extract_scene_attribute(line, "id")
		var script_path = _normalize_res_path(_extract_scene_attribute(line, "path"))
		if resource_id.is_empty() or script_path.is_empty():
			continue
		script_resources[resource_id] = script_path

	for raw_line in content.split("\n"):
		var line = raw_line.strip_edges()
		var marker = "script = ExtResource(\""
		var marker_index = line.find(marker)
		if marker_index == -1:
			continue

		var id_start = marker_index + marker.length()
		var id_end = line.find("\")", id_start)
		if id_end == -1:
			continue

		var resource_id = line.substr(id_start, id_end - id_start)
		var script_path = str(script_resources.get(resource_id, ""))
		if script_path.is_empty():
			continue
		_append_unique_string(scene_refs_by_script, script_path, scene_path)


func _extract_scene_attribute(line: String, attribute_name: String) -> String:
	var marker = "%s=\"" % attribute_name
	var start = line.find(marker)
	if start == -1:
		return ""
	start += marker.length()
	var finish = line.find("\"", start)
	if finish == -1:
		return ""
	return line.substr(start, finish - start).strip_edges()


func _append_unique_string(target: Dictionary, key: String, value: String) -> void:
	var items = target.get(key, [])
	if items.has(value):
		return
	items.append(value)
	items.sort()
	target[key] = items


func _get_reference_base_type(index: Dictionary, args: Dictionary) -> Dictionary:
	var query = _build_reference_query(args)
	var path = str(query.get("path", ""))
	if path.is_empty():
		return _error("Path is required for get_base_type in the current stable implementation", query, [
			"Call get_class_map first to resolve class_name to a script path."
		])

	var entries_by_path: Dictionary = index.get("script_entries_by_path", {})
	var entries = entries_by_path.get(path, [])
	if entries.is_empty():
		return _error("No matching C# class found", query)

	var entry: Dictionary = entries[0]
	if str(entry.get("language", "")) != "csharp":
		return _error("get_base_type only supports C# scripts", query)

	return _success({
		"built_at_unix": int(index.get("built_at_unix", 0)),
		"class_name": str(entry.get("class_name", "")),
		"namespace": str(entry.get("namespace", "")),
		"path": str(entry.get("path", "")),
		"base_type": str(entry.get("base_type", "")),
		"is_primary": bool(entry.get("is_primary", false))
	})


func _get_reference_scene_refs(index: Dictionary, args: Dictionary) -> Dictionary:
	var query = _build_reference_query(args)
	var path = str(query.get("path", ""))
	if path.is_empty():
		return _error("Path is required for get_scene_refs in the current stable implementation", query, [
			"Call get_class_map first to resolve class_name to a script path."
		])

	var entries_by_path: Dictionary = index.get("script_entries_by_path", {})
	var matched_scripts = entries_by_path.get(path, [])
	var scene_refs_by_script: Dictionary = index.get("scene_refs_by_script", {})
	var scenes = scene_refs_by_script.get(path, [])

	return _success({
		"built_at_unix": int(index.get("built_at_unix", 0)),
		"query": query,
		"matched_script_count": 1 if not matched_scripts.is_empty() else 0,
		"matched_scripts": matched_scripts,
		"count": scenes.size(),
		"scenes": scenes
	})


func _build_reference_query(args: Dictionary) -> Dictionary:
	return {
		"path": _normalize_res_path(str(args.get("path", ""))),
		"class_name": str(args.get("class_name", "")).strip_edges(),
		"namespace": str(args.get("namespace", "")).strip_edges()
	}
