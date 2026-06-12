extends RefCounted

const ToolLoaderScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader.gd")
const MCPToolManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_manifest.gd")
const ToolCatalogManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_catalog_manifest.gd")
const ToolPresentationService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_presentation_service.gd")
const ToolActivityRegistryScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_activity_registry.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")


class FakeServerContext extends RefCounted:
	var _tool_access_provider
	var _runtime_control_service

	func _init(tool_access_provider, runtime_control_service = null) -> void:
		_tool_access_provider = tool_access_provider
		_runtime_control_service = runtime_control_service

	func get_tool_access_provider():
		return _tool_access_provider

	func get_runtime_control_service():
		return _runtime_control_service


class FakeToolAccessProvider extends RefCounted:
	var hidden_categories: Dictionary = {}
	var blocked_categories: Dictionary = {}
	var denied_messages: Dictionary = {}

	func is_tool_category_visible(category: String):
		return not bool(hidden_categories.get(category, false))

	func is_tool_category_executable(category: String):
		return not bool(blocked_categories.get(category, false))

	func get_tool_access_denied_message(category: String) -> String:
		return str(denied_messages.get(category, "Tool category disabled"))


class FakeRuntimeControlService extends RefCounted:
	func get_status() -> Dictionary:
		return {
			"available": true,
			"armed": false,
			"message": "Runtime control is disabled for the current session."
		}


var _loader = null


