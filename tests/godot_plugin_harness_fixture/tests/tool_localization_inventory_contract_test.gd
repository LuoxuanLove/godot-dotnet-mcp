extends RefCounted

# {"name": "tool_localization_inventory_contracts"}

const ToolLoaderScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader.gd")
const LocalizationServiceScript = preload("res://addons/godot_dotnet_mcp/localization/localization_service.gd")
const SystemTreeCatalog = preload("res://addons/godot_dotnet_mcp/plugin/runtime/system_tree_catalog.gd")
const ToolPresentationServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_presentation_service.gd")
const ToolTreePresentationServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_tree_presentation_service.gd")

const REMOVED_PUBLIC_TOOL_LOCALIZATION_KEYS: Array[String] = [
	"debug_log",
	"tool_system_help_name",
	"tool_system_help_desc",
	"tool_system_plugin_reload_name",
	"tool_system_plugin_reload_desc",
	"tool_system_plugin_update_name",
	"tool_system_plugin_update_desc",
	"tool_system_tool_catalog_name",
	"tool_system_tool_catalog_desc",
	"tool_system_tool_activity_name",
	"tool_system_tool_activity_desc",
	"tool_system_scene_validate_name",
	"tool_system_scene_validate_desc",
	"tool_system_scene_analyze_name",
	"tool_system_scene_analyze_desc",
	"tool_system_editor_log_name",
	"tool_system_editor_log_desc",
	"tool_resource_manage_name",
	"tool_resource_manage_desc",
	"tool_filesystem_file_name",
	"tool_filesystem_file_desc",
	"tool_debug_log_name",
	"tool_debug_log_desc"
]

const TOOL_DESCRIPTION_KEYWORD_REQUIREMENTS := {
	"tool_system_project_state_desc": ["summary", "sections"]
}

const SCENE_TOOL_LOCALIZATION_KEYS: Array[String] = [
	"tool_system_scene_tree_name",
	"tool_system_scene_tree_desc",
	"tool_system_scene_patch_name",
	"tool_system_scene_patch_desc",
	"tool_action_system_scene_tree_get_tree_name",
	"tool_action_system_scene_tree_get_tree_desc",
	"tool_action_system_scene_tree_get_selected_name",
	"tool_action_system_scene_tree_get_selected_desc",
	"tool_action_system_scene_tree_select_name",
	"tool_action_system_scene_tree_select_desc",
	"tool_action_system_scene_tree_add_node_name",
	"tool_action_system_scene_tree_add_node_desc",
	"tool_action_system_scene_tree_remove_node_name",
	"tool_action_system_scene_tree_remove_node_desc",
	"tool_action_system_scene_tree_rename_node_name",
	"tool_action_system_scene_tree_rename_node_desc",
	"tool_action_system_scene_tree_reparent_node_name",
	"tool_action_system_scene_tree_reparent_node_desc",
	"tool_action_system_scene_tree_reorder_node_name",
	"tool_action_system_scene_tree_reorder_node_desc",
	"tool_action_system_scene_tree_attach_script_name",
	"tool_action_system_scene_tree_attach_script_desc",
	"tool_action_system_scene_tree_set_property_name",
	"tool_action_system_scene_tree_set_property_desc",
	"tool_action_system_scene_tree_get_property_name",
	"tool_action_system_scene_tree_get_property_desc",
	"tool_action_system_scene_tree_set_transform_name",
	"tool_action_system_scene_tree_set_transform_desc",
	"tool_action_system_scene_patch_add_node_name",
	"tool_action_system_scene_patch_add_node_desc",
	"tool_action_system_scene_patch_remove_node_name",
	"tool_action_system_scene_patch_remove_node_desc",
	"tool_action_system_scene_patch_rename_node_name",
	"tool_action_system_scene_patch_rename_node_desc",
	"tool_action_system_scene_patch_reparent_node_name",
	"tool_action_system_scene_patch_reparent_node_desc",
	"tool_action_system_scene_patch_attach_script_name",
	"tool_action_system_scene_patch_attach_script_desc",
	"tool_action_system_scene_patch_set_property_name",
	"tool_action_system_scene_patch_set_property_desc",
	"tool_action_system_scene_patch_update_property_name",
	"tool_action_system_scene_patch_update_property_desc"
]


class FakeServerContext extends RefCounted:
	var _tool_access_provider
	var _runtime_control_service

	func _init(tool_access_provider, runtime_control_service = null) -> void:
		_tool_access_provider = tool_access_provider
		_runtime_control_service = runtime_control_service

	func get_tool_access_provider():
		return _tool_access_provider

	func get_runtime_control_service():
		return _runtime_control_service


class FakeToolAccessProvider extends RefCounted:
	func is_tool_category_visible(_category: String) -> bool:
		return true

	func is_tool_category_executable(_category: String) -> bool:
		return true

	func get_tool_access_denied_message(_category: String) -> String:
		return "Tool category disabled"


class FakeRuntimeControlService extends RefCounted:
	func get_status() -> Dictionary:
		return {
			"available": true,
			"armed": false,
			"message": "Runtime control is disabled for the current session."
		}


