@tool
extends RefCounted
class_name DockMcpCatalogPreviewService

const MCPResourcesServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_resources_service.gd")
const MCPResourcesServiceContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_resources_service_context.gd")
const MCPPromptsServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_prompts_service.gd")
const MCPPromptsServiceContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_prompts_service_context.gd")

var _resources_service = MCPResourcesServiceScript.new()
var _prompts_service = MCPPromptsServiceScript.new()


func configure(server_controller = null) -> void:
	if _resources_service == null:
		_resources_service = MCPResourcesServiceScript.new()
	if _prompts_service == null:
		_prompts_service = MCPPromptsServiceScript.new()
	_resources_service.configure(_build_resources_context(server_controller))
	_prompts_service.configure(_build_prompts_context(server_controller))


func dispose() -> void:
	if _resources_service != null:
		_resources_service.dispose()
	if _prompts_service != null:
		_prompts_service.dispose()
	_resources_service = null
	_prompts_service = null


func build_preview(kind: String, id: String, arguments: Dictionary = {}) -> Dictionary:
	var normalized_kind := kind.strip_edges().to_lower()
	var normalized_id := id.strip_edges()
	if normalized_id.is_empty():
		return _error_preview(normalized_kind, normalized_id, "MCP catalog preview requires an identifier.", arguments)
	match normalized_kind:
		"resource":
			return _build_resource_preview(normalized_id, arguments)
		"template":
			return _build_template_preview(normalized_id, arguments)
		"prompt":
			return _build_prompt_preview(normalized_id, arguments)
		_:
			return _error_preview(normalized_kind, normalized_id, "Unsupported MCP catalog preview kind: %s" % kind, arguments)


func _build_resource_preview(uri: String, arguments: Dictionary) -> Dictionary:
	if _resources_service == null:
		_resources_service = MCPResourcesServiceScript.new()
	var metadata := _find_resource_metadata(uri)
	var result: Dictionary = _resources_service.build_resources_read_result({"uri": uri})
	if not bool(result.get("success", true)):
		return _error_preview("resource", uri, str(result.get("error", "Resource preview failed.")), arguments)
	var contents: Array = result.get("contents", [])
	var text := ""
	var mime_type := ""
	if not contents.is_empty() and contents[0] is Dictionary:
		var content := contents[0] as Dictionary
		text = str(content.get("text", ""))
		mime_type = str(content.get("mimeType", ""))
	return {
		"kind": "resource",
		"id": uri,
		"title": str(metadata.get("title", metadata.get("name", uri))),
		"description": str(metadata.get("description", "")),
		"success": true,
		"text": text,
		"mimeType": mime_type,
		"icons": _duplicate_array(metadata.get("icons", [])),
		"contents": contents.duplicate(true),
		"arguments": arguments.duplicate(true)
	}


func _build_template_preview(uri_template: String, arguments: Dictionary) -> Dictionary:
	var resolved := _resolve_template_uri(uri_template, arguments)
	if not bool(resolved.get("success", false)):
		return _error_preview("template", uri_template, str(resolved.get("error", "Resource template preview failed.")), arguments)
	var resolved_uri := str(resolved.get("uri", ""))
	var preview := _build_resource_preview(resolved_uri, arguments)
	preview["kind"] = "template"
	preview["id"] = uri_template
	preview["resolvedUri"] = resolved_uri
	preview["arguments"] = _compact_arguments(arguments)
	return preview


func _build_prompt_preview(name: String, arguments: Dictionary) -> Dictionary:
	if _prompts_service == null:
		_prompts_service = MCPPromptsServiceScript.new()
	var metadata := _find_prompt_metadata(name)
	var result: Dictionary = _prompts_service.build_prompts_get_result({
		"name": name,
		"arguments": _compact_arguments(arguments)
	})
	if not bool(result.get("success", true)):
		return _error_preview("prompt", name, str(result.get("error", "Prompt preview failed.")), arguments)
	var messages: Array = result.get("messages", [])
	var text_parts: Array[String] = []
	for message in messages:
		if not (message is Dictionary):
			continue
		var message_dict := message as Dictionary
		var role := str(message_dict.get("role", "user"))
		var content = message_dict.get("content", {})
		var text := ""
		if content is Dictionary:
			text = str((content as Dictionary).get("text", ""))
		elif content is String:
			text = str(content)
		if text.strip_edges().is_empty():
			continue
		text_parts.append("%s: %s" % [role, text])
	return {
		"kind": "prompt",
		"id": name,
		"title": str(metadata.get("title", result.get("description", name))),
		"description": str(metadata.get("description", result.get("description", ""))),
		"success": true,
		"text": "\n\n".join(text_parts),
		"messages": messages.duplicate(true),
		"arguments_metadata": _duplicate_array(metadata.get("arguments", [])),
		"icons": _duplicate_array(metadata.get("icons", [])),
		"arguments": _compact_arguments(arguments)
	}