func run_case(_tree: SceneTree) -> Dictionary:
	PluginSelfDiagnosticStore.clear()
	PluginSelfDiagnosticStore.record_incident(
		"warning",
		"contract_warning",
		"tool_loader_contract_incident",
		"Tool loader contract incident",
		"tool_loader_contract_test"
	)
	var tool_access_provider = FakeToolAccessProvider.new()

	var runtime_control_service = FakeRuntimeControlService.new()
	_loader = ToolLoaderScript.new()
	_loader.configure(FakeServerContext.new(tool_access_provider, runtime_control_service))
	_loader.set_tool_activity_registry(ToolActivityRegistryScript.new())
	var summary: Dictionary = _loader.initialize([])

	if int(summary.get("category_count", 0)) <= 0:
		return _failure("Tool loader initialize() did not report any categories.")
	if int(summary.get("tool_count", 0)) <= 0:
		return _failure("Tool loader initialize() did not report any visible tools.")
	if int(summary.get("exposed_tool_count", 0)) <= 0:
		return _failure("Tool loader initialize() did not report any exposed tools.")
	if int(summary.get("category_count", 0)) != _loader.get_all_domain_states().size():
		return _failure("Tool loader category summary should match indexed domain states.")

	var status: Dictionary = _loader.get_tool_loader_status()
	if not bool(status.get("healthy", false)):
		return _failure("Tool loader status should be healthy after initialization.")
	var lsp_service = _loader.get_gdscript_lsp_diagnostics_service()
	if lsp_service == null:
		return _failure("Tool loader should expose a GDScript LSP diagnostics service through the adapter path.")
	var lsp_snapshot: Dictionary = _loader.get_lsp_diagnostics_debug_snapshot()
	if not bool(lsp_snapshot.get("service_available", false)):
		return _failure("Tool loader LSP diagnostics snapshot should report a live service.")

	var exposed_tools: Array[Dictionary] = _loader.get_exposed_tool_definitions()
	if exposed_tools.is_empty():
		return _failure("Tool loader did not return any exposed tool definitions.")

	var all_tools: Array[Dictionary] = _loader.get_tool_definitions()
	if all_tools.size() <= exposed_tools.size():
		return _failure("Tool loader should keep internal atomic/domain tools available while exposing only high-level system tools publicly.")

	var tools_by_category: Dictionary = _loader.get_tools_by_category()
	for required_internal_category in ["debug", "editor", "project", "scene", "script", "node", "filesystem"]:
		if not tools_by_category.has(required_internal_category) or (tools_by_category[required_internal_category] as Array).is_empty():
			return _failure("Tool loader should keep strongest internal category available: %s" % required_internal_category)
	tool_access_provider.hidden_categories = {"debug": true}
	var hidden_tools_by_category: Dictionary = _loader.get_tools_by_category()
	if hidden_tools_by_category.has("debug"):
		return _failure("Tool loader access service should hide categories denied by the tool access provider.")
	tool_access_provider.hidden_categories.clear()

	var replacement_activity_registry = ToolActivityRegistryScript.new()
	_loader.set_tool_activity_registry(replacement_activity_registry)
	var system_runtime: Dictionary = _loader._runtime_by_category.get("system", {})
	var system_executor = system_runtime.get("instance", null)
	if system_executor == null or not ("_runtime_context" in system_executor):
		return _failure("Tool loader should keep the system executor runtime context observable after initialization.")
	if (system_executor._runtime_context as Dictionary).get("tool_activity_registry", null) != replacement_activity_registry:
		return _failure("Tool loader should refresh loaded executor runtime contexts when the activity registry changes.")

	var exposed_names: Array[String] = []
	for tool_def in exposed_tools:
		var exposed_name := str(tool_def.get("name", ""))
		var exposed_category := str(tool_def.get("category", ""))
		exposed_names.append(exposed_name)
		if not MCPToolManifest.PUBLIC_MCP_TOOL_CATEGORIES.has(exposed_category):
			return _failure("Public MCP exposure should follow the manifest categories, not expose: %s" % exposed_category)
		if not exposed_name.begins_with("%s_" % exposed_category):
			return _failure("Public MCP exposure should prefix public tools with their manifest category: %s" % exposed_name)
		if not ToolCatalogManifest.is_valid_mcp_tool_name(exposed_name):
			return _failure("Public MCP tool name should follow MCP 2025-11-25 naming guidance: %s" % exposed_name)
	var listed_tools := ToolPresentationService.build_mcp_tool_list(exposed_tools)
	for listed_tool in listed_tools:
		if not (listed_tool is Dictionary):
			return _failure("MCP tools/list entries should be dictionaries.")
		var listed_name := str((listed_tool as Dictionary).get("name", ""))
		if not ToolCatalogManifest.is_valid_mcp_tool_name(listed_name):
			return _failure("MCP tools/list item name should follow MCP 2025-11-25 naming guidance: %s" % listed_name)
	if exposed_names.has("system_help"):
		return _failure("Tool loader should remove system_help from the public tools/list surface.")
	if not _loader.is_tool_exposed("system_help"):
		return _failure("Tool loader should keep system_help callable only for a legacy replacement error.")
	if exposed_names.has("system_tool_catalog"):
		return _failure("Tool loader should remove system_tool_catalog from the public tool surface.")
	if not _loader.is_tool_exposed("system_tool_catalog"):
		return _failure("Tool loader should keep system_tool_catalog legacy calls routable for removal guidance.")
	if not exposed_names.has("system_project_state"):
		return _failure("Tool loader did not expose system_project_state under the default tool access provider.")
	if not exposed_names.has("system_editor_state"):
		return _failure("Tool loader did not expose system_editor_state under the default tool access provider.")
	if not exposed_names.has("system_editor_plugin_control"):
		return _failure("Tool loader did not expose system_editor_plugin_control under the default tool access provider.")
	if not exposed_names.has("system_editor_evidence"):
		return _failure("Tool loader did not expose system_editor_evidence under the default tool access provider.")
	if not exposed_names.has("system_settings_dialog"):
		return _failure("Tool loader did not expose system_settings_dialog under the default tool access provider.")
	if not exposed_names.has("system_inspector"):
		return _failure("Tool loader did not expose system_inspector under the default tool access provider.")
	for removed_plugin_tool_name in ["system_plugin_reload", "system_plugin_update"]:
		if exposed_names.has(removed_plugin_tool_name):
			return _failure("Tool loader should remove %s from public MCP exposure." % removed_plugin_tool_name)
		if not _loader.is_tool_exposed(removed_plugin_tool_name):
			return _failure("Tool loader should keep legacy %s calls routable to removal guidance." % removed_plugin_tool_name)
	if not exposed_names.has("system_plugin_maintenance"):
		return _failure("Tool loader did not expose the high-level system_plugin_maintenance entry.")
	if not exposed_names.has("system_dap_debugger"):
		return _failure("Tool loader did not expose the high-level system_dap_debugger entry.")
	if exposed_names.has("system_tool_activity"):
		return _failure("Tool loader should remove system_tool_activity from public MCP exposure.")
	if not _loader.is_tool_exposed("system_tool_activity"):
		return _failure("Tool loader should keep legacy system_tool_activity calls routable to removal guidance.")
	if exposed_names.has("system_editor_log"):
		return _failure("Tool loader should remove system_editor_log from public MCP exposure.")
	if not _loader.is_tool_exposed("system_editor_log"):
		return _failure("Tool loader should keep legacy system_editor_log calls routable to removal guidance.")
	if not exposed_names.has("system_scene_inspect"):
		return _failure("Tool loader did not expose the high-level system_scene_inspect entry.")
	for removed_scene_tool_name in ["system_scene_validate", "system_scene_analyze"]:
		if exposed_names.has(removed_scene_tool_name):
			return _failure("Tool loader should remove %s from public MCP exposure." % removed_scene_tool_name)
		if not _loader.is_tool_exposed(removed_scene_tool_name):
			return _failure("Tool loader should keep legacy %s calls routable to removal guidance." % removed_scene_tool_name)
	for runtime_tool_name in ["system_runtime_control", "system_runtime_step"]:
		if not exposed_names.has(runtime_tool_name):
			return _failure("Tool loader did not expose runtime tool '%s'." % runtime_tool_name)
	if not exposed_names.has("system_project_lifecycle"):
		return _failure("Tool loader did not expose the unified system_project_lifecycle entry.")
	for removed_tool_name in ["system_project_run", "system_project_stop"]:
		if exposed_names.has(removed_tool_name):
			return _failure("Tool loader should not expose removed project lifecycle entry '%s'." % removed_tool_name)
		if _loader.is_tool_exposed(removed_tool_name):
			return _failure("Tool loader should not keep removed project lifecycle entry '%s' callable." % removed_tool_name)
	for merged_runtime_tool_name in ["system_runtime_capture", "system_runtime_input"]:
		if exposed_names.has(merged_runtime_tool_name):
			return _failure("Tool loader should merge runtime I/O into system_runtime_step, not expose '%s'." % merged_runtime_tool_name)
	for deprecated_name in ["debug_log", "filesystem_file", "resource_manage"]:
		if exposed_names.has(deprecated_name):
			return _failure("Tool loader still exposed deprecated compatibility tool '%s'." % deprecated_name)
	var all_tool_names: Array[String] = []
	var all_full_tool_names: Array[String] = []
	for tool_def in all_tools:
		all_tool_names.append(str(tool_def.get("name", "")))
		all_full_tool_names.append(str(tool_def.get("full_name", tool_def.get("name", ""))))
	if all_tool_names.has("file") or all_full_tool_names.has("filesystem_file"):
		return _failure("Tool loader should remove the legacy filesystem_file definition.")
	if _loader.is_tool_exposed("filesystem_file"):
		return _failure("Tool loader should not keep legacy filesystem_file callable through public exposure.")
	for canonical_filesystem_tool_name in ["filesystem_directory", "filesystem_file_read", "filesystem_file_write", "filesystem_file_manage", "filesystem_json", "filesystem_search"]:
		if not all_full_tool_names.has(canonical_filesystem_tool_name):
			return _failure("Tool loader should keep canonical filesystem replacement tool '%s'." % canonical_filesystem_tool_name)
	if all_tool_names.has("resource_manage"):
		return _failure("Tool loader should remove the legacy resource_manage definition.")
	for canonical_resource_tool_name in ["resource_query", "resource_create", "resource_file_ops"]:
		if not all_tool_names.has(canonical_resource_tool_name):
			return _failure("Tool loader should keep canonical resource replacement tool '%s'." % canonical_resource_tool_name)
	if _loader.is_tool_exposed("resource_manage"):
		return _failure("Tool loader should not keep legacy resource_manage callable through public exposure.")
	var removed_resource_result: Dictionary = await _loader.execute_tool_async("resource", "manage", {"action": "create", "type": "Resource", "path": "res://Tmp/removed_resource_manage.tres"})
	if bool(removed_resource_result.get("success", true)):
		return _failure("Tool loader should not execute removed resource_manage through the resource domain.")
	var replacement_resource_path := "res://Tmp/godot_dotnet_mcp_tool_loader_contracts/removed_resource_manage.tres"
	var create_replacement_resource: Dictionary = await _loader.execute_tool_async("resource", "create", {"type": "Resource", "path": replacement_resource_path})
	if not bool(create_replacement_resource.get("success", false)):
		return _failure("Tool loader should create a resource fixture before executing resource_manage replacement guidance.")
	for resource_file_action in ["reload", "delete"]:
		var removed_resource_guidance: Dictionary = _loader.build_removed_public_tool_result("resource_manage", {"action": resource_file_action, "path": "res://Tmp/removed_resource_manage.tres"})
		var removed_resource_arguments := _replacement_arguments(removed_resource_guidance)
		if str(removed_resource_arguments.get("action", "")) != resource_file_action:
			return _failure("Tool loader removed resource_manage %s guidance should preserve replacement action." % resource_file_action)
		if str(removed_resource_arguments.get("source", "")) != "res://Tmp/removed_resource_manage.tres":
			return _failure("Tool loader removed resource_manage %s guidance should map path to resource_file_ops source." % resource_file_action)
		if removed_resource_arguments.has("path"):
			return _failure("Tool loader removed resource_manage %s guidance should not emit schema-invalid path argument." % resource_file_action)
		var executable_replacement_args := removed_resource_arguments.duplicate(true)
		executable_replacement_args["source"] = replacement_resource_path
		var replacement_execution: Dictionary = await _loader.execute_tool_async("resource", "file_ops", executable_replacement_args)
		if not bool(replacement_execution.get("success", false)):
			return _failure("Tool loader resource_manage %s replacement guidance should execute successfully through resource_file_ops." % resource_file_action)
	if all_tool_names.has("debug_log"):
		return _failure("Tool loader should remove the legacy debug_log definition.")
	for canonical_debug_tool_name in ["debug_log_write", "debug_log_buffer"]:
		if not all_tool_names.has(canonical_debug_tool_name):
			return _failure("Tool loader should keep canonical debug replacement tool '%s'." % canonical_debug_tool_name)
	if _loader.is_tool_exposed("debug_log"):
		return _failure("Tool loader should not keep legacy debug_log callable through public exposure.")
	var removed_debug_result: Dictionary = await _loader.execute_tool_async("debug", "log", {"action": "print", "message": "removed debug_log"})
	if bool(removed_debug_result.get("success", true)):
		return _failure("Tool loader should not execute removed debug_log through the debug domain.")

	_loader._state_store.tool_definitions_by_category.clear()
	_loader._state_store.tool_definitions_by_category["user"] = [
		{
			"name": "contract_probe",
			"description": "Contract probe user tool",
			"parameters": {}
		}
	]
	if not _loader.is_tool_exposed("user_contract_probe"):
		return _failure("Tool loader should expose user tools when the manifest marks the user category public.")
	var user_probe_found := false
	for user_tool_def in _loader.get_exposed_tool_definitions():
		if str(user_tool_def.get("name", "")) == "user_contract_probe":
			user_probe_found = str(user_tool_def.get("category", "")) == "user"
			break
	if not user_probe_found:
		return _failure("Tool loader should include public user tools in exposed definitions with the user category.")

	var runtime_control_result: Dictionary = await _loader.execute_tool_async("system", "runtime_control", {"action": "status"})
	if not bool(runtime_control_result.get("success", false)):
		return _failure("Tool loader execute_tool_async should route system_runtime_control successfully.")
	var runtime_control_data = runtime_control_result.get("data", {})
	if not (runtime_control_data is Dictionary) or bool((runtime_control_data as Dictionary).get("armed", true)):
		return _failure("Tool loader runtime control status did not return the expected armed flag.")

	var editor_state_result: Dictionary = await _loader.execute_tool_async("system", "editor_state", {})
	if not bool(editor_state_result.get("success", false)):
		return _failure("Tool loader should route system_editor_state successfully even when editor-only sections are unavailable.")
	var editor_state_data = editor_state_result.get("data", {})
	if not (editor_state_data is Dictionary):
		return _failure("Tool loader system_editor_state should return a dictionary payload.")
	var editor_section = (editor_state_data as Dictionary).get("editor", {})
	if not (editor_section is Dictionary):
		return _failure("Tool loader system_editor_state should include the editor section.")
	if bool((editor_section as Dictionary).get("available", true)):
		return _failure("Tool loader system_editor_state should report editor.available=false in headless mode.")
	tool_access_provider.blocked_categories = {"system": true}
	tool_access_provider.denied_messages = {"system": "System tools disabled by contract."}
	var access_denied_result: Dictionary = await _loader.execute_tool_async("system", "editor_state", {})
	if bool(access_denied_result.get("success", true)):
		return _failure("Tool loader access service should block execution for non-executable categories.")
	if str(access_denied_result.get("error", "")) != "System tools disabled by contract.":
		return _failure("Tool loader access service should return provider denied messages for blocked execution.")
	tool_access_provider.blocked_categories.clear()
	tool_access_provider.denied_messages.clear()

	var editor_evidence_result: Dictionary = await _loader.execute_tool_async("system", "editor_evidence", {"action": "status"})
	if not bool(editor_evidence_result.get("success", false)):
		return _failure("Tool loader should route system_editor_evidence status successfully.")
	var editor_evidence_data = editor_evidence_result.get("data", {})
	if not (editor_evidence_data is Dictionary) or not (((editor_evidence_data as Dictionary).get("surfaces", []) as Array).has("active_dialog")):
		return _failure("Tool loader system_editor_evidence should return available capture surfaces.")

	var settings_dialog_result: Dictionary = await _loader.execute_tool_async("system", "settings_dialog", {
		"action": "status",
		"surface": "project_settings"
	})
	if not bool(settings_dialog_result.get("success", false)):
		return _failure("Tool loader should route system_settings_dialog status successfully.")
	var settings_dialog_data = settings_dialog_result.get("data", {})
	if not (settings_dialog_data is Dictionary) or str((settings_dialog_data as Dictionary).get("surface", "")) != "project_settings":
		return _failure("Tool loader system_settings_dialog should return a settings surface payload.")
	var inspector_result: Dictionary = await _loader.execute_tool_async("system", "inspector", {"action": "status"})
	var inspector_data = inspector_result.get("data", {})
	if not (inspector_data is Dictionary) or not (inspector_data as Dictionary).has("available"):
		return _failure("Tool loader should route system_inspector status and return an Inspector workflow payload.")

	var project_state_result: Dictionary = await _loader.execute_tool_async("system", "project_state", {"include_runtime_health": true})
	if not bool(project_state_result.get("success", false)):
		return _failure("Tool loader should route system_project_state(include_runtime_health=true) successfully.")
	var project_state_data = project_state_result.get("data", {})
	if not (project_state_data is Dictionary):
		return _failure("Tool loader system_project_state should return a dictionary payload.")
	var runtime_health = (project_state_data as Dictionary).get("runtime_health", {})
	if not (runtime_health is Dictionary):
		return _failure("Tool loader system_project_state should include runtime_health when requested.")
	if not ((runtime_health as Dictionary).get("self_diagnostics", {}) is Dictionary):
		return _failure("Tool loader system_project_state runtime_health should include self_diagnostics.")
	var project_state_summary_result: Dictionary = await _loader.execute_tool_async("system", "project_state", {"summary": true})
	if not bool(project_state_summary_result.get("success", false)):
		return _failure("Tool loader should route system_project_state(summary=true) successfully.")
	var project_state_summary_data = project_state_summary_result.get("data", {})
	if not (project_state_summary_data is Dictionary) or not bool((project_state_summary_data as Dictionary).get("summary", false)):
		return _failure("Tool loader system_project_state(summary=true) should return a compact summary payload.")
	if (project_state_summary_data as Dictionary).has("scene_paths") or (project_state_summary_data as Dictionary).has("script_paths"):
		return _failure("Tool loader system_project_state(summary=true) should omit large path arrays.")
	var project_state_sections_result: Dictionary = await _loader.execute_tool_async("system", "project_state", {"sections": ["summary"]})
	if not bool(project_state_sections_result.get("success", false)):
		return _failure("Tool loader should route system_project_state sections successfully.")
	var project_state_sections_data = project_state_sections_result.get("data", {})
	if not (project_state_sections_data is Dictionary) or not (((project_state_sections_data as Dictionary).get("sections", {}) as Dictionary).has("summary")):
		return _failure("Tool loader system_project_state sections should return the requested summary section.")
	var project_state_context_result: Dictionary = await _loader.execute_tool_async("system", "project_state", {
		"summary": true,
		"_mcp_context": {
			"agent_id": "loader-contract-agent",
			"purpose": "verify loader-level activity"
		}
	})
	if not bool(project_state_context_result.get("success", false)):
		return _failure("Tool loader should execute ordinary tools with _mcp_context successfully.")
	var loader_activity = project_state_context_result.get("activity", {})
	if not (loader_activity is Dictionary) or str((loader_activity as Dictionary).get("call_id", "")).is_empty():
		return _failure("Tool loader should attach activity summaries to ordinary tool results.")
	var registry_status: Dictionary = _loader.get_tool_activity_registry().get_status()
	var registry_recent = registry_status.get("recent", [])
	if not (registry_recent is Array) or (registry_recent as Array).is_empty():
		return _failure("Tool loader activity registry should retain recent ordinary tool calls.")
	var registry_context = (((registry_recent as Array)[0] as Dictionary).get("agent_context", {}) as Dictionary)
	if str(registry_context.get("agent_id", "")) != "loader-contract-agent":
		return _failure("Tool loader should retain sanitized _mcp_context in the activity registry.")
	var execution_context: Dictionary = _loader.call("_build_execution_context")
	var begin_tool_activity: Callable = execution_context.get("begin_tool_activity", Callable())
	var finish_tool_activity: Callable = execution_context.get("finish_tool_activity", Callable())
	if not begin_tool_activity.is_valid() or not finish_tool_activity.is_valid():
		return _failure("Tool loader execution context should expose activity callbacks.")
	var plain_activity_record: Dictionary = begin_tool_activity.call("system", "project_state", {"summary": true}, {})
	var plain_activity_result: Dictionary = finish_tool_activity.call({
		"success": true,
		"data": {"summary": true},
		"activity": {
			"user_supplied": true
		},
		"message": "ok"
	}, plain_activity_record)
	var injected_activity = plain_activity_result.get("activity", {})
	if not (injected_activity is Dictionary) or str((injected_activity as Dictionary).get("call_id", "")).is_empty():
		return _failure("Tool loader should keep protocol activity summaries at top level.")
	var preserved_activity_data = plain_activity_result.get("data", {})
	if not (preserved_activity_data is Dictionary) or not ((((preserved_activity_data as Dictionary).get("activity", {}) as Dictionary).get("user_supplied", false))):
		return _failure("Tool loader should preserve non-protocol tool activity payloads inside data.")

	var help_result: Dictionary = await _loader.execute_tool_async("system", "help", {"include_tools": true})
	if bool(help_result.get("success", true)):
		return _failure("Tool loader system_help legacy call should return a removal error.")
	var help_data = help_result.get("data", {})
	if not (help_data is Dictionary):
		return _failure("Tool loader system_help removal error should return a dictionary payload.")
	if str((help_data as Dictionary).get("error_type", "")) != "removed_public_tool":
		return _failure("Tool loader system_help removal error should include removed_public_tool.")
	var replacement_resources = (help_data as Dictionary).get("replacement_resources", [])
	if not (replacement_resources is Array) or not (replacement_resources as Array).has("godot-dotnet-mcp://guides/index"):
		return _failure("Tool loader system_help removal error should include replacement guide resource URIs.")
	var catalog_result: Dictionary = await _loader.execute_tool_async("system", "tool_catalog", {"query": "runtime", "limit": 5})
	if bool(catalog_result.get("success", false)):
		return _failure("Tool loader should reject legacy system_tool_catalog calls with removal guidance.")
	var catalog_data = catalog_result.get("data", {})
	if not (catalog_data is Dictionary) or str((catalog_data as Dictionary).get("error_type", "")) != "removed_public_tool":
		return _failure("Tool loader system_tool_catalog removal response should expose error_type=removed_public_tool.")
	if not (((catalog_data as Dictionary).get("replacement_resources", []) as Array).has("godot-dotnet-mcp://tools/catalog/visible")):
		return _failure("Tool loader system_tool_catalog removal response should point to the visible catalog resource.")
	var activity_result: Dictionary = await _loader.execute_tool_async("system", "tool_activity", {"action": "status"})
	if bool(activity_result.get("success", true)):
		return _failure("Tool loader legacy system_tool_activity calls should return removal guidance.")
	var activity_data = activity_result.get("data", {})
	if not (activity_data is Dictionary) or str((activity_data as Dictionary).get("error_type", "")) != "removed_public_tool":
		return _failure("Tool loader system_tool_activity removal guidance should expose error_type=removed_public_tool.")
	if not (((activity_data as Dictionary).get("replacement_resources", []) as Array).has("godot-dotnet-mcp://activity/status")):
		return _failure("Tool loader system_tool_activity removal guidance should point to activity/status.")
	var editor_log_result: Dictionary = await _loader.execute_tool_async("system", "editor_log", {"action": "get_errors"})
	if bool(editor_log_result.get("success", true)):
		return _failure("Tool loader legacy system_editor_log calls should return removal guidance.")
	var editor_log_data = editor_log_result.get("data", {})
	if not (editor_log_data is Dictionary) or str((editor_log_data as Dictionary).get("error_type", "")) != "removed_public_tool":
		return _failure("Tool loader system_editor_log removal guidance should expose error_type=removed_public_tool.")
	if not (((editor_log_data as Dictionary).get("replacement_resources", []) as Array).has("godot-dotnet-mcp://logs/editor/errors")):
		return _failure("Tool loader system_editor_log removal guidance should point to editor log resources.")
	var clear_log_result: Dictionary = await _loader.execute_tool_async("system", "editor_log", {"action": "clear_output"})
	var clear_log_data = clear_log_result.get("data", {})
	var clear_replacements = (clear_log_data as Dictionary).get("replacement_tools", []) if clear_log_data is Dictionary else []
	if not (clear_replacements is Array) or (clear_replacements as Array).is_empty() or str(((clear_replacements as Array)[0] as Dictionary).get("name", "")) != "system_editor_control":
		return _failure("Tool loader system_editor_log clear_output guidance should point to system_editor_control.")
	var filtered_activity_result: Dictionary = await _loader.execute_tool_async("system", "tool_activity", {
		"action": "recent",
		"state": "completed",
		"tool": "project_state",
		"threshold_ms": 0.0,
		"failure_limit": 1,
		"limit": 5
	})
	if bool(filtered_activity_result.get("success", true)):
		return _failure("Tool loader filtered system_tool_activity legacy calls should also return removal guidance.")
	for removed_plugin_case in [
		{"tool": "plugin_reload", "removed": "system_plugin_reload", "replacement_action": "reload", "args": {"action": "full_reload_plugin"}},
		{"tool": "plugin_update", "removed": "system_plugin_update", "replacement_action": "status", "args": {"action": "get_current"}},
		{"tool": "plugin_update", "removed": "system_plugin_update", "replacement_action": "start_update", "args": {"action": "start_sync"}},
		{"tool": "plugin_update", "removed": "system_plugin_update", "replacement_action": "refresh_update_refs", "args": {"action": "discover_refs", "force_refresh": false}}
	]:
		var removed_plugin_result: Dictionary = await _loader.execute_tool_async("system", str(removed_plugin_case.get("tool", "")), removed_plugin_case.get("args", {}))
		if bool(removed_plugin_result.get("success", true)):
			return _failure("Tool loader legacy %s calls should return removal guidance." % str(removed_plugin_case.get("removed", "")))
		if not _is_removed_plugin_maintenance_tool(removed_plugin_result, str(removed_plugin_case.get("removed", "")), str(removed_plugin_case.get("replacement_action", ""))):
			return _failure("Tool loader %s removal guidance should point to system_plugin_maintenance." % str(removed_plugin_case.get("removed", "")))
		if str(removed_plugin_case.get("replacement_action", "")) == "refresh_update_refs":
			var replacement_args := _replacement_arguments(removed_plugin_result)
			if bool(replacement_args.get("force_refresh", true)):
				return _failure("Tool loader system_plugin_update discover_refs guidance should preserve force_refresh=false.")
	for removed_scene_case in [
		{"tool": "scene_validate", "removed": "system_scene_validate", "action": "validate"},
		{"tool": "scene_analyze", "removed": "system_scene_analyze", "action": "analyze"}
	]:
		var removed_scene_result: Dictionary = await _loader.execute_tool_async("system", str(removed_scene_case.get("tool", "")), {"scene": "res://Main.tscn"})
		if bool(removed_scene_result.get("success", true)):
			return _failure("Tool loader legacy %s calls should return removal guidance." % str(removed_scene_case.get("removed", "")))
		if not _is_removed_scene_tool(removed_scene_result, str(removed_scene_case.get("removed", "")), str(removed_scene_case.get("action", ""))):
			return _failure("Tool loader %s removal guidance should point to system_scene_inspect." % str(removed_scene_case.get("removed", "")))

	_loader.set_disabled_tools(["system_project_state"])
	if _loader.is_tool_exposed("system_project_state"):
		return _failure("Disabled tool system_project_state should no longer be exposed.")

	var disabled_status: Dictionary = _loader.get_tool_loader_status()
	if int(disabled_status.get("exposed_tool_count", 0)) >= int(status.get("exposed_tool_count", 0)):
		return _failure("Disabling system_project_state did not reduce the exposed tool count.")

	_loader.set_disabled_tools(["system_project_lifecycle"])
	if _loader.is_tool_exposed("system_project_lifecycle"):
		return _failure("Disabled tool system_project_lifecycle should no longer be exposed.")
	for removed_tool_name in ["system_project_run", "system_project_stop"]:
		if _loader.is_tool_exposed(removed_tool_name):
			return _failure("Removed project lifecycle entry '%s' should remain unavailable even when system_project_lifecycle is disabled." % removed_tool_name)

	return {
		"name": "tool_loader_contracts",
		"success": true,
		"error": "",
		"details": {
			"initial_tool_count": int(summary.get("tool_count", 0)),
			"initial_exposed_tool_count": int(summary.get("exposed_tool_count", 0)),
			"disabled_exposed_tool_count": int(disabled_status.get("exposed_tool_count", 0)),
			"healthy_status": str(status.get("status", "")),
			"lsp_service_generation": int(lsp_snapshot.get("service_generation", 0))
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	if _loader != null and _loader.has_method("shutdown"):
		_loader.shutdown()
	_loader = null


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_loader_contracts",
		"success": false,
		"error": message
	}


func _is_removed_scene_tool(result: Dictionary, removed_tool: String, replacement_action: String) -> bool:
	var data = result.get("data", {})
	if not (data is Dictionary):
		return false
	var data_dict := data as Dictionary
	if str(data_dict.get("error_type", "")) != "removed_public_tool":
		return false
	if str(data_dict.get("removed_tool", "")) != removed_tool:
		return false
	if not ((data_dict.get("replacement_resources", []) as Array).has("godot-dotnet-mcp://scene/{path}")):
		return false
	var replacement_tools = data_dict.get("replacement_tools", [])
	if not (replacement_tools is Array) or (replacement_tools as Array).is_empty():
		return false
	var replacement = (replacement_tools as Array)[0]
	if not (replacement is Dictionary):
		return false
	var replacement_arguments = (replacement as Dictionary).get("arguments", {})
	return str((replacement as Dictionary).get("name", "")) == "system_scene_inspect" and replacement_arguments is Dictionary and str((replacement_arguments as Dictionary).get("action", "")) == replacement_action


func _is_removed_plugin_maintenance_tool(result: Dictionary, removed_tool: String, replacement_action: String) -> bool:
	var data = result.get("data", {})
	if not (data is Dictionary):
		return false
	var data_dict := data as Dictionary
	if str(data_dict.get("error_type", "")) != "removed_public_tool":
		return false
	if str(data_dict.get("removed_tool", "")) != removed_tool:
		return false
	var replacement_tools = data_dict.get("replacement_tools", [])
	if not (replacement_tools is Array) or (replacement_tools as Array).is_empty():
		return false
	var replacement = (replacement_tools as Array)[0]
	if not (replacement is Dictionary):
		return false
	var replacement_arguments = (replacement as Dictionary).get("arguments", {})
	return str((replacement as Dictionary).get("name", "")) == "system_plugin_maintenance" and replacement_arguments is Dictionary and str((replacement_arguments as Dictionary).get("action", "")) == replacement_action


func _replacement_arguments(result: Dictionary) -> Dictionary:
	var data = result.get("data", {})
	if not (data is Dictionary):
		return {}
	var replacement_tools = (data as Dictionary).get("replacement_tools", [])
	if not (replacement_tools is Array) or (replacement_tools as Array).is_empty():
		return {}
	var replacement = (replacement_tools as Array)[0]
	if not (replacement is Dictionary):
		return {}
	var replacement_arguments = (replacement as Dictionary).get("arguments", {})
	if replacement_arguments is Dictionary:
		return replacement_arguments
	return {}
