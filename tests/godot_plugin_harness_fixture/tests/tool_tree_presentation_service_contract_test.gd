extends RefCounted

# {"name": "tool_tree_presentation_service_contracts"}

const ToolTreePresentationService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_tree_presentation_service.gd")
const ToolCatalogSnapshotService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_catalog_snapshot_service.gd")


class FakeLoader extends RefCounted:
	func get_exposed_tool_definitions() -> Array:
		return [
			{"name": "system_project_state", "category": "system", "description": "Project state", "enabled": true, "inputSchema": {"type": "object", "properties": {}}},
			{"name": "system_runtime_control", "category": "system", "description": "Runtime control", "enabled": true, "inputSchema": {"type": "object", "properties": {"action": {"type": "string"}}}},
			{"name": "system_dap_debugger", "category": "system", "description": "DAP debugger", "enabled": true, "inputSchema": {"type": "object", "properties": {"action": {"type": "string"}}}},
			{"name": "system_help", "category": "system", "description": "Removed help", "enabled": true, "inputSchema": {"type": "object", "properties": {}}},
			{"name": "plugin_runtime_state", "category": "plugin_runtime", "description": "Internal plugin state", "enabled": true, "inputSchema": {"type": "object", "properties": {}}},
			{"name": "user_sample_tool", "category": "user", "description": "User tool", "enabled": true, "inputSchema": {"type": "object", "properties": {}}}
		]

	func get_tool_definitions() -> Array:
		return get_exposed_tool_definitions()

	func get_all_tools_by_category() -> Dictionary:
		return {
			"system": [
				{"name": "project_state", "full_name": "system_project_state", "category": "system", "enabled": true, "inputSchema": {"type": "object", "properties": {}}},
				{"name": "runtime_control", "full_name": "system_runtime_control", "category": "system", "enabled": true, "inputSchema": {"type": "object", "properties": {"action": {"type": "string"}}}},
				{"name": "dap_debugger", "full_name": "system_dap_debugger", "category": "system", "enabled": true, "inputSchema": {"type": "object", "properties": {"action": {"type": "string"}}}},
				{"name": "help", "full_name": "system_help", "category": "system", "enabled": true, "inputSchema": {"type": "object", "properties": {}}}
			],
			"runtime": [
				{"name": "control", "full_name": "runtime_control", "category": "runtime", "enabled": true, "inputSchema": {"type": "object", "properties": {"action": {"type": "string"}}}}
			],
			"dap": [
				{"name": "debugger", "full_name": "dap_debugger", "category": "dap", "enabled": true, "inputSchema": {"type": "object", "properties": {"action": {"type": "string"}}}}
			],
			"material": [
				{"name": "inspect", "full_name": "material_inspect", "category": "material", "enabled": true, "inputSchema": {"type": "object", "properties": {}}}
			],
			"plugin_runtime": [
				{"name": "state", "full_name": "plugin_runtime_state", "category": "plugin_runtime", "enabled": true, "inputSchema": {"type": "object", "properties": {}}}
			],
			"user": [
				{"name": "sample_tool", "full_name": "user_sample_tool", "category": "user", "enabled": true, "inputSchema": {"type": "object", "properties": {}}}
			]
		}

	func get_domain_states() -> Array:
		return [
			{"category": "system", "domain_key": "core", "loaded": true, "tool_count": 4, "enabled_tool_count": 4},
			{"category": "runtime", "domain_key": "core", "loaded": true, "tool_count": 1, "enabled_tool_count": 1},
			{"category": "dap", "domain_key": "core", "loaded": true, "tool_count": 1, "enabled_tool_count": 1},
			{"category": "material", "domain_key": "visual", "loaded": true, "tool_count": 1, "enabled_tool_count": 1},
			{"category": "plugin_runtime", "domain_key": "plugin", "loaded": true, "tool_count": 1, "enabled_tool_count": 1},
			{"category": "user", "domain_key": "user", "loaded": true, "tool_count": 1, "enabled_tool_count": 1}
		]

	func get_tool_loader_status() -> Dictionary:
		return {"initialized": true, "load_error_count": 0}

	func is_public_removed_tool(tool_name: String) -> bool:
		return tool_name == "system_help"


