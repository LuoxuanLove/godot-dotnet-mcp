extends RefCounted

# {"name": "dock_model_service_contracts"}

const DockModelService = preload("res://addons/godot_dotnet_mcp/plugin/presenters/dock_model_service.gd")


class FakeState extends RefCounted:
	var settings: Dictionary = {}
	var current_tab := 0
	var current_cli_scope := ""
	var current_config_platform := ""
	var custom_tool_profiles: Dictionary = {}


class FakeServerController extends RefCounted:
	func get_all_tools_by_category() -> Dictionary:
		return {
			"system": [
				{"name": "project_state"},
				{"name": "runtime_diagnose"}
			],
			"scene": [
				{"name": "scene_validate"}
			],
			"user": [
				{"name": "sample_tool", "source": "user_tool", "script_path": "res://addons/godot_dotnet_mcp/custom_tools/sample_tool.gd"}
			]
		}

	func is_running() -> bool:
		return true

	func get_connection_stats() -> Dictionary:
		return {"connections": 1}

	func get_domain_states() -> Array:
		return []

	func get_reload_status() -> Dictionary:
		return {}

	func get_performance_summary() -> Dictionary:
		return {}

	func get_tool_load_errors() -> Array:
		return []


class FakeDockPresenter extends RefCounted:
	func build_model(context: Dictionary) -> Dictionary:
		return context


class FakeToolAccessFeature extends RefCounted:
	func is_tool_category_visible(category: String) -> bool:
		return category != "user"


class FakeContext extends RefCounted:
	var state
	var localization
	var server_controller
	var tool_catalog
	var config_service
	var dock_presenter
	var user_tool_service
	var client_install_detection_service
	var central_server_attach_service
	var runtime_process_service
	var user_tool_watch_service
	var tool_access_feature
	var self_diagnostic_feature
	var get_editor_scale := Callable()


func run_case(_tree: SceneTree) -> Dictionary:
	var service = DockModelService.new()
	var state = FakeState.new()
	state.settings = {
		"disabled_tools": [],
		"language": "en",
		"log_level": "info",
		"show_user_tools": true,
		"tool_profile_id": "default"
	}
	var server_controller = FakeServerController.new()
	var context = FakeContext.new()
	context.state = state
	context.localization = RefCounted.new()
	context.server_controller = server_controller
	context.tool_catalog = RefCounted.new()
	context.config_service = RefCounted.new()
	context.dock_presenter = FakeDockPresenter.new()
	context.user_tool_service = RefCounted.new()
	context.client_install_detection_service = null
	context.central_server_attach_service = null
	context.runtime_process_service = null
	context.user_tool_watch_service = null
	context.tool_access_feature = FakeToolAccessFeature.new()
	context.self_diagnostic_feature = null
	context.get_editor_scale = Callable()
	service.configure(context)

	var model: Dictionary = service.build_model()
	var tools_by_category: Dictionary = model.get("tools_by_category", {})
	if not tools_by_category.has("scene"):
		return _failure("Dock model should keep non-root atomic categories available for system tool tree lookup.")
	if not tools_by_category.has("system"):
		return _failure("Dock model should keep the exposed system category available.")
	if tools_by_category.has("user"):
		return _failure("Dock model should apply tool access visibility to tools_by_category.")
	if model.get("all_tools_by_category", {}).has("scene") == false:
		return _failure("Dock model should still keep the full tool set for profile and filtering logic.")
	if model.get("all_tools_by_category", {}).has("user") == false:
		return _failure("Dock model should still keep hidden categories in all_tools_by_category for profile logic.")
	var presentation: Dictionary = model.get("tool_presentation", {})
	if presentation.is_empty() or not (presentation.get("toolTree", []) is Array):
		return _failure("Dock model should include the unified tool presentation model.")
	if _contains_presentation_category(presentation.get("toolTree", []), "user"):
		return _failure("Dock presentation should not expose categories filtered by tool access visibility.")

	return {
		"name": "dock_model_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_categories": tools_by_category.keys(),
			"all_categories": model.get("all_tools_by_category", {}).keys()
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "dock_model_service_contracts",
		"success": false,
		"error": message
	}


func _contains_presentation_category(nodes: Array, category: String) -> bool:
	for node in nodes:
		if not (node is Dictionary):
			continue
		var node_dict := node as Dictionary
		if str(node_dict.get("kind", "")) == "category" and str(node_dict.get("key", "")) == category:
			return true
		if _contains_presentation_category(node_dict.get("children", []), category):
			return true
	return false
