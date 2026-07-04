extends RefCounted

# {"name": "mcp_tool_loader_supervisor_contracts"}

const SupervisorScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_loader_supervisor.gd")
const ToolLoaderScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader.gd")


class TestSupervisor extends SupervisorScript:
	var live_revision := 1
	var refresh_calls := 0

	func seed_summary() -> void:
		_tool_loader_last_summary = {
			"tool_count": 2,
			"exposed_tool_count": 1,
			"category_count": 1,
			"tool_load_error_count": 0,
			"catalog_revision": 1
		}

	func _get_tool_loader_catalog_revision() -> int:
		return live_revision

	func refresh_status_from_loader() -> void:
		refresh_calls += 1


class SignatureProbeLoader extends ToolLoaderScript:
	var supervisor = null
	var signature_during_sync := "<unset>"

	func set_disabled_tools(disabled_tools: Array) -> void:
		signature_during_sync = str(supervisor.get("_disabled_tools_signature"))
		super.set_disabled_tools(disabled_tools)


func run_case(_tree: SceneTree) -> Dictionary:
	var supervisor = TestSupervisor.new()
	supervisor.seed_summary()
	var first_status: Dictionary = supervisor.get_light_status()
	if int(first_status.get("catalog_revision", 0)) != 1:
		return _failure("Supervisor light status should expose the initialized loader catalog revision.")

	# Simulate a loader-side catalog mutation that does not rebuild the supervisor
	# summary. Dock refresh cache keys use light status and must still observe it.
	supervisor.live_revision = 7
	var live_status: Dictionary = supervisor.get_light_status()
	if int(live_status.get("catalog_revision", 0)) != 7:
		return _failure("Supervisor light status should publish the live loader catalog revision, not stale summary data.")

	var disabled_supervisor = TestSupervisor.new()
	var real_loader = ToolLoaderScript.new()
	disabled_supervisor.set("_tool_loader", real_loader)
	disabled_supervisor.set_disabled_tools([" system_runtime_control ", "system_project_state", "system_project_state"])
	disabled_supervisor.set_disabled_tools(["system_project_state", "system_runtime_control"])
	var disabled_tools := disabled_supervisor.get_disabled_tools()
	disabled_tools.sort()
	if disabled_tools != ["system_project_state", "system_runtime_control"]:
		return _failure("Supervisor should normalize, sort, and deduplicate disabled tools.")
	var loader_disabled_tools := real_loader.get_disabled_tools()
	loader_disabled_tools.sort()
	if loader_disabled_tools != ["system_project_state", "system_runtime_control"]:
		return _failure("Supervisor should forward normalized disabled tool sets to the loader.")
	if disabled_supervisor.refresh_calls != 1:
		return _failure("Supervisor should refresh status only for changed disabled tool sets.")
	disabled_supervisor.set_disabled_tools(["system_project_state"])
	if disabled_supervisor.refresh_calls != 2:
		return _failure("Supervisor should forward changed disabled tool sets to the loader.")
	real_loader.shutdown()

	var order_supervisor = TestSupervisor.new()
	var probe_loader = SignatureProbeLoader.new()
	probe_loader.supervisor = order_supervisor
	order_supervisor.set("_tool_loader", probe_loader)
	order_supervisor.set_disabled_tools(["system_project_state"])
	if probe_loader.signature_during_sync != "":
		return _failure("Supervisor should update the disabled-tools signature only after forwarding the set to the loader.")
	if str(order_supervisor.get("_disabled_tools_signature")) != "system_project_state":
		return _failure("Supervisor should mark the disabled-tools signature current after loader synchronization.")
	probe_loader.shutdown()
	probe_loader.supervisor = null
	order_supervisor.dispose()

	return {
		"name": "mcp_tool_loader_supervisor_contracts",
		"success": true,
		"error": "",
		"details": {
			"catalog_revision": int(live_status.get("catalog_revision", 0))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "mcp_tool_loader_supervisor_contracts",
		"success": false,
		"error": message
	}
