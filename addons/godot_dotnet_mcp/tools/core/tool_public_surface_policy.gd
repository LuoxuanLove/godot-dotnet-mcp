@tool
extends RefCounted
class_name ToolPublicSurfacePolicy

const ToolCatalogManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_catalog_manifest.gd")


func is_public_removed_tool(tool_name: String) -> bool:
	return ToolCatalogManifest.is_removed_public_tool(tool_name)


func is_exposed_tool_definition(tool_def: Dictionary) -> bool:
	if _as_bool(tool_def.get("compatibility_alias", false)):
		return false
	if is_public_removed_tool_definition(tool_def):
		return false
	var category := str(tool_def.get("category", ""))
	return is_exposed_tool_category(category)


func is_public_removed_tool_definition(tool_def: Dictionary) -> bool:
	var name := str(tool_def.get("name", ""))
	var full_name := str(tool_def.get("full_name", name))
	return is_public_removed_tool(full_name) or is_public_removed_tool(name)


func is_callable_removed_public_tool(tool_name: String, tool_definitions: Array, is_tool_enabled_callback: Callable = Callable()) -> bool:
	if not is_public_removed_tool(tool_name):
		return false
	for tool_def in tool_definitions:
		if not (tool_def is Dictionary):
			continue
		var definition := tool_def as Dictionary
		if str(definition.get("name", "")) != tool_name:
			continue
		if not is_exposed_tool_category(str(definition.get("category", ""))):
			return false
		if is_tool_enabled_callback.is_valid() and not _as_bool(is_tool_enabled_callback.call(tool_name)):
			return false
		return _as_bool(definition.get("enabled", true))
	return false


func build_removed_public_tool_result(tool_name: String, arguments: Dictionary = {}) -> Dictionary:
	if tool_name == "system_plugin_reload":
		var action := str(arguments.get("action", "")).strip_edges()
		return _removed_public_tool_result(
			tool_name,
			"Call system_plugin_maintenance instead.",
			[{
				"name": "system_plugin_maintenance",
				"arguments": {"action": "reload"} if action == "full_reload_plugin" else {"action": "status"}
			}],
			["tools/call", "resources/read", "resources/list"],
			["godot-dotnet-mcp://guides/capabilities", "godot-dotnet-mcp://tools/catalog/visible"]
		)
	if tool_name == "system_plugin_update":
		return _removed_public_tool_result(
			tool_name,
			"Call system_plugin_maintenance instead.",
			[{
				"name": "system_plugin_maintenance",
				"arguments": _plugin_update_replacement_arguments(str(arguments.get("action", "")).strip_edges(), arguments)
			}],
			["tools/call", "resources/read", "resources/list"],
			["godot-dotnet-mcp://guides/capabilities", "godot-dotnet-mcp://tools/catalog/visible"]
		)
	if tool_name == "system_editor_log":
		var action := str(arguments.get("action", "")).strip_edges()
		var replacement_tools: Array = []
		var replacement_methods: Array = ["resources/read", "resources/list", "prompts/get"]
		if action == "clear_output":
			replacement_tools.append({
				"name": "system_editor_control",
				"arguments": {"action": "clear_output"}
			})
			replacement_methods.append("tools/call")
		return _removed_public_tool_result(
			tool_name,
			"Read godot-dotnet-mcp://logs/editor/output or godot-dotnet-mcp://logs/editor/errors; use system_editor_control(action=clear_output) when clearing Output is required.",
			replacement_tools,
			replacement_methods,
			[
				"godot-dotnet-mcp://logs/editor/output",
				"godot-dotnet-mcp://logs/editor/errors",
				"godot-dotnet-mcp://diagnostics/summary"
			]
		)
	if tool_name == "resource_manage":
		var action := str(arguments.get("action", "")).strip_edges()
		var replacement_tool_name := "resource_file_ops"
		var replacement_arguments: Dictionary = {}
		match action:
			"create":
				replacement_tool_name = "resource_create"
				replacement_arguments = {
					"type": arguments.get("type", ""),
					"path": arguments.get("path", "")
				}
			"copy", "move":
				replacement_arguments = {
					"action": action,
					"source": arguments.get("source", ""),
					"dest": arguments.get("dest", "")
				}
			"delete", "reload":
				replacement_arguments = {
					"action": action,
					"source": arguments.get("path", arguments.get("source", ""))
				}
			"list", "search", "get_info", "get_dependencies":
				replacement_tool_name = "resource_query"
				replacement_arguments = arguments.duplicate(true)
			_:
				replacement_arguments = arguments.duplicate(true)
		replacement_arguments.erase("_mcp_context")
		return _removed_public_tool_result(
			tool_name,
			"Use resource_create for creation, resource_file_ops for copy/move/delete/reload, or resource_query for listing and dependency queries.",
			[{
				"name": replacement_tool_name,
				"arguments": replacement_arguments
			}],
			["tools/call", "resources/read", "resources/list"],
			["godot-dotnet-mcp://guides/capabilities", "godot-dotnet-mcp://tools/catalog/visible"]
		)
	return {}


func is_callable_compatibility_alias(tool_name: String, tool_definitions: Array, is_tool_enabled_callback: Callable = Callable()) -> bool:
	for tool_def in tool_definitions:
		if not (tool_def is Dictionary):
			continue
		var definition := tool_def as Dictionary
		if str(definition.get("name", "")) != tool_name:
			continue
		if not is_exposed_tool_category(str(definition.get("category", ""))):
			return false
		if not _as_bool(definition.get("enabled", true)):
			return false
		var replacement_tool := str(definition.get("compatibility_replacement", "")).strip_edges()
		if not replacement_tool.is_empty() and is_tool_enabled_callback.is_valid() and not _as_bool(is_tool_enabled_callback.call(replacement_tool)):
			return false
		return _as_bool(definition.get("compatibility_alias", false))
	return false


func is_exposed_tool_category(category: String) -> bool:
	return ToolCatalogManifest.is_public_category(category)


func _removed_public_tool_result(tool_name: String, guidance: String, replacement_tools: Array, replacement_methods: Array, replacement_resources: Array) -> Dictionary:
	return {
		"success": false,
		"error": "%s has been removed from the public tool surface. %s" % [tool_name, guidance],
		"data": {
			"error_type": "removed_public_tool",
			"removed_tool": tool_name,
			"replacement_tools": replacement_tools,
			"replacement_methods": replacement_methods,
			"replacement_resources": replacement_resources
		}
	}


func _plugin_update_replacement_arguments(action: String, args: Dictionary) -> Dictionary:
	match action:
		"get_current":
			return {"action": "status"}
		"get_status":
			return {"action": "update_status"}
		"discover_refs":
			return {
				"action": "refresh_update_refs",
				"force_refresh": args.get("force_refresh", true)
			}
		"set_source":
			return {
				"action": "set_update_source",
				"source": args.get("source", args.get("update_source", "")),
				"custom_branch": args.get("custom_branch", args.get("branch", "")),
				"release_tag": args.get("release_tag", args.get("tag", ""))
			}
		"start_sync":
			return {"action": "start_update"}
		_:
			return {"action": "status"}


func _as_bool(value) -> bool:
	return true if value else false
