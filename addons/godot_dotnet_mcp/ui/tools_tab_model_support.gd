@tool
extends RefCounted

const SystemTreeCatalog = preload("res://addons/godot_dotnet_mcp/plugin/runtime/system_tree_catalog.gd")

const CATEGORY_LABEL_KEYS := {
	"scene": "cat_scene",
	"node": "cat_node",
	"script": "cat_script",
	"resource": "cat_resource",
	"filesystem": "cat_filesystem",
	"project": "cat_project",
	"editor": "cat_editor",
	"plugin_runtime": "cat_plugin_runtime",
	"plugin_evolution": "cat_plugin_evolution",
	"plugin_developer": "cat_plugin_developer",
	"debug": "cat_debug",
	"animation": "cat_animation",
	"signal": "cat_signal",
	"group": "cat_group",
	"material": "cat_material",
	"shader": "cat_shader",
	"lighting": "cat_lighting",
	"particle": "cat_particle",
	"tilemap": "cat_tilemap",
	"geometry": "cat_geometry",
	"physics": "cat_physics",
	"navigation": "cat_navigation",
	"audio": "cat_audio",
	"ui": "cat_ui",
	"user": "cat_user",
	"system": "cat_system"
}


static func count_enabled_tools(model: Dictionary, filtered_tools_by_category: Dictionary, categories: Array = ["system", "user"]) -> Array:
	var total := 0
	var enabled := 0
	var disabled_tools: Array = model.get("settings", {}).get("disabled_tools", [])
	for category_variant in categories:
		var category := str(category_variant)
		for tool_def in get_filtered_tool_definitions(filtered_tools_by_category, category):
			total += 1
			var full_name = "%s_%s" % [category, tool_def.get("name", "")]
			if not disabled_tools.has(full_name):
				enabled += 1
	return [enabled, total]


static func count_categories(model: Dictionary, filtered_tools_by_category: Dictionary, categories: Array) -> Dictionary:
	var total := 0
	var enabled := 0
	for category_variant in categories:
		var counts = count_category(model, filtered_tools_by_category, str(category_variant))
		total += int(counts.get("total", 0))
		enabled += int(counts.get("enabled", 0))
	return {"total": total, "enabled": enabled}


static func count_category(model: Dictionary, filtered_tools_by_category: Dictionary, category: String) -> Dictionary:
	var total := 0
	var enabled := 0
	var disabled_tools: Array = model.get("settings", {}).get("disabled_tools", [])
	for tool_def in get_filtered_tool_definitions(filtered_tools_by_category, category):
		total += 1
		var full_name = "%s_%s" % [category, tool_def.get("name", "")]
		if not disabled_tools.has(full_name):
			enabled += 1
	return {"total": total, "enabled": enabled}


static func is_domain_fully_enabled(model: Dictionary, filtered_tools_by_category: Dictionary, categories: Array) -> bool:
	var counts = count_categories(model, filtered_tools_by_category, categories)
	return int(counts.get("total", 0)) > 0 and int(counts.get("total", 0)) == int(counts.get("enabled", 0))


static func is_category_fully_enabled(model: Dictionary, filtered_tools_by_category: Dictionary, category: String) -> bool:
	var counts = count_category(model, filtered_tools_by_category, category)
	return int(counts.get("total", 0)) > 0 and int(counts.get("total", 0)) == int(counts.get("enabled", 0))


static func get_filtered_tool_definitions(filtered_tools_by_category: Dictionary, category: String) -> Array:
	var tools = filtered_tools_by_category.get(category, [])
	return tools if tools is Array else []


static func get_category_label(localization, category: String) -> String:
	var key = CATEGORY_LABEL_KEYS.get(category, category)
	var translated = _get_text(localization, str(key))
	return translated if translated != key else category.capitalize()


static func get_category_label_key(category: String) -> String:
	return str(CATEGORY_LABEL_KEYS.get(category, category))


