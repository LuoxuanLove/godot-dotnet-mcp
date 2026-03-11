@tool
extends RefCounted
class_name SettingsStore


func load_plugin_settings(default_settings: Dictionary, settings_path: String, all_categories: Array, default_domains: Array) -> Dictionary:
	var settings = default_settings.duplicate(true)
	var has_settings_file = FileAccess.file_exists(settings_path)

	if has_settings_file:
		var file = FileAccess.open(settings_path, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				var data = json.get_data()
				if data is Dictionary:
					settings.merge(data, true)
			file.close()
	else:
		settings["collapsed_categories"] = all_categories.duplicate()
		settings["collapsed_domains"] = default_domains.duplicate()

	if str(settings.get("tool_profile_id", "")).is_empty():
		settings["tool_profile_id"] = "default"

	if has_settings_file:
		if not settings.has("collapsed_categories"):
			settings["collapsed_categories"] = all_categories.duplicate()
		if not settings.has("collapsed_domains"):
			settings["collapsed_domains"] = default_domains.duplicate()

	return {
		"settings": settings,
		"has_settings_file": has_settings_file
	}


func save_plugin_settings(settings_path: String, settings: Dictionary) -> void:
	var file = FileAccess.open(settings_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()


func load_custom_profiles(profile_dir: String) -> Dictionary:
	var profiles: Dictionary = {}
	var dir = DirAccess.open(profile_dir)
	if dir == null:
		return profiles

	dir.list_dir_begin()
	while true:
		var file_name = dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir() or not file_name.ends_with(".json"):
			continue

		var slug = file_name.get_basename()
		var file_path = _build_profile_file_path(profile_dir, slug)
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			continue

		var json = JSON.new()
		var text = file.get_as_text()
		file.close()
		if json.parse(text) != OK:
			continue

		var data = json.get_data()
		if not (data is Dictionary):
			continue

		var profile_id = "custom:%s" % slug
		var disabled_tools = data.get("disabled_tools", [])
		if not (disabled_tools is Array):
			disabled_tools = []
		profiles[profile_id] = {
			"id": profile_id,
			"name": str(data.get("name", slug)),
			"file_path": file_path,
			"disabled_tools": disabled_tools
		}
	dir.list_dir_end()
	return profiles


func save_custom_profile(profile_dir: String, profile_name: String, disabled_tools: Array) -> Dictionary:
	var user_dir = DirAccess.open("user://")
	if user_dir == null:
		return {"success": false}

	var relative_dir = profile_dir.trim_prefix("user://")
	if not user_dir.dir_exists(relative_dir):
		var dir_error = user_dir.make_dir_recursive(relative_dir)
		if dir_error != OK:
			return {"success": false}

	var slug = _slugify_profile_name(profile_name)
	var file_path = _build_profile_file_path(profile_dir, slug)
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return {"success": false}

	file.store_string(JSON.stringify({
		"name": profile_name,
		"disabled_tools": disabled_tools
	}, "\t"))
	file.close()

	return {
		"success": true,
		"slug": slug,
		"file_path": file_path
	}


func delete_custom_profile(profile_dir: String, profile_id: String) -> Dictionary:
	var slug = _custom_profile_slug_from_id(profile_id)
	if slug.is_empty():
		return {"success": false, "error_code": "invalid_profile_id"}

	var file_path = _build_profile_file_path(profile_dir, slug)
	if not FileAccess.file_exists(file_path):
		return {"success": false, "error_code": "profile_not_found", "profile_id": profile_id}

	var error = DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	if error != OK:
		return {"success": false, "error_code": "delete_failed", "profile_id": profile_id, "file_path": file_path}

	return {"success": true, "profile_id": profile_id, "file_path": file_path}


func rename_custom_profile(profile_dir: String, profile_id: String, profile_name: String) -> Dictionary:
	var slug = _custom_profile_slug_from_id(profile_id)
	if slug.is_empty():
		return {"success": false, "error_code": "invalid_profile_id"}

	var trimmed_name = profile_name.strip_edges()
	if trimmed_name.is_empty():
		return {"success": false, "error_code": "empty_profile_name", "profile_id": profile_id}

	var old_file_path = _build_profile_file_path(profile_dir, slug)
	var read_result = _read_custom_profile_file(old_file_path)
	if not bool(read_result.get("success", false)):
		return {
			"success": false,
			"error_code": str(read_result.get("error_code", "profile_not_found")),
			"profile_id": profile_id,
			"file_path": old_file_path
		}

	var new_slug = _slugify_profile_name(trimmed_name)
	var new_profile_id = "custom:%s" % new_slug
	var new_file_path = _build_profile_file_path(profile_dir, new_slug)
	if new_slug != slug and FileAccess.file_exists(new_file_path):
		return {
			"success": false,
			"error_code": "profile_name_conflict",
			"profile_id": profile_id,
			"new_profile_id": new_profile_id,
			"file_path": new_file_path
		}

	var disabled_tools = read_result.get("data", {}).get("disabled_tools", [])
	if not (disabled_tools is Array):
		disabled_tools = []

	var save_result = save_custom_profile(profile_dir, trimmed_name, disabled_tools)
	if not bool(save_result.get("success", false)):
		return {"success": false, "error_code": "save_failed", "profile_id": profile_id}

	if new_slug != slug:
		var delete_error = DirAccess.remove_absolute(ProjectSettings.globalize_path(old_file_path))
		if delete_error != OK:
			return {
				"success": false,
				"error_code": "delete_failed",
				"profile_id": profile_id,
				"file_path": old_file_path
			}

	return {
		"success": true,
		"old_profile_id": profile_id,
		"profile_id": new_profile_id,
		"profile_name": trimmed_name,
		"file_path": new_file_path,
		"slug": new_slug
	}


func _slugify_profile_name(profile_name: String) -> String:
	var lowered = profile_name.strip_edges().to_lower()
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_-]+")
	var sanitized = regex.sub(lowered, "_", true).strip_edges()
	sanitized = sanitized.trim_prefix("_").trim_suffix("_")
	return sanitized if not sanitized.is_empty() else "custom_profile"


func _build_profile_file_path(profile_dir: String, profile_slug: String) -> String:
	return "%s/%s.json" % [profile_dir, profile_slug]


func _custom_profile_slug_from_id(profile_id: String) -> String:
	if not profile_id.begins_with("custom:"):
		return ""
	return profile_id.trim_prefix("custom:")


func _read_custom_profile_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {"success": false, "error_code": "profile_not_found"}

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {"success": false, "error_code": "profile_open_failed"}

	var json = JSON.new()
	var text = file.get_as_text()
	file.close()
	if json.parse(text) != OK:
		return {"success": false, "error_code": "profile_parse_failed"}

	var data = json.get_data()
	if not (data is Dictionary):
		return {"success": false, "error_code": "profile_parse_failed"}

	return {"success": true, "data": data}
