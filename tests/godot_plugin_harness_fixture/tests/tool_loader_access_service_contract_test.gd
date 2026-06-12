extends RefCounted

const AccessServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_access_service.gd")


class FakeProvider:
	extends RefCounted

	var visible_value = true
	var executable_value = true
	var denied_message := "Denied by provider."

	func is_tool_category_visible(_category: String):
		return visible_value

	func is_tool_category_executable(_category: String):
		return executable_value

	func get_tool_access_denied_message(_category: String) -> String:
		return denied_message


class FakeServerContext:
	extends RefCounted

	var provider
	var parent

	func _init(new_provider = null, new_parent = null) -> void:
		provider = new_provider
		parent = new_parent

	func get_tool_access_provider():
		return provider

	func get_parent():
		return parent


class FakeParentOnlyContext:
	extends RefCounted

	var parent

	func _init(new_parent) -> void:
		parent = new_parent

	func get_parent():
		return parent


func run_case(_tree: SceneTree) -> Dictionary:
	var service = AccessServiceScript.new()

	if not service.is_category_visible("system", null) or not service.is_category_executable("system", null):
		return _failure("Access service should default missing server contexts to visible/executable.")
	if service.get_tool_access_error("system", null) != "Tool category is disabled.":
		return _failure("Access service should keep the default denied-message fallback.")

	var provider := FakeProvider.new()
	var parent_provider := FakeProvider.new()
	provider.visible_value = "off"
	parent_provider.visible_value = true
	var direct_context := FakeServerContext.new(provider, parent_provider)
	if service.get_tool_access_provider(direct_context) != provider:
		return _failure("Access service should prefer get_tool_access_provider() over get_parent().")
	if service.is_category_visible("user", direct_context):
		return _failure("Access service should preserve string false values from direct providers.")

	var parent_context := FakeParentOnlyContext.new(parent_provider)
	parent_provider.executable_value = 1
	if service.get_tool_access_provider(parent_context) != parent_provider:
		return _failure("Access service should keep get_parent() provider fallback.")
	if not service.is_category_executable("user", parent_context):
		return _failure("Access service should preserve truthy integer executable values.")

	var truthy_values := [true, 1, 0.25, "true", "1", "yes", "on", RefCounted.new()]
	for value in truthy_values:
		provider.visible_value = value
		if not service.is_category_visible("system", direct_context):
			return _failure("Access service should treat value as truthy: %s" % str(value))

	var falsey_values := [false, 0, 0.0, "false", "0", "no", "off", "", null]
	for value in falsey_values:
		provider.executable_value = value
		if service.is_category_executable("system", direct_context):
			return _failure("Access service should treat value as falsey: %s" % str(value))

	provider.denied_message = "Custom category denial."
	if service.get_tool_access_error("debug", direct_context) != "Custom category denial.":
		return _failure("Access service should preserve provider denied messages.")

	return {
		"name": "tool_loader_access_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"truthy_values": truthy_values.size(),
			"falsey_values": falsey_values.size()
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_loader_access_service_contracts",
		"success": false,
		"error": message
	}