static func get_group_tooltip(localization, label_key: String) -> String:
	var desc_key = "%s_desc" % label_key
	var translated = _get_text(localization, desc_key)
	return translated if translated != desc_key else ""


static func get_tool_display_name(localization, full_name: String, tool_name: String) -> String:
	var key = "tool_%s_name" % full_name
	var translated = _get_text(localization, key)
	return translated if translated != key else humanize_identifier(tool_name)


static func get_tool_description(localization, full_name: String, tool_def: Dictionary) -> String:
	var key = "tool_%s_desc" % full_name
	var translated = _get_text(localization, key)
	if translated != key:
		return translated
	return str(tool_def.get("description", ""))


static func get_action_display_name(localization, parent_tool: String, action_name: String) -> String:
	if localization != null:
		var specific_key = SystemTreeCatalog.get_action_name_key(parent_tool, action_name)
		var translated = _get_text(localization, specific_key)
		if translated != specific_key:
			return translated
		var generic_key = SystemTreeCatalog.get_generic_action_name_key(action_name)
		translated = _get_text(localization, generic_key)
		if translated != generic_key:
			return translated
	return humanize_identifier(action_name)


static func get_action_description(localization, parent_tool: String, action_name: String, tool_def: Dictionary) -> String:
	var action_display_name = get_action_display_name(localization, parent_tool, action_name)
	var parent_display_name = parent_tool
	if not tool_def.is_empty():
		var tool_name = str(tool_def.get("name", ""))
		if not tool_name.is_empty():
			parent_display_name = get_tool_display_name(localization, parent_tool, tool_name)
	if localization != null:
		var specific_key = SystemTreeCatalog.get_action_desc_key(parent_tool, action_name)
		var translated = _get_text(localization, specific_key)
		if translated != specific_key:
			return translated
		var generic_key = SystemTreeCatalog.get_generic_action_desc_key(action_name)
		translated = _get_text(localization, generic_key)
		if translated != generic_key:
			return translated
		var fallback_key = "tool_action_desc_fallback"
		var fallback_template = _get_text(localization, fallback_key)
		if fallback_template != fallback_key:
			var fallback_text = fallback_template % [action_display_name, parent_display_name]
			var tool_description = get_tool_description(localization, parent_tool, tool_def)
			if not tool_description.is_empty():
				fallback_text += "\n\n" + tool_description
			return fallback_text
	return ""


static func humanize_identifier(value: String) -> String:
	var parts: Array[String] = []
	for word in value.split("_"):
		if word.is_empty():
			continue
		parts.append(word.substr(0, 1).to_upper() + word.substr(1))
	return " ".join(parts)


static func get_category_load_error_messages(model: Dictionary, category: String) -> Array[String]:
	var messages: Array[String] = []
	for error_info in model.get("tool_load_errors", []):
		if not (error_info is Dictionary):
			continue
		var info := error_info as Dictionary
		if str(info.get("category", "")) != category:
			continue
		messages.append(str(info.get("message", "Tool domain load failed")))
	return messages


static func find_domain_definition(model: Dictionary, domain_key: String) -> Dictionary:
	for domain_def in model.get("domain_defs", []):
		if str(domain_def.get("key", "")) == domain_key:
			return (domain_def as Dictionary).duplicate(true)
	if domain_key == "other":
		return {
			"key": "other",
			"label": "domain_other",
			"categories": []
		}
	return {}


static func find_tool_definition(model: Dictionary, category: String, tool_name: String) -> Dictionary:
	for tool_def in model.get("tools_by_category", {}).get(category, []):
		if str(tool_def.get("name", "")) == tool_name:
			return (tool_def as Dictionary).duplicate(true)
	return {}


static func get_tool_def_by_full_name(model: Dictionary, full_name: String) -> Dictionary:
	var category = extract_category_from_full_name(model, full_name)
	if category.is_empty():
		return {}
	var tool_name = full_name.trim_prefix("%s_" % category)
	for tool_def in model.get("tools_by_category", {}).get(category, []):
		if str(tool_def.get("name", "")) == tool_name:
			return (tool_def as Dictionary).duplicate(true)
	return {}


