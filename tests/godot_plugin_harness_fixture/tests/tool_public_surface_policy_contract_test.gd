extends RefCounted

const ToolPublicSurfacePolicyScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_public_surface_policy.gd")


class EnabledProbe extends RefCounted:
	var enabled := {}

	func is_enabled(tool_name: String) -> bool:
		return bool(enabled.get(tool_name, false))


func run_case(_tree: SceneTree) -> Dictionary:
	var policy = ToolPublicSurfacePolicyScript.new()
	if not policy.is_public_removed_tool("system_plugin_update"):
		return _failure("Public surface policy should read removed tool names from the catalog manifest.")
	if policy.is_public_removed_tool("system_plugin_maintenance"):
		return _failure("Public surface policy should not mark canonical tools as removed.")

	var removed_def := {
		"name": "system_plugin_update",
		"full_name": "system_plugin_update",
		"category": "system",
		"enabled": true
	}
	if not policy.is_public_removed_tool_definition(removed_def):
		return _failure("Public surface policy should detect removed full-name definitions.")
	if policy.is_exposed_tool_definition(removed_def):
		return _failure("Public surface policy should filter removed tools from exposed definitions.")

	var compat_def := {
		"name": "system_legacy_probe",
		"category": "system",
		"enabled": true,
		"compatibility_alias": true,
		"compatibility_replacement": "system_project_state"
	}
	if policy.is_exposed_tool_definition(compat_def):
		return _failure("Public surface policy should filter compatibility aliases from exposed definitions.")
	var probe := EnabledProbe.new()
	probe.enabled = {"system_legacy_probe": true, "system_project_state": true}
	if not policy.is_callable_compatibility_alias("system_legacy_probe", [compat_def], Callable(probe, "is_enabled")):
		return _failure("Public surface policy should keep enabled compatibility aliases callable.")
	probe.enabled = {"system_legacy_probe": true, "system_project_state": false}
	if policy.is_callable_compatibility_alias("system_legacy_probe", [compat_def], Callable(probe, "is_enabled")):
		return _failure("Public surface policy should not route compatibility aliases whose replacement is disabled.")

	var removed_update := policy.build_removed_public_tool_result("system_plugin_update", {
		"action": "discover_refs",
		"force_refresh": false
	})
	if bool(removed_update.get("success", true)):
		return _failure("Removed tool guidance should fail closed.")
	var removed_update_data = removed_update.get("data", {})
	if not (removed_update_data is Dictionary):
		return _failure("Removed tool guidance should expose structured data.")
	if str((removed_update_data as Dictionary).get("error_type", "")) != "removed_public_tool":
		return _failure("Removed tool guidance should report removed_public_tool.")
	var replacement_args := _first_replacement_arguments(removed_update_data)
	if str(replacement_args.get("action", "")) != "refresh_update_refs":
		return _failure("Removed system_plugin_update discover_refs should map to refresh_update_refs.")
	if bool(replacement_args.get("force_refresh", true)):
		return _failure("Removed system_plugin_update discover_refs should preserve force_refresh=false.")

	var removed_resource := policy.build_removed_public_tool_result("resource_manage", {
		"action": "reload",
		"path": "res://Tmp/example.tres",
		"_mcp_context": {"agent": "contract"}
	})
	var resource_args := _first_replacement_arguments(removed_resource.get("data", {}))
	if str(resource_args.get("action", "")) != "reload":
		return _failure("Removed resource_manage reload should preserve replacement action.")
	if str(resource_args.get("source", "")) != "res://Tmp/example.tres":
		return _failure("Removed resource_manage reload should map path to source.")
	if resource_args.has("path") or resource_args.has("_mcp_context"):
		return _failure("Removed resource_manage reload should not emit schema-invalid legacy fields.")

	return {
		"success": true,
		"name": "tool_public_surface_policy_contracts",
		"policy_checks": 8
	}


func _first_replacement_arguments(removed_data) -> Dictionary:
	if not (removed_data is Dictionary):
		return {}
	var replacement_tools = (removed_data as Dictionary).get("replacement_tools", [])
	if not (replacement_tools is Array) or (replacement_tools as Array).is_empty():
		return {}
	var first_tool = (replacement_tools as Array)[0]
	if not (first_tool is Dictionary):
		return {}
	var args = (first_tool as Dictionary).get("arguments", {})
	if args is Dictionary:
		return (args as Dictionary)
	return {}


func _failure(message: String, extra: Dictionary = {}) -> Dictionary:
	var data := extra.duplicate(true)
	data["message"] = message
	return {
		"success": false,
		"error": message,
		"data": data
	}
