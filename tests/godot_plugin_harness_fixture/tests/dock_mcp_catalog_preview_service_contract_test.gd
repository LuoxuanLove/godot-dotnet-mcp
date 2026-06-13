extends RefCounted

# {"name": "dock_mcp_catalog_preview_service_contracts"}

const DockMcpCatalogPreviewService = preload("res://addons/godot_dotnet_mcp/plugin/presenters/dock_mcp_catalog_preview_service.gd")


class FakeServerController extends RefCounted:
	var registry = FakeActivityRegistry.new()

	func get_tool_loader():
		return self

	func get_tool_loader_status() -> Dictionary:
		return {"state": "ready", "loaded_tools": 4}

	func get_tool_activity_registry():
		return registry


class FakeActivityRegistry extends RefCounted:
	func get_status() -> Dictionary:
		return {"running": false, "recent_count": 5}

	func get_recent(_limit: int = 20) -> Dictionary:
		return {"recent": [{"id": "call-1", "tool": "system_project_state"}], "recent_count": 1}


func run_case(_tree: SceneTree) -> Dictionary:
	var service = DockMcpCatalogPreviewService.new()
	service.configure(FakeServerController.new())

	var resource_preview: Dictionary = service.build_preview("resource", "godot-dotnet-mcp://guides/index")
	if not bool(resource_preview.get("success", false)):
		return _failure("Dock MCP catalog preview service should read canonical resources through resources/read semantics.")
	if str(resource_preview.get("kind", "")) != "resource" or str(resource_preview.get("id", "")) != "godot-dotnet-mcp://guides/index":
		return _failure("Resource previews should preserve the requested kind and URI.")
	if not str(resource_preview.get("text", "")).contains("guides"):
		return _failure("Resource previews should expose readable resource text.")
	if str(resource_preview.get("mimeType", "")) != "application/json":
		return _failure("Resource previews should preserve resource mime type.")
	if str(resource_preview.get("title", "")).strip_edges().is_empty() or str(resource_preview.get("description", "")).is_empty():
		return _failure("Resource previews should preserve list metadata titles and descriptions.")
	if (resource_preview.get("icons", []) as Array).is_empty() or (resource_preview.get("contents", []) as Array).is_empty():
		return _failure("Resource previews should preserve resource icons and raw content metadata.")
	var activity_preview: Dictionary = service.build_preview("resource", "godot-dotnet-mcp://activity/status")
	var activity_text := str(activity_preview.get("text", ""))
	if not bool(activity_preview.get("success", false)) or not activity_text.contains("\"recent_count\"") or not activity_text.contains("5"):
		return _failure("Resource previews should read activity resources through the configured Dock runtime context.")

	var prompt_preview: Dictionary = service.build_preview("prompt", "godot.debug_triage", {"include_runtime": "true", "error_summary": "build failed", "empty": ""})
	if not bool(prompt_preview.get("success", false)):
		return _failure("Dock MCP catalog preview service should generate prompt previews through prompts/get semantics.")
	if not str(prompt_preview.get("text", "")).contains("build failed"):
		return _failure("Prompt previews should include generated prompt text from supplied arguments.")
	if (prompt_preview.get("arguments", {}) as Dictionary).has("empty"):
		return _failure("Prompt preview service should omit empty prompt argument values before calling prompts/get.")
	if str(prompt_preview.get("title", "")).strip_edges().is_empty() or str(prompt_preview.get("description", "")).is_empty():
		return _failure("Prompt previews should preserve prompt list title and description metadata.")
	if (prompt_preview.get("icons", []) as Array).is_empty() or (prompt_preview.get("messages", []) as Array).is_empty():
		return _failure("Prompt previews should preserve prompt icons and generated messages.")
	if not _has_argument(prompt_preview.get("arguments_metadata", []), "error_summary"):
		return _failure("Prompt previews should preserve prompt argument metadata alongside current argument values.")

	var prompt_error: Dictionary = service.build_preview("prompt", "godot.debug_triage", {"include_runtime": "maybe"})
	if bool(prompt_error.get("success", true)) or not str(prompt_error.get("error", "")).contains("true") or not str(prompt_error.get("error", "")).contains("false"):
		return _failure("Prompt previews should preserve prompts/get argument type validation errors.")
	var non_string_prompt_error: Dictionary = service.build_preview("prompt", "godot.debug_triage", {"include_runtime": []})
	if bool(non_string_prompt_error.get("success", true)) or not str(non_string_prompt_error.get("error", "")).contains("string"):
		return _failure("Prompt previews should pass non-string values through prompts/get validation instead of stringifying them.")
	var missing_id_error: Dictionary = service.build_preview("resource", "")
	if bool(missing_id_error.get("success", true)) or not str(missing_id_error.get("error", "")).contains("identifier"):
		return _failure("Preview service should reject empty identifiers before calling protocol services.")
	var unsupported_kind_error: Dictionary = service.build_preview("template", "godot-dotnet-mcp://scene/{path}")
	if bool(unsupported_kind_error.get("success", true)) or not str(unsupported_kind_error.get("error", "")).contains("Unsupported"):
		return _failure("Preview service should keep unsupported template previews explicit.")

	return {"name": "dock_mcp_catalog_preview_service_contracts", "success": true, "error": ""}


func _failure(message: String) -> Dictionary:
	return {
		"name": "dock_mcp_catalog_preview_service_contracts",
		"success": false,
		"error": message
	}


func _has_argument(entries, name: String) -> bool:
	if not (entries is Array):
		return false
	for entry in entries as Array:
		if entry is Dictionary and str((entry as Dictionary).get("name", "")) == name:
			return true
	return false