static func extract_category_from_full_name(model: Dictionary, full_name: String) -> String:
	for category in model.get("tools_by_category", {}).keys():
		var category_name = str(category)
		if full_name.begins_with("%s_" % category_name):
			return category_name
	return ""


static func extract_action_values(tool_def: Dictionary) -> Array[String]:
	var actions: Array[String] = []
	var input_schema = tool_def.get("inputSchema", {})
	if not (input_schema is Dictionary):
		return actions
	var properties = (input_schema as Dictionary).get("properties", {})
	if not (properties is Dictionary):
		return actions
	var action_definition = (properties as Dictionary).get("action", {})
	if not (action_definition is Dictionary):
		return actions
	for value in (action_definition as Dictionary).get("enum", []):
		actions.append(str(value))
	return actions


static func build_parameter_preview_lines(localization, tool_def: Dictionary) -> Array[String]:
	var input_schema = tool_def.get("inputSchema", {})
	if not (input_schema is Dictionary):
		return []
	var properties = (input_schema as Dictionary).get("properties", {})
	if not (properties is Dictionary):
		return []
	var required_lookup: Dictionary = {}
	for required_name in (input_schema as Dictionary).get("required", []):
		required_lookup[str(required_name)] = true
	var property_names: Array = (properties as Dictionary).keys()
	property_names.sort()
	var lines: Array[String] = []
	for property_name in property_names:
		var property_def = (properties as Dictionary).get(property_name, {})
		if not (property_def is Dictionary):
			continue
		lines.append("- %s" % format_parameter_summary(localization, str(property_name), property_def as Dictionary, required_lookup))
	return lines


static func build_action_parameter_lines(localization, tool_def: Dictionary) -> Array[String]:
	var input_schema = tool_def.get("inputSchema", {})
	if not (input_schema is Dictionary):
		return []
	var properties = (input_schema as Dictionary).get("properties", {})
	if not (properties is Dictionary):
		return []
	var required_lookup: Dictionary = {}
	for required_name in (input_schema as Dictionary).get("required", []):
		required_lookup[str(required_name)] = true
	var property_names: Array = (properties as Dictionary).keys()
	property_names.sort()
	var lines: Array[String] = []
	for property_name in property_names:
		if property_name == "action":
			continue
		var property_def = (properties as Dictionary).get(property_name, {})
		if not (property_def is Dictionary):
			continue
		lines.append("- %s" % format_parameter_summary(localization, str(property_name), property_def as Dictionary, required_lookup))
	return lines


static func format_parameter_summary(localization, property_name: String, property_def: Dictionary, required_lookup: Dictionary) -> String:
	var parts: Array[String] = [property_name]
	var type_name = str(property_def.get("type", "any"))
	parts.append(type_name)
	if required_lookup.has(property_name):
		parts.append(_get_text(localization, "tool_preview_required"))
	if property_def.has("enum"):
		var values: Array[String] = []
		for value in property_def.get("enum", []):
			values.append(str(value))
		parts.append("enum=%s" % ", ".join(values))
	var description = str(property_def.get("description", ""))
	if not description.is_empty():
		parts.append(description)
	return " | ".join(parts)


static func count_previewable_tools(tools: Array) -> int:
	var count := 0
	for _tool_def in tools:
		count += 1
	return count


static func filter_empty_preview_lines(lines: Array[String]) -> Array[String]:
	var filtered: Array[String] = []
	var previous_empty := false
	for line in lines:
		var text = str(line)
		if text.is_empty():
			if previous_empty:
				continue
			previous_empty = true
			filtered.append("")
			continue
		previous_empty = false
		filtered.append(text)
	return filtered


static func _get_text(localization, key: String) -> String:
	if localization == null:
		return key
	return localization.get_text(key)
