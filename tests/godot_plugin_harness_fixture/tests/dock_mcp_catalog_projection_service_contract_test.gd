extends RefCounted

# {"name": "dock_mcp_catalog_projection_service_contracts"}

const ProjectionServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/presenters/dock_mcp_catalog_projection_service.gd")


class FakeContext extends RefCounted:
	var loader_status := {"state": "ready", "loaded_tools": 7}
	var activity_registry = FakeActivityRegistry.new()

	func get_tool_loader():
		return null

	func get_tool_loader_status() -> Dictionary:
		return loader_status.duplicate(true)

	func get_tool_activity_registry():
		return activity_registry

	func sanitize_for_json(value):
		return value


class FakeActivityRegistry extends RefCounted:
	func get_status() -> Dictionary:
		return {"running": false, "recent_count": 3}

	func get_recent(_limit: int = 20) -> Dictionary:
		return {"recent": [{"id": "call-1", "tool": "system_project_state"}], "recent_count": 1}


func run_case(_tree: SceneTree) -> Dictionary:
	var service = ProjectionServiceScript.new()
	var context := FakeContext.new()
	service.configure({
		"get_tool_loader": Callable(context, "get_tool_loader"),
		"get_tool_loader_status": Callable(context, "get_tool_loader_status"),
		"get_tool_activity_registry": Callable(context, "get_tool_activity_registry"),
		"sanitize_for_json": Callable(context, "sanitize_for_json")
	})
	var projection: Dictionary = service.build_projection()

	var resources: Array = projection.get("mcp_resources", [])
	var templates: Array = projection.get("mcp_resource_templates", [])
	var prompts: Array = projection.get("mcp_prompts", [])
	var counts: Dictionary = projection.get("mcp_catalog_counts", {})
	if resources.is_empty() or templates.is_empty() or prompts.is_empty():
		return _failure("Projection should expose resources, resource templates, and prompts for Dock tabs.")
	if int(counts.get("resources", -1)) != resources.size() or int(counts.get("resource_templates", -1)) != templates.size() or int(counts.get("prompts", -1)) != prompts.size():
		return _failure("Projection counts should match the projected lists.")

	var guide := _find_resource(resources, "godot-dotnet-mcp://guides/index")
	if guide.is_empty() or str(guide.get("resource_kind", "")) != "guide":
		return _failure("Projection should classify canonical guide resources from protocol metadata.")
	if str(guide.get("title", "")).is_empty() or str(guide.get("description", "")).is_empty() or str(guide.get("mimeType", "")) != "application/json":
		return _failure("Projection should preserve resource title, description, and MIME metadata.")
	if (guide.get("icons", []) as Array).is_empty():
		return _failure("Projection should preserve MCP 2025-11-25 resource icons.")

	var diagnostic := _find_resource(resources, "godot-dotnet-mcp://diagnostics/summary")
	if diagnostic.is_empty() or str(diagnostic.get("resource_kind", "")) != "diagnostic":
		return _failure("Projection should classify diagnostic resources.")
	var activity := _find_resource(resources, "godot-dotnet-mcp://activity/status")
	if activity.is_empty() or str(activity.get("resource_kind", "")) != "activity":
		return _failure("Projection should classify activity resources.")
	var template := _find_resource(templates, "godot-dotnet-mcp://scene/{path}")
	if template.is_empty() or str(template.get("resource_kind", "")) != "template" or not bool(template.get("is_template", false)):
		return _failure("Projection should classify resource templates and preserve template flags.")
	if str(template.get("uriTemplate", "")).is_empty():
		return _failure("Projection should preserve resource template URI templates.")

	var orientation := _find_prompt(prompts, "godot.project_orientation")
	if orientation.is_empty() or str(orientation.get("prompt_kind", "")) != "orientation":
		return _failure("Projection should classify project-orientation prompts.")
	if str(orientation.get("title", "")).is_empty() or str(orientation.get("description", "")).is_empty():
		return _failure("Projection should preserve prompt title and description metadata.")
	if (orientation.get("icons", []) as Array).is_empty() or not _has_argument(orientation.get("arguments", []), "goal"):
		return _failure("Projection should preserve prompt icons and argument metadata.")
	var debug_prompt := _find_prompt(prompts, "godot.debug_triage")
	if debug_prompt.is_empty() or str(debug_prompt.get("prompt_kind", "")) != "debug":
		return _failure("Projection should classify debug workflow prompts from protocol metadata.")
	if _projection_source_still_uses_substring_classifiers():
		return _failure("Dock MCP catalog projection should consume protocol kind metadata instead of rebuilding private URI/name substring classifiers.")

	return {
		"name": "dock_mcp_catalog_projection_service_contracts",
		"success": true,
		"error": "",
		"details": counts
	}


func _find_resource(entries: Array, uri: String) -> Dictionary:
	for entry in entries:
		if entry is Dictionary and str((entry as Dictionary).get("uri", "")) == uri:
			return entry as Dictionary
	return {}


func _find_prompt(entries: Array, name: String) -> Dictionary:
	for entry in entries:
		if entry is Dictionary and str((entry as Dictionary).get("name", "")) == name:
			return entry as Dictionary
	return {}


func _has_argument(entries, name: String) -> bool:
	if not (entries is Array):
		return false
	for entry in entries as Array:
		if entry is Dictionary and str((entry as Dictionary).get("name", "")) == name:
			return true
	return false


func _projection_source_still_uses_substring_classifiers() -> bool:
	var script := FileAccess.open("res://addons/godot_dotnet_mcp/plugin/presenters/dock_mcp_catalog_projection_service.gd", FileAccess.READ)
	if script == null:
		return true
	var source := script.get_as_text()
	var forbidden := [
		"entry.get(\"resourceKind\"",
		"entry.get(\"promptKind\"",
		"begins_with(\"godot-dotnet-mcp://",
		".find(\"debug\")",
		".find(\"runtime\")",
		".find(\"ui\")",
		".find(\"authoring\")",
		".find(\"reference\")"
	]
	for pattern in forbidden:
		if source.find(pattern) != -1:
			return true
	return false


func _failure(message: String) -> Dictionary:
	return {
		"name": "dock_mcp_catalog_projection_service_contracts",
		"success": false,
		"error": message
	}
