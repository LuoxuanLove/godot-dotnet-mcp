extends RefCounted

const QueryServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_query_service.gd")
const ProjectionServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_catalog_projection_service.gd")
const PublicSurfacePolicyScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_public_surface_policy.gd")
const StatusServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_status_service.gd")

var _policy = PublicSurfacePolicyScript.new()


class WarningSink:
	extends RefCounted
	var warnings: Array[String] = []

	func record(message: String) -> void:
		warnings.append(message)


func run_case(_tree: SceneTree) -> Dictionary:
	var service = QueryServiceScript.new()
	var projection = ProjectionServiceScript.new()
	var warning_sink := WarningSink.new()
	var context := _projection_context()

	var visible_tools: Dictionary = service.build_tools_by_category(
		projection,
		context,
		true,
		{"system": {}},
		Callable(warning_sink, "record")
	)
	if not visible_tools.has("system"):
		return _failure("Query service should return visible tool groups from the projection service.")
	if visible_tools.has("hidden"):
		return _failure("Query service should keep hidden categories out of visible groups.")

	var visible_definitions: Array[Dictionary] = service.build_tool_definitions(
		projection,
		context,
		true,
		{"system": {}},
		Callable(warning_sink, "record")
	)
	if visible_definitions.size() != 4:
		return _failure("Query service should preserve visible decorated tool definitions.")

	var exposed_definitions: Array[Dictionary] = service.build_exposed_tool_definitions(projection, context, visible_definitions)
	if exposed_definitions.size() != 1 or str(exposed_definitions[0].get("name", "")) != "system_ping":
		return _failure("Query service should delegate exposed public filtering to the projection service. Got: %s" % [str(_names(exposed_definitions))])

	var policy = PublicSurfacePolicyScript.new()
	if not service.is_tool_exposed("system_ping", exposed_definitions, policy, visible_definitions, Callable(self, "_tool_enabled")):
		return _failure("Query service should expose normal public callable tools.")
	if not service.is_tool_exposed("system_plugin_reload", exposed_definitions, policy, visible_definitions, Callable(self, "_tool_enabled")):
		return _failure("Query service should keep callable removed public tools reachable for replacement errors.")
	if not service.is_tool_exposed("system_old_ping", exposed_definitions, policy, visible_definitions, Callable(self, "_tool_enabled")):
		return _failure("Query service should keep compatibility aliases callable when their replacement is enabled.")
	if service.is_tool_exposed("system_disabled_alias", exposed_definitions, policy, visible_definitions, Callable(self, "_tool_enabled")):
		return _failure("Query service should reject aliases whose replacement tool is disabled.")

	var visible_states: Array[Dictionary] = service.build_domain_states(
		projection,
		context,
		true,
		{"system": {}},
		Callable(warning_sink, "record")
	)
	if visible_states.size() != 1 or str(visible_states[0].get("domain", "")) != "system":
		return _failure("Query service should keep visible domain states on the shared projection path.")

	var empty_warnings := WarningSink.new()
	var empty_context := _projection_context()
	empty_context["is_category_visible"] = Callable(self, "_category_hidden")
	var empty_visible: Array[Dictionary] = service.build_tool_definitions(
		projection,
		empty_context,
		true,
		{"system": {}},
		Callable(empty_warnings, "record")
	)
	if not empty_visible.is_empty() or empty_warnings.warnings.size() != 1:
		return _failure("Query service should own empty visible fail-closed warnings.")

	var status: Dictionary = service.build_tool_loader_status(StatusServiceScript.new(), visible_definitions, exposed_definitions, ["system", "hidden"], 0)
	if int(status.get("tool_count", 0)) != 4 or int(status.get("exposed_tool_count", 0)) != 1 or int(status.get("category_count", 0)) != 2:
		return _failure("Query service should build status snapshots from read-side query outputs.")

	var source_guard := _verify_loader_source_delegates_read_side()
	if not bool(source_guard.get("success", false)):
		return source_guard

	return {
		"name": "tool_loader_query_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"visible_tool_count": visible_definitions.size(),
			"exposed_tool_count": exposed_definitions.size(),
			"warning_count": empty_warnings.warnings.size()
		}
	}


