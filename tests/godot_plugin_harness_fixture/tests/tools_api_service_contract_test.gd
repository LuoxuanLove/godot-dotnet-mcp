extends RefCounted

# {"name": "tools_api_service_contracts"}

const ToolsApiServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tools_api_service.gd")
const ToolsApiServiceContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tools_api_service_context.gd")

const JSON_SCHEMA_2020_12_URI := "https://json-schema.org/draft/2020-12/schema"


class FakeToolLoader:
	extends RefCounted

	func get_exposed_tool_definitions() -> Array:
		return [{
			"name": "system_project_state",
			"category": "system",
			"domain_key": "core",
			"enabled": true,
			"inputSchema": {"type": "object", "properties": {}}
		}, {
			"name": "system_scene_inspect",
			"category": "system",
			"domain_key": "core",
			"enabled": true,
			"inputSchema": {"type": "object", "properties": {}}
		}]

	func get_tool_definitions() -> Array:
		return get_exposed_tool_definitions()

	func get_domain_states() -> Array:
		return [{"category": "system", "status": "ready"}]

	func get_all_tools_by_category() -> Dictionary:
		return {
			"system": [{
				"name": "project_state",
				"full_name": "system_project_state",
				"category": "system",
				"enabled": true,
				"inputSchema": {"type": "object", "properties": {}}
			}],
			"project": [{
				"name": "info",
				"full_name": "project_info",
				"category": "project",
				"enabled": true,
				"inputSchema": {"type": "object", "properties": {}}
			}],
			"filesystem": [{
				"name": "directory",
				"full_name": "filesystem_directory",
				"category": "filesystem",
				"enabled": true,
				"inputSchema": {"type": "object", "properties": {}}
			}]
		}

	func get_performance_summary() -> Dictionary:
		return {"slow_operations": 0}


class FakeCallbacks:
	extends RefCounted

	var loader = FakeToolLoader.new()
	var loader_status := {
		"initialized": false,
		"healthy": false,
		"status": "uninitialized"
	}
	var ensure_called := false

	func get_tool_loader():
		return loader

	func get_tool_loader_status() -> Dictionary:
		return loader_status.duplicate(true)

	func ensure_initialized() -> void:
		ensure_called = true
		loader_status = {
			"initialized": true,
			"healthy": true,
			"status": "ready"
		}


func run_case(_tree: SceneTree) -> Dictionary:
	var source_guard := _verify_tools_api_requests_legacy_snapshot_view()
	if not source_guard.is_empty():
		return _failure(source_guard)

	var service = ToolsApiServiceScript.new()
	var callbacks = FakeCallbacks.new()
	var context = ToolsApiServiceContextScript.new()
	context.get_tool_loader = Callable(callbacks, "get_tool_loader")
	context.get_tool_loader_status = Callable(callbacks, "get_tool_loader_status")
	context.ensure_initialized = Callable(callbacks, "ensure_initialized")
	service.configure(context)

	var response: Dictionary = service.build_tools_list_response()
	if not callbacks.ensure_called:
		return _failure("Tools API service should initialize the lazy tool runtime before reading the loader.")
	var tools = response.get("tools", [])
	if not (tools is Array) or (tools as Array).size() != 2:
		return _failure("Tools API service did not preserve the exposed tool definitions.")
	if int(response.get("tool_count", 0)) != 2:
		return _failure("Tools API service did not preserve the tool count.")
	if not (response.get("toolTree", []) is Array) or (response.get("toolTree", []) as Array).is_empty():
		return _failure("Tools API service did not expose the unified tool tree.")
	if not (response.get("toolGroups", []) is Array) or (response.get("toolGroups", []) as Array).is_empty():
		return _failure("Tools API service did not expose tool groups.")
	if not ((tools as Array)[0] as Dictionary).has("groupPath"):
		return _failure("Tools API service should enrich flat tools with non-breaking groupPath metadata.")
	for tool_entry in tools:
		if not _tool_advertises_json_schema_2020_12(tool_entry, "inputSchema"):
			return _failure("Tools API service should advertise JSON Schema 2020-12 on inputSchema.")
		if not _tool_advertises_json_schema_2020_12(tool_entry, "outputSchema"):
			return _failure("Tools API service should advertise JSON Schema 2020-12 on outputSchema.")
	var tool_loader_status = response.get("tool_loader_status", {})
	if not (tool_loader_status is Dictionary) or str((tool_loader_status as Dictionary).get("status", "")) != "ready":
		return _failure("Tools API service did not preserve the loader status snapshot.")
	var catalog_manifest = response.get("catalogManifest", {})
	if not (catalog_manifest is Dictionary) or not (((catalog_manifest as Dictionary).get("public_categories", []) as Array).has("system")):
		return _failure("Tools API service should reuse the canonical catalog manifest snapshot.")
	if (catalog_manifest as Dictionary).has("removed_public_tools"):
		return _failure("Tools API service should not expose removed public tool names in public catalog metadata.")

	return {
		"name": "tools_api_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": int(response.get("tool_count", 0)),
			"domain_state_count": (response.get("domain_states", []) as Array).size(),
			"loader_status": str((tool_loader_status as Dictionary).get("status", ""))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tools_api_service_contracts",
		"success": false,
		"error": message
	}


func _verify_tools_api_requests_legacy_snapshot_view() -> String:
	var source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tools_api_service.gd")
	if source.is_empty():
		return "Tools API service source should be readable."
	var required := "ToolCatalogSnapshotService.build_snapshot(loader, {\n\t\t\"presentation_views\": [\"legacy\"]\n\t})"
	if source.find(required) == -1:
		return "Tools API service should request only the legacy catalog presentation view for tools/list."
	return ""


func _tool_advertises_json_schema_2020_12(tool_entry, key: String) -> bool:
	if not (tool_entry is Dictionary):
		return false
	var schema = (tool_entry as Dictionary).get(key, {})
	return schema is Dictionary and str((schema as Dictionary).get("$schema", "")) == JSON_SCHEMA_2020_12_URI
