extends RefCounted

# {"name": "dock_mcp_catalog_preview_service_contracts"}

const DockMcpCatalogPreviewService = preload("res://addons/godot_dotnet_mcp/plugin/presenters/dock_mcp_catalog_preview_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var service = DockMcpCatalogPreviewService.new()
	service.configure(null)

	var resource_preview: Dictionary = service.build_preview("resource", "godot-dotnet-mcp://guides/index")
	if not bool(resource_preview.get("success", false)):
		return _failure("Dock MCP catalog preview service should read canonical resources through resources/read semantics.")
	if str(resource_preview.get("kind", "")) != "resource" or str(resource_preview.get("id", "")) != "godot-dotnet-mcp://guides/index":
		return _failure("Resource previews should preserve the requested kind and URI.")
	if not str(resource_preview.get("text", "")).contains("guides"):
		return _failure("Resource previews should expose readable resource text.")
	if str(resource_preview.get("mimeType", "")) != "application/json":
		return _failure("Resource previews should preserve resource mime type.")

	var prompt_preview: Dictionary = service.build_preview("prompt", "godot.debug_triage", {"include_runtime": "true", "error_summary": "build failed", "empty": ""})
	if not bool(prompt_preview.get("success", false)):
		return _failure("Dock MCP catalog preview service should generate prompt previews through prompts/get semantics.")
	if not str(prompt_preview.get("text", "")).contains("build failed"):
		return _failure("Prompt previews should include generated prompt text from supplied arguments.")
	if (prompt_preview.get("arguments", {}) as Dictionary).has("empty"):
		return _failure("Prompt preview service should omit empty prompt argument values before calling prompts/get.")

	var prompt_error: Dictionary = service.build_preview("prompt", "godot.debug_triage", {"include_runtime": "maybe"})
	if bool(prompt_error.get("success", true)) or not str(prompt_error.get("error", "")).contains("true") or not str(prompt_error.get("error", "")).contains("false"):
		return _failure("Prompt previews should preserve prompts/get argument type validation errors.")
	var non_string_prompt_error: Dictionary = service.build_preview("prompt", "godot.debug_triage", {"include_runtime": []})
	if bool(non_string_prompt_error.get("success", true)) or not str(non_string_prompt_error.get("error", "")).contains("string"):
		return _failure("Prompt previews should pass non-string values through prompts/get validation instead of stringifying them.")

	return {"name": "dock_mcp_catalog_preview_service_contracts", "success": true, "error": ""}


func _failure(message: String) -> Dictionary:
	return {
		"name": "dock_mcp_catalog_preview_service_contracts",
		"success": false,
		"error": message
	}