func _projection_context() -> Dictionary:
	return {
		"ordered_categories": ["system", "hidden"],
		"entries_by_category": {
			"system": {"domain_key": "core", "source": "builtin", "path": "res://system.gd"},
			"hidden": {"domain_key": "internal", "source": "builtin", "path": "res://hidden.gd"}
		},
		"runtime_by_category": {
			"system": {"state": "loaded", "instance": RefCounted.new(), "version": 1},
			"hidden": {"state": "loaded", "instance": RefCounted.new(), "version": 1}
		},
		"tool_definitions_by_category": {
			"system": [
				{"name": "ping", "description": "Ping"},
				{"name": "plugin_reload", "description": "Removed public guard"},
				{"name": "old_ping", "description": "Compatibility alias", "compatibility_alias": true, "compatibility_replacement": "system_ping"},
				{"name": "disabled_alias", "description": "Disabled compatibility alias", "compatibility_alias": true, "compatibility_replacement": "system_disabled_replacement"}
			],
			"hidden": [
				{"name": "secret", "description": "Hidden"}
			]
		},
		"ensure_tool_definitions": Callable(self, "_ensure_tool_definitions"),
		"is_category_visible": Callable(self, "_category_visible"),
		"is_tool_enabled": Callable(self, "_tool_enabled"),
		"is_exposed_tool_definition": Callable(self, "_is_exposed_tool_definition"),
		"is_public_removed_tool_definition": Callable(self, "_is_public_removed_tool_definition")
	}


func _ensure_tool_definitions(category: String) -> Array:
	return (_projection_context().get("tool_definitions_by_category", {}) as Dictionary).get(category, [])


func _category_visible(category: String) -> bool:
	return category == "system"


func _category_hidden(_category: String) -> bool:
	return false


func _tool_enabled(tool_name: String) -> bool:
	return tool_name != "system_disabled_replacement"


func _is_exposed_tool_definition(tool_def: Dictionary) -> bool:
	return _policy.is_exposed_tool_definition(tool_def)


func _is_public_removed_tool_definition(tool_def: Dictionary) -> bool:
	return _policy.is_public_removed_tool_definition(tool_def)


func _verify_loader_source_delegates_read_side() -> Dictionary:
	var source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/tools/core/tool_loader.gd")
	if source.is_empty():
		return _failure("Tool loader source should be readable for query-service source guards.")
	for required in [
		"ToolLoaderQueryServiceScript.new()",
		"_query_service.build_tools_by_category(",
		"_query_service.build_tool_definitions(",
		"_query_service.build_exposed_tool_definitions(",
		"_query_service.build_domain_states(",
		"_query_service.is_tool_exposed(",
		"_query_service.build_tool_loader_status("
	]:
		if source.find(required) == -1:
			return _failure("MCPToolLoader should delegate read-side query behavior to ToolLoaderQueryService: %s" % required)
	for forbidden in [
		"for tool_def in get_exposed_tool_definitions():",
		"var tool_count := get_tool_definitions().size()",
		"var exposed_tool_count := get_exposed_tool_definitions().size()",
		"var category_count := _ordered_categories.size()"
	]:
		if source.find(forbidden) != -1:
			return _failure("MCPToolLoader should not rebuild read-side query/status logic in the facade: %s" % forbidden)
	return {"success": true}


func _names(definitions: Array) -> Array[String]:
	var result: Array[String] = []
	for definition in definitions:
		if definition is Dictionary:
			result.append(str((definition as Dictionary).get("name", "")))
	return result


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_loader_query_service_contracts",
		"success": false,
		"error": message
	}
