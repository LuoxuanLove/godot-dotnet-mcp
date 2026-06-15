extends RefCounted

# {"name": "dock_model_service_contracts"}

const DockModelService = preload("res://addons/godot_dotnet_mcp/plugin/presenters/dock_model_service.gd")
const ServerRuntimeController = preload("res://addons/godot_dotnet_mcp/plugin/runtime/server_runtime_controller.gd")

var _controllers: Array = []


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
	var update_ref_versions := {"dev": "1.2.3"}
	var update_compare_state := "success"
	var update_compare_error := ""
	var update_compare_base_commit := "base123456"
	var update_compare_target_ref := "dev"
	var update_compare_target_commit := "abcdef123456"
	var update_compare_ahead_by := 3
	var update_compare_behind_by := 1
	var update_sync_state := "idle"
	var update_sync_status := ""
	var update_sync_error := ""
	var update_sync_target_ref := ""
	var update_sync_target_kind := ""
	var mcp_catalog_preview: Dictionary = {}


class FakeServerController extends ServerRuntimeController:
	var all_tools_request_count := 0
	var heavy_status_request_count := 0
	var tool_loader_request_count := 0

	func _init() -> void:
		_server = FakeServer.new()

	func get_tool_loader():
		tool_loader_request_count += 1
		return (_server as FakeServer).get_tool_loader()

	func get_exposed_tool_definitions() -> Array:
		return (_server as FakeServer).get_exposed_tool_definitions()

	func get_tool_definitions() -> Array:
		return (_server as FakeServer).get_tool_definitions()

	func get_all_tools_by_category() -> Dictionary:
		all_tools_request_count += 1
		return (_server as FakeServer).get_all_tools_by_category()

	func is_running() -> bool:
		return true

	func get_connection_stats() -> Dictionary:
		return {"connections": 1}

	func get_domain_states() -> Array:
		heavy_status_request_count += 1
		return (_server as FakeServer).get_domain_states()

	func get_reload_status() -> Dictionary:
		heavy_status_request_count += 1
		return {}

	func get_performance_summary() -> Dictionary:
		heavy_status_request_count += 1
		return (_server as FakeServer).get_performance_summary()

	func get_tool_load_errors() -> Array:
		heavy_status_request_count += 1
		return []

	func is_public_removed_tool(tool_name: String) -> bool:
		return (_server as FakeServer).is_public_removed_tool(tool_name)


class FakeServer extends Node:
	var project_state_script_path := "res://addons/godot_dotnet_mcp/tools/system/project_state.gd"

	func get_tool_loader():
		return self

	func get_tool_loader_status() -> Dictionary:
		return {"state": "ready", "loaded_tools": 6}

	func get_tool_activity_registry():
		return FakeActivityRegistry.new()

	func get_exposed_tool_definitions() -> Array:
		return [{
			"name": "system_project_state",
			"category": "system",
			"source": "builtin",
			"load_state": "loaded",
			"script_path": project_state_script_path
		}, {
			"name": "system_tool_activity",
			"category": "system",
			"source": "builtin",
			"load_state": "loaded",
			"script_path": "res://addons/godot_dotnet_mcp/tools/system/tool_activity.gd"
		}, {
			"name": "plugin_runtime_state",
			"category": "plugin_runtime",
			"source": "builtin",
			"load_state": "loaded",
			"script_path": "res://addons/godot_dotnet_mcp/tools/plugin/runtime.gd"
		}, {
			"name": "material_inspect",
			"category": "material",
			"source": "builtin",
			"load_state": "loaded",
			"script_path": "res://addons/godot_dotnet_mcp/tools/material/inspect.gd"
		}]

	func get_tool_definitions() -> Array:
		var tools := get_exposed_tool_definitions()
		tools.append({
			"name": "user_sample_tool",
			"category": "user",
			"source": "user_tool",
			"load_state": "loaded",
			"script_path": "res://addons/godot_dotnet_mcp/custom_tools/sample_tool.gd"
		})
		return tools

	func get_all_tools_by_category() -> Dictionary:
		return {
			"system": [
				{"name": "project_state", "source": "builtin", "load_state": "loaded", "script_path": project_state_script_path},
				{"name": "tool_activity", "source": "builtin", "load_state": "loaded", "script_path": "res://addons/godot_dotnet_mcp/tools/system/tool_activity.gd"},
				{"name": "runtime_diagnose"}
			],
			"plugin_runtime": [
				{"name": "state"}
			],
			"plugin_evolution": [
				{"name": "update_status"}
			],
			"plugin_developer": [
				{"name": "self_test"}
			],
			"material": [
				{"name": "inspect"}
			],
			"physics": [
				{"name": "inspect"}
			],
			"ui": [
				{"name": "control"}
			],
			"scene": [
				{"name": "scene_validate"}
			],
			"user": [
				{"name": "sample_tool", "source": "user_tool", "script_path": "res://addons/godot_dotnet_mcp/custom_tools/sample_tool.gd"}
			]
		}

	func get_domain_states() -> Array:
		return [{"category": "system", "domain_key": "core", "loaded": true, "tool_count": 3, "enabled_tool_count": 3}]

	func get_performance_summary() -> Dictionary:
		return {}

	func is_public_removed_tool(tool_name: String) -> bool:
		return tool_name == "system_tool_activity"


