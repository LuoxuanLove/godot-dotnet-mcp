extends RefCounted

# {"name": "plugin_usage_guide_service_contracts"}

const PluginUsageGuideServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_usage_guide_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var source_guard := _verify_plugin_entrypoint_delegates_usage_guides()
	if not source_guard.is_empty():
		return _failure(source_guard)

	var service = PluginUsageGuideServiceScript.new()
	var guides := [
		{"kind": "runtime", "payload": service.build_runtime_usage_guide(), "tools": ["plugin_runtime_state", "debug_runtime_bridge"]},
		{"kind": "evolution", "payload": service.build_evolution_usage_guide(), "tools": ["plugin_evolution_list_user_tools", "plugin_evolution_user_tool_audit"]},
		{"kind": "developer", "payload": service.build_developer_usage_guide(), "tools": ["plugin_developer_settings", "debug_runtime_bridge"]}
	]
	for guide in guides:
		var check := _verify_guide_payload(guide["kind"], guide["payload"], guide["tools"])
		if not check.is_empty():
			return _failure(check)

	return {"name": "plugin_usage_guide_service_contracts", "success": true, "error": ""}


func _verify_guide_payload(kind: String, payload: Dictionary, expected_tools: Array) -> String:
	if payload.get("success") != true:
		return "PluginUsageGuideService %s guide should return success." % kind
	if not (payload.get("data", {}) is Dictionary):
		return "PluginUsageGuideService %s guide should return dictionary data." % kind
	var data := payload.get("data", {}) as Dictionary
	for required in ["summary", "recommended_flow", "warnings"]:
		if not (data.get(required, []) is Array) or (data.get(required, []) as Array).is_empty():
			return "PluginUsageGuideService %s guide should include non-empty %s." % [kind, required]
	var flow: Array = data.get("recommended_flow", [])
	var flow_text := JSON.stringify(flow)
	for tool_name in expected_tools:
		if flow_text.find(str(tool_name)) == -1:
			return "PluginUsageGuideService %s guide should mention expected tool: %s" % [kind, str(tool_name)]
	if str(payload.get("message", "")).is_empty():
		return "PluginUsageGuideService %s guide should include a message." % kind
	return ""


func _verify_plugin_entrypoint_delegates_usage_guides() -> String:
	var plugin_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin.gd")
	var service_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_usage_guide_service.gd")
	if plugin_source.is_empty() or service_source.is_empty():
		return "Plugin usage guide sources should be readable."
	for required in [
		"PluginUsageGuideServiceScript.new()",
		"_ensure_plugin_usage_guide_service().build_runtime_usage_guide()",
		"_ensure_plugin_usage_guide_service().build_evolution_usage_guide()",
		"_ensure_plugin_usage_guide_service().build_developer_usage_guide()"
	]:
		if plugin_source.find(required) == -1:
			return "plugin.gd should delegate plugin usage guide responsibility: %s" % required
	for forbidden in [
		"Start with plugin_runtime_state before changing toggles or reload state.",
		"Self-evolution only manages User-category tools and never writes into builtin categories.",
		"Plugin developer tools are internal maintenance helpers for Dock-facing settings"
	]:
		if plugin_source.find(forbidden) != -1:
			return "plugin.gd should not retain plugin usage guide internals: %s" % forbidden
	for required_service in [
		"func build_runtime_usage_guide()",
		"func build_evolution_usage_guide()",
		"func build_developer_usage_guide()"
	]:
		if service_source.find(required_service) == -1:
			return "PluginUsageGuideService should own usage guide method: %s" % required_service
	return ""


func _failure(message: String, details: Dictionary = {}) -> Dictionary:
	return {"name": "plugin_usage_guide_service_contracts", "success": false, "error": message, "details": details}
