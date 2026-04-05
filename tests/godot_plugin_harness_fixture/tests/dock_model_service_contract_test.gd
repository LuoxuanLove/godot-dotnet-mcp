extends RefCounted

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
		"permission_level": "evolution",
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
	context.tool_access_feature = null
	context.self_diagnostic_feature = null
	context.get_editor_scale = Callable()
	service.configure(context)

	var model: Dictionary = service.build_model()
	var tools_by_category: Dictionary = model.get("tools_by_category", {})
	if tools_by_category.has("scene"):
		return _failure("Dock model should only expose the high-level exposed categories in the tools tab.")
	if not tools_by_category.has("system"):
		return _failure("Dock model should keep the exposed system category available.")
	if model.get("all_tools_by_category", {}).has("scene") == false:
		return _failure("Dock model should still keep the full tool set for profile and permission logic.")

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