class FakeLocalization extends RefCounted:
	func get_language() -> String:
		return "en"

	func get_available_languages() -> Array:
		return []

	func get_text(_key: String) -> String:
		return ""


class FakeActivityRegistry extends RefCounted:
	func get_status() -> Dictionary:
		return {"running": false, "recent_count": 2}

	func get_recent(_limit: int = 20) -> Dictionary:
		return {"recent": [{"id": "call-1", "tool": "system_project_state"}], "recent_count": 1}


class FakeUserToolService extends RefCounted:
	func list_user_tools() -> Array:
		return []


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
	state.mcp_catalog_preview = {"kind": "prompt", "id": "godot.project_orientation", "success": true, "text": "Preview text"}
	state.settings = {
		"disabled_tools": [],
		"language": "en",
		"log_level": "info",
		"show_user_tools": true,
		"tool_profile_id": "default"
	}
	var server_controller = FakeServerController.new()
	_controllers.append(server_controller)
	var context = FakeContext.new()
	context.state = state
	context.localization = FakeLocalization.new()
	context.server_controller = server_controller
	context.tool_catalog = FakeToolCatalog.new()
	context.config_service = RefCounted.new()
	context.dock_presenter = null
	context.user_tool_service = FakeUserToolService.new()
	context.client_install_detection_service = null
	context.central_server_attach_service = null
	context.runtime_process_service = null
	context.user_tool_watch_service = null
	context.tool_access_feature = FakeToolAccessFeature.new()
	context.self_diagnostic_feature = null
	context.get_editor_scale = Callable()
	service.configure(context)

	state.current_tab = 0
	var home_model: Dictionary = service.build_model()
	if server_controller.all_tools_request_count != 0:
		return _failure("Dock home model should not request the full tool catalog.")
	if server_controller.heavy_status_request_count != 0:
		return _failure("Dock home model should not request heavy runtime diagnostics.")
	if not (home_model.get("toolTree", []) as Array).is_empty():
		return _failure("Dock home model should not build the heavy tools tree.")

	state.current_tab = 1
	var model: Dictionary = service.build_model()
	if server_controller.all_tools_request_count <= 0:
		return _failure("Dock Tools tab model should request the tool catalog on demand.")
	if server_controller.heavy_status_request_count <= 0:
		return _failure("Dock Tools tab model should request runtime diagnostics only when the Tools view needs them.")
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
	var metadata_by_name: Dictionary = presentation.get("toolMetadataByName", {})
	var project_metadata: Dictionary = metadata_by_name.get("system_project_state", {})
	if project_metadata.is_empty():
		return _failure("Dock model should reuse snapshot presentation metadata for visible tools.")
	if (project_metadata.get("groupPath", []) as Array).is_empty() or str(project_metadata.get("loadState", "")) != "loaded" or str(project_metadata.get("source", "")) != "builtin":
		return _failure("Dock snapshot metadata should preserve groupPath, loadState, and source.")
	if str(project_metadata.get("scriptPath", "")).is_empty():
		return _failure("Dock snapshot metadata should preserve scriptPath.")
	if str(project_metadata.get("title", "")) != "System Project State":
		return _failure("Dock snapshot metadata should preserve presentation titles for Tools UI consumers.")
	var project_annotations = project_metadata.get("annotations", {})
	if not (project_annotations is Dictionary) or bool((project_annotations as Dictionary).get("readOnlyHint", false)) != true:
		return _failure("Dock snapshot metadata should preserve MCP annotations for Tools UI consumers.")
	var project_input_schema = project_metadata.get("inputSchema", {})
	if not (project_input_schema is Dictionary) or str((project_input_schema as Dictionary).get("$schema", "")) != "https://json-schema.org/draft/2020-12/schema":
		return _failure("Dock snapshot metadata should preserve normalized input schemas for Tools UI consumers.")
	var project_output_schema = project_metadata.get("outputSchema", {})
	if not (project_output_schema is Dictionary) or str((project_output_schema as Dictionary).get("$schema", "")) != "https://json-schema.org/draft/2020-12/schema":
		return _failure("Dock snapshot metadata should preserve normalized output schemas for Tools UI consumers.")
	if metadata_by_name.has("system_tool_activity"):
		return _failure("Dock presentation should filter removed public tools through the snapshot service.")
	var agent_presentation: Dictionary = model.get("agent_tool_presentation", {})
	var active_presentation: Dictionary = model.get("active_tool_presentation", {})
	if agent_presentation.is_empty() or active_presentation.is_empty():
		return _failure("Dock model should expose Agent Tools as the default active presentation.")
	if model.get("toolTree", []) != agent_presentation.get("toolTree", []):
		return _failure("Dock model should feed the Tools tab from Agent Tools by default.")
	if _contains_presentation_category(model.get("toolTree", []), "plugin_runtime"):
		return _failure("Dock default Tools tab tree should not expose internal executor categories.")
	if not _contains_kind_key(model.get("toolTree", []), "public_tool", "system_project_state"):
		return _failure("Dock default Tools tab tree should include canonical public tools.")
	if not (model.get("internal_executor_presentation", {}) is Dictionary) or (model.get("internal_executor_presentation", {}) as Dictionary).is_empty():
		return _failure("Dock model should keep internal executor presentation available for advanced diagnostics.")
	if not (model.get("tool_diagnostics_presentation", {}) is Dictionary) or (model.get("tool_diagnostics_presentation", {}) as Dictionary).is_empty():
		return _failure("Dock model should keep diagnostics presentation available without mixing it into the default tree.")
	if not (model.get("mcp_resources", []) as Array).is_empty() or not (model.get("mcp_prompts", []) as Array).is_empty():
		return _failure("Dock Tools tab should not build the Resources/Prompts protocol projection.")

	var changed_script_path := "res://addons/godot_dotnet_mcp/tools/system/project_state_v2.gd"
	(server_controller._server as FakeServer).project_state_script_path = changed_script_path
	var refreshed_model: Dictionary = service.build_model()
	var refreshed_presentation: Dictionary = refreshed_model.get("tool_presentation", {})
	var refreshed_metadata_by_name: Dictionary = refreshed_presentation.get("toolMetadataByName", {})
	var refreshed_project_metadata: Dictionary = refreshed_metadata_by_name.get("system_project_state", {})
	if str(refreshed_project_metadata.get("scriptPath", "")) != changed_script_path:
		return _failure("Dock catalog snapshot cache should invalidate when tool metadata changes without a count change.")

	state.current_tab = 2
	server_controller.heavy_status_request_count = 0
	var tool_loader_requests_before_protocol_catalog: int = server_controller.tool_loader_request_count
	var resources_model: Dictionary = service.build_model()
	if server_controller.heavy_status_request_count != 0:
		return _failure("Dock Resources tab model should not request heavy runtime diagnostics.")
	if server_controller.tool_loader_request_count != tool_loader_requests_before_protocol_catalog:
		return _failure("Dock Resources tab model should not request the tool loader for protocol list projection.")
	var protocol_projection_result := _verify_mcp_protocol_projection(resources_model)
	if not bool(protocol_projection_result.get("success", false)):
		return protocol_projection_result
	if str((resources_model.get("mcp_catalog_preview", {}) as Dictionary).get("text", "")) != "Preview text":
		return _failure("Dock model should expose the current MCP catalog preview result to Resources/Prompts tabs.")
	state.current_tab = 3
	var prompt_loader_requests_before_protocol_catalog: int = server_controller.tool_loader_request_count
	var prompts_model: Dictionary = service.build_model()
	if server_controller.tool_loader_request_count != prompt_loader_requests_before_protocol_catalog:
		return _failure("Dock Prompts tab model should not request the tool loader for protocol list projection.")
	if (prompts_model.get("mcp_prompts", []) as Array).is_empty():
		return _failure("Dock Prompts tab model should project MCP prompts without loading the tool runtime.")
	if _contains_presentation_category(presentation.get("toolTree", []), "user"):
		return _failure("Dock presentation should not expose categories filtered by tool access visibility.")
	if not _contains_presentation_tool(presentation.get("toolTree", []), "plugin_runtime_state"):
		return _failure("Dock presentation should expose visible plugin runtime top-level tools.")
	if not _contains_presentation_tool(presentation.get("toolTree", []), "plugin_evolution_update_status"):
		return _failure("Dock presentation should expose visible plugin evolution top-level tools.")
	if not _contains_presentation_tool(presentation.get("toolTree", []), "plugin_developer_self_test"):
		return _failure("Dock presentation should expose visible plugin developer top-level tools.")
	if not _contains_presentation_tool(presentation.get("toolTree", []), "material_inspect"):
		return _failure("Dock presentation should expose visible visual-domain top-level tools.")
	if not _contains_presentation_tool(presentation.get("toolTree", []), "physics_inspect"):
		return _failure("Dock presentation should expose visible gameplay-domain top-level tools.")
	if not _contains_presentation_tool(presentation.get("toolTree", []), "ui_control"):
		return _failure("Dock presentation should expose visible interface-domain top-level tools.")
	if not model.has("plugin_freshness") or not (model.get("plugin_freshness", {}) is Dictionary):
		return _failure("Dock model should include plugin freshness data for the Settings tab update summary.")
	if not model.has("plugin_version"):
		return _failure("Dock model should include plugin version data for the Settings tab update summary.")
	if str(model.get("update_refs_state", "")) != "success" or not (model.get("update_refs_branches", []) as Array).has("dev") or not (model.get("update_refs_releases", []) as Array).has("v1.0.0") or str((model.get("update_refs_commits", {}) as Dictionary).get("dev", "")) != "abcdef123456" or str((model.get("update_refs_versions", {}) as Dictionary).get("dev", "")) != "1.2.3" or str(model.get("update_refs_latest_stable_release", "")) != "v1.0.0" or str(model.get("update_refs_latest_release", "")) != "v1.1.0-beta":
		return _failure("Dock model should project transient update ref discovery state for the Settings tab.")
	if str(model.get("update_compare_state", "")) != "success" or str(model.get("update_compare_target_ref", "")) != "dev" or int(model.get("update_compare_ahead_by", -1)) != 3 or int(model.get("update_compare_behind_by", -1)) != 1:
		return _failure("Dock model should project transient update compare state for the Settings tab.")
	if model.has("update_ref_branches") or model.has("update_ref_releases") or model.has("update_ref_latest_stable_release") or model.has("update_ref_latest_release") or model.has("update_ref_commits") or model.has("update_ref_versions"):
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


