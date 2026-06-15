extends RefCounted

# {"name": "tool_loader_supervisor_contracts"}

const ToolLoaderSupervisorScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_loader_supervisor.gd")


class CountingSupervisor:
	extends ToolLoaderSupervisorScript

	var register_calls: Array = []

	func _replace_tool_loader() -> void:
		pass

	func register_tools(reason: String = "initialize", force_reload_scripts: bool = false) -> Dictionary:
		register_calls.append({
			"reason": reason,
			"force_reload_scripts": force_reload_scripts
		})
		return {}


func run_case(_tree: SceneTree) -> Dictionary:
	var supervisor = CountingSupervisor.new()
	supervisor.set("_tool_loader_initialized", true)
	supervisor.set("_tool_loader_status", "no_visible_tools")
	supervisor.ensure_initialized()
	if not supervisor.register_calls.is_empty():
		return _failure("Tool loader supervisor should not force lazy recovery for legitimate no_visible_tools state.")

	supervisor.set("_tool_loader_status", "empty_registry")
	supervisor.ensure_initialized()
	if supervisor.register_calls.size() != 1:
		return _failure("Tool loader supervisor should force one lazy recovery for empty_registry state.")
	var recovery_call: Dictionary = supervisor.register_calls[0]
	if str(recovery_call.get("reason", "")) != "lazy_recover" or not bool(recovery_call.get("force_reload_scripts", false)):
		return _failure("Tool loader supervisor empty_registry recovery should use lazy_recover with force reload.")

	var fresh_supervisor = CountingSupervisor.new()
	fresh_supervisor.set("_tool_loader_initialized", false)
	fresh_supervisor.ensure_initialized()
	if fresh_supervisor.register_calls.size() != 1:
		return _failure("Tool loader supervisor should lazily initialize an uninitialized loader once.")
	var init_call: Dictionary = fresh_supervisor.register_calls[0]
	if str(init_call.get("reason", "")) != "lazy_initialize" or bool(init_call.get("force_reload_scripts", false)):
		return _failure("Tool loader supervisor lazy initialization should not force reload scripts.")

	return {
		"name": "tool_loader_supervisor_contracts",
		"success": true,
		"error": "",
		"details": {
			"empty_registry_recovered": true,
			"no_visible_tools_preserved": true
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_loader_supervisor_contracts",
		"success": false,
		"error": message
	}