func run_case(_tree: SceneTree) -> Dictionary:
	var loader := FakeLoader.new()
	var exposed := loader.get_exposed_tool_definitions()
	var all_tools := loader.get_all_tools_by_category()
	var agent_tree := ToolTreePresentationService.build_agent_tool_tree(exposed)
	var internal_tree := ToolTreePresentationService.build_internal_executor_tree(all_tools, exposed, loader.get_domain_states())
	var diagnostics_tree := ToolTreePresentationService.build_diagnostics_tree(exposed, all_tools, loader.get_tool_loader_status())

	if str(agent_tree.get("view", "")) != "agent_tools":
		return _failure("Agent tool tree should identify the default Agent Tools view.")
	if str(agent_tree.get("signature", "")).is_empty() or str(internal_tree.get("signature", "")).is_empty() or str(diagnostics_tree.get("signature", "")).is_empty():
		return _failure("Tool tree presentation layers should expose reusable signatures for UI refresh checks.")
	if str(agent_tree.get("signature", "")) == str(internal_tree.get("signature", "")):
		return _failure("Tool tree presentation signatures should distinguish the active view.")
	if _find_node(agent_tree.get("toolTree", []), "public_tool", "system_project_state").is_empty():
		return _failure("Agent tool tree should include canonical system tools.")
	if _find_node(agent_tree.get("toolTree", []), "public_tool", "user_sample_tool").is_empty():
		return _failure("Agent tool tree should include user tools.")
	if not _find_node(agent_tree.get("toolTree", []), "public_tool", "runtime_control").is_empty():
		return _failure("Agent tool tree should not expose runtime executor tools as public defaults.")
	if not _find_node(agent_tree.get("toolTree", []), "public_tool", "dap_debugger").is_empty():
		return _failure("Agent tool tree should not expose dap executor tools as public defaults.")
	if not _find_node(agent_tree.get("toolTree", []), "public_tool", "plugin_runtime_state").is_empty():
		return _failure("Agent tool tree should not expose plugin runtime internals as public defaults.")
	if not _find_node(agent_tree.get("toolTree", []), "public_tool", "system_help").is_empty():
		return _failure("Agent tool tree should exclude removed public tools from the default view.")
	var runtime_group := _find_node(agent_tree.get("toolTree", []), "tool_group", "runtime_debugging")
	if runtime_group.is_empty():
		return _failure("Agent tool tree should group runtime/debugging canonical tools.")
	if _count_nodes(runtime_group.get("children", []), "system_dap_debugger") != 1:
		return _failure("DAP should appear exactly once in Agent Tools.")
	if _count_nodes(runtime_group.get("children", []), "system_runtime_control") != 1:
		return _failure("Runtime control should appear exactly once in Agent Tools.")
	var project_state_metadata: Dictionary = (agent_tree.get("toolMetadataByName", {}) as Dictionary).get("system_project_state", {})
	if str(project_state_metadata.get("visibility", "")) != "public" or str(project_state_metadata.get("callability", "")) != "callable":
		return _failure("Agent tool metadata should expose visibility and callability.")

	if _find_node(internal_tree.get("toolTree", []), "executor_category", "runtime").is_empty():
		return _failure("Internal executor tree should include runtime executor category.")
	if _find_node(internal_tree.get("toolTree", []), "executor_category", "dap").is_empty():
		return _failure("Internal executor tree should include dap executor category.")
	if _find_node(internal_tree.get("toolTree", []), "executor_category", "material").is_empty():
		return _failure("Internal executor tree should include visual/internal executor categories.")
	var runtime_executor_tool := _find_node(internal_tree.get("toolTree", []), "executor_tool", "runtime_control")
	if runtime_executor_tool.is_empty() or str(runtime_executor_tool.get("visibility", "")) != "internal":
		return _failure("Internal executor tree should label non-public executor tools as internal.")

	var legacy_help := _find_node(diagnostics_tree.get("toolTree", []), "legacy_tool", "system_help")
	if legacy_help.is_empty():
		return _failure("Diagnostics tree should include removed legacy tools.")
	if str(legacy_help.get("callability", "")) != "compat_callable" or str(legacy_help.get("replacement", "")) != "godot-dotnet-mcp://guides/index":
		return _failure("Diagnostics tree should explain legacy replacement guidance.")

	var snapshot := ToolCatalogSnapshotService.build_snapshot(loader)
	if not bool(snapshot.get("success", false)):
		return _failure("Snapshot should build for the fake loader.")
	if not snapshot.has("agent_tool_presentation") or not snapshot.has("internal_executor_presentation") or not snapshot.has("tool_diagnostics_presentation"):
		return _failure("Snapshot should expose the new presentation model layers.")
	var snapshot_agent: Dictionary = snapshot.get("agent_tool_presentation", {})
	if not _find_node(snapshot_agent.get("toolTree", []), "public_tool", "system_project_state").is_empty() and _find_node(snapshot_agent.get("toolTree", []), "public_tool", "system_help").is_empty():
		return {"name": "tool_tree_presentation_service_contracts", "success": true, "error": ""}
	return _failure("Snapshot agent presentation should include canonical tools and exclude removed tools.")


func _find_node(nodes: Array, kind: String, key: String) -> Dictionary:
	for node in nodes:
		if not (node is Dictionary):
			continue
		var node_dict := node as Dictionary
		if str(node_dict.get("kind", "")) == kind and str(node_dict.get("key", "")) == key:
			return node_dict
		var child := _find_node(node_dict.get("children", []), kind, key)
		if not child.is_empty():
			return child
	return {}


func _count_nodes(nodes: Array, key: String) -> int:
	var count := 0
	for node in nodes:
		if not (node is Dictionary):
			continue
		var node_dict := node as Dictionary
		if str(node_dict.get("key", "")) == key:
			count += 1
		count += _count_nodes(node_dict.get("children", []), key)
	return count


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_tree_presentation_service_contracts",
		"success": false,
		"error": message
	}