func cleanup_case(_tree: SceneTree) -> void:
	for controller in _controllers:
		if controller != null and controller.has_method("detach"):
			controller.detach()
	_controllers.clear()


func _failure(message: String) -> Dictionary:
	return {
		"name": "dock_model_service_contracts",
		"success": false,
		"error": message
	}


func _verify_mcp_protocol_projection(model: Dictionary) -> Dictionary:
	var resources: Array = model.get("mcp_resources", [])
	var resource_templates: Array = model.get("mcp_resource_templates", [])
	var prompts: Array = model.get("mcp_prompts", [])
	var counts: Dictionary = model.get("mcp_catalog_counts", {})
	if resources.is_empty():
		return _failure("Dock model should project MCP resources for the protocol catalog UI.")
	if resource_templates.is_empty():
		return _failure("Dock model should project MCP resource templates for the protocol catalog UI.")
	if prompts.is_empty():
		return _failure("Dock model should project MCP prompts for the protocol catalog UI.")
	if int(counts.get("resources", -1)) != resources.size() or int(counts.get("resource_templates", -1)) != resource_templates.size() or int(counts.get("prompts", -1)) != prompts.size():
		return _failure("Dock model should include MCP catalog counts matching the projected lists.")

	var guide_resource := _find_resource_by_uri(resources, "godot-dotnet-mcp://guides/index")
	if guide_resource.is_empty():
		return _failure("Dock model should include the canonical guide index resource.")
	if str(guide_resource.get("resource_kind", "")) != "guide":
		return _failure("Dock resource projection should classify guide resources.")
	if str(guide_resource.get("title", "")).is_empty() or str(guide_resource.get("description", "")).is_empty() or str(guide_resource.get("mimeType", "")) != "application/json":
		return _failure("Dock resource projection should preserve title, description, and mime type.")
	if (guide_resource.get("icons", []) as Array).is_empty():
		return _failure("Dock resource projection should preserve MCP 2025-11-25 resource icons.")

	var state_resource := _find_resource_by_uri(resources, "godot-dotnet-mcp://state/editor")
	if str(state_resource.get("resource_kind", "")) != "state":
		return _failure("Dock resource projection should classify state resources.")
	var log_resource := _find_resource_by_uri(resources, "godot-dotnet-mcp://logs/editor/errors")
	if str(log_resource.get("resource_kind", "")) != "log":
		return _failure("Dock resource projection should classify editor log resources.")
	var catalog_resource := _find_resource_by_uri(resources, "godot-dotnet-mcp://tools/catalog/visible")
	if str(catalog_resource.get("resource_kind", "")) != "catalog":
		return _failure("Dock resource projection should classify catalog resources.")
	var activity_resource := _find_resource_by_uri(resources, "godot-dotnet-mcp://activity/recent")
	if str(activity_resource.get("resource_kind", "")) != "activity":
		return _failure("Dock resource projection should classify activity resources.")

	var scene_template := _find_resource_by_uri(resource_templates, "godot-dotnet-mcp://scene/{path}")
	if scene_template.is_empty() or str(scene_template.get("resource_kind", "")) != "template" or not bool(scene_template.get("is_template", false)):
		return _failure("Dock resource projection should include and classify resource templates.")

	var orientation_prompt := _find_prompt_by_name(prompts, "godot.project_orientation")
	if orientation_prompt.is_empty():
		return _failure("Dock prompt projection should include the project orientation workflow.")
	if str(orientation_prompt.get("title", "")).is_empty() or str(orientation_prompt.get("description", "")).is_empty():
		return _failure("Dock prompt projection should preserve prompt title and description.")
	if (orientation_prompt.get("icons", []) as Array).is_empty():
		return _failure("Dock prompt projection should preserve MCP 2025-11-25 prompt icons.")
	var orientation_args: Array = orientation_prompt.get("arguments", [])
	if not _array_has_argument(orientation_args, "goal"):
		return _failure("Dock prompt projection should preserve prompt argument metadata.")
	var runtime_prompt := _find_prompt_by_name(prompts, "godot.runtime_validation")
	if str(runtime_prompt.get("prompt_kind", "")) != "runtime":
		return _failure("Dock prompt projection should classify runtime workflows.")
	return {"success": true}