func _find_resource_metadata(uri: String) -> Dictionary:
	var lists := [
		_resources_service.build_resources_list_result().get("resources", []),
		_resources_service.build_resource_templates_list_result().get("resourceTemplates", [])
	]
	for entries in lists:
		if not (entries is Array):
			continue
		for entry in entries as Array:
			if not (entry is Dictionary):
				continue
			var entry_dict := entry as Dictionary
			if str(entry_dict.get("uri", entry_dict.get("uriTemplate", ""))) == uri:
				return entry_dict.duplicate(true)
	return {}


func _resolve_template_uri(uri_template: String, arguments: Dictionary) -> Dictionary:
	var placeholders := _template_placeholders(uri_template)
	if placeholders.is_empty():
		return {"success": true, "uri": uri_template}
	var compacted := _compact_arguments(arguments)
	var resolved := uri_template
	var missing: Array[String] = []
	for placeholder in placeholders:
		var value := str(compacted.get(placeholder, "")).strip_edges()
		if value.is_empty():
			missing.append(placeholder)
			continue
		resolved = resolved.replace("{%s}" % placeholder, value)
	if not missing.is_empty():
		return {
			"success": false,
			"error": "Resource template preview requires argument(s): %s." % ", ".join(missing)
		}
	return {"success": true, "uri": resolved}


func _template_placeholders(uri_template: String) -> Array[String]:
	var placeholders: Array[String] = []
	var search_from := 0
	while true:
		var start := uri_template.find("{", search_from)
		if start == -1:
			break
		var end := uri_template.find("}", start + 1)
		if end == -1:
			break
		var name := uri_template.substr(start + 1, end - start - 1).strip_edges()
		if not name.is_empty() and not placeholders.has(name):
			placeholders.append(name)
		search_from = end + 1
	return placeholders


func _find_prompt_metadata(name: String) -> Dictionary:
	var entries = _prompts_service.build_prompts_list_result().get("prompts", [])
	if not (entries is Array):
		return {}
	for entry in entries as Array:
		if entry is Dictionary and str((entry as Dictionary).get("name", "")) == name:
			return (entry as Dictionary).duplicate(true)
	return {}


func _compact_arguments(arguments: Dictionary) -> Dictionary:
	var compacted := {}
	for key in arguments.keys():
		var name := str(key).strip_edges()
		if name.is_empty():
			continue
		var raw_value = arguments.get(key)
		if raw_value is String:
			var value := str(raw_value).strip_edges()
			if value.is_empty():
				continue
			compacted[name] = value
			continue
		if raw_value == null:
			continue
		compacted[name] = raw_value
	return compacted


func _duplicate_array(values) -> Array:
	if values is Array:
		return (values as Array).duplicate(true)
	return []


func _error_preview(kind: String, id: String, error: String, arguments: Dictionary) -> Dictionary:
	return {
		"kind": kind,
		"id": id,
		"success": false,
		"error": error,
		"text": "",
		"arguments": arguments.duplicate(true)
	}


func _build_resources_context(server_controller):
	var context = MCPResourcesServiceContextScript.new()
	context.get_tool_loader = Callable(self, "_get_tool_loader").bind(server_controller)
	context.get_tool_loader_status = Callable(self, "_get_tool_loader_status").bind(server_controller)
	context.get_tool_activity_registry = Callable(self, "_get_tool_activity_registry").bind(server_controller)
	context.sanitize_for_json = Callable(self, "_sanitize_for_json")
	return context


func _build_prompts_context(server_controller):
	var context = MCPPromptsServiceContextScript.new()
	context.get_tool_loader_status = Callable(self, "_get_tool_loader_status").bind(server_controller)
	return context


func _get_tool_loader(server_controller):
	if server_controller != null and server_controller.has_method("get_tool_loader"):
		return server_controller.get_tool_loader()
	return null


func _get_tool_loader_status(server_controller) -> Dictionary:
	if server_controller != null and server_controller.has_method("get_tool_loader_status"):
		var status = server_controller.get_tool_loader_status()
		if status is Dictionary:
			return (status as Dictionary).duplicate(true)
	var loader = _get_tool_loader(server_controller)
	if loader != null and loader.has_method("get_tool_loader_status"):
		var loader_status = loader.get_tool_loader_status()
		if loader_status is Dictionary:
			return (loader_status as Dictionary).duplicate(true)
	return {}


func _get_tool_activity_registry(server_controller):
	var loader = _get_tool_loader(server_controller)
	if loader != null and loader.has_method("get_tool_activity_registry"):
		return loader.get_tool_activity_registry()
	return null


func _sanitize_for_json(value):
	match typeof(value):
		TYPE_DICTIONARY:
			var result := {}
			for key in value:
				result[str(key)] = _sanitize_for_json(value[key])
			return result
		TYPE_ARRAY:
			var result := []
			for item in value:
				result.append(_sanitize_for_json(item))
			return result
		TYPE_OBJECT:
			return str(value)
		_:
			return value
