@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

## Script tools for Godot MCP
## Godot.NET-first script analysis with optional GDScript editing helpers

var _reference_index: Dictionary = {}
var _reference_index_ready := false


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "read",
			"description": """SCRIPT READ: Read a Godot script file as plain text.

SUPPORTED:
- GDScript (.gd)
- C# (.cs)

EXAMPLES:
- Read a C# script: {"path": "res://Scripts/Player.cs"}
- Read a GDScript: {"path": "res://addons/example/tool.gd"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Script file path (res://...)"
					}
				},
				"required": ["path"]
			}
		},
		{
			"name": "open",
			"description": """SCRIPT OPEN: Open scripts in Godot's script editor.

ACTIONS:
- open: Open a script
- open_at_line: Open a script at a specific line
- get_open_scripts: List open scripts

EXAMPLES:
- Open: {"action": "open", "path": "res://Scripts/Player.cs"}
- Open at line: {"action": "open_at_line", "path": "res://Scripts/Player.cs", "line": 42}
- List open scripts: {"action": "get_open_scripts"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["open", "open_at_line", "get_open_scripts"]
					},
					"path": {
						"type": "string",
						"description": "Script file path"
					},
					"line": {
						"type": "integer",
						"description": "Line number for open_at_line"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "inspect",
			"description": """SCRIPT INSPECT: Parse a Godot script and return language-aware metadata.

RETURNS:
- language
- class_name
- base_type
- namespace (C#)
- methods
- exports
- export_groups

EXAMPLES:
- Inspect C#: {"path": "res://Scripts/Player.cs"}
- Inspect GDScript: {"path": "res://addons/example/tool.gd"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Script file path"
					}
				},
				"required": ["path"]
			}
		},
		{
			"name": "symbols",
			"description": """SCRIPT SYMBOLS: List symbols parsed from a Godot script.

FILTERS:
- kind: class, method, export, enum
- query: substring match on symbol name

EXAMPLES:
- All symbols: {"path": "res://Scripts/Player.cs"}
- Only exports: {"path": "res://Scripts/Player.cs", "kind": "export"}
- Filter by name: {"path": "res://Scripts/Player.cs", "query": "Score"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Script file path"
					},
					"kind": {
						"type": "string",
						"enum": ["class", "method", "export", "enum"]
					},
					"query": {
						"type": "string",
						"description": "Filter symbols by substring"
					}
				},
				"required": ["path"]
			}
		},
		{
			"name": "exports",
			"description": """SCRIPT EXPORTS: Return exported members declared by a script.

SUPPORTED:
- [Export] members in C#
- @export variables in GDScript

EXAMPLES:
- C# exports: {"path": "res://Scripts/Player.cs"}
- GDScript exports: {"path": "res://addons/example/tool.gd"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Script file path"
					}
				},
				"required": ["path"]
			}
		},
		{
			"name": "references",
			"description": """SCRIPT REFERENCES: Build an on-demand cross-file script index for scene usage and C# inheritance lookups.

ACTIONS:
- get_scene_refs: List .tscn files that reference a script via script = ExtResource(...)
- get_base_type: Return the direct base type for a C# class
- get_class_map: List all discovered C# class-to-path mappings

NOTES:
- The current stable implementation is path-first for get_scene_refs/get_base_type
- Use get_class_map to resolve a class name to its script path when needed
- refresh rebuilds the cached index for the current editor session

EXAMPLES:
- Scene refs by path: {"action": "get_scene_refs", "path": "res://Scripts/Player.cs"}
- Base type by path: {"action": "get_base_type", "path": "res://Scripts/Player.cs"}
- Class map: {"action": "get_class_map"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["get_scene_refs", "get_base_type", "get_class_map"]
					},
					"path": {
						"type": "string",
						"description": "Optional script file path"
					},
					"class_name": {
						"type": "string",
						"description": "Optional class name"
					},
					"namespace": {
						"type": "string",
						"description": "Optional namespace filter for C# classes"
					},
					"refresh": {
						"type": "boolean",
						"description": "Rebuild the cached index before querying"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "edit_gd",
			"description": """GDSCRIPT EDIT: Edit GDScript files only.

ACTIONS:
- create: Create a new .gd script
- write: Replace full script content
- delete: Delete a .gd script
- add_function: Append a function
- remove_function: Remove a function by name
- add_variable: Add a variable declaration
- add_signal: Add a signal declaration
- add_export: Add an exported variable
- get_functions: List parsed functions
- get_variables: List parsed variables

EXAMPLES:
- Create: {"action": "create", "path": "res://scripts/player.gd", "extends": "Node2D"}
- Add function: {"action": "add_function", "path": "res://scripts/player.gd", "name": "flash", "body": "return 1", "return_type": "int"}
- List variables: {"action": "get_variables", "path": "res://scripts/player.gd"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["create", "write", "delete", "add_function", "remove_function", "add_variable", "add_signal", "add_export", "get_functions", "get_variables"]
					},
					"path": {
						"type": "string",
						"description": "GDScript file path"
					},
					"content": {
						"type": "string"
					},
					"extends": {
						"type": "string"
					},
					"class_name": {
						"type": "string"
					},
					"name": {
						"type": "string"
					},
					"type": {
						"type": "string"
					},
					"value": {
						"type": "string"
					},
					"params": {
						"type": "array",
						"items": {"type": "string"}
					},
					"body": {
						"type": "string"
					},
					"return_type": {
						"type": "string"
					}
				},
				"required": ["action", "path"]
			}
		},
		{
			"name": "edit_cs",
			"description": """C# EDIT: Template-based editing for .cs scripts.

ACTIONS:
- create: Create a new .cs script from namespace/class/base_type
- write: Replace full script content
- add_field: Append a field near the end of the primary class
- add_method: Append a method stub near the end of the primary class

EXAMPLES:
- Create: {"action": "create", "path": "res://Scripts/Player.cs", "namespace": "Game", "class_name": "Player", "base_type": "Node"}
- Add field: {"action": "add_field", "path": "res://Scripts/Player.cs", "name": "Speed", "type": "float", "value": "5.0f", "exported": true}
- Add method: {"action": "add_method", "path": "res://Scripts/Player.cs", "name": "Jump", "return_type": "void", "body": "// TODO: implement"}
- Write: {"action": "write", "path": "res://Scripts/Player.cs", "content": "using Godot;"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["create", "write", "add_field", "add_method"]
					},
					"path": {
						"type": "string",
						"description": "C# script file path"
					},
					"namespace": {
						"type": "string"
					},
					"class_name": {
						"type": "string"
					},
					"base_type": {
						"type": "string"
					},
					"content": {
						"type": "string"
					},
					"name": {
						"type": "string"
					},
					"type": {
						"type": "string"
					},
					"value": {
						"type": "string"
					},
					"access": {
						"type": "string"
					},
					"modifiers": {
						"type": "array",
						"items": {"type": "string"}
					},
					"exported": {
						"type": "boolean"
					},
					"params": {
						"type": "array",
						"items": {"type": "string"}
					},
					"body": {
						"type": "string"
					},
					"return_type": {
						"type": "string"
					},
				},
				"required": ["action", "path"]
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"read":
			return _execute_read(args)
		"open":
			return _execute_open(args)
		"inspect":
			return _execute_inspect(args)
		"symbols":
			return _execute_symbols(args)
		"exports":
			return _execute_exports(args)
		"references":
			return _execute_references(args)
		"edit_gd":
			return _execute_edit_gd(args)
		"edit_cs":
			return _execute_edit_cs(args)
		_:
			return _error("Unknown tool: %s" % tool_name)


func _execute_read(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	if path.is_empty():
		return _error("Path is required")

	var read_result = _read_text_file(path)
	if not read_result.get("success", false):
		return read_result

	var data = read_result["data"]
	data["language"] = _detect_script_language(data["path"])
	return _success(data)


func _execute_open(args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	match action:
		"open":
			return _open_script(args.get("path", ""))
		"open_at_line":
			return _open_script_at_line(args.get("path", ""), args.get("line", 1))
		"get_open_scripts":
			return _get_open_scripts()
		_:
			return _error("Unknown action: %s" % action)


func _execute_inspect(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	if path.is_empty():
		return _error("Path is required")

	var parse_result = _parse_script_metadata(path)
	if not parse_result.get("success", false):
		return parse_result

	var metadata = parse_result["data"]
	metadata["symbol_count"] = metadata.get("symbols", []).size()
	metadata["method_count"] = metadata.get("methods", []).size()
	metadata["export_count"] = metadata.get("exports", []).size()
	return _success(metadata)


func _execute_symbols(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	if path.is_empty():
		return _error("Path is required")

	var parse_result = _parse_script_metadata(path)
	if not parse_result.get("success", false):
		return parse_result

	var kind_filter = str(args.get("kind", "")).strip_edges()
	var query = str(args.get("query", "")).to_lower()
	var symbols: Array = []

	for symbol in parse_result["data"].get("symbols", []):
		var symbol_kind = str(symbol.get("kind", ""))
		var symbol_name = str(symbol.get("name", ""))
		if not kind_filter.is_empty() and symbol_kind != kind_filter:
			continue
		if not query.is_empty() and symbol_name.to_lower().find(query) == -1:
			continue
		symbols.append(symbol)

	return _success({
		"path": _normalize_res_path(path),
		"language": parse_result["data"].get("language", "unknown"),
		"count": symbols.size(),
		"symbols": symbols
	})


func _execute_exports(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	if path.is_empty():
		return _error("Path is required")

	var parse_result = _parse_script_metadata(path)
	if not parse_result.get("success", false):
		return parse_result

	var metadata = parse_result["data"]
	return _success({
		"path": metadata["path"],
		"language": metadata["language"],
		"class_name": metadata.get("class_name", ""),
		"count": metadata.get("exports", []).size(),
		"export_groups": metadata.get("export_groups", []),
		"exports": metadata.get("exports", [])
	})


func _execute_references(args: Dictionary) -> Dictionary:
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


func _execute_edit_gd(args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	var path = _normalize_res_path(args.get("path", ""))
	if path.is_empty():
		return _error("Path is required")
	if not path.ends_with(".gd"):
		return _error("script_edit_gd only supports .gd files")

	match action:
		"create":
			return _create_gdscript(path, args.get("extends", "Node"), args.get("class_name", ""))
		"write":
			return _write_gdscript(path, args.get("content", ""))
		"delete":
			return _delete_script_file(path)
		"add_function":
			return _add_gd_function(path, args)
		"remove_function":
			return _remove_gd_function(path, args.get("name", ""))
		"add_variable":
			return _add_gd_variable(path, args)
		"add_signal":
			return _add_gd_signal(path, args.get("name", ""), args.get("params", []))
		"add_export":
			return _add_gd_export(path, args)
		"get_functions":
			return _get_gd_functions(path)
		"get_variables":
			return _get_gd_variables(path)
		_:
			return _error("Unknown action: %s" % action)


func _execute_edit_cs(args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	var path = _normalize_res_path(str(args.get("path", "")))
	if path.is_empty():
		return _error("Path is required")
	if not path.ends_with(".cs"):
		return _error("script_edit_cs only supports .cs files")

	match action:
		"create":
			return _create_csharp_script(path, args)
		"write":
			return _write_csharp_script(path, str(args.get("content", "")))
		"add_field":
			return _add_csharp_field(path, args)
		"add_method":
			return _add_csharp_method(path, args)
		_:
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


func _append_dictionary_array(target: Dictionary, key: String, value: Dictionary) -> void:
	var items = target.get(key, [])
	items.append(value.duplicate(true))
	target[key] = items


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


func _resolve_reference_entries(index: Dictionary, args: Dictionary, csharp_only: bool) -> Array:
	return []


func _build_reference_query(args: Dictionary) -> Dictionary:
	return {
		"path": _normalize_res_path(str(args.get("path", ""))),
		"class_name": str(args.get("class_name", "")).strip_edges(),
		"namespace": str(args.get("namespace", "")).strip_edges()
	}


func _open_script(path: String) -> Dictionary:
	var normalized = _normalize_res_path(path)
	if normalized.is_empty():
		return _error("Path is required")
	if not ResourceLoader.exists(normalized):
		return _error("Script not found: %s" % normalized)

	var script = load(normalized)
	if not script:
		return _error("Failed to load script")

	var ei = _get_editor_interface()
	if ei:
		ei.edit_script(script)

	return _success({"path": normalized}, "Script opened in editor")


func _open_script_at_line(path: String, line: int) -> Dictionary:
	var normalized = _normalize_res_path(path)
	if normalized.is_empty():
		return _error("Path is required")
	if not ResourceLoader.exists(normalized):
		return _error("Script not found: %s" % normalized)

	var script = load(normalized)
	if not script:
		return _error("Failed to load script")

	var ei = _get_editor_interface()
	if ei:
		ei.edit_script(script, line)

	return _success({
		"path": normalized,
		"line": line
	}, "Script opened at line %d" % line)


func _get_open_scripts() -> Dictionary:
	var ei = _get_editor_interface()
	if not ei:
		return _error("Editor interface not available")

	var script_editor = ei.get_script_editor()
	if not script_editor:
		return _error("Script editor not available")

	var open_scripts = script_editor.get_open_scripts()
	var scripts: Array[Dictionary] = []

	for script in open_scripts:
		scripts.append({
			"path": str(script.resource_path),
			"type": str(script.get_class()),
			"language": _detect_script_language(str(script.resource_path))
		})

	return _success({
		"count": scripts.size(),
		"scripts": scripts
	})


func _create_gdscript(path: String, extends_class: String, class_name_str: String) -> Dictionary:
	if FileAccess.file_exists(path):
		return _error("Script already exists: %s" % path)

	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

	var lines: Array[String] = []
	if not class_name_str.is_empty():
		lines.append("class_name %s" % class_name_str)
	lines.append("extends %s" % extends_class)
	lines.append("")
	lines.append("func _ready() -> void:")
	lines.append("\tpass")

	return _write_gdscript(path, "\n".join(lines))


func _write_gdscript(path: String, content: String) -> Dictionary:
	if content.is_empty():
		return _error("Content is required")

	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return _error("Failed to write script")

	file.store_string(content)
	file.close()

	var fs = _get_filesystem()
	if fs:
		fs.scan()

	return _success({
		"path": path,
		"language": "gdscript",
		"line_count": content.split("\n").size()
	}, "Script written: %s" % path)


func _create_csharp_script(path: String, args: Dictionary) -> Dictionary:
	if FileAccess.file_exists(path):
		return _error("Script already exists: %s" % path)

	var class_name_str := str(args.get("class_name", "")).strip_edges()
	if class_name_str.is_empty():
		class_name_str = path.get_file().trim_suffix(".cs")
	var namespace_str := str(args.get("namespace", "")).strip_edges()
	var base_type := str(args.get("base_type", "Node")).strip_edges()
	if base_type.is_empty():
		base_type = "Node"

	var lines: Array[String] = []
	lines.append("using Godot;")
	lines.append("")
	if not namespace_str.is_empty():
		lines.append("namespace %s;" % namespace_str)
		lines.append("")
	lines.append("public partial class %s : %s" % [class_name_str, base_type])
	lines.append("{")
	lines.append("}")

	return _write_csharp_script(path, "\n".join(lines))


func _write_csharp_script(path: String, content: String) -> Dictionary:
	if content.is_empty():
		return _error("Content is required")

	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _error("Failed to write script")

	file.store_string(content)
	file.close()

	var fs = _get_filesystem()
	if fs:
		fs.scan()

	return _validate_csharp_script(path, content)


func _add_csharp_field(path: String, args: Dictionary) -> Dictionary:
	var field_name = str(args.get("name", "")).strip_edges()
	if field_name.is_empty():
		return _error("Field name is required")
	var member_code = _build_csharp_field_code(args)
	return _append_csharp_member(path, member_code)


func _add_csharp_method(path: String, args: Dictionary) -> Dictionary:
	var method_name = str(args.get("name", "")).strip_edges()
	if method_name.is_empty():
		return _error("Method name is required")
	var member_code = _build_csharp_method_code(args)
	return _append_csharp_member(path, member_code)


func _build_csharp_field_code(args: Dictionary) -> String:
	var access = str(args.get("access", "public")).strip_edges()
	if access.is_empty():
		access = "public"
	var type_name = str(args.get("type", "Variant")).strip_edges()
	if type_name.is_empty():
		type_name = "Variant"
	var field_name = str(args.get("name", "")).strip_edges()
	var value = str(args.get("value", "")).strip_edges()
	var exported = bool(args.get("exported", false))
	var modifiers = args.get("modifiers", [])

	var parts: Array[String] = []
	parts.append(access)
	if modifiers is Array:
		for modifier in modifiers:
			var modifier_text = str(modifier).strip_edges()
			if not modifier_text.is_empty():
				parts.append(modifier_text)
	parts.append(type_name)
	parts.append(field_name)

	var declaration = " ".join(parts)
	if not value.is_empty():
		declaration += " = %s" % value
	declaration += ";"
	if exported:
		return "[Export]\n%s" % declaration
	return declaration


func _build_csharp_method_code(args: Dictionary) -> String:
	var access = str(args.get("access", "public")).strip_edges()
	if access.is_empty():
		access = "public"
	var return_type = str(args.get("return_type", "void")).strip_edges()
	if return_type.is_empty():
		return_type = "void"
	var method_name = str(args.get("name", "")).strip_edges()
	var modifiers = args.get("modifiers", [])
	var params_value = args.get("params", [])
	var body = str(args.get("body", "")).strip_edges()
	if body.is_empty():
		body = "// TODO: implement"
		if return_type != "void":
			body += "\nreturn default;"

	var signature_parts: Array[String] = []
	signature_parts.append(access)
	if modifiers is Array:
		for modifier in modifiers:
			var modifier_text = str(modifier).strip_edges()
			if not modifier_text.is_empty():
				signature_parts.append(modifier_text)
	signature_parts.append(return_type)

	var params_list: Array[String] = []
	if params_value is Array:
		for item in params_value:
			var param_text = str(item).strip_edges()
			if not param_text.is_empty():
				params_list.append(param_text)
	signature_parts.append("%s(%s)" % [method_name, ", ".join(params_list)])

	var lines: Array[String] = []
	lines.append(" ".join(signature_parts))
	lines.append("{")
	for body_line in body.split("\n"):
		lines.append("    %s" % body_line)
	lines.append("}")
	return "\n".join(lines)


func _append_csharp_member(path: String, member_code: String) -> Dictionary:
	var read_result = _read_text_file(path)
	if not bool(read_result.get("success", false)):
		return read_result

	var content = str(read_result.get("data", {}).get("content", ""))
	var class_close_index = _find_primary_csharp_class_close(content)
	if class_close_index == -1:
		return _error("Failed to locate primary C# class body")

	var member_indent = _detect_csharp_member_indent(content, class_close_index)
	var indented_member = _indent_multiline_block(member_code, member_indent)
	var prefix = _trim_trailing_whitespace(content.substr(0, class_close_index))
	var suffix = content.substr(class_close_index)
	var new_content = "%s\n\n%s\n%s" % [prefix, indented_member, suffix]
	return _write_csharp_script(path, new_content)


func _find_primary_csharp_class_close(content: String) -> int:
	var class_index = content.find("class ")
	if class_index == -1:
		return -1

	var open_brace_index = content.find("{", class_index)
	if open_brace_index == -1:
		return -1

	return _find_matching_brace(content, open_brace_index)


func _find_matching_brace(content: String, open_brace_index: int) -> int:
	var depth = 0
	for index in range(open_brace_index, content.length()):
		var char_value = content.substr(index, 1)
		if char_value == "{":
			depth += 1
		elif char_value == "}":
			depth -= 1
			if depth == 0:
				return index
	return -1


func _detect_csharp_member_indent(content: String, class_close_index: int) -> String:
	var line_start_index = content.rfind("\n", class_close_index)
	if line_start_index == -1:
		return "    "

	var closing_line = content.substr(line_start_index + 1, class_close_index - line_start_index - 1)
	return "%s    " % _leading_whitespace(closing_line)


func _indent_multiline_block(content: String, indent: String) -> String:
	var lines: Array[String] = []
	for raw_line in content.split("\n"):
		lines.append("%s%s" % [indent, raw_line])
	return "\n".join(lines)


func _leading_whitespace(line: String) -> String:
	var index = 0
	while index < line.length():
		var char_value = line.substr(index, 1)
		if char_value != " " and char_value != "\t":
			break
		index += 1
	return line.substr(0, index)


func _trim_trailing_whitespace(value: String) -> String:
	var end_index = value.length()
	while end_index > 0:
		var char_value = value.substr(end_index - 1, 1)
		if char_value != " " and char_value != "\t" and char_value != "\n" and char_value != "\r":
			break
		end_index -= 1
	return value.substr(0, end_index)


func _validate_csharp_script(path: String, content: String) -> Dictionary:
	var parse_result = _parse_script_metadata(path)
	if not bool(parse_result.get("success", false)):
		return _error("C# script validation failed", {
			"path": path,
			"line_count": content.split("\n").size(),
			"parse_result": parse_result
		})

	var metadata := parse_result.get("data", {})
	if str(metadata.get("class_name", "")).strip_edges().is_empty():
		return _error("C# script validation failed: class declaration not found", {
			"path": path,
			"line_count": content.split("\n").size()
		})

	return _success({
		"path": path,
		"language": "csharp",
		"class_name": metadata.get("class_name", ""),
		"namespace": metadata.get("namespace", ""),
		"line_count": content.split("\n").size(),
		"method_count": metadata.get("methods", []).size(),
		"export_count": metadata.get("exports", []).size()
	}, "C# script written: %s" % path)


func _delete_script_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _error("Script not found: %s" % path)

	var error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if error != OK:
		return _error("Failed to delete script: %s" % error_string(error))

	var fs = _get_filesystem()
	if fs:
		fs.scan()

	return _success({"deleted": path}, "Script deleted")


func _add_gd_function(path: String, args: Dictionary) -> Dictionary:
	var name = str(args.get("name", ""))
	if name.is_empty():
		return _error("Function name is required")

	var read_result = _read_text_file(path)
	if not read_result.get("success", false):
		return read_result

	var content = read_result["data"]["content"] as String
	var params_str = ", ".join(args.get("params", []))
	var return_type = str(args.get("return_type", "")).strip_edges()
	var body = str(args.get("body", "pass"))
	var func_signature = "\n\nfunc %s(%s)" % [name, params_str]
	if not return_type.is_empty():
		func_signature += " -> %s" % return_type
	func_signature += ":\n"
	var func_code = func_signature

	for line in body.split("\n"):
		func_code += "\t%s\n" % line

	return _write_gdscript(path, content + func_code)


func _remove_gd_function(path: String, name: String) -> Dictionary:
	if name.is_empty():
		return _error("Function name is required")

	var read_result = _read_text_file(path)
	if not read_result.get("success", false):
		return read_result

	var content = read_result["data"]["content"] as String
	var lines = content.split("\n")
	var new_lines: Array[String] = []
	var in_function = false
	var func_indent = 0

	for line in lines:
		var stripped = line.strip_edges()
		if stripped.begins_with("func %s" % name):
			in_function = true
			func_indent = line.length() - line.strip_edges(true, false).length()
			continue

		if in_function:
			var current_indent = line.length() - line.strip_edges(true, false).length()
			if not stripped.is_empty() and current_indent <= func_indent:
				in_function = false

		if not in_function:
			new_lines.append(line)

	return _write_gdscript(path, "\n".join(new_lines))


func _add_gd_variable(path: String, args: Dictionary) -> Dictionary:
	var name = str(args.get("name", ""))
	if name.is_empty():
		return _error("Variable name is required")

	var read_result = _read_text_file(path)
	if not read_result.get("success", false):
		return read_result

	var content = read_result["data"]["content"] as String
	var lines = content.split("\n")
	var insert_index = 0
	for i in lines.size():
		var line = lines[i].strip_edges()
		if line.begins_with("extends ") or line.begins_with("class_name "):
			insert_index = i + 1
		elif not line.is_empty() and not line.begins_with("#"):
			break

	var var_type = str(args.get("type", ""))
	var value = str(args.get("value", ""))
	var var_line = "var %s" % name
	if not var_type.is_empty():
		var_line += ": %s" % var_type
	if not value.is_empty():
		var_line += " = %s" % value

	lines.insert(insert_index, var_line)
	return _write_gdscript(path, "\n".join(lines))


func _add_gd_signal(path: String, name: String, params: Array) -> Dictionary:
	if name.is_empty():
		return _error("Signal name is required")

	var read_result = _read_text_file(path)
	if not read_result.get("success", false):
		return read_result

	var content = read_result["data"]["content"] as String
	var lines = content.split("\n")
	var insert_index = 0
	for i in lines.size():
		var line = lines[i].strip_edges()
		if line.begins_with("extends ") or line.begins_with("class_name "):
			insert_index = i + 1
		elif not line.is_empty() and not line.begins_with("#") and not line.begins_with("signal "):
			break

	var signal_line = "signal %s" % name
	if not params.is_empty():
		signal_line += "(%s)" % ", ".join(params)

	lines.insert(insert_index, signal_line)
	return _write_gdscript(path, "\n".join(lines))


func _add_gd_export(path: String, args: Dictionary) -> Dictionary:
	var name = str(args.get("name", ""))
	if name.is_empty():
		return _error("Export variable name is required")

	var read_result = _read_text_file(path)
	if not read_result.get("success", false):
		return read_result

	var content = read_result["data"]["content"] as String
	var lines = content.split("\n")
	var insert_index = 0
	for i in lines.size():
		var line = lines[i].strip_edges()
		if line.begins_with("extends ") or line.begins_with("class_name ") or line.begins_with("signal "):
			insert_index = i + 1
		elif not line.is_empty() and not line.begins_with("#"):
			break

	var export_line = "@export var %s" % name
	var var_type = str(args.get("type", ""))
	var value = str(args.get("value", ""))
	if not var_type.is_empty():
		export_line += ": %s" % var_type
	if not value.is_empty():
		export_line += " = %s" % value

	lines.insert(insert_index, export_line)
	return _write_gdscript(path, "\n".join(lines))


func _get_gd_functions(path: String) -> Dictionary:
	var parse_result = _parse_script_metadata(path)
	if not parse_result.get("success", false):
		return parse_result
	if parse_result["data"].get("language") != "gdscript":
		return _error("get_functions only supports .gd files")

	return _success({
		"path": parse_result["data"]["path"],
		"count": parse_result["data"].get("methods", []).size(),
		"functions": parse_result["data"].get("methods", [])
	})


func _get_gd_variables(path: String) -> Dictionary:
	var read_result = _read_text_file(path)
	if not read_result.get("success", false):
		return read_result

	var content = read_result["data"]["content"] as String
	var variables: Array[Dictionary] = []
	var regex = RegEx.new()
	regex.compile("(?m)^(?:@export\\s+)?var\\s+([A-Za-z_][A-Za-z0-9_]*)(?:\\s*:\\s*([^=]+))?(?:\\s*=\\s*(.+))?")

	for match_result in regex.search_all(content):
		var var_info = {
			"name": match_result.get_string(1),
			"exported": str(match_result.get_string(0)).strip_edges().begins_with("@export")
		}
		if not match_result.get_string(2).is_empty():
			var var_type = match_result.get_string(2).strip_edges()
			if var_type.ends_with("\r"):
				var_type = var_type.trim_suffix("\r")
			var_info["type"] = var_type
		if not match_result.get_string(3).is_empty():
			var_info["default"] = match_result.get_string(3).strip_edges()
		variables.append(var_info)

	return _success({
		"path": _normalize_res_path(path),
		"count": variables.size(),
		"variables": variables
	})
