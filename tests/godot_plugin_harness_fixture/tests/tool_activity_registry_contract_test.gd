extends RefCounted

# {"name": "tool_activity_registry_contracts"}

const ToolActivityRegistryScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_activity_registry.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var registry = ToolActivityRegistryScript.new()
	var long_notes := "n".repeat(220)
	var first: Dictionary = registry.begin_call(
		"system_project_state",
		"system",
		"project_state",
		{"action": "status", "path": "res://project.godot"},
		{
			"agent_id": "registry-contract-agent",
			"purpose": "verify state transitions",
			"notes": long_notes,
			"secret": "should not be recorded"
		},
		{
			"connection_id": "conn-1",
			"request_id": "req-1",
			"transport": "http"
		}
	)
	var second: Dictionary = registry.begin_call(
		"system_tool_activity",
		"system",
		"tool_activity",
		{"action": "status"},
		{"agent_role": "observer"},
		{"transport": "stdio"}
	)

	var status: Dictionary = registry.get_status()
	if int(status.get("running_count", 0)) != 2:
		return _failure("Tool activity registry should report both running calls.")
	var order = status.get("execution_order", [])
	if not (order is Array) or (order as Array).size() != 2:
		return _failure("Tool activity registry should expose running execution order.")
	if str(((order as Array)[0] as Dictionary).get("call_id", "")) != str(first.get("call_id", "")):
		return _failure("Tool activity registry should preserve begin order for running calls.")

	var running_lookup: Dictionary = registry.get_call(str(first.get("call_id", "")))
	if not bool(running_lookup.get("found", false)):
		return _failure("Tool activity registry should return running calls from get_call.")
	var running_call = running_lookup.get("call", {})
	if not (running_call is Dictionary) or str((running_call as Dictionary).get("state", "")) != "running":
		return _failure("Tool activity registry get_call should preserve running state.")
	var context = ((running_call as Dictionary).get("agent_context", {}) as Dictionary)
	if context.has("secret"):
		return _failure("Tool activity registry should drop unsupported agent context keys.")
	if str(context.get("notes", "")).length() != 160:
		return _failure("Tool activity registry should truncate long agent context text.")
	var scope = ((running_call as Dictionary).get("scope", {}) as Dictionary)
	if str(scope.get("path", "")) != "res://project.godot":
		return _failure("Tool activity registry should retain lightweight scope hints.")

	var finished: Dictionary = registry.finish_call(str(first.get("call_id", "")), false, "contract failure")
	if str(finished.get("state", "")) != "failed":
		return _failure("Tool activity registry should mark failed calls.")
	if str(finished.get("error", "")) != "contract failure":
		return _failure("Tool activity registry should retain failed call error messages.")

	status = registry.get_status()
	if int(status.get("running_count", 0)) != 1 or int(status.get("recent_count", 0)) != 1:
		return _failure("Tool activity registry should move finished calls from running to recent.")
	order = status.get("execution_order", [])
	if not (order is Array) or (order as Array).size() != 1:
		return _failure("Tool activity registry should remove finished calls from running order.")
	if str(((order as Array)[0] as Dictionary).get("call_id", "")) != str(second.get("call_id", "")):
		return _failure("Tool activity registry should keep remaining running calls ordered.")

	var recent_result: Dictionary = registry.get_recent(50)
	var recent = recent_result.get("recent", [])
	if not (recent is Array) or (recent as Array).size() != 1:
		return _failure("Tool activity registry recent query should return completed calls.")
	if str(((recent as Array)[0] as Dictionary).get("call_id", "")) != str(first.get("call_id", "")):
		return _failure("Tool activity registry recent query should preserve completed call identity.")

	var recent_lookup: Dictionary = registry.get_call(str(first.get("call_id", "")))
	if not bool(recent_lookup.get("found", false)):
		return _failure("Tool activity registry should return recent calls from get_call.")
	var missing_lookup: Dictionary = registry.get_call("missing-call-id")
	if bool(missing_lookup.get("found", true)):
		return _failure("Tool activity registry should report missing calls as not found.")

	registry.finish_call(str(second.get("call_id", "")), true)
	var final_status: Dictionary = registry.get_status()
	if int(final_status.get("running_count", -1)) != 0 or int(final_status.get("recent_count", 0)) != 2:
		return _failure("Tool activity registry should finish all calls cleanly.")

	return {
		"name": "tool_activity_registry_contracts",
		"success": true,
		"error": "",
		"details": {
			"first_call_id": str(first.get("call_id", "")),
			"second_call_id": str(second.get("call_id", "")),
			"recent_count": int(final_status.get("recent_count", 0))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_activity_registry_contracts",
		"success": false,
		"error": message
	}
