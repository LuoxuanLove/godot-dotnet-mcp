extends RefCounted

# {"name": "system_help_contracts"}

const SystemHelpImplScript = preload("res://addons/godot_dotnet_mcp/tools/system/impl_help.gd")
const MCPProtocolFacts = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd")


class FakeToolLoader extends RefCounted:
	func get_exposed_tool_definitions() -> Array[Dictionary]:
		return [
			{"name": "system_editor_control"},
			{"name": "system_editor_evidence"},
			{"name": "system_project_state"},
			{"name": "system_help"}
		]


func run_case(_tree: SceneTree) -> Dictionary:
	var impl = SystemHelpImplScript.new()
	impl.configure_runtime({"tool_loader": FakeToolLoader.new()})

	var tool_defs: Array[Dictionary] = impl.get_tools()
	if tool_defs.size() != 1:
		return _failure("system help implementation should expose exactly one tool definition.")
	if str(tool_defs[0].get("name", "")) != "help":
		return _failure("system help implementation should expose help as the local tool name.")

	var result: Dictionary = impl.execute("help", {})
	if not bool(result.get("success", false)):
		return _failure("system help should return a success payload.")
	var data = result.get("data", {})
	if not (data is Dictionary):
		return _failure("system help should return a dictionary payload.")
	var help_data: Dictionary = data
	var visual_guidance = help_data.get("visual_guidance", {})
	if not (visual_guidance is Dictionary):
		return _failure("system help should include visual guidance.")
	if not bool((visual_guidance as Dictionary).get("prefer_editor_screenshot", false)):
		return _failure("system help should explicitly recommend editor screenshots for UI judgment.")
	if str((visual_guidance as Dictionary).get("screenshot_tool", "")) != "system_editor_evidence":
		return _failure("system help should prefer system_editor_evidence as the self-describing screenshot tool.")
	if not (((visual_guidance as Dictionary).get("capture_surfaces", []) as Array).has("active_dialog")):
		return _failure("system help should expose editor evidence capture surfaces.")
	if not bool((visual_guidance as Dictionary).get("hidden_controls_supported", false)):
		return _failure("system help should explicitly state hidden controls can be enumerated.")
	var preference_order = (visual_guidance as Dictionary).get("ui_automation_preference_order", [])
	if not (preference_order is Array) or (preference_order as Array).size() != 3:
		return _failure("system help should expose the three-level UI automation preference order.")
	var expected_levels := ["semantic", "control", "mouse_fallback"]
	for index in expected_levels.size():
		var entry = (preference_order as Array)[index]
		if not (entry is Dictionary):
			return _failure("system help UI automation preference entry should be a dictionary.")
		var entry_dict := entry as Dictionary
		if str(entry_dict.get("level", "")) != expected_levels[index]:
			return _failure("system help UI automation preference order should keep %s at index %d." % [expected_levels[index], index])
	if not _preference_entry_has_tool((preference_order as Array)[0], "system_settings_dialog") or not _preference_entry_has_tool((preference_order as Array)[0], "system_inspector") or not _preference_entry_has_tool((preference_order as Array)[0], "system_editor_evidence") or not _preference_entry_has_action((preference_order as Array)[0], "capture") or not _preference_entry_has_action((preference_order as Array)[0], "activate_ui") or not _preference_entry_has_action((preference_order as Array)[0], "resolve_property"):
		return _failure("system help semantic UI preference should mention settings_dialog, inspector, editor_evidence, capture, activate_ui, and resolve_property.")
	if not _preference_entry_has_action((preference_order as Array)[1], "set_control_text") or not _preference_entry_has_action((preference_order as Array)[1], "press_popup_button"):
		return _failure("system help control-level UI preference should mention text and popup control actions.")
	if not _preference_entry_has_action((preference_order as Array)[2], "click_control") or not _preference_entry_has_action((preference_order as Array)[2], "hover_control"):
		return _failure("system help mouse fallback UI preference should mention click and hover fallback actions.")

	var schema = help_data.get("schema", {})
	if not (schema is Dictionary):
		return _failure("system help should include schema facts.")
	if str((schema as Dictionary).get("tool_schema_version", "")) != MCPProtocolFacts.get_tool_schema_version():
		return _failure("system help should expose the unified tool schema version.")
	if MCPProtocolFacts.get_tool_schema_version() != "2026-06-08.24":
		return _failure("system help contract should cover the current scene inspect schema version.")

	var exposed_tools: Array = help_data.get("exposed_system_tools", [])
	if not exposed_tools.has("system_help") or not exposed_tools.has("system_editor_control"):
		return _failure("system help should include exposed system tool names when requested.")
	var prompt_guides = help_data.get("prompt_guides", {})
	if not (prompt_guides is Dictionary):
		return _failure("system help should include MCP prompt guide discovery details.")
	var prompt_methods_text := JSON.stringify(prompt_guides)
	for expected_text in ["prompts/list", "prompts/get", "godot.project_orientation", "godot.content_authoring", "godot.debug_triage", "godot.reference_integrity", "godot.runtime_validation", "godot.editor_ui_control"]:
		if prompt_methods_text.find(expected_text) == -1:
			return _failure("system help prompt guide details should mention: %s" % expected_text)
	var capabilities = help_data.get("capabilities", {})
	if not (capabilities is Dictionary) or not (capabilities as Dictionary).has("prompts") or not (((capabilities as Dictionary).get("prompts", []) is Array)):
		return _failure("system help capabilities should include prompts as an explicit category.")
	var help_text := JSON.stringify(help_data)
	if help_text.find("focus_result") == -1 or help_text.find("resolve_row") == -1 or help_text.find("resolve_property") == -1 or help_text.find("system_inspector") == -1 or help_text.find("run_task") == -1 or help_text.find("system_editor_evidence") == -1 or help_text.find("active_dialog") == -1:
		return _failure("system help should mention current settings_dialog, inspector, and editor evidence workflow action names.")

	var compact_result: Dictionary = impl.execute("help", {"include_tools": false})
	if not bool(compact_result.get("success", false)):
		return _failure("system help include_tools=false should still succeed.")
	if (compact_result.get("data", {}) as Dictionary).has("exposed_system_tools"):
		return _failure("system help include_tools=false should omit exposed_system_tools.")

	return {
		"name": "system_help_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_schema_version": MCPProtocolFacts.get_tool_schema_version(),
			"tool_count": exposed_tools.size()
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "system_help_contracts",
		"success": false,
		"error": message
	}


func _preference_entry_has_tool(entry, tool_name: String) -> bool:
	if not (entry is Dictionary):
		return false
	var tools = (entry as Dictionary).get("tools", [])
	return tools is Array and (tools as Array).has(tool_name)


func _preference_entry_has_action(entry, action_name: String) -> bool:
	if not (entry is Dictionary):
		return false
	var actions = (entry as Dictionary).get("actions", [])
	return actions is Array and (actions as Array).has(action_name)
