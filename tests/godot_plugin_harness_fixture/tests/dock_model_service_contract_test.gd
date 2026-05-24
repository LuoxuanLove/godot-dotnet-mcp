extends RefCounted

# {"name": "dock_model_service_contracts"}

const DockModelService = preload("res://addons/godot_dotnet_mcp/plugin/presenters/dock_model_service.gd")


class FakeState extends RefCounted:
	var settings: Dictionary = {}
	var current_tab := 0
	var current_cli_scope := ""
	var current_config_platform := ""
	var custom_tool_profiles: Dictionary = {}
	var update_refs_state := "success"
	var update_refs_status := "Discovered refs."
	var update_refs_error := ""
	var update_ref_branches: Array[String] = ["dev"]
	var update_ref_releases: Array[String] = ["v1.0.0"]
	var update_ref_latest_stable_release := "v1.0.0"
	var update_ref_latest_release := "v1.1.0-beta"
	var update_refs_release_source := "releases"
	var update_ref_commits := {"dev": "abcdef123456"}
	var update_sync_state := "idle"
	var update_sync_status := ""
	var update_sync_error := ""
	var update_sync_target_ref := ""
	var update_sync_target_kind := ""


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


class FakeLocalization extends RefCounted:
	func get_language() -> String:
		return "en"

	func get_available_languages() -> Array:
		return []

	func get_text(_key: String) -> String:
		return ""


class FakeToolCatalog extends RefCounted:
	func build_tool_name_index(_all_tools_by_category: Dictionary) -> Array:
		return []

	func has_tool_profile(profile_id: String, _builtin_profiles: Array, _custom_profiles: Dictionary) -> bool:
		return profile_id == "default"

	func find_matching_profile_id(_disabled_tools: Array, _builtin_profiles: Array, _custom_profiles: Dictionary, _tool_names: Array) -> String:
		return "default"

	func profile_matches_state(_profile_id: String, _disabled_tools: Array, _builtin_profiles: Array, _custom_profiles: Dictionary, _tool_names: Array) -> bool:
		return true


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
	context.localization = FakeLocalization.new()
	context.server_controller = server_controller
	context.tool_catalog = FakeToolCatalog.new()
	context.config_service = RefCounted.new()
	context.dock_presenter = null
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
	if not model.has("plugin_freshness") or not (model.get("plugin_freshness", {}) is Dictionary):
		return _failure("Dock model should include plugin freshness data for the Settings tab update summary.")
	if not model.has("plugin_version"):
		return _failure("Dock model should include plugin version data for the Settings tab update summary.")
	if str(model.get("update_refs_state", "")) != "success" or not (model.get("update_refs_branches", []) as Array).has("dev") or not (model.get("update_refs_releases", []) as Array).has("v1.0.0") or str((model.get("update_refs_commits", {}) as Dictionary).get("dev", "")) != "abcdef123456" or str(model.get("update_refs_latest_stable_release", "")) != "v1.0.0" or str(model.get("update_refs_latest_release", "")) != "v1.1.0-beta":
		return _failure("Dock model should project transient update ref discovery state for the Settings tab.")
	if model.has("update_ref_branches") or model.has("update_ref_releases") or model.has("update_ref_latest_stable_release") or model.has("update_ref_latest_release") or model.has("update_ref_commits"):
		return _failure("Dock model should expose transient update discovery refs with plural model keys only.")

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