func _find_resource_by_uri(entries: Array, uri: String) -> Dictionary:
	for entry in entries:
		if entry is Dictionary and str((entry as Dictionary).get("uri", "")) == uri:
			return entry as Dictionary
	return {}


func _find_prompt_by_name(entries: Array, name: String) -> Dictionary:
	for entry in entries:
		if entry is Dictionary and str((entry as Dictionary).get("name", "")) == name:
			return entry as Dictionary
	return {}


func _array_has_argument(entries: Array, name: String) -> bool:
	for entry in entries:
		if entry is Dictionary and str((entry as Dictionary).get("name", "")) == name:
			return true
	return false


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


func _contains_presentation_tool(nodes: Array, tool_name: String) -> bool:
	for node in nodes:
		if not (node is Dictionary):
			continue
		var node_dict := node as Dictionary
		if str(node_dict.get("kind", "")) == "tool" and str(node_dict.get("key", "")) == tool_name:
			return true
		if _contains_presentation_tool(node_dict.get("children", []), tool_name):
			return true
	return false


func _contains_kind_key(nodes: Array, kind: String, key: String) -> bool:
	for node in nodes:
		if not (node is Dictionary):
			continue
		var node_dict := node as Dictionary
		if str(node_dict.get("kind", "")) == kind and str(node_dict.get("key", "")) == key:
			return true
		if _contains_kind_key(node_dict.get("children", []), kind, key):
			return true
	return false
