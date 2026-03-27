@tool
extends "res://addons/godot_dotnet_mcp/tools/project/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var requested_path := _normalize_res_path(str(args.get("path", "")))
	var project_paths: Array[String] = []

	if requested_path.is_empty():
		project_paths = _find_csproj_files("res://")
		if project_paths.is_empty():
			return _error("No .csproj files found under res://")
	else:
		if not requested_path.ends_with(".csproj"):
			return _error("Path must point to a .csproj file")
		if not FileAccess.file_exists(requested_path):
			return _error("File not found: %s" % requested_path)
		project_paths.append(requested_path)

	var projects: Array[Dictionary] = []
	for project_path in project_paths:
		var parse_result = _parse_csproj_file(project_path)
		if not bool(parse_result.get("success", false)):
			return parse_result
		projects.append(parse_result.get("data", {}).duplicate(true))

	return _success({
		"count": projects.size(),
		"projects": projects
	})


func _parse_csproj_file(path: String) -> Dictionary:
	var read_result = _read_text_file(path)
	if not bool(read_result.get("success", false)):
		return read_result

	var content := str(read_result.get("data", {}).get("content", ""))
	var target_framework := _extract_first_xml_tag(content, "TargetFramework")
	var target_frameworks: Array[String] = []
	if target_framework.is_empty():
		target_frameworks = _split_semicolon_values(_extract_first_xml_tag(content, "TargetFrameworks"))
		if not target_frameworks.is_empty():
			target_framework = target_frameworks[0]
	else:
		target_frameworks.append(target_framework)

	var assembly_name := _extract_first_xml_tag(content, "AssemblyName")
	if assembly_name.is_empty():
		assembly_name = path.get_file().trim_suffix(".csproj")

	var define_constants_raw := _extract_first_xml_tag(content, "DefineConstants")
	var package_references := _parse_package_references(content)
	var project_references := _parse_project_references(content)

	return _success({
		"path": _normalize_res_path(path),
		"target_framework": target_framework,
		"target_frameworks": target_frameworks,
		"assembly_name": assembly_name,
		"root_namespace": _extract_first_xml_tag(content, "RootNamespace"),
		"define_constants": define_constants_raw,
		"define_constants_list": _split_semicolon_values(define_constants_raw),
		"package_reference_count": package_references.size(),
		"package_references": package_references,
		"project_reference_count": project_references.size(),
		"project_references": project_references
	})
