@tool
extends RefCounted
class_name ToolCatalogService


func find_domain_key_for_category(domain_defs: Array, category: String) -> String:
	for domain_def in domain_defs:
		if category in domain_def.get("categories", []):
			return str(domain_def.get("key", ""))
	return ""


func get_disabled_tools_for_profile(profile_id: String, builtin_profiles: Array, custom_profiles: Dictionary, tool_names: Array, current_disabled_tools: Array) -> Array:
	for profile in builtin_profiles:
		if str(profile.get("id", "")) == profile_id:
			return _get_disabled_tools_for_builtin_profile(profile, tool_names)

	if custom_profiles.has(profile_id):
		var disabled_tools = custom_profiles[profile_id].get("disabled_tools", [])
		return disabled_tools.duplicate() if disabled_tools is Array else []

	return current_disabled_tools.duplicate()


func has_tool_profile(profile_id: String, builtin_profiles: Array, custom_profiles: Dictionary) -> bool:
	if profile_id.is_empty():
		return false
	for profile in builtin_profiles:
		if str(profile.get("id", "")) == profile_id:
			return true
	return custom_profiles.has(profile_id)


func find_matching_profile_id(disabled_tools: Array, builtin_profiles: Array, custom_profiles: Dictionary, tool_names: Array) -> String:
	for profile in builtin_profiles:
		var profile_id = str(profile.get("id", ""))
		if profile_matches_state(profile_id, disabled_tools, builtin_profiles, custom_profiles, tool_names):
			return profile_id

	for profile_id in custom_profiles.keys():
		if profile_matches_state(str(profile_id), disabled_tools, builtin_profiles, custom_profiles, tool_names):
			return str(profile_id)

	return ""


func profile_matches_state(profile_id: String, disabled_tools: Array, builtin_profiles: Array, custom_profiles: Dictionary, tool_names: Array) -> bool:
	var left = get_disabled_tools_for_profile(profile_id, builtin_profiles, custom_profiles, tool_names, disabled_tools)
	var right = disabled_tools.duplicate()
	left.sort()
	right.sort()
	return left == right


func get_sorted_custom_profile_ids(custom_profiles: Dictionary) -> Array:
	var ids = custom_profiles.keys()
	ids.sort()
	return ids


func count_tools_by_category(category: String, enabled_tools: Dictionary) -> Dictionary:
	var total = 0
	var enabled = 0
	for tool_name in enabled_tools.keys():
		if str(tool_name).begins_with(category + "_"):
			total += 1
			if enabled_tools[tool_name]:
				enabled += 1
	return {"total": total, "enabled": enabled}


func count_tools_by_categories(categories: Array, enabled_tools: Dictionary) -> Dictionary:
	var total = 0
	var enabled = 0
	for category in categories:
		var counts = count_tools_by_category(str(category), enabled_tools)
		total += int(counts["total"])
		enabled += int(counts["enabled"])
	return {"total": total, "enabled": enabled}


func build_tool_name_index(tools_by_category: Dictionary) -> Array:
	var tool_names: Array = []
	for category in tools_by_category.keys():
		for tool_def in tools_by_category[category]:
			tool_names.append("%s_%s" % [category, tool_def.get("name", "")])
	tool_names.sort()
	return tool_names


func _get_disabled_tools_for_builtin_profile(profile: Dictionary, tool_names: Array) -> Array:
	var enabled_categories = profile.get("enabled_categories", [])
	if enabled_categories.is_empty():
		return []

	var disabled: Array = []
	for tool_name in tool_names:
		var category = str(tool_name).split("_")[0]
		if not enabled_categories.has(category):
			disabled.append(tool_name)

	disabled.sort()
	return disabled
