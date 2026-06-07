extends RefCounted

const ToolLoaderScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader.gd")
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
	func is_tool_category_visible(_category: String) -> bool:
		return true

	func is_tool_category_executable(_category: String) -> bool:
		return true

	func get_tool_access_denied_message(_category: String) -> String:
		return "Tool category disabled"


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

	var exposed_names: Array[String] = []
	for tool_def in exposed_tools:
		var exposed_name := str(tool_def.get("name", ""))
		exposed_names.append(exposed_name)
		if not exposed_name.begins_with("system_"):
			return _failure("Public MCP exposure should remain high-level system-only, not permission-filtered atomic exposure: %s" % exposed_name)
	if not exposed_names.has("system_help"):
		return _failure("Tool loader did not expose system_help under the default tool access provider.")
	if not exposed_names.has("system_tool_catalog"):
		return _failure("Tool loader did not expose system_tool_catalog under the default tool access provider.")
	if not exposed_names.has("system_project_state"):
		return _failure("Tool loader did not expose system_project_state under the default tool access provider.")
	if not exposed_names.has("system_editor_state"):
		return _failure("Tool loader did not expose system_editor_state under the default tool access provider.")
	if not exposed_names.has("system_editor_plugin_control"):
		return _failure("Tool loader did not expose system_editor_plugin_control under the default tool access provider.")
	if not exposed_names.has("system_settings_dialog"):
		return _failure("Tool loader did not expose system_settings_dialog under the default tool access provider.")
	if not exposed_names.has("system_plugin_reload"):
		return _failure("Tool loader did not expose the stable system_plugin_reload lifecycle entry.")
	if not exposed_names.has("system_plugin_update"):
		return _failure("Tool loader did not expose the high-level system_plugin_update entry.")
	if not exposed_names.has("system_dap_debugger"):
		return _failure("Tool loader did not expose the high-level system_dap_debugger entry.")
	if not exposed_names.has("system_tool_activity"):
		return _failure("Tool loader did not expose the high-level system_tool_activity entry.")
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

	var settings_dialog_result: Dictionary = await _loader.execute_tool_async("system", "settings_dialog", {
		"action": "status",
		"surface": "project_settings"
	})
	if not bool(settings_dialog_result.get("success", false)):
		return _failure("Tool loader should route system_settings_dialog status successfully.")
	var settings_dialog_data = settings_dialog_result.get("data", {})
	if not (settings_dialog_data is Dictionary) or str((settings_dialog_data as Dictionary).get("surface", "")) != "project_settings":
		return _failure("Tool loader system_settings_dialog should return a settings surface payload.")

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
	var plain_activity_record: Dictionary = _loader.call("_begin_tool_activity", "system", "project_state", {"summary": true}, {})
	var plain_activity_result: Dictionary = _loader.call("_finish_tool_activity", {
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
	if not bool(help_result.get("success", false)):
		return _failure("Tool loader should route system_help successfully.")
	var help_data = help_result.get("data", {})
	if not (help_data is Dictionary):
		return _failure("Tool loader system_help should return a dictionary payload.")
	var visual_guidance = (help_data as Dictionary).get("visual_guidance", {})
	if not (visual_guidance is Dictionary) or not bool((visual_guidance as Dictionary).get("hidden_controls_supported", false)):
		return _failure("Tool loader system_help should expose hidden-control guidance.")
	var catalog_result: Dictionary = await _loader.execute_tool_async("system", "tool_catalog", {"query": "runtime", "limit": 5})
	if not bool(catalog_result.get("success", false)):
		return _failure("Tool loader should route system_tool_catalog successfully.")
	var catalog_data = catalog_result.get("data", {})
	if not (catalog_data is Dictionary) or not ((catalog_data as Dictionary).get("matches", []) is Array):
		return _failure("Tool loader system_tool_catalog should return a matches array.")
	var activity_result: Dictionary = await _loader.execute_tool_async("system", "tool_activity", {"action": "status"})
	if not bool(activity_result.get("success", false)):
		return _failure("Tool loader should route system_tool_activity successfully.")
	var activity_data = activity_result.get("data", {})
	if not (activity_data is Dictionary) or not (activity_data as Dictionary).has("running_count"):
		return _failure("Tool loader system_tool_activity should return activity counts.")

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
