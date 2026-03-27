@tool
extends "res://addons/godot_dotnet_mcp/tools/resource/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action := str(args.get("action", ""))
	match action:
		"list":
			return _list_resources(_normalize_resource_path(str(args.get("path", "res://"))), str(args.get("type", "")), bool(args.get("recursive", true)))
		"search":
			return _search_resources(str(args.get("pattern", "")), str(args.get("type", "")), bool(args.get("recursive", true)))
		"get_info":
			return _get_resource_info(_normalize_resource_path(str(args.get("path", ""))))
		"get_dependencies":
			return _get_dependencies(_normalize_resource_path(str(args.get("path", ""))))
		_:
			return _error("Unknown action: %s" % action)


func _list_resources(path: String, type_filter: String, recursive: bool) -> Dictionary:
	var resources: Array[Dictionary] = []
	var fs := _get_filesystem()

	if fs != null:
		var dir = fs.get_filesystem_path(path)
		if dir == null:
			return _error("Directory not found: %s" % path)
		_collect_resources(dir, type_filter, recursive, resources)
	else:
		var absolute_dir := ProjectSettings.globalize_path(path)
		if not DirAccess.dir_exists_absolute(absolute_dir):
			return _error("Directory not found: %s" % path)
		_append_directory_resources(absolute_dir, path, type_filter, recursive, resources)

	return _success({
		"path": path,
		"count": resources.size(),
		"resources": resources
	})


func _collect_resources(dir: EditorFileSystemDirectory, type_filter: String, recursive: bool, results: Array[Dictionary]) -> void:
	for i in dir.get_file_count():
		var file_type := str(dir.get_file_type(i))
		var file_path := str(dir.get_file_path(i))
		if _resource_matches_type_filter(file_type, file_path, type_filter):
			results.append({
				"path": file_path,
				"type": file_type,
				"name": str(dir.get_file(i))
			})

	if recursive:
		for i in dir.get_subdir_count():
			_collect_resources(dir.get_subdir(i), type_filter, recursive, results)


func _search_resources(pattern: String, type_filter: String, recursive: bool) -> Dictionary:
	if pattern.is_empty():
		return _error("Pattern is required")

	var resources: Array[Dictionary] = []
	var fs := _get_filesystem()
	if fs != null:
		_search_resources_recursive(fs.get_filesystem(), pattern, type_filter, recursive, resources)
	else:
		_search_resources_from_disk(ProjectSettings.globalize_path("res://"), "res://", pattern, type_filter, recursive, resources)

	return _success({
		"pattern": pattern,
		"count": resources.size(),
		"resources": resources
	})


func _search_resources_recursive(dir: EditorFileSystemDirectory, pattern: String, type_filter: String, recursive: bool, results: Array[Dictionary]) -> void:
	for i in dir.get_file_count():
		var file_name := str(dir.get_file(i))
		var file_type := str(dir.get_file_type(i))
		var file_path := str(dir.get_file_path(i))
		var matches_pattern := file_name.match(pattern) or file_name.contains(pattern.replace("*", ""))
		var matches_type := _resource_matches_type_filter(file_type, file_path, type_filter)
		if matches_pattern and matches_type:
			results.append({
				"path": file_path,
				"type": file_type,
				"name": file_name
			})

	if recursive:
		for i in dir.get_subdir_count():
			_search_resources_recursive(dir.get_subdir(i), pattern, type_filter, recursive, results)


func _search_resources_from_disk(absolute_dir: String, root_res_path: String, pattern: String, type_filter: String, recursive: bool, results: Array[Dictionary]) -> void:
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry == "." or entry == "..":
			continue

		var child_absolute := absolute_dir.path_join(entry)
		var child_res_path := _normalize_resource_path(root_res_path.path_join(entry))
		if dir.current_is_dir():
			if recursive:
				_search_resources_from_disk(child_absolute, child_res_path, pattern, type_filter, recursive, results)
		else:
			var file_type := _infer_resource_type_from_path(child_res_path)
			var matches_pattern := entry.match(pattern) or entry.contains(pattern.replace("*", ""))
			if matches_pattern and _resource_matches_type_filter(file_type, child_res_path, type_filter):
				results.append({
					"path": child_res_path,
					"type": file_type,
					"name": entry
				})
	dir.list_dir_end()


func _get_resource_info(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")
	if not ResourceLoader.exists(path):
		return _error("Resource not found: %s" % path)

	var resource = load(path)
	if resource == null:
		return _error("Failed to load resource: %s" % path)

	var info := {
		"path": path,
		"type": str(resource.get_class()),
		"name": str(path.get_file()),
		"extension": str(path.get_extension())
	}

	if resource is Texture2D:
		info["width"] = resource.get_width()
		info["height"] = resource.get_height()
		var image = resource.get_image() if resource.has_method("get_image") else null
		info["format"] = image.get_format() if image else "compressed"
	elif resource is AudioStream:
		info["length"] = resource.get_length() if resource.has_method("get_length") else 0
	elif resource is PackedScene:
		var state = resource.get_state()
		info["node_count"] = state.get_node_count()
	elif resource is Script:
		info["base_type"] = str(resource.get_instance_base_type())
		info["is_tool"] = resource.is_tool() if resource.has_method("is_tool") else false

	return _success(info)


func _get_dependencies(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var deps: Array[String] = []
	for dependency in ResourceLoader.get_dependencies(path):
		deps.append(str(dependency))

	return _success({
		"path": path,
		"count": deps.size(),
		"dependencies": deps
	})