var _loader = null


func run_case(_tree: SceneTree) -> Dictionary:
	_loader = ToolLoaderScript.new()
	_loader.configure(FakeServerContext.new(FakeToolAccessProvider.new(), FakeRuntimeControlService.new()))
	var summary: Dictionary = _loader.initialize([])
	if int(summary.get("tool_count", 0)) <= 0:
		return _failure("Tool localization inventory requires initialized tool definitions.")

	var tools_by_category: Dictionary = _loader.get_tools_by_category()
	var presentation: Dictionary = ToolPresentationServiceScript.build_tool_presentation(
		_loader.get_exposed_tool_definitions(),
		tools_by_category,
		_loader.get_domain_states()
	)
	var agent_presentation: Dictionary = ToolTreePresentationServiceScript.build_agent_tool_tree(
		_loader.get_exposed_tool_definitions()
	)
	var required_key_groups := _collect_required_visible_tool_key_groups(presentation, tools_by_category)
	required_key_groups.append_array(_collect_required_visible_tool_key_groups(agent_presentation, tools_by_category))
	var localization = LocalizationServiceScript.new()
	localization._init_translations()
	var locale_codes: Array[String] = localization.get_available_language_codes()
	var forbidden_removed_keys := _find_forbidden_removed_public_tool_keys(localization, locale_codes)
	if not forbidden_removed_keys.is_empty():
		return _failure("Removed tools should not keep visible localization keys: %s" % ", ".join(forbidden_removed_keys.slice(0, 120)))

	var description_keyword_gaps := _find_tool_description_keyword_gaps(localization, locale_codes)
	if not description_keyword_gaps.is_empty():
		return _failure("Visible tool descriptions are missing schema keywords: %s" % ", ".join(description_keyword_gaps.slice(0, 120)))

	var scene_tool_english_fallbacks := _find_scene_tool_english_fallbacks(localization, locale_codes)
	if not scene_tool_english_fallbacks.is_empty():
		return _failure("Scene tree and scene patch localization keys should not fall back to English in non-English locales: %s" % ", ".join(scene_tool_english_fallbacks.slice(0, 120)))

	var missing := _find_missing_key_groups(localization, locale_codes, required_key_groups)
	if not missing.is_empty():
		return _failure("Visible Tools page localization key groups are missing: %s" % ", ".join(missing.slice(0, 120)))
	return {
		"name": "tool_localization_inventory_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_category_count": tools_by_category.size(),
			"locale_count": locale_codes.size(),
			"required_key_group_count": required_key_groups.size()
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	if _loader != null and _loader.has_method("shutdown"):
		_loader.shutdown()
	_loader = null


func _collect_required_visible_tool_key_groups(presentation: Dictionary, tools_by_category: Dictionary) -> Array:
	var key_groups: Array = []
	var seen := {}
	var tool_index := _build_tool_index(tools_by_category)
	for node in presentation.get("toolTree", []):
		if node is Dictionary:
			_collect_visible_tree_node_key_groups(node as Dictionary, tool_index, key_groups, seen)
	return key_groups


func _build_tool_index(tools_by_category: Dictionary) -> Dictionary:
	var tool_index := {}
	for category in tools_by_category.keys():
		var category_name := str(category)
		for tool_def in tools_by_category.get(category, []):
			if not (tool_def is Dictionary):
				continue
			var tool := (tool_def as Dictionary).duplicate(true)
			if bool(tool.get("compatibility_alias", false)):
				continue
			var tool_name := str(tool.get("name", ""))
			if tool_name.is_empty():
				continue
			var full_name := "%s_%s" % [category_name, tool_name]
			tool["category"] = category_name
			tool["full_name"] = full_name
			tool_index[full_name] = tool
	return tool_index


func _collect_visible_tree_node_key_groups(node: Dictionary, tool_index: Dictionary, key_groups: Array, seen: Dictionary) -> void:
	var kind := str(node.get("kind", ""))
	match kind:
		"domain", "category", "tool_group":
			var label_key := str(node.get("labelKey", ""))
			_add_required_group(key_groups, seen, [label_key])
			_add_required_group(key_groups, seen, ["%s_desc" % label_key])
		"tool", "atomic":
			var full_name := str(node.get("fullName", node.get("key", "")))
			_add_required_group(key_groups, seen, ["tool_%s_name" % full_name])
			_add_required_group(key_groups, seen, ["tool_%s_desc" % full_name])
			_collect_schema_key_groups(tool_index.get(full_name, {}), full_name, key_groups, seen)
		"action":
			var parent_tool := str(node.get("parentTool", node.get("parent_tool", "")))
			var action_name := str(node.get("actionName", node.get("action", "")))
			_collect_action_key_groups(parent_tool, action_name, key_groups, seen)
	for child in node.get("children", []):
		if child is Dictionary:
			_collect_visible_tree_node_key_groups(child as Dictionary, tool_index, key_groups, seen)


func _collect_schema_key_groups(tool: Dictionary, full_name: String, key_groups: Array, seen: Dictionary) -> void:
	if tool.is_empty():
		return
	var input_schema = tool.get("inputSchema", {})
	if not (input_schema is Dictionary):
		return
	var properties = (input_schema as Dictionary).get("properties", {})
	if not (properties is Dictionary):
		return
	for property_name_value in (properties as Dictionary).keys():
		var property_name := str(property_name_value)
		var property_def = (properties as Dictionary).get(property_name, {})
		if not (property_def is Dictionary):
			continue
		if property_name == "action":
			for action_value in _get_preview_action_values(full_name, property_def as Dictionary):
				_collect_action_key_groups(full_name, str(action_value), key_groups, seen)
			continue
		if str((property_def as Dictionary).get("description", "")).is_empty():
			_collect_parameter_key_group(full_name, property_name, key_groups, seen)


func _get_preview_action_values(full_name: String, action_definition: Dictionary) -> Array[String]:
	if full_name.begins_with("system_"):
		return []
	var values: Array[String] = []
	for action_value in action_definition.get("enum", []):
		values.append(str(action_value))
	return values


func _collect_action_key_groups(parent_tool: String, action_name: String, key_groups: Array, seen: Dictionary) -> void:
	if parent_tool.is_empty() or action_name.is_empty():
		return
	_add_required_group(key_groups, seen, [
		SystemTreeCatalog.get_action_name_key(parent_tool, action_name),
		SystemTreeCatalog.get_generic_action_name_key(action_name),
		"tool_action_name_fallback"
	])
	_add_required_group(key_groups, seen, [
		SystemTreeCatalog.get_action_desc_key(parent_tool, action_name),
		SystemTreeCatalog.get_generic_action_desc_key(action_name),
		"tool_action_desc_fallback"
	])


func _collect_parameter_key_group(full_name: String, property_name: String, key_groups: Array, seen: Dictionary) -> void:
	if full_name.is_empty() or property_name.is_empty():
		return
	var keys: Array[String] = ["tool_param_%s_%s_desc" % [full_name, property_name]]
	if full_name == "dap_debugger":
		keys.append("tool_param_system_dap_debugger_%s_desc" % property_name)
	keys.append("tool_param_%s_desc" % property_name)
	keys.append("tool_param_desc_fallback")
	_add_required_group(key_groups, seen, keys)


func _add_required_group(key_groups: Array, seen: Dictionary, keys: Array) -> void:
	var normalized: Array[String] = []
	for key in keys:
		var key_text := str(key)
		if key_text.is_empty():
			continue
		normalized.append(key_text)
	normalized.sort()
	if normalized.is_empty():
		return
	var signature := "|".join(normalized)
	if seen.has(signature):
		return
	seen[signature] = true
	key_groups.append(normalized)


func _find_missing_key_groups(localization, locale_codes: Array[String], required_key_groups: Array) -> Array[String]:
	var missing: Array[String] = []
	var seen := {}
	for locale_name in locale_codes:
		for key_group in required_key_groups:
			if _has_any_translation(localization, locale_name, key_group):
				continue
			var label := " or ".join(key_group)
			if seen.has(label):
				continue
			seen[label] = true
			missing.append(label)
	missing.sort()
	return missing


func _has_any_translation(localization, locale_name: String, key_group: Array) -> bool:
	for key in key_group:
		var key_text := str(key)
		if localization.get_text_for(locale_name, key_text) != key_text:
			return true
	return false


func _find_forbidden_removed_public_tool_keys(localization, locale_codes: Array[String]) -> Array[String]:
	var found: Array[String] = []
	for locale_name in locale_codes:
		for key in REMOVED_PUBLIC_TOOL_LOCALIZATION_KEYS:
			if localization.get_text_for(locale_name, key) != key:
				found.append("%s:%s" % [locale_name, key])
	found.sort()
	return found


func _find_tool_description_keyword_gaps(localization, locale_codes: Array[String]) -> Array[String]:
	var gaps: Array[String] = []
	for locale_name in locale_codes:
		for key in TOOL_DESCRIPTION_KEYWORD_REQUIREMENTS.keys():
			var text := str(localization.get_text_for(locale_name, str(key)))
			for keyword in TOOL_DESCRIPTION_KEYWORD_REQUIREMENTS[key]:
				var keyword_text := str(keyword)
				if not text.contains(keyword_text):
					gaps.append("%s:%s missing '%s'" % [locale_name, key, keyword_text])
	gaps.sort()
	return gaps


func _find_scene_tool_english_fallbacks(localization, locale_codes: Array[String]) -> Array[String]:
	var fallbacks: Array[String] = []
	var english_text_by_key := {}
	for key in SCENE_TOOL_LOCALIZATION_KEYS:
		english_text_by_key[key] = str(localization.get_text_for("en", key))
	for locale_name in locale_codes:
		if locale_name == "en":
			continue
		for key in SCENE_TOOL_LOCALIZATION_KEYS:
			var localized := str(localization.get_text_for(locale_name, key))
			if localized == str(english_text_by_key.get(key, "")):
				fallbacks.append("%s:%s" % [locale_name, key])
	fallbacks.sort()
	return fallbacks


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_localization_inventory_contracts",
		"success": false,
		"error": message
	}
